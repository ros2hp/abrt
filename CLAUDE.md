# ABRT Business Rules Extraction Project

## Purpose
Extract business rules from legacy PL/SQL code (Oracle 7 / Oracle Forms 3) using the Abstract Business Rule Tree (ABRT) formal model, and generate equivalent Rust implementations.

## ABRT Specification
- Current version: **v1.1** (`ABRT_PL-SQL_Business_Rules.md`)
- Oracle Forms 3 extension: **v2.0** (`ABRT_Oracle_Forms3_Extension.md`)
- Always follow the ABRT node taxonomy and grammar defined in these specs

### Key Rules
- Use `TRIGGER_OPERATION` (not `BUSINESS_OPERATION`) for Oracle database triggers
- Each `TRIGGER_OPERATION` must specify: `trigger_name`, `table_name`, `trigger_timing`, `trigger_event`, `trigger_level`
- If no business rule name is found in comments or code, default to the trigger name as the business rule label
- Use `FORM_OPERATION` for Oracle Forms 3 triggers (v2.0 extension)
- Flag all hard-coded LITERAL constants with `review_flag: true`
- Note discrepancies between code behaviour and comments/error messages (e.g., Sunday vs weekends)

## JSON Output
- ABRT JSON files use `_abrt.json` suffix (e.g., `example_abrt.json`)
- Top-level keys: `abrt_version`, `application`, `source_file`, `trigger_operations`, `business_operations`
- Always validate JSON after writing
- Use `"ref"` for cross-references to avoid duplicating DATA_INPUT/FORMULA nodes

## Project Structure
```
example.sql             — Source PL/SQL to extract from
example_abrt.json       — ABRT JSON output
ABRT_PL-SQL_Business_Rules.md      — ABRT v1.1 spec
ABRT_Oracle_Forms3_Extension.md    — ABRT v2.0 Forms extension
.mcp.json               — MySQL MCP server config (credentials via env vars)
```

## Database
- MySQL MCP server configured in `.mcp.json`
- Credentials passed via environment variables (`MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`)
- Rust code targets MySQL via sqlx 
