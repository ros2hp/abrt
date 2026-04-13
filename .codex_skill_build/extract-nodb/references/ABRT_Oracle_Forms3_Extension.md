# Abstract Business Rule Tree (ABRT) — Extension for Oracle Forms 3
## Supplement to: ABRT v1.0 — PL/SQL Business Rules Specification
### Applied to Legacy Superannuation Applications (Oracle 7 / Oracle Forms 3)

---

## 1. Why Oracle Forms 3 Requires a Separate Extension

The PL/SQL ABRT (v1.0) was designed around **procedural, server-side code** — stored procedures and functions that execute atomically when called. Oracle Forms 3 introduces an entirely different execution model that demands additional node types, new data source categories, and a layered trigger architecture.

### Key Differences: PL/SQL vs Oracle Forms 3

| Dimension | PL/SQL (Server-side) | Oracle Forms 3 (Client-side) |
|---|---|---|
| Execution model | Procedural, call-and-return | Event-driven, trigger cascade |
| Invocation | Explicit call from code | Implicit: user action, navigation, commit |
| Rule location | Package / procedure body | Trigger attached to form / block / item |
| Data scope | Parameters + DB tables | Form items + globals + DB block fields |
| Control flow | Sequential + loops | Trigger firing order + RAISE_FORM_TRIGGER_FAILURE |
| User interaction | None (batch) | Central — field entry, button press, key events |
| Validation timing | On call | On entry, on exit, pre-insert, pre-update |
| State | Stateless (per call) | Stateful across navigation within a session |

### What This Extension Adds

This extension introduces **six new ABRT node types** specific to Forms 3, **four new DATA_INPUT source types**, **two new CONSTANT types**, and a **FORM_OPERATION root node** to sit alongside the existing `BUSINESS_OPERATION`. All existing PL/SQL node types remain valid — Forms 3 triggers frequently contain embedded PL/SQL that uses the full PL/SQL ABRT vocabulary.

---

## 2. Oracle Forms 3 Architecture Primer (for ABRT Context)

Understanding how Forms 3 is structured is essential to correctly attributing business rules to the right node type.

### 2.1 Form Object Hierarchy

```
FORM
  └── BLOCK (1..n)           — maps to a database table or is control-only
        └── ITEM (1..n)      — text field, list, checkbox, button, display item
              └── TRIGGER    — PL/SQL code attached at item level
        └── TRIGGER          — PL/SQL code attached at block level
  └── TRIGGER                — PL/SQL code attached at form level
```

### 2.2 Trigger Firing Hierarchy (outermost to innermost scope)

When an event occurs, Forms 3 fires triggers from the **most specific scope outward** (item → block → form). This means a business rule at the form level is a *default* that can be overridden at the block or item level.

```
Form-level trigger    ← widest scope, default behaviour
  Block-level trigger ← overrides form-level for this block
    Item-level trigger  ← most specific, overrides both
```

### 2.3 Oracle Forms 3 Trigger Categories

| Trigger Category | Fires When | Business Rule Significance |
|---|---|---|
| KEY- triggers | User presses a key (KEY-COMMIT, KEY-NXTFLD, KEY-ENTQRY) | Intercept standard actions, enforce workflow |
| ON- triggers | Replaces default Forms behaviour (ON-INSERT, ON-UPDATE) | Custom DML logic, audit rules |
| PRE- triggers | Before an action (PRE-INSERT, PRE-COMMIT, PRE-QUERY) | Validation and preparation rules |
| POST- triggers | After an action (POST-INSERT, POST-QUERY, POST-CHANGE) | Derived field calculation, post-entry rules |
| WHEN- triggers | In response to user/system events (WHEN-VALIDATE-ITEM, WHEN-NEW-FORM-INSTANCE) | Validation, initialisation, field-level rules |

### 2.4 Forms 3 Data Namespaces

| Namespace | Syntax | Scope | ABRT Source Type |
|---|---|---|---|
| Block item | `:BLOCK_NAME.ITEM_NAME` | Current form session | FORM_ITEM |
| Global variable | `:GLOBAL.variable_name` | Entire session (all forms) | GLOBAL_VAR |
| System variable | `:SYSTEM.variable_name` | Runtime state (e.g., MODE, CURSOR_ITEM) | SYSTEM_VAR |
| Parameter | `:PARAMETER.param_name` | Passed when form is called | FORM_PARAM |
| Sequence | Next value from DB sequence | Form session | SEQUENCE (existing) |

