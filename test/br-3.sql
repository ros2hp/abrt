-- ==========================================================================
-- br-3.sql — Ten PL/SQL business rule test cases (set 3)
-- ==========================================================================

-- BR 1: Employee leave approval (nested IF with balance check and manager override)
PROCEDURE approve_leave_request (p_request_id IN NUMBER) IS
  v_emp_id        NUMBER;
  v_leave_type    VARCHAR2(20);
  v_days_requested NUMBER;
  v_leave_balance  NUMBER;
  v_manager_level  NUMBER;
BEGIN
  SELECT emp_id, leave_type, days_requested
    INTO v_emp_id, v_leave_type, v_days_requested
    FROM leave_requests WHERE id = p_request_id;

  SELECT leave_balance INTO v_leave_balance
    FROM leave_balances WHERE emp_id = v_emp_id AND leave_type = v_leave_type;

  -- EMBEDDED RULE: Leave request must not exceed available balance, unless manager level >= 3 can override up to 5 extra days
  IF v_days_requested <= v_leave_balance THEN
    UPDATE leave_requests SET status = 'APPROVED', approved_date = SYSDATE WHERE id = p_request_id;
    UPDATE leave_balances SET leave_balance = leave_balance - v_days_requested
     WHERE emp_id = v_emp_id AND leave_type = v_leave_type;
  ELSE
    SELECT manager_level INTO v_manager_level
      FROM employees WHERE id = v_emp_id;

    IF v_manager_level >= 3 AND v_days_requested <= v_leave_balance + 5 THEN
      UPDATE leave_requests SET status = 'APPROVED_OVERRIDE', approved_date = SYSDATE WHERE id = p_request_id;
      UPDATE leave_balances SET leave_balance = 0
       WHERE emp_id = v_emp_id AND leave_type = v_leave_type;
    ELSE
      UPDATE leave_requests SET status = 'REJECTED', rejection_reason = 'Insufficient leave balance' WHERE id = p_request_id;
    END IF;
  END IF;
END;


-- BR 2: Product price adjustment trigger (BEFORE UPDATE with percentage cap)
CREATE TRIGGER trg_price_change_limit BEFORE UPDATE OF unit_price ON products FOR EACH ROW
DECLARE
  v_pct_change NUMBER;
BEGIN
  v_pct_change := ABS(:NEW.unit_price - :OLD.unit_price) / :OLD.unit_price * 100;

  -- EMBEDDED RULE: Price changes exceeding 25% require approval; block changes over 50%
  IF v_pct_change > 50 THEN
    RAISE_APPLICATION_ERROR(-20030, 'Price change exceeds maximum 50% threshold.');
  ELSIF v_pct_change > 25 THEN
    :NEW.price_status := 'PENDING_APPROVAL';
    :NEW.approval_required_date := SYSDATE;
  END IF;
END;


-- BR 3: Loan repayment allocation (waterfall: fees first, then interest, then principal)
PROCEDURE allocate_repayment (p_loan_id IN NUMBER, p_payment_amount IN NUMBER) IS
  v_outstanding_fees    NUMBER;
  v_accrued_interest    NUMBER;
  v_principal_balance   NUMBER;
  v_remaining           NUMBER;
  v_fee_applied         NUMBER;
  v_interest_applied    NUMBER;
  v_principal_applied   NUMBER;
BEGIN
  SELECT outstanding_fees, accrued_interest, principal_balance
    INTO v_outstanding_fees, v_accrued_interest, v_principal_balance
    FROM loans WHERE id = p_loan_id;

  v_remaining := p_payment_amount;

  -- EMBEDDED RULE: Payment waterfall — fees first, then accrued interest, then principal
  v_fee_applied := LEAST(v_remaining, v_outstanding_fees);
  v_remaining := v_remaining - v_fee_applied;

  v_interest_applied := LEAST(v_remaining, v_accrued_interest);
  v_remaining := v_remaining - v_interest_applied;

  v_principal_applied := LEAST(v_remaining, v_principal_balance);

  UPDATE loans
     SET outstanding_fees    = outstanding_fees - v_fee_applied,
         accrued_interest    = accrued_interest - v_interest_applied,
         principal_balance   = principal_balance - v_principal_applied,
         last_payment_date   = SYSDATE
   WHERE id = p_loan_id;

  INSERT INTO loan_payments (loan_id, payment_date, total_amount, fee_portion, interest_portion, principal_portion)
  VALUES (p_loan_id, SYSDATE, p_payment_amount, v_fee_applied, v_interest_applied, v_principal_applied);
END;


-- BR 4: Credit limit assignment (simple CASE on account type with income multiplier)
FUNCTION assign_credit_limit (p_account_type IN VARCHAR2, p_annual_income IN NUMBER) RETURN NUMBER IS
  v_multiplier  NUMBER;
  v_limit       NUMBER;
