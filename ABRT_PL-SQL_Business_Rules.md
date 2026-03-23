# Abstract Business Rule Tree (ABRT)
## A Formal Model for Extracting Business Rules from PL/SQL Code
### Applied to Legacy Superannuation Applications (Oracle 7 / Oracle Forms 3)

---

## 1. Overview and Purpose

An **Abstract Business Rule Tree (ABRT)** is a structured, hierarchical representation of business rules embedded in PL/SQL code. Analogous to how an Abstract Syntax Tree (AST) abstracts the syntactic structure of a program, the ABRT abstracts the *semantic business intent* from procedural code — stripping away implementation detail and exposing the underlying policy, constraint, or calculation that the code enforces.

### Key Distinctions from an AST

| Dimension | AST | ABRT |
|---|---|---|
| Purpose | Describe program structure | Describe business intent |
| Nodes | Syntax constructs (IF, LOOP, ASSIGN) | Business concepts (Constraint, Calculation, Policy) |
| Leaves | Literals, identifiers, operators | Business inputs, constants, reference data |
| Edge semantics | Parent/child syntactic relation | Business dependency / rule composition |
| Audience | Compiler / tooling | Business analyst / domain expert |
| Source | Single language construct | One or more PL/SQL constructs combined |

---

## 2. ABRT Node Taxonomy

The ABRT is composed of **seven node categories**, each representing a distinct kind of business rule construct found in PL/SQL code.

---

### 2.1 BUSINESS_OPERATION (Root Node)

The top-level container. Corresponds to a PL/SQL package, stored procedure, or function that represents a coherent business activity.

```
BUSINESS_OPERATION
  id:           unique identifier (e.g., "CALC_MEMBER_BENEFIT")
  label:        human-readable name
  source:       PL/SQL object name (package.procedure)
  operation_type: [ CALCULATION | VALIDATION | PROCESS | QUERY | EVENT ]
  children:     [ BUSINESS_RULE* ]
```

**Operation Types:**
- `CALCULATION` — Derives a value (e.g., benefit amount, tax, contribution rate)
- `VALIDATION` — Checks data correctness or eligibility before an action
- `PROCESS` — Executes a state change (e.g., roll over account, apply fee)
- `QUERY` — Retrieves and transforms data for reporting or display
- `EVENT` — Triggered response to a business event (e.g., member death, retirement)

---

### 2.2 BUSINESS_RULE (Primary Node)

Represents a single, identifiable, and nameable business rule within an operation. In PL/SQL, one business rule may map to a block of IF/ELSIF logic, a calculation expression, a cursor loop, or a combination.

```
BUSINESS_RULE
  id:           unique identifier (e.g., "BR-CONTRIB-001")
  label:        short business name
  description:  plain English statement of the rule
  rule_type:    [ CONSTRAINT | FORMULA | POLICY | ELIGIBILITY | DERIVATION | ALLOCATION | LOOKUP ]
  priority:     integer (for ordered rule sets)
  source_lines: PL/SQL line range for traceability
  children:     [ CONDITION* | FORMULA* | POLICY_BRANCH* | LOOKUP_REF* | DATA_INPUT* ]
```

**Rule Types:**
- `CONSTRAINT` — A hard limit or prohibition (e.g., "Contribution must not exceed concessional cap")
- `FORMULA` — A mathematical or logical derivation (e.g., "Final benefit = years_service × salary × accrual_rate")
- `POLICY` — A decision based on policy settings (e.g., "If fund type = defined benefit, apply DB formula")
- `ELIGIBILITY` — Determines whether a member qualifies for something
- `DERIVATION` — Classifies or maps a value to a category
- `ALLOCATION` — Distributes an amount across accounts or members
- `LOOKUP` — Retrieves a rate or value from a reference table based on criteria

---

### 2.3 CONDITION (Branch Node)

Represents a conditional branch within a business rule. Derived from IF / ELSIF / CASE / DECODE constructs in PL/SQL. Conditions form a tree of their own — AND/OR compositions are explicit child nodes.