---

## 3. New ABRT Node Types for Oracle Forms 3

---

### 3.1 FORM_OPERATION (New Root Node)

The Forms 3 equivalent of `BUSINESS_OPERATION`. Represents a complete business activity as conducted through a form — from opening a screen through to committing data.

```
FORM_OPERATION
  id:             unique identifier (e.g., "ENROL_NEW_MEMBER")
  label:          human-readable name ("Enrol New Member")
  source_form:    Oracle Forms module name (e.g., "MEMBENROL.FMB")
  source_block:   primary block name (e.g., "MEMBER_DETAIL")
  operation_type: [ DATA_ENTRY | ENQUIRY | PROCESS | MAINTENANCE | NAVIGATION ]
  entry_point:    trigger that initiates the operation
                  (e.g., "WHEN-NEW-FORM-INSTANCE", "KEY-COMMIT")
  children:       [ TRIGGER_RULE* ]
  calls:          [ BUSINESS_OPERATION* ]  -- PL/SQL operations invoked
```

**Operation Types:**
- `DATA_ENTRY` — User enters new data (member enrolment, contribution entry)
- `ENQUIRY` — User queries and views data without modifying it
- `PROCESS` — User initiates a business process (benefit payment, rollover)
- `MAINTENANCE` — Reference data maintenance (rate tables, member categories)
- `NAVIGATION` — Multi-form workflow navigation (menu, drill-down)

---

### 3.2 TRIGGER_RULE (Primary Forms Node)

The central node for Forms 3 business rules. Represents a single trigger at a specific scope (form/block/item) that encodes one or more business rules. This is the Forms 3 equivalent of `BUSINESS_RULE`.

```
TRIGGER_RULE
  id:             unique identifier (e.g., "TR-ENROL-007")
  label:          business name of the rule
  description:    plain English rule statement
  trigger_name:   Oracle Forms trigger name (e.g., "WHEN-VALIDATE-ITEM")
  trigger_scope:  [ FORM | BLOCK | ITEM ]
  scope_ref:      object the trigger is attached to
                  (e.g., "MEMBER_DETAIL.MEMBER_DOB" for item scope)
  rule_type:      [ VALIDATION | INITIALISATION | DERIVATION | NAVIGATION |
                    ENFORCEMENT | AUTHORISATION | AUDIT | COMMIT_CONTROL ]
  firing_order:   integer (when multiple triggers of same type on same object)
  overrides:      TRIGGER_RULE.id (if this trigger overrides a parent-scope trigger)
  source_lines:   line range within trigger body
  children:       [ CONDITION* | FORMULA* | POLICY_BRANCH* |
                    LOOKUP_REF* | FORM_MESSAGE* | NAVIGATION_RULE* |
                    FIELD_BEHAVIOUR* ]
  calls:          [ BUSINESS_OPERATION* ]   -- PL/SQL procedures called
```

**Rule Types (Forms-specific):**
- `VALIDATION` — Checks item or record data against business rules (most common)
- `INITIALISATION` — Sets default values when form/block/item is first entered
- `DERIVATION` — Calculates a field value from other fields (POST-CHANGE, POST-QUERY)
- `NAVIGATION` — Controls which screen or block the user goes to next
- `ENFORCEMENT` — Prevents an action (RAISE_FORM_TRIGGER_FAILURE)
- `AUTHORISATION` — Controls access based on user role or session state
- `AUDIT` — Stamps who changed what and when
- `COMMIT_CONTROL` — Rules that fire at PRE/ON/POST-INSERT/UPDATE/DELETE

---

### 3.3 FORM_MESSAGE (User Communication Node)

Oracle Forms 3 communicates business rule violations back to the user via MESSAGE() calls and alerts. These are first-class business rule artefacts — the message text often *is* the business rule statement in user-facing language.

```
FORM_MESSAGE
  id:             unique identifier
  label:          short message purpose description
  message_text:   the exact text shown to the user
  message_type:   [ ERROR | WARNING | INFORMATION | CONFIRMATION ]
  severity:       [ HALT | STOP | CAUTION | NOTE ]
  trigger_context: the TRIGGER_RULE that raises this message
  condition_ref:  CONDITION that causes this message to fire
  halt_trigger:   boolean  -- is RAISE_FORM_TRIGGER_FAILURE called after?
```

**Why this matters:** In legacy superannuation Forms, error messages frequently encode the *only* documented statement of a business rule. A message like "Member must be under preservation age to access restricted component" is the rule.

