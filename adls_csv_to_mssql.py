#!/usr/bin/env python3
"""Load CSV files from Azure OneLake into SQL Server, then mark them as done.

This is a pure-Python loader: it talks to OneLake with the Azure Data Lake
Storage Gen2 SDK and to SQL Server with pyodbc, so it needs neither Spark nor
Hadoop. OneLake only supports Microsoft Entra ID (Azure AD) authentication, so
credentials are resolved through azure-identity's DefaultAzureCredential
(environment variables, managed identity, Azure CLI login, and so on).

Dependencies:
    pip install azure-storage-file-datalake azure-identity pyodbc

SQL Server also requires the Microsoft ODBC Driver for SQL Server.

Required environment variables:
    MSSQL_ODBC_CONNECTION_STRING
        e.g. Driver={ODBC Driver 18 for SQL Server};Server=tcp:sql.example.net,1433;
             Database=Sales;Uid=user;Pwd=password;Encrypt=yes;TrustServerCertificate=no;

Example:
    python adls_csv_to_mssql.py \
      --source-dir 'abfss://Sales@onelake.dfs.fabric.microsoft.com/Bronze.Lakehouse/Files/orders' \
      --table dbo.Orders
"""

from __future__ import annotations

import argparse
import csv
import io
import logging
import os
import sys
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple
from urllib.parse import urlsplit

import pyodbc
from azure.core.exceptions import ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from azure.storage.filedatalake import DataLakeServiceClient, FileSystemClient


LOGGER = logging.getLogger("adls_csv_to_mssql")

ONELAKE_ACCOUNT_URL = "https://onelake.dfs.fabric.microsoft.com"
DONE_SUFFIX = ".done"


@dataclass(frozen=True)
class SourceLocation:
    """A parsed OneLake location split into account, workspace, and path."""

    account_url: str
    workspace: str
    directory: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Append each OneLake CSV file to SQL Server and rename it with .done."
    )
    parser.add_argument(
        "--source-dir",
        required=True,
        help=(
            "OneLake folder, for example "
            "abfss://Workspace@onelake.dfs.fabric.microsoft.com/Item.Lakehouse/Files/inbound"
        ),
    )
    parser.add_argument(
        "--table",
        required=True,
        help="Destination SQL Server table, for example dbo.Orders.",
    )
    parser.add_argument(
        "--columns",
        help=(
            "Optional comma-separated destination column list, for example "
            "'order_id,customer_id,amount'. Defaults to the CSV header row; "
            "required when --no-header is used."
        ),
    )
    parser.add_argument("--delimiter", default=",", help="CSV delimiter (default: comma).")
    parser.add_argument(
        "--no-header",
        action="store_true",
        help="Treat the first CSV row as data instead of column names.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1000,
        help="Row insert batch size (default: 1000).",
    )
    parser.add_argument(
        "--encoding",
        default="utf-8-sig",
        help="Text encoding used to decode CSV files (default: utf-8-sig).",
    )
    args = parser.parse_args()

    if args.batch_size < 1:
        parser.error("--batch-size must be at least 1")
    if args.no_header and not args.columns:
        parser.error("--columns is required when --no-header is used")

    return args


