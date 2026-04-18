---
name: extract-nodb
description: Extract business rules from PL/SQL files in an `IN/` directory using the ABRT v1.24 specification, write fresh `_abrt.json` files to `OUT/`, perform validation and gap analysis, and move processed inputs to `DONE/` without loading a database. Use when the user wants ABRT JSON output only from Oracle PL/SQL source files.
---

# ABRT Extraction Pipeline (No DB)

Use this skill when the user wants to process one or more Oracle PL/SQL `.sql` files into ABRT JSON without any MySQL or other database load step.

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
   - Perform structural validation of the JSON output against the ABRT v1.24 spec after the gap analysis.
   - If the gap analysis or structural validation finds any issue, correct the JSON output and re-run both checks until the output conforms to the spec or the extraction is declared failed.
4. If a file succeeds, move the source file from `IN/` to `DONE/`.
5. If any file fails validation, stop starting new work, allow in-flight work to finish when practical, and report the failure clearly.
6. Report a final summary with processed file names and counts.

## Strict Execution Requirements

- Do not search the repo for pre-existing candidate JSON outputs to reuse.
- Do not copy prior outputs from test fixtures, parser work directories, or historical artifacts.
- Each child worker must perform the extraction itself for its assigned `IN/*.sql` file during the current run.
- Each generated `OUT/*.json` file must be freshly generated from the current SQL source, followed by a gap analysis against `ABRT_PL-SQL_Business_Rules.md`, and then structurally validated against the ABRT v1.24 grammar before the file is treated as complete.
- If either check reveals a defect that can be corrected, update the generated JSON and re-run the checks.
- If fresh extraction cannot be performed, report failure instead of substituting an existing JSON file.

## Extraction Rules

- Follow ABRT v1.24.
- Use `TRIGGER_OPERATION` for database triggers.
- Use `BUSINESS_OPERATION` for procedures and functions.
- Flag hard-coded `LITERAL` constants with `review_flag: true`.
- Use `COMPOSITE` only when a branch contains multiple imperative outcomes that should be represented as one ordered action.
- Model `CONDITION` nodes using the v1.24 explicit forms:
  - `LEAF_CONDITION`: `operator` set, `logical_op` = `NONE`, no child `conditions`, no `then_branch` or `else_branch` unless it is the actual branching node.
  - `COMPOUND_CONDITION`: `operator` = `null`, `logical_op` = `AND` / `OR` / `NOT`, composed via child `conditions`.
- Do not mix leaf and compound forms on the same `CONDITION` node.
- Model PL/SQL `EXIT` and `EXIT WHEN` as `ACTION(action_type=EXIT_LOOP)`. Use `target` only when the source exits a named outer loop.
- Note discrepancies between code behavior and comments or error messages when they materially differ.
- Use these top-level JSON keys:
  - `abrt_version`
  - `application`
  - `source_file`
  - `trigger_operations`
  - `business_operations`

### BUSINESS_OPERATION label (v1.18)

- Short noun phrase naming what the operation *is* — not what it does step by step.
- Business vocabulary; no PL/SQL identifiers or variable names.
- Derive from the procedure/function header comment when present; otherwise synthesise from the logic.
- Title case, 3–6 words.
- Examples: `"Previous Period"`, `"Calculate Discount Rate"`, `"Apply Order Discount"`

### BUSINESS_OPERATION description (v1.24)

- Plain English summary covering the **full scope of the operation**: what business activity it performs, what data it consumes, and what it produces or changes.
- A reader unfamiliar with the code should understand the operation's purpose without reading the source.
- **PL/SQL identifiers are not acronyms.** Do not use variable names, parameter names, cursor names, or column names (`pMshpID`, `Per_ID`, `crMshp`, etc.) as terms in descriptions. Use plain English business vocabulary instead (e.g., "membership identifier", "person identifier").
- **Acronym rule — genuine business/domain acronyms only** (e.g., `RIP`, `SG`, `SMSF`, `CSS`):
  - Expand the acronym on **first use only** in the description. Subsequent uses in the same description may use the bare acronym.
  - Acronym appears in the source code (comments, table/column names — not variable names): `ACRONYM (expansion) (ref: business_operation.source, line N)` on first use
    - Example: `RIP (Re-appointed Invalidity Pensioner) (ref: ACRONYM_TEST_PKG.get_join_date, line 49)`
  - Acronym is well-known in the superannuation industry but not in the code: `ACRONYM (expansion) (not sourced from code)` on first use
    - Example: `SMSF (Self-Managed Superannuation Fund) (not sourced from code)`
  - Do not use an acronym without expansion on its first appearance.