BEGIN
  -- EMBEDDED RULE: Credit limit = income * multiplier based on account type, capped at $500,000
  CASE p_account_type
    WHEN 'PLATINUM' THEN v_multiplier := 5.0;
    WHEN 'GOLD'     THEN v_multiplier := 3.0;
    WHEN 'SILVER'   THEN v_multiplier := 1.5;
    WHEN 'BASIC'    THEN v_multiplier := 0.5;
    ELSE v_multiplier := 0.25;
  END CASE;

  v_limit := LEAST(p_annual_income * v_multiplier, 500000);

  RETURN v_limit;
END;


-- BR 5: Appointment scheduling conflict check (date-range overlap detection)
PROCEDURE schedule_appointment (p_doctor_id IN NUMBER, p_patient_id IN NUMBER,
                                 p_start_time IN DATE, p_end_time IN DATE) IS
  v_conflict_count NUMBER;
  v_is_emergency   CHAR(1);
BEGIN
  -- EMBEDDED RULE: Appointments cannot overlap with existing bookings for the same doctor
  SELECT COUNT(*) INTO v_conflict_count
    FROM appointments
   WHERE doctor_id = p_doctor_id
     AND status != 'CANCELLED'
     AND p_start_time < end_time
     AND p_end_time > start_time;

  IF v_conflict_count > 0 THEN
    SELECT NVL(emergency_flag, 'N') INTO v_is_emergency
      FROM patients WHERE id = p_patient_id;

    -- EMBEDDED RULE: Emergency patients can double-book; non-emergency are rejected
    IF v_is_emergency = 'Y' THEN
      INSERT INTO appointments (doctor_id, patient_id, start_time, end_time, status, priority)
      VALUES (p_doctor_id, p_patient_id, p_start_time, p_end_time, 'EMERGENCY_OVERRIDE', 1);
    ELSE
      RAISE_APPLICATION_ERROR(-20040, 'Time slot conflicts with an existing appointment.');
    END IF;
  ELSE
    INSERT INTO appointments (doctor_id, patient_id, start_time, end_time, status, priority)
    VALUES (p_doctor_id, p_patient_id, p_start_time, p_end_time, 'CONFIRMED', 5);
  END IF;
END;


-- BR 6: Inventory write-off trigger (AFTER UPDATE with threshold-based auto-disposal)
CREATE TRIGGER trg_inventory_writeoff AFTER UPDATE OF quantity_on_hand ON warehouse_inventory FOR EACH ROW
BEGIN
  -- EMBEDDED RULE: When stock drops to zero and item is perishable, create disposal record
  IF :NEW.quantity_on_hand = 0 AND :OLD.quantity_on_hand > 0 AND :NEW.is_perishable = 'Y' THEN
    INSERT INTO disposal_records (item_id, warehouse_id, disposal_date, disposal_type, quantity_disposed, reason)
    VALUES (:NEW.item_id, :NEW.warehouse_id, SYSDATE, 'STOCK_DEPLETION', :OLD.quantity_on_hand, 'Perishable item fully depleted');
  END IF;

  -- EMBEDDED RULE: When stock falls below safety threshold, raise replenishment alert
  IF :NEW.quantity_on_hand < :NEW.safety_stock AND :OLD.quantity_on_hand >= :OLD.safety_stock THEN
    INSERT INTO replenishment_alerts (item_id, warehouse_id, alert_date, current_qty, safety_stock, status)
    VALUES (:NEW.item_id, :NEW.warehouse_id, SYSDATE, :NEW.quantity_on_hand, :NEW.safety_stock, 'OPEN');
  END IF;
END;


-- BR 7: Commission calculation (tiered with accelerators above quota)
FUNCTION calculate_commission (p_salesperson_id IN NUMBER, p_period IN VARCHAR2) RETURN NUMBER IS
  v_quota         NUMBER;
  v_actual_sales  NUMBER;
  v_pct_achieved  NUMBER;
  v_commission    NUMBER;
  v_base_rate     NUMBER := 0.05;
BEGIN
  SELECT sales_quota INTO v_quota
    FROM sales_targets WHERE salesperson_id = p_salesperson_id AND period = p_period;

  SELECT NVL(SUM(sale_amount), 0) INTO v_actual_sales
    FROM sales WHERE salesperson_id = p_salesperson_id AND sale_period = p_period;

  v_pct_achieved := v_actual_sales / v_quota * 100;

  -- EMBEDDED RULE: Commission tiers — base 5%, 7% if 100-150% of quota, 10% above 150%, zero if below 50%
  IF v_pct_achieved < 50 THEN
    v_commission := 0;
  ELSIF v_pct_achieved < 100 THEN
    v_commission := v_actual_sales * 0.05;
  ELSIF v_pct_achieved <= 150 THEN
    v_commission := v_actual_sales * 0.07;
  ELSE
    v_commission := v_actual_sales * 0.10;
  END IF;

  RETURN ROUND(v_commission, 2);