```
CONDITION
  id:           unique identifier
  label:        plain English condition description
  operator:     [ EQ | NEQ | GT | GTE | LT | LTE | IN | NOT_IN | IS_NULL | IS_NOT_NULL | BETWEEN ]
  logical_op:   [ AND | OR | NOT | NONE ]  -- how this combines with siblings
  left_operand: DATA_INPUT | CONSTANT | DERIVED_VALUE
  right_operand: DATA_INPUT | CONSTANT | DERIVED_VALUE | VALUE_SET
  children:     [ CONDITION* ]    -- nested AND/OR sub-conditions
  then_branch:  BUSINESS_RULE | FORMULA | POLICY_BRANCH
  else_branch:  BUSINESS_RULE | FORMULA | POLICY_BRANCH | NULL
```

**Example mapping:**
```sql
IF v_age >= 65 AND v_status = 'ACTIVE' THEN ...
```
Maps to:
```
CONDITION(logical_op=AND)
  ├── CONDITION(left=AGE, op=GTE, right=CONSTANT(65))
  └── CONDITION(left=MEMBER_STATUS, op=EQ, right=CONSTANT('ACTIVE'))
```

---

### 2.4 FORMULA (Calculation Node)

Represents a calculation, expression, or derivation. Maps to PL/SQL arithmetic, string operations, or function calls that produce a business value.

```
FORMULA
  id:           unique identifier
  label:        name of the calculated quantity
  expression:   human-readable formula (e.g., "salary × accrual_rate × years_service")
  result_type:  [ MONETARY | PERCENTAGE | INTEGER | DATE | BOOLEAN | CATEGORY ]
  result_unit:  string (e.g., "AUD", "years", "%")
  operands:     [ DATA_INPUT | CONSTANT | FORMULA ]   -- inputs to this formula
  operator_seq: ordered list of operators applied
  rounding:     ROUNDING_RULE (optional)
  children:     [ FORMULA* ]   -- sub-calculations
```

**Rounding Rule (embedded):**
```
ROUNDING_RULE
  method:   [ ROUND | TRUNCATE | CEILING | FLOOR | BANKER ]
  decimals: integer
  basis:    [ CENT | DOLLAR | UNIT ]
```

---

### 2.5 DATA_INPUT (Leaf Node)

Represents a data value consumed by a rule. This is the primary leaf node type — it traces where rule inputs come from.

```
DATA_INPUT
  id:           unique identifier
  label:        business name of the data item
  source_type:  [ ARGUMENT | TABLE_COLUMN | CURSOR_FIELD | PACKAGE_VARIABLE | GLOBAL | SEQUENCE | SYSDATE ]
  source_ref:   fully-qualified source (e.g., "MEMBERS.DATE_OF_BIRTH", ":p_salary")
  data_type:    [ NUMBER | VARCHAR | DATE | BOOLEAN ]
  is_key:       boolean  -- is this a primary driver of rule behaviour?
  nullable:     boolean
  default_value: CONSTANT (optional)
  validation:   [ RANGE | SET | FORMAT | REFERENTIAL ] (optional)
```

**Source Types explained:**
- `ARGUMENT` — Passed into the PL/SQL procedure/function as a parameter (`:p_member_id`)
- `TABLE_COLUMN` — Read directly from a database table via SELECT
- `CURSOR_FIELD` — Retrieved via a cursor loop (common for bulk operations)
- `PACKAGE_VARIABLE` — A package-level variable (may carry state across calls)
- `GLOBAL` — Oracle Forms global variable or application constant
- `SEQUENCE` — Oracle SEQUENCE value (used for generated IDs)
- `SYSDATE` — Current date (critical in superannuation for age and period calculations)

---

### 2.6 CONSTANT (Leaf Node)

Represents a hard-coded value or named constant that acts as a rule parameter. Distinguishing constants from inputs is critical — constants represent embedded policy decisions that may need to change.

```
CONSTANT
  id:           unique identifier
  label:        business name of the constant
  value:        the literal value
  value_type:   [ NUMERIC | STRING | DATE | BOOLEAN ]
  const_type:   [ LITERAL | NAMED_CONST | TABLE_PARAM | REGULATORY | SYSTEM ]
  description:  business meaning of this value
  review_flag:  boolean  -- should this be externalised as a configurable parameter?
```

**Constant Types:**
- `LITERAL` — Raw value embedded in code (e.g., `0.095` for SG rate — *high risk*)
- `NAMED_CONST` — Declared as a PL/SQL constant (e.g., `c_max_age CONSTANT NUMBER := 75`)
- `TABLE_PARAM` — Looked up from a parameter/configuration table
- `REGULATORY` — A legislated value (e.g., concessional cap, SG rate, preservation age)
- `SYSTEM` — A system constant (e.g., fund ID, product code)