### BUSINESS_RULE label (v1.18)

- Short action phrase naming what the rule *enforces or decides*.
- Business vocabulary; no PL/SQL variable names or table names.
- Derive from inline comments (`-- Business rule:`, `-- Rule:`) where present; otherwise synthesise from the logic.
- Title case, 3–6 words. Must be distinct from the description.
- Examples: `"Minimum Order Total Constraint"`, `"Customer Tier Discount Rate Policy"`, `"Status Change Detection"`

### BUSINESS_RULE description (v1.24)

- Plain English summary covering the **scope of this rule only**: what condition it tests, what value it derives, what decision it makes, or what side effect it produces.
- More detailed than the label: the label names the rule; the description explains it.
- **PL/SQL identifiers are not acronyms.** Do not use variable names, parameter names, cursor names, or column names as terms in descriptions. Use plain English business vocabulary instead.
- **Acronym rule — genuine business/domain acronyms only** (e.g., `RIP`, `SG`, `SMSF`, `CSS`):
  - Expand the acronym on **first use only** in the description. Subsequent uses in the same description may use the bare acronym.
  - Acronym appears in the source code (comments, table/column names — not variable names): `ACRONYM (expansion) (ref: business_operation.source, line N)` on first use
    - Example: `RIP (Re-appointed Invalidity Pensioner) (ref: ACRONYM_TEST_PKG.get_join_date, line 49)`
  - Acronym is well-known in the superannuation industry but not in the code: `ACRONYM (expansion) (not sourced from code)` on first use
  - Do not use an acronym without expansion on its first appearance.

### BUSINESS_OPERATION.source format (v1.17)

The `source` field must use the canonical format: `PACKAGE.procedure_name`

Derivation rules (apply in order):

1. **`PACKAGE`** — use the package name from the `CREATE PACKAGE BODY` statement in the source file, converted to **UPPER CASE**. If no package statement exists (standalone procedure or function file), fall back to the source file stem in UPPER CASE.
2. **`procedure_name`** — use the name from the `CREATE PROCEDURE` or `CREATE FUNCTION` statement, converted to **lower case**.
3. If `PACKAGE` and `procedure_name` match case-insensitively, **omit the prefix** and use only the lower-case procedure/function name.

Examples:

| Package (from CREATE PACKAGE BODY) | Procedure/Function | source |
|---|---|---|
| `SAS_MEMBERSHIPS_STATUS` | `Previous_Period` | `"SAS_MEMBERSHIPS_STATUS.previous_period"` |
| `APPLY_ORDER_DISCOUNT_TEST_PKG` | `apply_order_discount_test` | `"APPLY_ORDER_DISCOUNT_TEST_PKG.apply_order_discount_test"` |
| `APPLY_ORDER_DISCOUNT_TEST_PKG` | `calc_discount_ratei_2` | `"APPLY_ORDER_DISCOUNT_TEST_PKG.calc_discount_ratei_2"` |
| *(no package — file stem used)* `CALC_DISCOUNT_RATE` | `calc_discount_rate` | `"calc_discount_rate"` *(match — prefix omitted)* |
| *(no package — file stem used)* `APPLY_ORDER_DISCOUNT` | `calc_discount_rate` | `"APPLY_ORDER_DISCOUNT.calc_discount_rate"` |

This value is the resolution key used during two-pass cross-reference resolution.

### FUNCTION node (v1.24)