---

### 3.4 FIELD_BEHAVIOUR (UI State Node)

Oracle Forms 3 triggers frequently encode business rules by controlling the visual and interactive state of form items — making fields enabled/disabled, visible/hidden, required/optional, or navigable. These are business rules expressed as UI behaviour.

```
FIELD_BEHAVIOUR
  id:             unique identifier
  label:          business description of the behaviour
  target_item:    ":BLOCK.ITEM" reference
  behaviour_type: [ ENABLED | DISABLED | VISIBLE | HIDDEN |
                    REQUIRED | OPTIONAL | NAVIGABLE | NON_NAVIGABLE |
                    DISPLAYED | CONCEALED ]
  condition_ref:  CONDITION that triggers this behaviour change
  trigger_ref:    TRIGGER_RULE that sets this behaviour
  rationale:      why this field is controlled this way (business reason)
```

**Example:** In a superannuation form, the `DEFINED_BENEFIT_FORMULA` field group may only be `ENABLED` when `MEMBER.FUND_TYPE = 'DB'`. That conditional enablement is a business rule — it reflects the policy that DB-specific data is only relevant for DB fund members.

---

### 3.5 NAVIGATION_RULE (Workflow Node)

Oracle Forms 3 controls business process flow through navigation triggers — GO_BLOCK, GO_ITEM, CALL_FORM, OPEN_FORM, and NEW_FORM. These encode the permitted sequence of business operations.

```
NAVIGATION_RULE
  id:             unique identifier
  label:          business name of the navigation step
  nav_type:       [ GO_BLOCK | GO_ITEM | CALL_FORM | OPEN_FORM |
                    NEW_FORM | EXIT_FORM | NEXT_BLOCK | CLEAR_FORM ]
  target:         destination block, item, or form name
  condition_ref:  CONDITION that triggers navigation (optional — may be unconditional)
  pre_condition:  CONDITION that must be true before navigation is permitted
  passes_data:    [ FORM_ITEM* | GLOBAL_VAR* | FORM_PARAM* ]
                  -- data carried to next form/block
  trigger_ref:    TRIGGER_RULE that performs this navigation
  sequence:       integer (position in multi-step workflow)
```

---

### 3.6 SESSION_STATE (Forms State Node)

Oracle Forms 3 maintains rich session state through global variables and system variables that carry business context across blocks and forms. This node documents *what state is being read or written* by a trigger as a business rule input or output.

```
SESSION_STATE
  id:             unique identifier
  label:          business name of this state variable
  var_ref:        full reference (e.g., ":GLOBAL.CURRENT_MEMBER_ID")
  var_type:       [ GLOBAL_VAR | SYSTEM_VAR | FORM_PARAM ]
  state_role:     [ INPUT | OUTPUT | BOTH ]
  business_meaning: plain English description of what this variable represents
  set_by:         TRIGGER_RULE.id that writes this variable
  read_by:        [ TRIGGER_RULE.id* ] that read this variable
  lifecycle:      [ FORM_SESSION | APPLICATION_SESSION | CROSS_FORM ]
```

---

## 4. Extended DATA_INPUT Source Types

The existing `DATA_INPUT` node gains four new `source_type` values for Forms 3:

```
DATA_INPUT
  source_type: (existing types +)
    FORM_ITEM    — value in a form block item (:BLOCK.ITEM)
    GLOBAL_VAR   — Oracle Forms global variable (:GLOBAL.varname)
    SYSTEM_VAR   — Oracle Forms system variable (:SYSTEM.varname)
    FORM_PARAM   — Parameter passed to the form (:PARAMETER.pname)
```

### Key System Variables with Business Rule Significance

| System Variable | Business Meaning | ABRT Usage |
|---|---|---|
| `:SYSTEM.FORM_STATUS` | Whether form has unsaved changes (CHANGED/NEW/QUERY) | COMMIT_CONTROL rules |
| `:SYSTEM.BLOCK_STATUS` | Block record status | Pre-insert/update decision |
| `:SYSTEM.RECORD_STATUS` | Individual record state | Audit and version rules |
| `:SYSTEM.MODE` | NORMAL / ENTER-QUERY / QUERY | Query vs entry rule branching |
| `:SYSTEM.CURSOR_ITEM` | Which item has focus | Navigation enforcement |
| `:SYSTEM.LAST_RECORD` | Are we on the last record? | Batch processing rules |
| `:SYSTEM.DATE_THRESHOLD` | (custom) Used in some super systems for effective date | Date-sensitive rule inputs |