---

### 2.7 VALUE_SET (Collection Leaf Node)

Represents an explicit set of values used as the right operand of an `IN` or `NOT_IN` condition, or as a multi-value `when_value` in a `POLICY_CASE`. In PL/SQL this corresponds to the parenthesised list in `IN (...)` expressions or multi-value CASE branches.

```
VALUE_SET
  id:           unique identifier
  label:        business name of the value set (e.g., "Active Member Statuses")
  values:       [ CONSTANT+ ]   -- ordered list of permitted/matching values
  value_type:   [ NUMERIC | STRING | DATE ]  -- all values must share the same type
  description:  business meaning of this set (optional)
  review_flag:  boolean  -- true if any member CONSTANT is a LITERAL that should be externalised
```

**Example mapping:**
```sql
IF v_status IN ('ACTIVE', 'PENDING', 'SUSPENDED') THEN ...
```
Maps to:
```
CONDITION
  ├── left_operand:  DATA_INPUT[MEMBER_STATUS]
  ├── operator:      IN
  └── right_operand: VALUE_SET[ELIGIBLE_STATUSES]
                       values: [ CONSTANT('ACTIVE'), CONSTANT('PENDING'), CONSTANT('SUSPENDED') ]
                       value_type: STRING
```

**Usage contexts:**
- `CONDITION.right_operand` — when the operator is `IN` or `NOT_IN`
- `POLICY_CASE.when_value` — when a single CASE branch matches multiple values

---

### 2.8 POLICY_BRANCH (Decision Node)


Represents a multi-way policy decision — where the same business operation follows different paths based on fund type, member category, product type, or regulatory regime. Common in superannuation where DB, DC, and hybrid funds co-exist.

```
POLICY_BRANCH
  id:             unique identifier
  label:          name of the policy decision point
  discriminator:  DATA_INPUT | FORMULA  -- the value that drives the branching
  branches:       [ POLICY_CASE* ]

POLICY_CASE
  when_value:     CONSTANT | VALUE_SET
  label:          description of this policy path
  condition:      CONDITION (optional — structured decomposition of when_value
                             when the case is guarded by a comparison expression
                             such as "p_weight > 50" rather than a simple value match)
  rule_set:       [ BUSINESS_RULE* ]
```

When a `POLICY_CASE` is derived from an IF/ELSIF branch whose guard is a comparison expression (e.g., `p_weight > 50`, `balance > 1000000`), the parser emits a structured `CONDITION` node on the policy case in addition to the `when_value`. This ensures that the operands, operator, and data types of the guard expression are captured as first-class ABRT elements and can be queried independently — for example, to find all rules that reference a particular DATA_INPUT or to validate that the comparison operator matches business intent.

---

### 2.9 LOOKUP_REF (Reference Data Node)

Represents a reference to a lookup table, rate table, or static classification table. Superannuation systems are rich in rate tables (contribution rates, tax brackets, fee schedules, age factors).

```
LOOKUP_REF
  id:             unique identifier
  label:          business name of the lookup
  table_name:     database table or view
  key_columns:    [ DATA_INPUT* ]     -- inputs used to select the row
  result_column:  string              -- column returned
  lookup_type:    [ RATE | AMOUNT | CATEGORY | FLAG | DATE_RANGE ]
  effective_date_col: string (optional)  -- for time-effective lookups
  fallback:       CONSTANT (optional) -- default if no row found
```

---

## 3. ABRT Grammar (Formal Notation)

```
ABRT              ::= BUSINESS_OPERATION+

BUSINESS_OPERATION ::= { id, label, source, operation_type, BUSINESS_RULE+ }

BUSINESS_RULE     ::= { id, label, description, rule_type, priority,
                         (CONDITION | FORMULA | POLICY_BRANCH | LOOKUP_REF)+ }

CONDITION         ::= { id, label, operator, logical_op,
                         left_operand, right_operand,
                         CONDITION*,
                         then_branch, else_branch }

FORMULA           ::= { id, label, expression, result_type,
                         (DATA_INPUT | CONSTANT | FORMULA)+,
                         ROUNDING_RULE? }

POLICY_BRANCH     ::= { id, label, discriminator:(DATA_INPUT | FORMULA),
                         POLICY_CASE+ }

POLICY_CASE       ::= { when_value, label, CONDITION?, BUSINESS_RULE+ }

LOOKUP_REF        ::= { id, label, table_name,
                         key_columns:DATA_INPUT+,
                         result_column, lookup_type,
                         effective_date_col?,
                         fallback:CONSTANT? }

DATA_INPUT        ::= { id, label, source_type, source_ref,
                         data_type, is_key, nullable, default_value? }

CONSTANT          ::= { id, label, value, value_type,
                         const_type, description, review_flag }

VALUE_SET         ::= { id, label, values:CONSTANT+, value_type,
                         description?, review_flag }
```