- Use `FUNCTION` for derived values sourced from user-defined PL/SQL function calls that return a value. Use `FORMULA` for built-in functions and inline expressions — do not use `FUNCTION` for built-ins.
- `FUNCTION.expression` holds the full call expression including arguments (e.g., `"calc_discount_rate(p_customer_tier, p_order_total)"`) — for human readability only, not the resolution key.
- `FUNCTION.target` is the canonical resolution key — same format as `BUSINESS_OPERATION.source`: `PACKAGE.function_name` or bare `function_name` when they match. Set at extraction time; does not change.
- `FUNCTION.called_operation_id` is the resolved result of two-pass resolution: initialise to `"_EXTERNAL_"` at extraction time; upgraded to the matched `BUSINESS_OPERATION.id` during resolution. Never `null` — FUNCTION is only for user-defined calls.
- Both `target` and `called_operation_id` are required on every `FUNCTION` node. This mirrors `ACTION(CALL)` exactly — `target` is the key, `called_operation_id` is the result.

### ACTION(CALL) cross-references (v1.13)

- `ACTION(action_type=CALL)` nodes carry a `called_operation_id` field:
  - `null` — built-in or external with no operation model
  - `"_EXTERNAL_"` — user-defined, target package not in batch
  - `"BOP-xxx"` — resolved `BUSINESS_OPERATION.id` after two-pass resolution
- `target` on `ACTION(CALL)` follows the same canonical `PACKAGE.procedure_name` format as `BUSINESS_OPERATION.source` and serves as the resolution key.
- Both `FUNCTION` and `ACTION(CALL)` nodes participate in two-pass resolution and both contribute `BUSINESS_RULE.id` entries to the target operation's `called_by_rule_id` array.

### `called_by_rule_id` (v1.24)

- On `BUSINESS_OPERATION`, the reverse-index field is named `called_by_rule_id`.
- Each entry is a composite string: the calling `BUSINESS_OPERATION.label` enclosed in double-quote characters, followed by a space and the enclosing `BUSINESS_RULE.id`.
- Format: `"\"<CALLING_OPERATION_LABEL>\" <BUSINESS_RULE.id>"`
- Example: `"\"Apply Order Discount\" BR-BFC-001-002"` — where `Apply Order Discount` is the label of the operation containing the calling FUNCTION or ACTION(CALL), and `BR-BFC-001-002` is the rule within that operation that holds the call.
- Empty for entry-point operations that are not called by any rule in the batch.

### Two-pass resolution

After extracting all operations in the batch:
1. For each `FUNCTION` node where `called_operation_id` is `"_EXTERNAL_"`, match `target` (case-insensitive) against `BUSINESS_OPERATION.source` across all files.
2. For each `ACTION(CALL)` node where `called_operation_id` is `"_EXTERNAL_"`, match `target` (case-insensitive) against `BUSINESS_OPERATION.source` across all files.
3. On a match for either node type:
   - Set `called_operation_id` to the matched `BUSINESS_OPERATION.id`.
   - Append a composite entry to the target operation's `called_by_rule_id` in the form `"\"<calling_operation_label>\" <BUSINESS_RULE.id>"` — the label of the calling operation in double-quote characters, a space, then the enclosing rule's id.
4. Unmatched calls (target package not in batch) remain `"_EXTERNAL_"`.

### Infrastructure exclusions (Step 0)

Before extracting rules, identify and skip infrastructure code that carries no business meaning:

- **Pure audit triggers** — triggers whose sole purpose is recording history (e.g., calling a versioning procedure unconditionally on every INSERT/UPDATE/DELETE with no filtering logic). Do not extract these as ABRT content. Omit entirely, or record a one-line note in the top-level `notes` array if a stub is warranted. Distinguish from **notification/sync triggers** that encode a business decision about which changes matter — those contain extractable business rules.
- **Audit/tracing** — logging inserts for operational observability only
- **Concurrency control**, **transaction control**, **lock management**, **identifier generation**, **generic error recovery** — exclude per spec Step 0

### CONSTANT node placement

