---
name: extract-nodb
description: Extract business rules from PL/SQL files in an `IN/` directory using the ABRT v1.8 specification, write fresh `_abrt.json` files to `OUT/`, perform validation and gap analysis, and move processed inputs to `DONE/` without loading a database. Use when the user wants ABRT JSON output only from Oracle PL/SQL source files.
---

# ABRT Extraction Pipeline (No DB)

Use this skill when the user wants to process one or more Oracle PL/SQL `.sql` files into ABRT JSON without any MySQL or other database load step. This is the Codex version of the Claude skill named `extract_nodb`.

## Required Inputs

- A working directory containing `IN/`, `OUT/`, and `DONE/`
- Source `.sql` files in `IN/`
- The ABRT reference docs, usually at repo root or under `references/`:
  - `ABRT_PL-SQL_Business_Rules.md`
  - `ABRT_Oracle_Forms3_Extension.md`

If the directories do not exist, create them before processing. If `IN/` has no `.sql` files, report that and stop.

## Concurrency

- Default maximum concurrent workers: `5`
- This cap is configurable when the skill is executed.
- If no override is provided, use `5`.
- Never exceed the configured cap.

## Workflow

1. Scan `IN/` for `.sql` files and sort them deterministically.
2. Process files with parallel workers only when that improves throughput and does not block validation. Use a maximum of `5` concurrent workers by default, or the configured override when one is provided.
3. For each file:
   - Read the SQL source.
   - Read the ABRT references from the repo root. If a `references/` directory exists instead, use that.
   - Extract business rules into new ABRT JSON generated from that SQL source during the current run.
   - Write `OUT/<basename>_abrt.json`.
   - Perform a gap analysis against `ABRT_PL-SQL_Business_Rules.md`.
   - Perform structural validation of the JSON output against the ABRT v1.8 spec after the gap analysis.
   - If the gap analysis or structural validation finds any issue, correct the JSON output and re-run both checks until the output conforms to the spec or the extraction is declared failed.
4. If a file succeeds, move the source file from `IN/` to `DONE/`.
5. If any file fails validation, stop starting new work, allow in-flight work to finish when practical, and report the failure clearly.
6. Report a final summary with processed file names and counts.

## Strict Execution Requirements

- Do not search the repo for pre-existing candidate JSON outputs to reuse.
- Do not copy prior outputs from test fixtures, parser work directories, or historical artifacts.
- Each child worker must perform the extraction itself for its assigned `IN/*.sql` file during the current run.
- Each generated `OUT/*.json` file must be freshly generated from the current SQL source, followed by a gap analysis against `ABRT_PL-SQL_Business_Rules.md`, and then structurally validated against the ABRT v1.8 grammar before the file is treated as complete.
- If either check reveals a defect that can be corrected, update the generated JSON and re-run the checks.
- If fresh extraction cannot be performed, report failure instead of substituting an existing JSON file.

## Extraction Rules

- Follow ABRT v1.8.
- Use `TRIGGER_OPERATION` for database triggers.
- Use `BUSINESS_OPERATION` for procedures and functions.
- Flag hard-coded `LITERAL` constants with `review_flag: true`.
- Use `COMPOSITE` only when a branch contains multiple imperative outcomes that should be represented as one ordered action.
- Model `CONDITION` nodes using the v1.8 explicit forms:
  - `LEAF_CONDITION`: `operator` set, `logical_op` = `NONE`, no child `conditions`, no `then_branch` or `else_branch` unless it is the actual branching node.
  - `COMPOUND_CONDITION`: `operator` = `null`, `logical_op` = `AND` / `OR` / `NOT`, composed via child `conditions`.
- Do not mix leaf and compound forms on the same `CONDITION` node.
- Note discrepancies between code behavior and comments or error messages when they materially differ.
- Use these top-level JSON keys:
  - `abrt_version`
  - `application`
  - `source_file`
  - `trigger_operations`
  - `business_operations`

## Validation

After writing each JSON file, perform a gap analysis against `ABRT_PL-SQL_Business_Rules.md` and then perform structural validation of the generated JSON against the ABRT v1.8 spec.

Check that:

1. Every node type used in the JSON is defined in the ABRT grammar.
2. Every required field for each node type is present.
3. Every enum value matches the spec.
4. Parent-child structure conforms to the grammar.
5. No unknown fields are present.
6. `abrt_version` is `1.8`.
7. Every `CONDITION` node conforms to one of the v1.8 explicit forms:
   - leaf: `operator` present, `logical_op` = `NONE`
   - compound: `operator` = `null`, `logical_op` in `AND` / `OR` / `NOT`, child `conditions` used for composition
8. No `CONDITION` node mixes leaf and compound forms in a way the v1.8 grammar forbids.

If any difference is found:

1. Correct the generated JSON output.
2. Re-run the gap analysis.
3. Re-run structural validation.
4. Only mark the file complete if both checks pass.

If the JSON cannot be corrected to conform to the spec, treat that file as a failure and do not mark it complete.

The gap analysis and structural validation must evaluate the newly generated JSON for that file, not a previously saved artifact.

## Execution Notes

- Prefer direct local processing over elaborate orchestration unless the batch size justifies parallel work.
- When using parallel workers, keep status reporting simple: running, queued, completed, failed.
- Do not add any database load, schema read, or MySQL logging steps in this skill.
- Keep outputs deterministic where possible so repeated runs are easy to compare.
- Overwrite stale `OUT/<basename>_abrt.json` with the fresh extraction for the current run.
- Move the processed source to `DONE/` only after the gap analysis and the structural validation pass.

## References

- Read `ABRT_PL-SQL_Business_Rules.md` for the core grammar, validation rules, and gap analysis baseline.
- Read `ABRT_Oracle_Forms3_Extension.md` when the SQL uses Oracle Forms-specific patterns or extensions.