---

## 5. Extended CONSTANT Types

Two new `const_type` values for Forms 3:

```
CONSTANT
  const_type: (existing types +)
    FORM_DEFAULT  — default value set via Forms Designer (not code)
                    (e.g., item Initial Value property = 'AUD')
    ALERT_TEXT    — static text in a Forms Alert object
                    (business rule captured in alert message)
```

---

## 6. Updated ABRT Grammar (Forms 3 Extension)

```
ABRT              ::= BUSINESS_OPERATION+
                    | FORM_OPERATION+
                    | ( FORM_OPERATION+ linked_to BUSINESS_OPERATION+ )

FORM_OPERATION    ::= { id, label, source_form, source_block,
                         operation_type, entry_point,
                         TRIGGER_RULE+,
                         calls: BUSINESS_OPERATION* }

TRIGGER_RULE      ::= { id, label, description,
                         trigger_name, trigger_scope, scope_ref,
                         rule_type, firing_order,
                         overrides: TRIGGER_RULE?,
                         ( CONDITION | FORMULA | POLICY_BRANCH
                           | LOOKUP_REF | FORM_MESSAGE
                           | NAVIGATION_RULE | FIELD_BEHAVIOUR )+,
                         calls: BUSINESS_OPERATION* }

FORM_MESSAGE      ::= { id, label, message_text, message_type,
                         severity, condition_ref, halt_trigger }

FIELD_BEHAVIOUR   ::= { id, label, target_item, behaviour_type,
                         condition_ref, trigger_ref, rationale }

NAVIGATION_RULE   ::= { id, label, nav_type, target,
                         condition_ref?, pre_condition?,
                         passes_data: (FORM_ITEM|GLOBAL_VAR|FORM_PARAM)*,
                         sequence }

SESSION_STATE     ::= { id, label, var_ref, var_type, state_role,
                         business_meaning, set_by, read_by+, lifecycle }
```

---

## 7. Full Node Taxonomy (Combined PL/SQL + Forms 3)

```
ABRT
├── BUSINESS_OPERATION  [PL/SQL root]
│     ├── BUSINESS_RULE
│     │     ├── CONDITION ──────── DATA_INPUT (ARGUMENT | TABLE_COLUMN |
│     │     │     └── CONDITION     CURSOR_FIELD | PACKAGE_VARIABLE |
│     │     ├── FORMULA             GLOBAL | SEQUENCE | SYSDATE |
│     │     │     └── FORMULA       FORM_ITEM | GLOBAL_VAR |   ← NEW
│     │     ├── POLICY_BRANCH       SYSTEM_VAR | FORM_PARAM)   ← NEW
│     │     │     └── POLICY_CASE
│     │     └── LOOKUP_REF ─────── CONSTANT (LITERAL | NAMED_CONST |
│     │                             TABLE_PARAM | REGULATORY |
│     │                             SYSTEM | FORM_DEFAULT |    ← NEW
│     │                             ALERT_TEXT)                ← NEW
│
└── FORM_OPERATION      [Forms 3 root]      ← NEW
      ├── TRIGGER_RULE                       ← NEW
      │     ├── CONDITION            (reused from PL/SQL ABRT)
      │     ├── FORMULA              (reused from PL/SQL ABRT)
      │     ├── POLICY_BRANCH        (reused from PL/SQL ABRT)
      │     ├── LOOKUP_REF           (reused from PL/SQL ABRT)
      │     ├── FORM_MESSAGE         ← NEW
      │     ├── FIELD_BEHAVIOUR      ← NEW
      │     ├── NAVIGATION_RULE      ← NEW
      │     └── calls ──────────────► BUSINESS_OPERATION (cross-link)
      │
      └── SESSION_STATE              ← NEW
```

---

## 8. The ABRT Trigger Firing Model

A critical concept unique to Forms 3 is **trigger scope inheritance and override**. The ABRT must capture not just what a trigger does, but *where it sits in the firing hierarchy* and *whether it overrides a parent-scope rule*.

```
TRIGGER_SCOPE_CHAIN
  form_level:  TRIGGER_RULE (default rule for all blocks)
    block_level: TRIGGER_RULE (overrides form-level for this block)
      item_level:  TRIGGER_RULE (overrides block-level for this item)
```

### Override Semantics