- `CONSTANT` nodes belong **inline** as operands within the nodes where they are used — `CONDITION.left_operand` / `CONDITION.right_operand`, `FORMULA.operands`, `ACTION.arguments` / `ACTION.value`.
- `CONSTANT` nodes must **never** appear in a rule's `data_inputs` array. `data_inputs` contains only `DATA_INPUT` source nodes.

### REF node usage

- **Boolean `true` / `false` — always inline, never REF.** Write the full `CONSTANT` node inline every time.
- **Non-boolean `CONSTANT`** — inline at first use; `REF` on repeat use within the same rule or across rules in the same operation.
- **`DATA_INPUT`** — inline at first use; `REF` on repeat use.
- **`FORMULA` result** — always use `REF` when consuming a derived value in a subsequent condition or rule.

## Validation

After writing each JSON file, perform a gap analysis against `ABRT_PL-SQL_Business_Rules.md` and then perform structural validation of the generated JSON against the ABRT v1.24 spec.

Check that:

1. Every node type used in the JSON is defined in the ABRT grammar.
2. Every required field for each node type is present.
3. Every enum value matches the spec.
4. Parent-child structure conforms to the grammar.
5. No unknown fields are present.
6. `abrt_version` is `"1.24"`.
7. Every `BUSINESS_OPERATION` has a non-empty `description` field.
8. Every `BUSINESS_RULE` has a non-empty `description` field.
9. Every `BUSINESS_OPERATION` has a non-empty `label` (short noun phrase, title case, business vocabulary).
10. Every `BUSINESS_RULE` has a non-empty `label` (short action phrase, title case, business vocabulary).
11. Every acronym used in any `description` is followed by its expansion and a parenthetical source reference in one of the two permitted forms: `(ref: business_operation.source, line N)` for code-sourced acronyms, or `(not sourced from code)` for well-known industry acronyms.
12. Every `CONDITION` node conforms to one of the v1.24 explicit forms:
    - leaf: `operator` present, `logical_op` = `NONE`
    - compound: `operator` = `null`, `logical_op` in `AND` / `OR` / `NOT`, child `conditions` used for composition
13. No `CONDITION` node mixes leaf and compound forms.
14. No `CONSTANT` node appears in any rule's `data_inputs` array.
15. No `REF` node points to a boolean `CONSTANT` (`value_type: "BOOLEAN"`). Boolean constants must be inlined.
16. `BUSINESS_OPERATION.called_by_rule_id` entries are composite strings in the form `"\"<CALLING_OPERATION_LABEL>\" <BUSINESS_RULE.id>"` — not bare IDs, not objects.
17. Every `ACTION.action_type` value matches the v1.24 enum, including `EXIT_LOOP` where applicable.
18. `BUSINESS_OPERATION.source` follows the canonical format: package name from `CREATE PACKAGE BODY` (UPPER CASE) or file stem (UPPER CASE) if no package, dot-separated from lower-case procedure/function name; prefix omitted when they match case-insensitively.
19. `ACTION(CALL)` nodes include `called_operation_id` (`null`, `"_EXTERNAL_"`, or resolved `BUSINESS_OPERATION.id`).
20. `FUNCTION` nodes have both a `target` field (canonical format or `"_EXTERNAL_"`) and a `called_operation_id` field (`"_EXTERNAL_"` or resolved `BUSINESS_OPERATION.id`). `null` is not permitted on `FUNCTION.called_operation_id`.
21. `called_by_rule_id` on each `BUSINESS_OPERATION` is consistent with resolved `FUNCTION.target` and `ACTION(CALL).target` values across the batch — each entry must be a composite string in the form `"\"<CALLING_OPERATION_LABEL>\" <BUSINESS_RULE.id>"` where the label is the calling operation's label in double-quote characters and the ID is the enclosing rule of the matching node.

If any difference is found:

1. Correct the generated JSON output.
2. Re-run the gap analysis.
3. Re-run structural validation.
4. Only mark the file complete if both checks pass.

If the JSON cannot be corrected to conform to the spec, treat that file as a failure and do not mark it complete.

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