---

## 4. ABRT Representation Example

### 4.1 Example PL/SQL — Superannuation Guarantee Contribution Calculation

```sql
PROCEDURE calc_sg_contribution (
    p_member_id   IN NUMBER,
    p_salary      IN NUMBER,
    p_period_end  IN DATE
) IS
    v_age          NUMBER;
    v_sg_rate      NUMBER;
    v_contribution NUMBER;
    v_status       VARCHAR2(10);
BEGIN
    -- Get member age and status
    SELECT TRUNC(MONTHS_BETWEEN(p_period_end, date_of_birth)/12),
           status
    INTO   v_age, v_status
    FROM   members
    WHERE  member_id = p_member_id;

    -- Eligibility check
    IF v_status != 'ACTIVE' OR v_age > 75 THEN
        RETURN;
    END IF;

    -- Lookup SG rate from rate table
    SELECT rate INTO v_sg_rate
    FROM   sg_rates
    WHERE  effective_date <= p_period_end
    ORDER BY effective_date DESC
    FETCH FIRST 1 ROW ONLY;

    -- Calculate contribution
    v_contribution := ROUND(p_salary * v_sg_rate, 2);

    INSERT INTO contributions (member_id, amount, period_end, contrib_type)
    VALUES (p_member_id, v_contribution, p_period_end, 'SG');
END;
```

---

### 4.2 ABRT for the Above Procedure

```
BUSINESS_OPERATION
├── id:             "CALC_SG_CONTRIBUTION"
├── label:          "Calculate Superannuation Guarantee Contribution"
├── source:         "CONTRIB_PKG.CALC_SG_CONTRIBUTION"
├── operation_type: CALCULATION
│
├── BUSINESS_RULE [BR-SG-001]
│   ├── label:      "SG Contribution Eligibility"
│   ├── rule_type:  ELIGIBILITY
│   ├── description: "Member must be ACTIVE status and aged 75 or under to
│   │                 receive an SG contribution"
│   │
│   ├── CONDITION [COND-001] (logical_op=AND)
│   │   ├── CONDITION [COND-001a]
│   │   │   ├── left_operand:  DATA_INPUT[MEMBER_STATUS]
│   │   │   │     source_type: TABLE_COLUMN
│   │   │   │     source_ref:  "MEMBERS.STATUS"
│   │   │   ├── operator:      EQ
│   │   │   └── right_operand: CONSTANT[STATUS_ACTIVE]
│   │   │         value:       "ACTIVE"
│   │   │         const_type:  SYSTEM
│   │   │
│   │   └── CONDITION [COND-001b]
│   │       ├── left_operand:  FORMULA[MEMBER_AGE]
│   │       ├── operator:      LTE
│   │       └── right_operand: CONSTANT[MAX_SG_AGE]
│   │             value:       75
│   │             const_type:  REGULATORY
│   │             review_flag: TRUE
│   │             description: "Maximum age for SG eligibility (legislative)"
│   │
│   ├── then_branch: → BR-SG-002 (continue to rate lookup)
│   └── else_branch: RETURN (no contribution posted)
│
├── BUSINESS_RULE [BR-SG-002]
│   ├── label:      "Derive Member Age at Period End"
│   ├── rule_type:  FORMULA
│   ├── description: "Age is calculated in whole years between date of birth
│   │                 and the period end date"
│   │
│   └── FORMULA [FORM-001]
│       ├── label:       "MEMBER_AGE"
│       ├── expression:  "TRUNC( MONTHS_BETWEEN(period_end, date_of_birth) / 12 )"
│       ├── result_type: INTEGER
│       ├── result_unit: "years"
│       ├── operands:
│       │   ├── DATA_INPUT[PERIOD_END_DATE]
│       │   │     source_type: ARGUMENT
│       │   │     source_ref:  ":p_period_end"
│       │   │     is_key:      TRUE
│       │   └── DATA_INPUT[DATE_OF_BIRTH]
│       │         source_type: TABLE_COLUMN
│       │         source_ref:  "MEMBERS.DATE_OF_BIRTH"
│       └── ROUNDING_RULE
│             method:   TRUNCATE
│             decimals: 0
│             basis:    UNIT
│
├── BUSINESS_RULE [BR-SG-003]
│   ├── label:      "Look Up Current SG Rate"
│   ├── rule_type:  LOOKUP
│   ├── description: "The SG rate is determined from the SG_RATES table using
│   │                 the most recent rate effective on or before period end"
│   │
│   └── LOOKUP_REF [LKP-001]
│       ├── label:              "SG_RATE"
│       ├── table_name:         "SG_RATES"
│       ├── key_columns:        [ DATA_INPUT[PERIOD_END_DATE] ]
│       ├── result_column:      "RATE"
│       ├── lookup_type:        RATE
│       ├── effective_date_col: "EFFECTIVE_DATE"
│       └── fallback:           NONE  ← ⚠ Exception raised if no rate found
│
└── BUSINESS_RULE [BR-SG-004]
    ├── label:      "Calculate SG Contribution Amount"
    ├── rule_type:  FORMULA
    ├── description: "SG contribution equals salary multiplied by the SG rate,
    │                 rounded to the nearest cent"
    │
    └── FORMULA [FORM-002]
        ├── label:       "SG_CONTRIBUTION_AMOUNT"
        ├── expression:  "ROUND( salary × sg_rate, 2 )"
        ├── result_type: MONETARY
        ├── result_unit: "AUD"
        ├── operands:
        │   ├── DATA_INPUT[GROSS_SALARY]
        │   │     source_type: ARGUMENT
        │   │     source_ref:  ":p_salary"
        │   │     is_key:      TRUE
        │   └── FORMULA[SG_RATE] (→ output of LKP-001)
        └── ROUNDING_RULE
              method:   ROUND
              decimals: 2
              basis:    CENT
```

