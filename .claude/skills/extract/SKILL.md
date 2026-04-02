---
name: extract
description: Extract business rules from PL/SQL files in the IN directory using ABRT spec, write JSON to OUT, load into MySQL, and move processed files to DONE. Use when the user wants to process PL/SQL files for business rule extraction.
argument-hint: "[max-agents (default 10)]"
user-invocable: true
---

# ABRT Extraction Pipeline

Process all `.sql` files in the `@IN` directory, extracting business rules and loading them into MySQL.

## Configuration
- **@IN**: `IN/` — source PL/SQL `.sql` files
- **@OUT**: `OUT/` — output `_abrt.json` files
- **@DONE**: `DONE/` — processed files moved here after completion
- **Database**: `rulesdb_claude` (run `USE rulesdb_claude` via MCP before any queries)
- **Schema**: `abrt_schema.sql`
- **ABRT specs**: `ABRT_PL-SQL_Business_Rules.md` (v1.7), `ABRT_Oracle_Forms3_Extension.md` (v2.0)
- **Max concurrent agents**: $ARGUMENTS (default 10 if not specified)

## Main Agent Steps

1. Scan `IN/` for `.sql` files. If none, report and stop.
2. For each file, insert a log entry into `abrt_process_log` (file_name, start defaults to NOW()). Retrieve the `seq_no` via `SELECT LAST_INSERT_ID()`.
3. Spawn a **background** child agent per file, up to the max concurrent limit. Pass the `seq_no` as the agent's unique identifier. When at the limit, wait for a child to complete before spawning the next.
4. When a child agent responds:
   - **If status is SUCCESS**: Move the `.sql` file from `IN/` to `DONE/`. If at the concurrency limit and files remain, spawn the next child.
   - **If status is FAIL**: **Stop reading from IN. Do NOT spawn any new agents.** Wait for all currently running child agents to respond, then report the failure and terminate.
5. When all files are processed and all agents have responded, report summary and stop.

## Child Agent Prompt Template

Each child agent receives this task:

> **Sequence number:** {seq_no}
> **File:** IN/{filename}
> **Output:** OUT/{basename}_abrt.json
>
> ### Step 1: Read inputs
> - Read the .sql file from IN/
> - Read both ABRT spec files
> - Read abrt_schema.sql for table structure
>
> ### Step 2: Extract business rules
> - Follow ABRT v1.7 spec exactly
> - Use `TRIGGER_OPERATION` for database triggers, `BUSINESS_OPERATION` for procedures/functions
> - Flag all hard-coded LITERAL constants with `review_flag: true`
> - Note discrepancies between code behaviour and comments/error messages
> - Top-level JSON keys: `abrt_version`, `application`, `source_file`, `trigger_operations`, `business_operations`
>
> ### Step 3: Write JSON output
> - Write to OUT/{basename}_abrt.json
>
> ### Step 4: Gap analysis
> After writing the JSON, perform a gap analysis comparing the JSON output against the ABRT grammar spec in `ABRT_PL-SQL_Business_Rules.md`. Check that:
> 1. Every node type used in the JSON is defined in the ABRT grammar
> 2. Every required field per node type is present
> 3. Every enum value used matches the allowed values in the spec
> 4. The tree structure (parent-child relationships) conforms to the grammar
> 5. No unknown/extra fields exist that are not in the spec
>
> **If the gap analysis reveals ANY differences:**
> - Update the log entry immediately:
>   `UPDATE abrt_process_log SET finished = NOW(), status = 'FAIL', message = 'gap analysis reveals difference' WHERE seq_no = {seq_no}`
> - Return to main agent: `FAIL: gap analysis reveals a difference in agent {seq_no}`
> - **Do NOT proceed to database loading. Terminate immediately.**
>
> **If the gap analysis reveals NO differences, proceed to Step 5.**
>
> ### Step 5: Load into MySQL
> - Run `USE rulesdb_claude` first
> - Insert in FK-respecting order:
>   1. abrt_extraction (retrieve extraction_id via LAST_INSERT_ID())
>   2. abrt_data_input, abrt_constant
>   3. abrt_value_set + abrt_value_set_member
>   4. abrt_action, abrt_action_argument, abrt_action_column
>   5. abrt_business_operation, abrt_trigger_operation
>   6. abrt_business_rule
>   7. abrt_condition, abrt_formula (rounding_method is VARCHAR(20), not ENUM)
>   8. abrt_formula_operand, abrt_formula_wrapper_arg
>   9. abrt_policy_branch
>   10. abrt_policy_case
>   11. abrt_policy_case_rule, abrt_policy_case_action, abrt_policy_case_formula
>   12. abrt_lookup_ref, abrt_lookup_key_column
>   13. abrt_cursor_scope, abrt_cursor_scope_field
>   14. abrt_derived_value
>   15. abrt_rule_constant, abrt_rule_action, abrt_rule_data_input
>
> ### CRITICAL: Junction tables must be fully populated
>
> **abrt_rule_action** — insert ALL rule-to-action mappings from:
> 1. `abrt_condition.then_ref` where `then_type = 'ACTION'`
> 2. `abrt_condition.else_ref` where `else_type = 'ACTION'`
> 3. `abrt_policy_case_action` (trace through policy_case -> policy_branch -> rule)
> 4. Direct unconditional child actions
>
> **abrt_rule_data_input** — insert ALL rule-to-data-input mappings from:
> 1. `abrt_condition.left_ref` where `left_type = 'DATA_INPUT'`
> 2. `abrt_condition.right_ref` where `right_type = 'DATA_INPUT'`
> 3. `abrt_formula_operand.operand_ref` where `operand_type = 'DATA_INPUT'`
> 4. `abrt_cursor_scope_field` (trace through cursor_scope -> rule)
> 5. Direct standalone inputs (e.g., procedure arguments)
>
> **abrt_rule_constant** — insert ALL rule-to-constant mappings from:
> 1. `abrt_condition.right_ref` where `right_type = 'CONSTANT'`
> 2. `abrt_formula_operand.operand_ref` where `operand_type = 'CONSTANT'`
> 3. `abrt_policy_case.when_ref` where `when_type = 'CONSTANT'`
> 4. Direct constants referenced by the rule
>
> ### Step 6: Update process log (success)
> UPDATE abrt_process_log SET finished = NOW(), status = 'OK', business_rules_count = {count}, infrastructure_count = {infra_count} WHERE seq_no = {seq_no}
>
> ### Step 7: Return completion
> Return: `SUCCESS`, file_name, business_rules_count, infrastructure_count, DB load confirmation

## MCP Caveats
- MySQL MCP server blocks `DROP` and `TRUNCATE` keywords (injection filter)
- `abrt_formula.rounding_method` is VARCHAR(20) not ENUM — insert string values directly

## Reporting
Announce agent spawns and completions with a running tally:
> Agents: N running, N queued, N completed

## Failure Handling
When the main agent receives a FAIL from any child agent:
1. Log the failure in the summary output
2. Stop scanning IN — do not spawn any new agents
3. Wait for all currently running agents to respond
4. Report final status showing which agents succeeded and which failed
5. Terminate
