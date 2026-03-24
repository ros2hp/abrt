-- ==========================================================================
-- ten-br.sql — Ten PL/SQL business rule test cases
-- ==========================================================================

-- BR 1: Employee overtime eligibility (compound AND with nested OR)
PROCEDURE calculate_overtime_pay (p_emp_id IN NUMBER) IS
  v_hours_worked  NUMBER;
  v_dept          VARCHAR2(30);
  v_salary_grade  NUMBER;
  v_hourly_rate   NUMBER;
BEGIN
  SELECT hours_worked, department, salary_grade, hourly_rate
    INTO v_hours_worked, v_dept, v_salary_grade, v_hourly_rate
    FROM employees WHERE id = p_emp_id;

  -- EMBEDDED RULE: Overtime at 1.5x for >40hrs if non-exempt, 2x on holidays
  IF v_hours_worked > 40 AND (v_dept != 'EXECUTIVE' AND v_salary_grade < 15) THEN
    UPDATE payroll SET overtime_amount = (v_hours_worked - 40) * v_hourly_rate * 1.5
     WHERE emp_id = p_emp_id;
  END IF;
END;


-- BR 2: Inventory reorder trigger (BEFORE UPDATE with threshold)
CREATE TRIGGER trg_inventory_reorder BEFORE UPDATE ON inventory FOR EACH ROW
BEGIN
  -- EMBEDDED RULE: Auto-reorder when stock drops below minimum threshold
  IF :NEW.quantity_on_hand < :NEW.reorder_point AND :OLD.quantity_on_hand >= :OLD.reorder_point THEN
    INSERT INTO purchase_orders (item_id, order_qty, status, created_date)
    VALUES (:NEW.item_id, :NEW.reorder_quantity, 'PENDING', SYSDATE);
  END IF;
END;


-- BR 3: Customer discount tiering (multi-branch CASE)
FUNCTION calculate_discount (p_cust_id IN NUMBER, p_order_total IN NUMBER) RETURN NUMBER IS
  v_loyalty_years  NUMBER;
  v_discount       NUMBER;
BEGIN
  SELECT TRUNC(MONTHS_BETWEEN(SYSDATE, join_date) / 12)
    INTO v_loyalty_years FROM customers WHERE id = p_cust_id;

  -- EMBEDDED RULE: Discount tiers based on loyalty years and order size
  CASE
    WHEN v_loyalty_years >= 10 AND p_order_total > 500 THEN
      v_discount := p_order_total * 0.15;
    WHEN v_loyalty_years >= 5 THEN
      v_discount := p_order_total * 0.10;
    WHEN v_loyalty_years >= 1 AND p_order_total > 200 THEN
      v_discount := p_order_total * 0.05;
    ELSE
      v_discount := 0;
  END CASE;

  RETURN v_discount;
END;


-- BR 4: Wire transfer compliance check (multiple constraints)
PROCEDURE submit_wire_transfer (p_account_id IN NUMBER, p_amount IN NUMBER, p_dest_country IN VARCHAR2) IS
  v_balance       NUMBER;
  v_account_status VARCHAR2(20);
BEGIN
  SELECT balance, status INTO v_balance, v_account_status
    FROM accounts WHERE id = p_account_id;

  -- EMBEDDED RULE: Account must be active
  IF v_account_status != 'ACTIVE' THEN
    RAISE_APPLICATION_ERROR(-20010, 'Wire transfers require an active account.');
  END IF;

  -- EMBEDDED RULE: Transfers over $10,000 to non-domestic destinations require compliance review
  IF p_amount > 10000 AND p_dest_country != 'AU' THEN
    INSERT INTO compliance_queue (account_id, amount, destination, status, flagged_date)
    VALUES (p_account_id, p_amount, p_dest_country, 'PENDING_REVIEW', SYSDATE);
  ELSE
    -- EMBEDDED RULE: Insufficient funds check
    IF v_balance < p_amount + 25.00 THEN
      RAISE_APPLICATION_ERROR(-20011, 'Insufficient funds including wire fee.');
    END IF;
    UPDATE accounts SET balance = balance - p_amount - 25.00 WHERE id = p_account_id;
  END IF;
END;


-- BR 5: Late payment interest calculation (date arithmetic with tiered rates)
FUNCTION calc_late_interest (p_invoice_id IN NUMBER) RETURN NUMBER IS
  v_due_date     DATE;
  v_amount_due   NUMBER;
  v_days_overdue NUMBER;
  v_interest     NUMBER;
BEGIN
  SELECT due_date, amount_due INTO v_due_date, v_amount_due
    FROM invoices WHERE id = p_invoice_id;

  v_days_overdue := TRUNC(SYSDATE - v_due_date);

  -- EMBEDDED RULE: Tiered late interest — 1.5% up to 30 days, 3% up to 90, 5% beyond
  IF v_days_overdue <= 0 THEN
    v_interest := 0;
  ELSIF v_days_overdue <= 30 THEN
    v_interest := v_amount_due * 0.015;
  ELSIF v_days_overdue <= 90 THEN
    v_interest := v_amount_due * 0.03;
  ELSE
    v_interest := v_amount_due * 0.05;
  END IF;

  RETURN v_interest;
END;