---

## 5. ABRT Node Relationship Summary

```
BUSINESS_OPERATION
        │
        └─── BUSINESS_RULE (1..n)
                    │
          ┌─────────┼──────────────┬──────────────┐
          │         │              │              │
      CONDITION  FORMULA    POLICY_BRANCH   LOOKUP_REF
          │         │              │              │
     ┌────┴───┐  ┌──┴──┐     POLICY_CASE    DATA_INPUT
     │        │  │     │          │          CONSTANT
 CONDITION CONDITION DATA_  FORMULA   BUSINESS_RULE
(AND/OR)  (AND/OR)  INPUT  CONSTANT
                │
           DATA_INPUT
           CONSTANT
           FORMULA (nested)
```

---

## 6. Superannuation-Specific ABRT Patterns

The following recurring patterns are found in superannuation PL/SQL and have specific ABRT representations:

### Pattern 1: Age-Based Policy Switch
Superannuation rules often change at preservation age, retirement age (60), and maximum SG age (75).
```
POLICY_BRANCH(discriminator=MEMBER_AGE_BAND)
  ├── POLICY_CASE(when=UNDER_PRESERVATION_AGE) → CONSTRAINT(no_access)
  ├── POLICY_CASE(when=PRESERVATION_TO_60)     → ELIGIBILITY(cashing_conditions)
  └── POLICY_CASE(when=60_AND_OVER)            → FORMULA(unrestricted_benefit)
```

### Pattern 2: Tax Component Stacking
Benefits are split into taxable/tax-free components, each calculated separately.
```
BUSINESS_RULE(ALLOCATION)
  ├── FORMULA(TAX_FREE_COMPONENT)
  │     = contributions_before_July_1983 + crystallised_pre_July_83
  └── FORMULA(TAXABLE_COMPONENT)
        = total_benefit − tax_free_component
```

### Pattern 3: Effective-Date Rate Lookup
All rates (SG, tax, fees) are time-effective — always uses period date as key.
```
LOOKUP_REF
  key_columns:        [ PERIOD_END_DATE, MEMBER_CATEGORY ]
  effective_date_col: "EFFECTIVE_FROM"
  fallback:           RAISE_APPLICATION_ERROR
```

### Pattern 4: Regulatory Cap Constraint
```
CONDITION(left=CALCULATED_AMOUNT, op=GT, right=CONSTANT[CAP_VALUE])
  then_branch: FORMULA(result = CAP_VALUE)  ← apply cap
  else_branch: FORMULA(result = CALCULATED_AMOUNT)  ← pass through
```