def required_environment_variable(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Required environment variable {name} is not set")
    return value


def parse_source_location(source_dir: str) -> SourceLocation:
    """Split a OneLake URL into its account, workspace, and directory parts.

    Accepts both the abfss form
        abfss://<workspace>@onelake.dfs.fabric.microsoft.com/<path>
    and the https form
        https://onelake.dfs.fabric.microsoft.com/<workspace>/<path>
    """
    parsed = urlsplit(source_dir)
    scheme = parsed.scheme.lower()

    if scheme == "abfss":
        if not parsed.username:
            raise ValueError(
                "abfss URL must include the workspace, for example "
                "abfss://Workspace@onelake.dfs.fabric.microsoft.com/..."
            )
        workspace = parsed.username
        host = parsed.hostname or ""
        directory = parsed.path.lstrip("/")
    elif scheme == "https":
        host = parsed.hostname or ""
        segments = parsed.path.lstrip("/").split("/", 1)
        if not segments or not segments[0]:
            raise ValueError(
                "https URL must include the workspace, for example "
                "https://onelake.dfs.fabric.microsoft.com/Workspace/..."
            )
        workspace = segments[0]
        directory = segments[1] if len(segments) > 1 else ""
    else:
        raise ValueError(f"Unsupported source URL scheme: {source_dir!r}")

    if not host:
        raise ValueError(f"Source URL is missing a host: {source_dir!r}")

    return SourceLocation(
        account_url=f"https://{host}",
        workspace=workspace,
        directory=directory.rstrip("/"),
    )


def file_system_client(location: SourceLocation) -> FileSystemClient:
    service = DataLakeServiceClient(
        account_url=location.account_url,
        credential=DefaultAzureCredential(),
    )
    return service.get_file_system_client(location.workspace)


def list_csv_files(filesystem: FileSystemClient, directory: str) -> List[str]:
    try:
        paths = filesystem.get_paths(path=directory or None, recursive=False)
        files = [
            path.name
            for path in paths
            if not path.is_directory and path.name.lower().endswith(".csv")
        ]
    except ResourceNotFoundError as error:
        raise FileNotFoundError(f"Source folder does not exist: {directory}") from error
    return sorted(files)


def done_path(path: str) -> str:
    return f"{path}{DONE_SUFFIX}"


def read_rows(
    filesystem: FileSystemClient,
    path: str,
    *,
    delimiter: str,
    has_header: bool,
    encoding: str,
    explicit_columns: Optional[List[str]],
) -> Tuple[List[str], List[Tuple[object, ...]]]:
    """Download a CSV file and return its columns and rows.

    Empty string fields become None so they arrive at SQL Server as NULL.
    """
    file_client = filesystem.get_file_client(path)
    raw = file_client.download_file().readall()
    text = raw.decode(encoding)
    reader = csv.reader(io.StringIO(text), delimiter=delimiter)

    if has_header:
        try:
            header = next(reader)
        except StopIteration:
            return (explicit_columns or [], [])
        columns = explicit_columns or [name.strip() for name in header]
    else:
        columns = explicit_columns or []

    rows = [tuple(value if value != "" else None for value in row) for row in reader]
    return columns, rows


def insert_statement(table: str, columns: Sequence[str], value_count: int) -> str:
    placeholders = ", ".join("?" for _ in range(value_count))
    if columns:
        column_list = ", ".join(columns)
        return f"INSERT INTO {table} ({column_list}) VALUES ({placeholders})"
    return f"INSERT INTO {table} VALUES ({placeholders})"


def insert_rows(
    connection: "pyodbc.Connection",
    table: str,
    columns: Sequence[str],
    rows: Sequence[Tuple[object, ...]],
    batch_size: int,
) -> None:
    if not rows:
        return

    value_count = len(columns) if columns else len(rows[0])
    statement = insert_statement(table, columns, value_count)

    cursor = connection.cursor()
    cursor.fast_executemany = True
    try:
        for start in range(0, len(rows), batch_size):
            cursor.executemany(statement, rows[start : start + batch_size])
    finally:
        cursor.close()


def rename_as_done(filesystem: FileSystemClient, path: str) -> str:
    destination = done_path(path)
    file_client = filesystem.get_file_client(path)
    # rename_file expects the destination as "<filesystem>/<path>".
    file_client.rename_file(f"{filesystem.file_system_name}/{destination}")
    return destination


def process_file(
    filesystem: FileSystemClient,
    path: str,
    args: argparse.Namespace,
    connection: "pyodbc.Connection",
) -> None:
    # Check before inserting so an existing .done name cannot cause a known
    # post-insert rename failure.
    if filesystem.get_file_client(done_path(path)).exists():
        raise FileExistsError(f"Done file already exists: {done_path(path)}")

    columns, rows = read_rows(
        filesystem,
        path,
        delimiter=args.delimiter,
        has_header=not args.no_header,
        encoding=args.encoding,
        explicit_columns=(
            [name.strip() for name in args.columns.split(",")] if args.columns else None
        ),
    )

    try:
        insert_rows(connection, args.table, columns, rows, args.batch_size)
        connection.commit()
    except Exception:
        connection.rollback()
        raise

    done_uri = rename_as_done(filesystem, path)
    LOGGER.info("Loaded %s (%d row(s)) and renamed it to %s", path, len(rows), done_uri)


def main() -> int:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    args = parse_args()

    try:
        odbc_connection_string = required_environment_variable(
            "MSSQL_ODBC_CONNECTION_STRING"
        )
        location = parse_source_location(args.source_dir)
    except (RuntimeError, ValueError) as error:
        LOGGER.error("%s", error)
        return 2

    filesystem = file_system_client(location)
    connection = pyodbc.connect(odbc_connection_string, autocommit=False)
    try:
        csv_files = list_csv_files(filesystem, location.directory)
        LOGGER.info("Found %d CSV file(s) in %s", len(csv_files), args.source_dir)

        failed_files = []
        for path in csv_files:
            LOGGER.info("Processing %s", path)
            try:
                process_file(filesystem, path, args, connection)
            except Exception:
                failed_files.append(path)
                LOGGER.exception(
                    "Failed to process %s; the source file was not renamed", path
                )

        if failed_files:
            LOGGER.error(
                "%d file(s) failed: %s", len(failed_files), ", ".join(failed_files)
            )
            return 1

        LOGGER.info("All CSV files were processed successfully")
        return 0
    finally:
        connection.close()
        filesystem.close()


if __name__ == "__main__":
    sys.exit(main())
