-- ============================================================================
-- ABRT v1.6 MySQL Schema
-- Relational tables for serialising ABRT JSON to a MySQL database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Top-level: ABRT extraction run
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_extraction (
    extraction_id   INT AUTO_INCREMENT PRIMARY KEY,
    abrt_version    VARCHAR(10)   NOT NULL,
    application     VARCHAR(200)  NOT NULL,
    source_file     VARCHAR(500)  NOT NULL,
    extracted_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- BUSINESS_OPERATION (root node for procedures/functions)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_business_operation (
    operation_id    VARCHAR(100)  NOT NULL PRIMARY KEY,
    extraction_id   INT           NOT NULL,
    label           VARCHAR(500)  NOT NULL,
    source          VARCHAR(500)  NOT NULL,
    operation_type  ENUM('CALCULATION','VALIDATION','PROCESS','QUERY','EVENT')
                    NOT NULL,
    CONSTRAINT fk_busop_extraction
        FOREIGN KEY (extraction_id) REFERENCES abrt_extraction(extraction_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- TRIGGER_OPERATION (root node for database triggers)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_trigger_operation (
    operation_id    VARCHAR(100)  NOT NULL PRIMARY KEY,
    extraction_id   INT           NOT NULL,
    label           VARCHAR(500)  NOT NULL,
    trigger_name    VARCHAR(128)  NOT NULL,
    table_name      VARCHAR(128)  NOT NULL,
    table_owner     VARCHAR(128)  NULL,
    trigger_timing  ENUM('BEFORE','AFTER','INSTEAD_OF')
                    NOT NULL,
    trigger_event   ENUM('INSERT','UPDATE','DELETE',
                         'INSERT_UPDATE','INSERT_DELETE',
                         'UPDATE_DELETE','INSERT_UPDATE_DELETE')
                    NOT NULL,
    trigger_level   ENUM('ROW','STATEMENT')
                    NOT NULL,
    when_clause     VARCHAR(2000) NULL,
    enabled         BOOLEAN       NOT NULL DEFAULT TRUE,
    source_lines    VARCHAR(20)   NULL,
    CONSTRAINT fk_trgop_extraction
        FOREIGN KEY (extraction_id) REFERENCES abrt_extraction(extraction_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- BUSINESS_RULE (child of either operation type)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_business_rule (
    rule_id             VARCHAR(100)  NOT NULL PRIMARY KEY,
    business_op_id      VARCHAR(100)  NULL,
    trigger_op_id       VARCHAR(100)  NULL,
    parent_rule_id      VARCHAR(100)  NULL,
    label               VARCHAR(500)  NOT NULL,
    rule_type           ENUM('CONSTRAINT','FORMULA','POLICY','ELIGIBILITY',
                             'DERIVATION','ALLOCATION','LOOKUP','ACTION')
                        NOT NULL,
    description         TEXT          NULL,
    priority            INT           NULL,
    source_lines        VARCHAR(20)   NULL,
    CONSTRAINT fk_rule_busop
        FOREIGN KEY (business_op_id) REFERENCES abrt_business_operation(operation_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_rule_trgop
        FOREIGN KEY (trigger_op_id) REFERENCES abrt_trigger_operation(operation_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_rule_parent
        FOREIGN KEY (parent_rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_rule_parent
        CHECK (business_op_id IS NOT NULL OR trigger_op_id IS NOT NULL
               OR parent_rule_id IS NOT NULL)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- CONDITION (branch node within a business rule)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_condition (
    condition_id    VARCHAR(100)  NOT NULL PRIMARY KEY,
    rule_id         VARCHAR(100)  NOT NULL,
    parent_cond_id  VARCHAR(100)  NULL,
    label           VARCHAR(500)  NOT NULL,
    logical_op      ENUM('AND','OR','NOT','NONE')
                    NOT NULL DEFAULT 'NONE',
    operator        ENUM('EQ','NEQ','GT','GTE','LT','LTE',
                         'IN','NOT_IN','IS_NULL','IS_NOT_NULL','BETWEEN')
                    NULL,
    left_type       ENUM('DATA_INPUT','FORMULA','CONSTANT')  NULL,
    left_ref        VARCHAR(100)  NULL,
    right_type      ENUM('DATA_INPUT','FORMULA','CONSTANT','VALUE_SET')  NULL,
    right_ref       VARCHAR(100)  NULL,
    then_type       ENUM('ACTION','FORMULA','BUSINESS_RULE','POLICY_BRANCH')  NULL,
    then_ref        VARCHAR(100)  NULL,
    else_type       ENUM('ACTION','FORMULA','BUSINESS_RULE','POLICY_BRANCH')  NULL,
    else_ref        VARCHAR(100)  NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    CONSTRAINT fk_cond_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_cond_parent
        FOREIGN KEY (parent_cond_id) REFERENCES abrt_condition(condition_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- FORMULA (calculation node)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_formula (
    formula_id      VARCHAR(100)  NOT NULL PRIMARY KEY,
    rule_id         VARCHAR(100)  NOT NULL,
    label           VARCHAR(500)  NOT NULL,
    expression      VARCHAR(2000) NOT NULL,
    result_type     ENUM('MONETARY','PERCENTAGE','INTEGER','DATE',
                         'BOOLEAN','CATEGORY')
                    NOT NULL,
    result_unit     VARCHAR(50)   NULL,
    rounding_method ENUM('ROUND','TRUNCATE','CEILING','FLOOR','BANKER')
                    NULL,
    rounding_decimals INT         NULL,
    rounding_basis  ENUM('CENT','DOLLAR','UNIT')
                    NULL,
    wrapper_fn      ENUM('GREATEST','LEAST','NVL','ABS','SIGN')
                    NULL,             -- outer bounding/coalescing function
    note            TEXT          NULL,
    CONSTRAINT fk_formula_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- DATA_INPUT (leaf node — data sources)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_data_input (
    data_input_id   VARCHAR(100)  NOT NULL PRIMARY KEY,
    label           VARCHAR(500)  NOT NULL,
    source_type     ENUM('ARGUMENT','TABLE_COLUMN','CURSOR_FIELD',
                         'PACKAGE_VARIABLE','GLOBAL','SEQUENCE','SYSDATE',
                         'FORM_ITEM','GLOBAL_VAR','SYSTEM_VAR','FORM_PARAM')
                    NOT NULL,
    source_ref      VARCHAR(500)  NOT NULL,
    data_type       ENUM('NUMBER','VARCHAR','DATE','BOOLEAN')
                    NOT NULL,
    is_key          BOOLEAN       NOT NULL DEFAULT FALSE,
    nullable        BOOLEAN       NOT NULL DEFAULT TRUE,
    default_value   VARCHAR(500)  NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- CONSTANT (leaf node — hard-coded values)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_constant (
    constant_id     VARCHAR(100)  NOT NULL PRIMARY KEY,
    label           VARCHAR(500)  NOT NULL,
    value           VARCHAR(500)  NOT NULL,
    value_type      ENUM('NUMERIC','STRING','DATE','BOOLEAN')
                    NOT NULL,
    const_type      ENUM('LITERAL','NAMED_CONST','TABLE_PARAM',
                         'REGULATORY','SYSTEM','FORM_DEFAULT','ALERT_TEXT')
                    NOT NULL,
    description     TEXT          NULL,
    review_flag     BOOLEAN       NOT NULL DEFAULT FALSE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- VALUE_SET (collection leaf node — set of constants for IN / NOT_IN)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_value_set (
    value_set_id    VARCHAR(100)  NOT NULL PRIMARY KEY,
    label           VARCHAR(500)  NOT NULL,
    value_type      ENUM('NUMERIC','STRING','DATE')
                    NOT NULL,
    description     TEXT          NULL,
    review_flag     BOOLEAN       NOT NULL DEFAULT FALSE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- VALUE_SET_MEMBER (links a value set to its constituent constants)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_value_set_member (
    value_set_id    VARCHAR(100)  NOT NULL,
    constant_id     VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (value_set_id, constant_id),
    CONSTRAINT fk_vsmember_set
        FOREIGN KEY (value_set_id) REFERENCES abrt_value_set(value_set_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_vsmember_const
        FOREIGN KEY (constant_id) REFERENCES abrt_constant(constant_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- ACTION (imperative outcome of a condition branch)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_action (
    action_id       VARCHAR(100)  NOT NULL PRIMARY KEY,
    action_type     ENUM('RAISE_ERROR','UPDATE','INSERT','DELETE',
                         'CALL','RETURN','ASSIGN')
                    NOT NULL,
    target          VARCHAR(500)  NULL,       -- table.column, procedure, or variable
    error_code      INT           NULL,       -- RAISE_ERROR only
    message         TEXT          NULL,        -- RAISE_ERROR only
    value_type      ENUM('CONSTANT','DATA_INPUT','FORMULA')  NULL,
    value_ref       VARCHAR(100)  NULL,       -- UPDATE, ASSIGN, RETURN value
    description     TEXT          NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- ACTION_ARGUMENT (named arguments for CALL actions)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_action_argument (
    action_id       VARCHAR(100)  NOT NULL,
    argument_name   VARCHAR(128)  NOT NULL,
    argument_type   ENUM('CONSTANT','DATA_INPUT','FORMULA')
                    NOT NULL,
    argument_ref    VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (action_id, argument_name),
    CONSTRAINT fk_actarg_action
        FOREIGN KEY (action_id) REFERENCES abrt_action(action_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- ACTION_COLUMN (column mappings for INSERT actions)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_action_column (
    action_id       VARCHAR(100)  NOT NULL,
    column_name     VARCHAR(128)  NOT NULL,
    column_type     ENUM('CONSTANT','DATA_INPUT','FORMULA')
                    NOT NULL,
    column_ref      VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (action_id, column_name),
    CONSTRAINT fk_actcol_action
        FOREIGN KEY (action_id) REFERENCES abrt_action(action_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- FORMULA_OPERAND (links formulas to their inputs: DATA_INPUT, CONSTANT, or
-- nested FORMULA)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_formula_operand (
    operand_id      INT AUTO_INCREMENT PRIMARY KEY,
    formula_id      VARCHAR(100)  NOT NULL,
    operand_type    ENUM('DATA_INPUT','CONSTANT','FORMULA')
                    NOT NULL,
    operand_ref     VARCHAR(100)  NOT NULL,             -- fk to abrt_constant.constant_id OR abrt_data_input.data_input_id 
    sort_order      INT           NOT NULL DEFAULT 0,
    CONSTRAINT fk_operand_formula
        FOREIGN KEY (formula_id) REFERENCES abrt_formula(formula_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- FORMULA_WRAPPER_ARG (additional arguments for wrapper functions, e.g.
-- the floor value in GREATEST(calc, 150))
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_formula_wrapper_arg (
    wrapper_arg_id  INT AUTO_INCREMENT PRIMARY KEY,
    formula_id      VARCHAR(100)  NOT NULL,
    arg_type        ENUM('CONSTANT','DATA_INPUT','FORMULA')
                    NOT NULL,
    arg_ref         VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    CONSTRAINT fk_wraparg_formula
        FOREIGN KEY (formula_id) REFERENCES abrt_formula(formula_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- CURSOR_SCOPE (iteration boundary for cursor-based rules)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_cursor_scope (
    cursor_scope_id VARCHAR(100)  NOT NULL PRIMARY KEY,
    rule_id         VARCHAR(100)  NOT NULL,
    label           VARCHAR(500)  NOT NULL,
    cursor_name     VARCHAR(128)  NOT NULL,
    source_table    VARCHAR(128)  NOT NULL,
    filter_cond_id  VARCHAR(100)  NULL,       -- root CONDITION of cursor WHERE clause
    CONSTRAINT fk_cscp_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_cscp_filter
        FOREIGN KEY (filter_cond_id) REFERENCES abrt_condition(condition_id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- CURSOR_SCOPE_FIELD (links a cursor scope to its consumed DATA_INPUT fields)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_cursor_scope_field (
    cursor_scope_id VARCHAR(100)  NOT NULL,
    data_input_id   VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (cursor_scope_id, data_input_id),
    CONSTRAINT fk_cscpfld_scope
        FOREIGN KEY (cursor_scope_id) REFERENCES abrt_cursor_scope(cursor_scope_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_cscpfld_input
        FOREIGN KEY (data_input_id) REFERENCES abrt_data_input(data_input_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- DERIVED_VALUE (links a business rule to its pre-evaluated FORMULA values,
-- evaluated in order before conditions and branches)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_derived_value (
    rule_id         VARCHAR(100)  NOT NULL,
    formula_id      VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (rule_id, formula_id),
    CONSTRAINT fk_derval_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_derval_formula
        FOREIGN KEY (formula_id) REFERENCES abrt_formula(formula_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- POLICY_BRANCH (multi-way decision node)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_policy_branch (
    branch_id           VARCHAR(100)  NOT NULL PRIMARY KEY,
    rule_id             VARCHAR(100)  NOT NULL,
    label               VARCHAR(500)  NOT NULL,
    discriminator_type  ENUM('SIMPLE','SEARCHED')
                        NOT NULL,
    discriminator_ref   VARCHAR(100)  NULL,       -- required for SIMPLE; null for SEARCHED
    bracket_type        ENUM('MARGINAL','FLAT','TIERED')
                        NULL,                     -- optional: numeric tiered policy semantics
    note                TEXT          NULL,
    CONSTRAINT fk_branch_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- POLICY_CASE (individual branch within a POLICY_BRANCH)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_policy_case (
    case_id         INT AUTO_INCREMENT PRIMARY KEY,
    branch_id       VARCHAR(100)  NOT NULL,
    priority        INT           NOT NULL,
    label           VARCHAR(500)  NOT NULL,
    when_type       ENUM('CONSTANT','VALUE_SET','CONDITION','DEFAULT')
                    NOT NULL,
    when_ref        VARCHAR(100)  NULL,
    CONSTRAINT fk_case_branch
        FOREIGN KEY (branch_id) REFERENCES abrt_policy_branch(branch_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- POLICY_CASE_RULE (links a policy case to its business rules)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_policy_case_rule (
    case_id         INT           NOT NULL,
    rule_id         VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (case_id, rule_id),
    CONSTRAINT fk_caserule_case
        FOREIGN KEY (case_id) REFERENCES abrt_policy_case(case_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_caserule_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- POLICY_CASE_ACTION (links a policy case directly to actions — used when
-- a branch leads to a simple imperative outcome with no further rules)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_policy_case_action (
    case_id         INT           NOT NULL,
    action_id       VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (case_id, action_id),
    CONSTRAINT fk_caseact_case
        FOREIGN KEY (case_id) REFERENCES abrt_policy_case(case_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_caseact_action
        FOREIGN KEY (action_id) REFERENCES abrt_action(action_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- LOOKUP_REF (reference data lookup node)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_lookup_ref (
    lookup_id           VARCHAR(100)  NOT NULL PRIMARY KEY,
    rule_id             VARCHAR(100)  NOT NULL,
    label               VARCHAR(500)  NOT NULL,
    table_name          VARCHAR(128)  NOT NULL,
    result_column       VARCHAR(128)  NOT NULL,
    lookup_type         ENUM('RATE','AMOUNT','CATEGORY','FLAG','DATE_RANGE')
                        NOT NULL,
    effective_date_col  VARCHAR(128)  NULL,
    fallback_ref        VARCHAR(100)  NULL,
    CONSTRAINT fk_lookup_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- LOOKUP_KEY_COLUMN (key inputs for a lookup)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_lookup_key_column (
    lookup_id       VARCHAR(100)  NOT NULL,
    data_input_id   VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (lookup_id, data_input_id),
    CONSTRAINT fk_lkpkey_lookup
        FOREIGN KEY (lookup_id) REFERENCES abrt_lookup_ref(lookup_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_lkpkey_input
        FOREIGN KEY (data_input_id) REFERENCES abrt_data_input(data_input_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- RULE_ACTION (links business rules to direct child ACTION nodes — used
-- when rule_type = 'ACTION' and the action is an unconditional child)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_rule_action (
    rule_id         VARCHAR(100)  NOT NULL,
    action_id       VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (rule_id, action_id),
    CONSTRAINT fk_ruleact_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_ruleact_action
        FOREIGN KEY (action_id) REFERENCES abrt_action(action_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- RULE_DATA_INPUT (links business rules to their standalone data inputs,
-- e.g. procedure arguments not part of a condition or formula)
-- ----------------------------------------------------------------------------
CREATE TABLE abrt_rule_data_input (
    rule_id         VARCHAR(100)  NOT NULL,
    data_input_id   VARCHAR(100)  NOT NULL,
    sort_order      INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (rule_id, data_input_id),
    CONSTRAINT fk_ruledi_rule
        FOREIGN KEY (rule_id) REFERENCES abrt_business_rule(rule_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_ruledi_input
        FOREIGN KEY (data_input_id) REFERENCES abrt_data_input(data_input_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Indexes for common query patterns
-- ----------------------------------------------------------------------------
CREATE INDEX idx_busop_extraction ON abrt_business_operation(extraction_id);
CREATE INDEX idx_trgop_extraction ON abrt_trigger_operation(extraction_id);
CREATE INDEX idx_trgop_table      ON abrt_trigger_operation(table_name);
CREATE INDEX idx_rule_busop       ON abrt_business_rule(business_op_id);
CREATE INDEX idx_rule_trgop       ON abrt_business_rule(trigger_op_id);
CREATE INDEX idx_cond_rule        ON abrt_condition(rule_id);
CREATE INDEX idx_formula_rule     ON abrt_formula(rule_id);
CREATE INDEX idx_operand_formula  ON abrt_formula_operand(formula_id);
CREATE INDEX idx_branch_rule      ON abrt_policy_branch(rule_id);
CREATE INDEX idx_case_branch      ON abrt_policy_case(branch_id);
CREATE INDEX idx_constant_review  ON abrt_constant(review_flag);
CREATE INDEX idx_vsmember_set     ON abrt_value_set_member(value_set_id);
CREATE INDEX idx_valueset_review  ON abrt_value_set(review_flag);
CREATE INDEX idx_action_type      ON abrt_action(action_type);
CREATE INDEX idx_action_target    ON abrt_action(target);
CREATE INDEX idx_actarg_action    ON abrt_action_argument(action_id);
CREATE INDEX idx_actcol_action    ON abrt_action_column(action_id);
CREATE INDEX idx_wraparg_formula  ON abrt_formula_wrapper_arg(formula_id);
CREATE INDEX idx_cscp_rule        ON abrt_cursor_scope(rule_id);
CREATE INDEX idx_cscpfld_scope    ON abrt_cursor_scope_field(cursor_scope_id);
CREATE INDEX idx_derval_rule      ON abrt_derived_value(rule_id);
CREATE INDEX idx_branch_bracket   ON abrt_policy_branch(bracket_type);
CREATE INDEX idx_caseact_case     ON abrt_policy_case_action(case_id);
CREATE INDEX idx_ruleact_rule     ON abrt_rule_action(rule_id);