| Scenario | ABRT Representation |
|---|---|
| Item trigger completely replaces form trigger | `overrides: form_level_trigger_id` |
| Item trigger supplements form trigger | Both fire; `overrides: NULL`; document firing_order |
| Block trigger prevents item trigger | Document via FIELD_BEHAVIOUR(DISABLED) |
| RAISE_FORM_TRIGGER_FAILURE halts chain | ENFORCEMENT rule; `halt_trigger: TRUE` |

---

## 9. Applied Example: Member Date-of-Birth Validation

### 9.1 Scenario
In a superannuation member enrolment form, the date of birth field must be validated to ensure:
1. The date is not in the future
2. The member is at least 15 years old at enrolment (minimum working age)
3. The member is no older than 75 (maximum SG eligibility age)
4. The field is mandatory

### 9.2 Oracle Forms 3 Code (WHEN-VALIDATE-ITEM trigger on MEMBER_ENROL.MEMBER_DOB)

```sql
-- Trigger: WHEN-VALIDATE-ITEM
-- Block:   MEMBER_ENROL
-- Item:    MEMBER_DOB

DECLARE
  v_age   NUMBER;
BEGIN
  -- Mandatory check
  IF :MEMBER_ENROL.MEMBER_DOB IS NULL THEN
    MESSAGE('Date of Birth is mandatory.');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  -- Must not be future date
  IF :MEMBER_ENROL.MEMBER_DOB > SYSDATE THEN
    MESSAGE('Date of Birth cannot be in the future.');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  -- Calculate age
  v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, :MEMBER_ENROL.MEMBER_DOB) / 12);

  -- Minimum age
  IF v_age < 15 THEN
    MESSAGE('Member must be at least 15 years of age.');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  -- Maximum age for SG
  IF v_age > 75 THEN
    MESSAGE('WARNING: Member exceeds SG eligibility age of 75.');
    -- Note: warning only, does not halt
  END IF;

  -- Store derived age in global for use by other triggers
  :GLOBAL.MEMBER_AGE_AT_ENROL := v_age;
END;
```

---

### 9.3 ABRT for the Above Trigger