END;


-- BR 8: Document retention classification (CASE with multiple criteria)
PROCEDURE classify_document_retention (p_doc_id IN NUMBER) IS
  v_doc_type       VARCHAR2(30);
  v_sensitivity    VARCHAR2(20);
  v_created_date   DATE;
  v_retention_years NUMBER;
  v_disposal_method VARCHAR2(20);
BEGIN
  SELECT doc_type, sensitivity, created_date
    INTO v_doc_type, v_sensitivity, v_created_date
    FROM documents WHERE id = p_doc_id;

  -- EMBEDDED RULE: Retention period based on document type
  CASE v_doc_type
    WHEN 'FINANCIAL' THEN v_retention_years := 7;
    WHEN 'LEGAL'     THEN v_retention_years := 10;
    WHEN 'HR'        THEN v_retention_years := 5;
    WHEN 'MEDICAL'   THEN v_retention_years := 15;
    WHEN 'GENERAL'   THEN v_retention_years := 3;
    ELSE v_retention_years := 1;
  END CASE;

  -- EMBEDDED RULE: Highly sensitive documents require secure shredding; others use standard disposal
  IF v_sensitivity = 'TOP_SECRET' OR v_sensitivity = 'CONFIDENTIAL' THEN
    v_disposal_method := 'SECURE_SHRED';
  ELSE
    v_disposal_method := 'STANDARD';
  END IF;

  UPDATE documents
     SET retention_years = v_retention_years,
         disposal_date = ADD_MONTHS(v_created_date, v_retention_years * 12),
         disposal_method = v_disposal_method
   WHERE id = p_doc_id;
END;


-- BR 9: Account dormancy detection (BEFORE UPDATE trigger with inactivity window)
CREATE TRIGGER trg_account_dormancy BEFORE UPDATE ON bank_accounts FOR EACH ROW
BEGIN
  -- EMBEDDED RULE: If last transaction was over 365 days ago and account is still ACTIVE, mark as DORMANT
  IF :NEW.last_transaction_date < SYSDATE - 365
     AND :OLD.account_status = 'ACTIVE'
     AND :NEW.account_status = 'ACTIVE' THEN
    :NEW.account_status := 'DORMANT';
    :NEW.dormancy_date := SYSDATE;
  END IF;

  -- EMBEDDED RULE: Dormant accounts with balance under $10 are flagged for closure review
  IF :NEW.account_status = 'DORMANT' AND :NEW.balance < 10 THEN
    :NEW.closure_review_flag := 'Y';
    :NEW.closure_review_date := SYSDATE;
  END IF;
END;


-- BR 10: Shipping surcharge calculation (compound conditions with weight, dimension, and hazmat)
FUNCTION calculate_shipping_surcharge (p_shipment_id IN NUMBER) RETURN NUMBER IS
  v_weight        NUMBER;
  v_length        NUMBER;
  v_width         NUMBER;
  v_height        NUMBER;
  v_dim_weight    NUMBER;
  v_billable_wt   NUMBER;
  v_is_hazmat     CHAR(1);
  v_is_fragile    CHAR(1);
  v_surcharge     NUMBER := 0;
BEGIN
  SELECT weight_kg, length_cm, width_cm, height_cm, hazmat_flag, fragile_flag
    INTO v_weight, v_length, v_width, v_height, v_is_hazmat, v_is_fragile
    FROM shipments WHERE id = p_shipment_id;

  -- EMBEDDED RULE: Dimensional weight = L*W*H / 5000; billable weight is the greater of actual and dimensional
  v_dim_weight := (v_length * v_width * v_height) / 5000;
  v_billable_wt := GREATEST(v_weight, v_dim_weight);

  -- EMBEDDED RULE: Oversize surcharge if billable weight exceeds 30kg
  IF v_billable_wt > 30 THEN
    v_surcharge := v_surcharge + (v_billable_wt - 30) * 2.50;
  END IF;

  -- EMBEDDED RULE: Hazardous materials surcharge is flat $75
  IF v_is_hazmat = 'Y' THEN
    v_surcharge := v_surcharge + 75;
  END IF;

  -- EMBEDDED RULE: Fragile handling surcharge is 15% of base surcharge, minimum $12
  IF v_is_fragile = 'Y' THEN
    v_surcharge := v_surcharge + GREATEST(v_surcharge * 0.15, 12);
  END IF;

  RETURN ROUND(v_surcharge, 2);
END;