-- BR 6: Audit trail trigger (AFTER INSERT OR UPDATE with conditional logging)
CREATE TRIGGER trg_audit_sensitive_changes AFTER INSERT OR UPDATE ON customer_accounts FOR EACH ROW
BEGIN
  -- EMBEDDED RULE: Log all changes to high-value accounts (balance > 100000)
  IF :NEW.balance > 100000 THEN
    INSERT INTO audit_log (table_name, record_id, action_type, old_value, new_value, changed_by, change_date)
    VALUES ('CUSTOMER_ACCOUNTS', :NEW.account_id,
            CASE WHEN :OLD.account_id IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
            TO_CHAR(:OLD.balance), TO_CHAR(:NEW.balance),
            USER, SYSDATE);
  END IF;
END;


-- BR 7: Insurance premium rating (lookup + formula with multiple factors)
FUNCTION calculate_premium (p_policy_type IN VARCHAR2, p_age IN NUMBER, p_sum_insured IN NUMBER) RETURN NUMBER IS
  v_base_rate    NUMBER;
  v_age_factor   NUMBER;
  v_premium      NUMBER;
BEGIN
  SELECT base_rate INTO v_base_rate
    FROM premium_rates WHERE policy_type = p_policy_type AND effective_date <= SYSDATE
    ORDER BY effective_date DESC FETCH FIRST 1 ROW ONLY;

  -- EMBEDDED RULE: Age loading — under 25 pays 1.8x, 25-65 standard, over 65 pays 2.2x
  IF p_age < 25 THEN
    v_age_factor := 1.8;
  ELSIF p_age <= 65 THEN
    v_age_factor := 1.0;
  ELSE
    v_age_factor := 2.2;
  END IF;

  -- EMBEDDED RULE: Premium = sum insured * base rate * age factor, minimum $150
  v_premium := GREATEST(p_sum_insured * v_base_rate * v_age_factor, 150);

  RETURN v_premium;
END;


-- BR 8: Order fulfilment priority assignment (searched CASE with compound conditions)
PROCEDURE assign_fulfilment_priority (p_order_id IN NUMBER) IS
  v_customer_tier  VARCHAR2(20);
  v_order_value    NUMBER;
  v_is_expedited   CHAR(1);
  v_priority       NUMBER;
BEGIN
  SELECT c.tier, o.total_value, o.expedited_flag
    INTO v_customer_tier, v_order_value, v_is_expedited
    FROM orders o JOIN customers c ON o.customer_id = c.id
   WHERE o.id = p_order_id;

  -- EMBEDDED RULE: Priority 1-4 based on tier, value, and expedited flag
  CASE
    WHEN v_is_expedited = 'Y' AND v_customer_tier = 'PLATINUM' THEN
      v_priority := 1;
    WHEN v_is_expedited = 'Y' OR v_customer_tier = 'PLATINUM' THEN
      v_priority := 2;
    WHEN v_order_value > 1000 OR v_customer_tier = 'GOLD' THEN
      v_priority := 3;
    ELSE
      v_priority := 4;
  END CASE;

  UPDATE orders SET fulfilment_priority = v_priority WHERE id = p_order_id;
END;


-- BR 9: Membership expiry notification (date-based with multiple windows)
PROCEDURE process_membership_renewals IS
  CURSOR c_members IS
    SELECT member_id, expiry_date, email, membership_type
      FROM memberships WHERE expiry_date BETWEEN SYSDATE AND SYSDATE + 90;
BEGIN
  FOR r IN c_members LOOP
    -- EMBEDDED RULE: Send reminders at 90, 30, and 7 days before expiry; auto-cancel if lapsed > 14 days
    IF r.expiry_date - SYSDATE <= 7 THEN
      send_notification(r.member_id, r.email, 'URGENT_RENEWAL');
    ELSIF r.expiry_date - SYSDATE <= 30 THEN
      send_notification(r.member_id, r.email, 'RENEWAL_REMINDER');
    ELSIF r.expiry_date - SYSDATE <= 90 THEN
      send_notification(r.member_id, r.email, 'ADVANCE_NOTICE');
    END IF;
  END LOOP;

  -- EMBEDDED RULE: Auto-cancel memberships lapsed more than 14 days
  UPDATE memberships SET status = 'CANCELLED'
   WHERE expiry_date < SYSDATE - 14 AND status = 'ACTIVE';
END;


-- BR 10: Tax withholding calculation (IF/ELSIF with progressive brackets)
FUNCTION calculate_tax_withholding (p_annual_salary IN NUMBER) RETURN NUMBER IS
  v_tax NUMBER;
BEGIN
  -- EMBEDDED RULE: Australian-style progressive tax brackets (simplified)
  IF p_annual_salary <= 18200 THEN
    v_tax := 0;
  ELSIF p_annual_salary <= 45000 THEN
    v_tax := (p_annual_salary - 18200) * 0.19;
  ELSIF p_annual_salary <= 120000 THEN
    v_tax := 5092 + (p_annual_salary - 45000) * 0.325;
  ELSIF p_annual_salary <= 180000 THEN
    v_tax := 29467 + (p_annual_salary - 120000) * 0.37;
  ELSE
    v_tax := 51667 + (p_annual_salary - 180000) * 0.45;
  END IF;

  RETURN ROUND(v_tax / 12, 2);
END;