```
FORM_OPERATION
├── id:             "ENROL_NEW_MEMBER"
├── label:          "Enrol New Member"
├── source_form:    "MEMBENROL.FMB"
├── source_block:   "MEMBER_ENROL"
├── operation_type: DATA_ENTRY
├── entry_point:    "WHEN-NEW-FORM-INSTANCE"
│
└── TRIGGER_RULE [TR-ENROL-DOB-001]
    ├── label:        "Validate Member Date of Birth"
    ├── trigger_name: "WHEN-VALIDATE-ITEM"
    ├── trigger_scope: ITEM
    ├── scope_ref:    "MEMBER_ENROL.MEMBER_DOB"
    ├── rule_type:    VALIDATION
    │
    ├── BUSINESS_RULE [BR-DOB-001]
    │   ├── label:       "Date of Birth is Mandatory"
    │   ├── rule_type:   CONSTRAINT
    │   ├── description: "A member cannot be enrolled without a date of birth"
    │   │
    │   ├── CONDITION [COND-DOB-001]
    │   │   ├── left_operand:  DATA_INPUT[MEMBER_DOB]
    │   │   │     source_type: FORM_ITEM
    │   │   │     source_ref:  ":MEMBER_ENROL.MEMBER_DOB"
    │   │   │     is_key:      TRUE
    │   │   └── operator:      IS_NULL
    │   │
    │   ├── then_branch:
    │   │   └── FORM_MESSAGE [MSG-DOB-001]
    │   │       ├── message_text: "Date of Birth is mandatory."
    │   │       ├── message_type: ERROR
    │   │       ├── severity:     HALT
    │   │       └── halt_trigger: TRUE
    │   └── else_branch: → BR-DOB-002
    │
    ├── BUSINESS_RULE [BR-DOB-002]
    │   ├── label:       "Date of Birth Must Not Be Future"
    │   ├── rule_type:   CONSTRAINT
    │   ├── description: "Date of birth cannot be after today's date"
    │   │
    │   ├── CONDITION [COND-DOB-002]
    │   │   ├── left_operand:  DATA_INPUT[MEMBER_DOB]
    │   │   │     source_type: FORM_ITEM
    │   │   │     source_ref:  ":MEMBER_ENROL.MEMBER_DOB"
    │   │   ├── operator:      GT
    │   │   └── right_operand: DATA_INPUT[SYSDATE]
    │   │         source_type: SYSDATE
    │   │
    │   └── then_branch:
    │       └── FORM_MESSAGE [MSG-DOB-002]
    │           ├── message_text: "Date of Birth cannot be in the future."
    │           ├── message_type: ERROR
    │           ├── severity:     HALT
    │           └── halt_trigger: TRUE
    │
    ├── BUSINESS_RULE [BR-DOB-003]
    │   ├── label:       "Derive Member Age at Enrolment"
    │   ├── rule_type:   DERIVATION
    │   ├── description: "Age at enrolment is calculated in whole years from
    │   │                 date of birth to current date"
    │   │
    │   └── FORMULA [FORM-DOB-001]
    │       ├── label:       "MEMBER_AGE_AT_ENROL"
    │       ├── expression:  "TRUNC( MONTHS_BETWEEN(SYSDATE, dob) / 12 )"
    │       ├── result_type: INTEGER
    │       ├── result_unit: "years"
    │       ├── operands:
    │       │   ├── DATA_INPUT[SYSDATE]  source_type: SYSDATE
    │       │   └── DATA_INPUT[MEMBER_DOB]
    │       │         source_type: FORM_ITEM
    │       │         source_ref:  ":MEMBER_ENROL.MEMBER_DOB"
    │       └── ROUNDING_RULE
    │             method:   TRUNCATE
    │             decimals: 0
    │
    ├── BUSINESS_RULE [BR-DOB-004]
    │   ├── label:       "Minimum Member Age for Enrolment"
    │   ├── rule_type:   ELIGIBILITY
    │   ├── description: "Member must be at least 15 years old to be enrolled"
    │   │
    │   ├── CONDITION [COND-DOB-003]
    │   │   ├── left_operand:  FORMULA[MEMBER_AGE_AT_ENROL]
    │   │   ├── operator:      LT
    │   │   └── right_operand: CONSTANT[MIN_ENROL_AGE]
    │   │         value:       15
    │   │         const_type:  REGULATORY
    │   │         description: "Minimum working age for superannuation"
    │   │         review_flag: TRUE
    │   │
    │   └── then_branch:
    │       └── FORM_MESSAGE [MSG-DOB-003]
    │           ├── message_text: "Member must be at least 15 years of age."
    │           ├── message_type: ERROR
    │           ├── severity:     HALT
    │           └── halt_trigger: TRUE
    │
    ├── BUSINESS_RULE [BR-DOB-005]
    │   ├── label:       "SG Eligibility Age Warning"
    │   ├── rule_type:   VALIDATION
    │   ├── description: "Members over 75 are outside SG eligibility — warn
    │   │                 operator but permit enrolment to proceed"
    │   │
    │   ├── CONDITION [COND-DOB-004]
    │   │   ├── left_operand:  FORMULA[MEMBER_AGE_AT_ENROL]
    │   │   ├── operator:      GT
    │   │   └── right_operand: CONSTANT[MAX_SG_AGE]
    │   │         value:       75
    │   │         const_type:  REGULATORY
    │   │         description: "Maximum age for SG contribution eligibility"
    │   │         review_flag: TRUE
    │   │
    │   └── then_branch:
    │       └── FORM_MESSAGE [MSG-DOB-004]
    │           ├── message_text: "WARNING: Member exceeds SG eligibility age of 75."
    │           ├── message_type: WARNING
    │           ├── severity:     CAUTION
    │           └── halt_trigger: FALSE   ← operator may continue
    │
    └── SESSION_STATE [SS-DOB-001]
        ├── label:            "Member Age at Enrolment"
        ├── var_ref:          ":GLOBAL.MEMBER_AGE_AT_ENROL"
        ├── var_type:         GLOBAL_VAR
        ├── state_role:       OUTPUT
        ├── business_meaning: "Derived age used by downstream triggers to
        │                      determine SG eligibility and contribution rules"
        ├── set_by:           TR-ENROL-DOB-001
        ├── read_by:          [ TR-CONTRIB-001, TR-BENEFIT-CALC-001 ]
        └── lifecycle:        FORM_SESSION
```

---

## 10. Forms 3 ABRT Patterns (Superannuation-Specific)

### Pattern F1: Field Conditional Enablement (Access Control by Member Type)