### Pattern 5: Cursor-Based Batch Allocation
```
BUSINESS_OPERATION(type=ALLOCATION)
  └── BUSINESS_RULE(type=ALLOCATION)
        ├── DATA_INPUT(source_type=CURSOR_FIELD) [each member's balance]
        ├── FORMULA(member_share = member_balance / total_fund_balance × earnings)
        └── CONSTRAINT(total_allocated = total_earnings)  ← reconciliation check
```

---

## 7. ABRT JSON Schema Representation

For tooling purposes, the ABRT can be serialised as JSON:

```json
{
  "abrt_version": "1.2",
  "application": "Superannuation Admin System",
  "source_db": "Oracle 7",
  "business_operation": {
    "id": "CALC_SG_CONTRIBUTION",
    "label": "Calculate Superannuation Guarantee Contribution",
    "source": "CONTRIB_PKG.CALC_SG_CONTRIBUTION",
    "operation_type": "CALCULATION",
    "business_rules": [
      {
        "id": "BR-SG-001",
        "label": "SG Contribution Eligibility",
        "rule_type": "ELIGIBILITY",
        "description": "Member must be ACTIVE and aged <= 75",
        "conditions": [
          {
            "id": "COND-001",
            "logical_op": "AND",
            "children": [
              {
                "id": "COND-001a",
                "left": { "type": "DATA_INPUT", "ref": "MEMBERS.STATUS" },
                "operator": "EQ",
                "right": { "type": "CONSTANT", "value": "ACTIVE" }
              },
              {
                "id": "COND-001b",
                "left": { "type": "FORMULA", "ref": "FORM-001" },
                "operator": "LTE",
                "right": {
                  "type": "CONSTANT",
                  "value": 75,
                  "const_type": "REGULATORY",
                  "review_flag": true
                }
              }
            ]
          }
        ]
      }
    ]
  }
}
```

---

## 8. ABRT Extraction Methodology from PL/SQL

When analysing PL/SQL code to build an ABRT, apply the following process:

### Step 1 — Identify the Business Operation
- Name and type the stored procedure/function
- Read any header comments for business context
- Identify the IN/OUT parameters as primary DATA_INPUTs

### Step 2 — Identify Rule Boundaries
- Each major IF/ELSIF block is a likely BUSINESS_RULE boundary
- Each significant calculation assignment is a FORMULA
- Each SELECT from a reference table is a LOOKUP_REF
- Each RAISE_APPLICATION_ERROR is a CONSTRAINT violation point

### Step 3 — Extract Conditions
- Map IF conditions to CONDITION nodes
- Decompose AND/OR compound conditions into child CONDITION trees
- Identify whether conditions test DATA_INPUTs or FORMULAs

### Step 4 — Extract Formulas
- Capture arithmetic expressions as FORMULA nodes
- Record each ROUND/TRUNC call as a ROUNDING_RULE
- Identify sub-calculations as nested FORMULA children

### Step 5 — Classify Constants
- Flag all numeric/string literals embedded in code
- Classify as REGULATORY, SYSTEM, or LITERAL
- Mark high-risk `LITERAL` constants with `review_flag: TRUE`

### Step 6 — Trace Data Sources
- Every variable used in a condition or formula maps to a DATA_INPUT
- Record the original table.column or parameter name
- Note SYSDATE dependencies (critical for time-sensitive rules)

### Step 7 — Name the Rules in Business Language
- Rename every node using business terminology, not technical names
- Write BUSINESS_RULE descriptions in plain English
- Validate names with a domain expert if available

---

## 9. TRIGGER_OPERATION (Database Trigger Root Node)

Oracle database triggers (BEFORE/AFTER INSERT/UPDATE/DELETE on tables) are a primary location for business rules in PL/SQL systems. Unlike stored procedures which are called explicitly, triggers fire implicitly when DML occurs — making their embedded rules easy to overlook during analysis. The `TRIGGER_OPERATION` node elevates triggers to a top-level ABRT construct alongside `BUSINESS_OPERATION`.

### 9.1 Node Definition