```
TRIGGER_RULE (WHEN-NEW-RECORD-INSTANCE, BLOCK level)
  └── POLICY_BRANCH(discriminator=DATA_INPUT[:MEMBER.FUND_TYPE])
        ├── POLICY_CASE(when='DB')
        │     └── FIELD_BEHAVIOUR(target=DB_FORMULA_FIELDS, type=ENABLED)
        ├── POLICY_CASE(when='DC')
        │     └── FIELD_BEHAVIOUR(target=DB_FORMULA_FIELDS, type=DISABLED)
        │     └── FIELD_BEHAVIOUR(target=INVESTMENT_OPTION_FIELDS, type=ENABLED)
        └── POLICY_CASE(when='HYBRID')
              └── FIELD_BEHAVIOUR(target=DB_FORMULA_FIELDS, type=ENABLED)
              └── FIELD_BEHAVIOUR(target=INVESTMENT_OPTION_FIELDS, type=ENABLED)
```

### Pattern F2: Cross-Block Validation via Global Variable

```
TRIGGER_RULE (PRE-INSERT, BLOCK level, BENEFIT_PAYMENT block)
  └── CONDITION(left=DATA_INPUT[:GLOBAL.MEMBER_STATUS], op=NEQ, right=CONSTANT('ACTIVE'))
        └── FORM_MESSAGE(text="Cannot process payment: member is not active",
                         halt_trigger=TRUE)
-- Note: :GLOBAL.MEMBER_STATUS set by MEMBER_DETAIL block trigger
-- SESSION_STATE node documents this cross-block dependency
```

### Pattern F3: Commit-Time Multi-Rule Validation Chain

```
TRIGGER_RULE (PRE-COMMIT, FORM level)
  ├── BUSINESS_RULE [mandatory field completeness check]
  │     └── CONDITION(IS_NULL checks on required fields)
  │           └── FORM_MESSAGE(ERROR, halt=TRUE)
  ├── BUSINESS_RULE [referential integrity]
  │     └── calls: BUSINESS_OPERATION(VALIDATE_MEMBER_EXISTS)
  └── BUSINESS_RULE [business date check]
        └── CONDITION(effective_date <= SYSDATE)
              └── FORM_MESSAGE(WARNING, halt=FALSE)
```

### Pattern F4: Query Mode vs Entry Mode Branching

```
TRIGGER_RULE (WHEN-NEW-RECORD-INSTANCE)
  └── POLICY_BRANCH(discriminator=DATA_INPUT[:SYSTEM.MODE])
        ├── POLICY_CASE(when='ENTER-QUERY')
        │     └── FIELD_BEHAVIOUR(target=ALL_CALC_FIELDS, type=DISABLED)
        ├── POLICY_CASE(when='NORMAL')
        │     └── FIELD_BEHAVIOUR(target=KEY_FIELDS, type=ENABLED)
        └── POLICY_CASE(when='QUERY')
              └── FIELD_BEHAVIOUR(target=ALL_FIELDS, type=NON_NAVIGABLE)
```

### Pattern F5: Multi-Form Workflow with Parameter Passing

```
TRIGGER_RULE (KEY-COMMIT on MEMBER_SEARCH form)
  └── NAVIGATION_RULE
        ├── nav_type:    CALL_FORM
        ├── target:      "MEMBENROL"
        ├── pre_condition: CONDITION(member selected IS_NOT_NULL)
        ├── passes_data: [ SESSION_STATE[:GLOBAL.SELECTED_MEMBER_ID],
                           SESSION_STATE[:GLOBAL.SELECTED_MEMBER_NAME] ]
        └── sequence:    1
```

---

## 11. Forms 3 ABRT Extraction Methodology

When analysing Oracle Forms 3 code to build an ABRT, apply this process *in addition to* the PL/SQL extraction methodology (ABRT v1.0, Section 8):

### Step 1 — Inventory All Triggers
For each form module (.FMB), enumerate every trigger at every scope level. The Oracle Forms Designer Object Navigator provides this. Record: trigger name, scope (form/block/item), and the object it is attached to.

### Step 2 — Classify Each Trigger by Rule Type
Use the trigger name and its scope to make an initial classification (VALIDATION, INITIALISATION, etc.). KEY- and WHEN- triggers are almost always business rules. ON- triggers implement business process logic. PRE- and POST- triggers are boundary rules.

### Step 3 — Map the Trigger Firing Chain
For each FORM_OPERATION, identify the sequence of triggers that fire. Document overrides — where an item-level trigger replaces the default form-level trigger for the same event. Use the `overrides` attribute on TRIGGER_RULE.

### Step 4 — Extract FORM_MESSAGEs First
Before analysing logic, collect all MESSAGE() calls and Alert text. Each one is a candidate FORM_MESSAGE node and often contains the most business-legible statement of a rule.

### Step 5 — Map FIELD_BEHAVIOUR Rules
Identify all SET_ITEM_PROPERTY calls that control enabled/disabled, visible/hidden, required/optional states. Each controlled field state change driven by a business condition is a FIELD_BEHAVIOUR node.

### Step 6 — Trace SESSION_STATE Dependencies
Identify all `:GLOBAL.*` variable assignments and reads. For each global variable, create a SESSION_STATE node and document which triggers write it and which read it. These are the cross-trigger data flows of the application.

### Step 7 — Identify PL/SQL Call-Outs
Find all EXEC_PLSQL, user-named procedure calls, or references to stored procedures from within trigger code. Each call links to a `BUSINESS_OPERATION` in the PL/SQL ABRT — document this as a `calls:` relationship on the TRIGGER_RULE.

### Step 8 — Document NAVIGATION_RULEs
Map every GO_BLOCK, GO_ITEM, CALL_FORM, OPEN_FORM, and NEW_FORM call. Note conditions that gate navigation and data passed between forms via globals or parameters.

---

## 12. Combined ABRT: Forms 3 + PL/SQL Cross-Reference

The full picture of a superannuation business operation spans both layers. The ABRT cross-reference links them:

```
FORM_OPERATION [PROCESS_BENEFIT_PAYMENT]
    │
    ├── TRIGGER_RULE [TR-PAY-001: PRE-INSERT validation]
    │       └── calls ──────────────────────────────────────────────►
    │                                          BUSINESS_OPERATION
    │                                          [VALIDATE_PAYMENT_ELIGIBILITY]
    │                                            └── BUSINESS_RULE [BR-PAY-001]
    │                                            └── BUSINESS_RULE [BR-PAY-002]
    │
    ├── TRIGGER_RULE [TR-PAY-002: ON-INSERT audit stamp]
    │       └── calls ──────────────────────────────────────────────►
    │                                          BUSINESS_OPERATION
    │                                          [STAMP_PAYMENT_AUDIT]
    │
    └── TRIGGER_RULE [TR-PAY-003: POST-INSERT confirmation]
            └── FORM_MESSAGE [MSG-PAY-001: "Payment posted successfully"]
            └── NAVIGATION_RULE [go to PAYMENT_HISTORY block]
```

This cross-reference pattern is the key architectural insight: **the Form handles user interaction rules; the PL/SQL handles data and calculation rules.** The ABRT captures both layers and the linkage between them.

---

## 13. Limitations Specific to Oracle Forms 3

- **No source code in .FMB:** Oracle Forms 3 stores trigger code in a binary `.FMB` file. Trigger bodies must be exported to text (via `f30gen` or Forms Designer "Save as Text") before ABRT extraction can begin.
- **Dynamic item references:** Some Forms 3 code uses `NAME_IN()` and `COPY()` built-ins to reference items by constructed string names — these cannot be statically resolved and require runtime analysis.
- **Alert objects:** Business rule text in Alert objects (as opposed to MESSAGE() calls) is stored in the form definition, not trigger code, and requires separate extraction.
- **Default item values:** Items with default values set in the Forms Designer property sheet (not in trigger code) encode initialisation rules that are invisible in trigger text. These must be extracted from the `.FMB` object properties.
- **Library (.PLL) triggers:** Shared logic in Oracle Forms PL/SQL Libraries is called from multiple forms and represents shared business rules — these require their own ABRT nodes linked from each form that includes the library.
- **KEY-OTHERS trigger:** A catch-all trigger that fires for any key not explicitly handled — may encode implicit business rules about what keyboard actions are permitted.

---

## 14. Updated ABRT Version

This document extends the ABRT specification to version **2.0**, combining:

- **ABRT v1.0** — PL/SQL stored procedures and functions
- **ABRT v2.0 Extension** — Oracle Forms 3 triggers and form-layer business rules

Future extensions planned:
- **ABRT v2.1** — DDL constraints (CHECK, NOT NULL, UNIQUE, FOREIGN KEY)
- **ABRT v2.2** — Database table triggers (BEFORE/AFTER INSERT/UPDATE/DELETE)

---

*ABRT v2.0 Specification — Superannuation Legacy System Documentation Project*
*Extends: ABRT v1.0 — PL/SQL Business Rules Specification*