```
TRIGGER_OPERATION
  id:              unique identifier (e.g., "TRG_ORDERS_WEEKDAY")
  label:           human-readable name (e.g., "Validate Order Day of Week")
  trigger_name:    Oracle trigger name (e.g., "ORDERS_WEEKDAY")
  table_name:      table the trigger is attached to (e.g., "ORDERS")
  table_owner:     schema owner of the table (optional)
  trigger_timing:  [ BEFORE | AFTER | INSTEAD_OF ]
  trigger_event:   [ INSERT | UPDATE | DELETE | INSERT_UPDATE |
                     INSERT_DELETE | UPDATE_DELETE | INSERT_UPDATE_DELETE ]
  trigger_level:   [ ROW | STATEMENT ]
  when_clause:     optional WHEN condition on the trigger (e.g., "NEW.amount > 0")
  enabled:         boolean (is the trigger currently enabled?)
  source_lines:    line range in source file
  business_rules:  [ BUSINESS_RULE+ ]
```

### 9.2 Trigger Timing

| Timing | Meaning | Typical Business Rule Use |
|---|---|---|
| `BEFORE` | Fires before the DML executes | Validation, default value injection, constraint enforcement |
| `AFTER` | Fires after the DML executes | Audit logging, cascading updates, notification |
| `INSTEAD_OF` | Replaces the DML (views only) | Updatable view logic |

### 9.3 Trigger Events

| Event | Fires On | Common Pattern |
|---|---|---|
| `INSERT` | New row inserted | Default values, mandatory field checks |
| `UPDATE` | Existing row modified | State transition validation, audit stamps |
| `DELETE` | Row removed | Soft-delete enforcement, referential cleanup |
| `INSERT_UPDATE` | Either insert or update | Shared validation (e.g., date range checks) |
| `INSERT_UPDATE_DELETE` | Any DML | Universal audit trail |

### 9.4 Trigger Level

| Level | Syntax | Fires | `:NEW` / `:OLD` Available |
|---|---|---|---|
| `ROW` | `FOR EACH ROW` | Once per affected row | Yes |
| `STATEMENT` | (no `FOR EACH ROW`) | Once per DML statement | No |

### 9.5 Business Rule Naming Convention

If no explicit business rule name is provided (via comments or naming conventions in the trigger body), the **trigger name** is used as the default business rule label. This ensures every trigger produces at least one named business rule in the ABRT.

### 9.6 Example: Row-Level BEFORE INSERT Trigger

```sql
CREATE TRIGGER orders_weekday BEFORE INSERT ON orders FOR EACH ROW
BEGIN
  IF TO_CHAR(:NEW.order_date, 'DY') = 'SUN' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Orders cannot be processed on weekends.');
  END IF;
END;
```

Maps to:

```
TRIGGER_OPERATION
├── id:              "TRG_ORDERS_WEEKDAY"
├── label:           "Validate Order Day of Week"
├── trigger_name:    "ORDERS_WEEKDAY"
├── table_name:      "ORDERS"
├── trigger_timing:  BEFORE
├── trigger_event:   INSERT
├── trigger_level:   ROW
├── enabled:         TRUE
│
└── BUSINESS_RULE [BR-ORD-001]
    ├── label:       "Sunday Order Prohibition"
    │                (derived from trigger name: ORDERS_WEEKDAY)
    ├── rule_type:   CONSTRAINT
    ├── description: "Orders cannot be placed on a Sunday"
    │
    ├── CONDITION [COND-ORD-001]
    │   ├── left_operand:  FORMULA(TO_CHAR(:NEW.order_date, 'DY'))
    │   ├── operator:      EQ
    │   └── right_operand: CONSTANT('SUN')
    │
    └── then_branch: RAISE_APPLICATION_ERROR(-20001, ...)
```

### 9.7 Superannuation-Specific Trigger Patterns

**Pattern T1: Audit Stamp Trigger (BEFORE INSERT OR UPDATE, ROW level)**
```
TRIGGER_OPERATION(trigger_event=INSERT_UPDATE, trigger_level=ROW)
  └── BUSINESS_RULE(rule_type=DERIVATION)
        ├── FORMULA(CREATED_BY = USER, CREATED_DATE = SYSDATE)  -- on INSERT
        └── FORMULA(MODIFIED_BY = USER, MODIFIED_DATE = SYSDATE) -- on UPDATE
```

**Pattern T2: Soft Delete Enforcement (BEFORE DELETE, ROW level)**
```
TRIGGER_OPERATION(trigger_event=DELETE, trigger_level=ROW)
  └── BUSINESS_RULE(rule_type=CONSTRAINT)
        └── RAISE_APPLICATION_ERROR('Direct deletes not permitted; use archive procedure')
```

**Pattern T3: State Transition Guard (BEFORE UPDATE, ROW level)**
```
TRIGGER_OPERATION(trigger_event=UPDATE, trigger_level=ROW)
  └── BUSINESS_RULE(rule_type=CONSTRAINT)
        ├── CONDITION(OLD.status = 'CLOSED' AND NEW.status != 'CLOSED')
        └── RAISE_APPLICATION_ERROR('Cannot reopen a closed account')
```

**Pattern T4: Sequence-Based Key Generation (BEFORE INSERT, ROW level)**
```
TRIGGER_OPERATION(trigger_event=INSERT, trigger_level=ROW)
  └── BUSINESS_RULE(rule_type=DERIVATION)
        └── FORMULA(NEW.id = sequence.NEXTVAL)
```

---

### 9.8 Updated ABRT Grammar

```
ABRT              ::= ( BUSINESS_OPERATION | TRIGGER_OPERATION )+

BUSINESS_OPERATION ::= { id, label, source, operation_type, BUSINESS_RULE+ }

TRIGGER_OPERATION ::= { id, label, trigger_name, table_name, table_owner?,
                         trigger_timing, trigger_event, trigger_level,
                         when_clause?, enabled,
                         BUSINESS_RULE+ }

BUSINESS_RULE     ::= { id, label, description, rule_type, priority,
                         (CONDITION | FORMULA | POLICY_BRANCH | LOOKUP_REF)+ }

CONDITION         ::= { id, label, operator, logical_op,
                         left_operand, right_operand,
                         CONDITION*,
                         then_branch, else_branch }

FORMULA           ::= { id, label, expression, result_type,
                         (DATA_INPUT | CONSTANT | FORMULA)+,
                         ROUNDING_RULE? }

POLICY_BRANCH     ::= { id, label, discriminator:(DATA_INPUT | FORMULA),
                         POLICY_CASE+ }

POLICY_CASE       ::= { when_value, label, CONDITION?, BUSINESS_RULE+ }

LOOKUP_REF        ::= { id, label, table_name,
                         key_columns:DATA_INPUT+,
                         result_column, lookup_type,
                         effective_date_col?,
                         fallback:CONSTANT? }

DATA_INPUT        ::= { id, label, source_type, source_ref,
                         data_type, is_key, nullable, default_value? }

CONSTANT          ::= { id, label, value, value_type,
                         const_type, description, review_flag }

VALUE_SET         ::= { id, label, values:CONSTANT+, value_type,
                         description?, review_flag }
```

### 9.9 Updated Node Relationship Summary

```
ABRT
├── BUSINESS_OPERATION
│         │
│         └─── BUSINESS_RULE (1..n)
│                     │
│           ┌─────────┼──────────────┬──────────────┐
│           │         │              │              │
│       CONDITION  FORMULA    POLICY_BRANCH   LOOKUP_REF
│
└── TRIGGER_OPERATION
          │
          ├── trigger_name, table_name, trigger_timing,
          │   trigger_event, trigger_level
          │
          └─── BUSINESS_RULE (1..n)
                     │
           ┌─────────┼──────────────┬──────────────┐
           │         │              │              │
       CONDITION  FORMULA    POLICY_BRANCH   LOOKUP_REF
```

---

## 10. ABRT Limitations and Assumptions

- The ABRT represents *one invocation path* through PL/SQL code. Dynamic SQL, REF CURSORs, and runtime-determined table names reduce traceability.
- Oracle Forms 3 trigger code that calls PL/SQL must be analysed separately and linked to the ABRT via the ARGUMENT data inputs.
- Exception handlers (WHEN OTHERS) may contain implicit business rules (default behaviours) that need explicit ABRT nodes.
- Package-level state (global variables across procedure calls) requires multi-procedure ABRTs to be linked.
- The Oracle 7 data dictionary (`ALL_SOURCE`, `ALL_ARGUMENTS`) can assist automated extraction but will require manual curation for business naming.

---

*ABRT Specification v1.2 — Superannuation Legacy System Documentation Project*
*v1.1 adds TRIGGER_OPERATION root node for Oracle database triggers*
*v1.2 adds optional CONDITION node to POLICY_CASE for IF/ELSIF guard expressions*
