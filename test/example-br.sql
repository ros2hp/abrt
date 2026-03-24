PROCEDURE process_loan_application (p_cust_id IN NUMBER) IS
  v_credit_score NUMBER;
BEGIN
  SELECT credit_score INTO v_credit_score FROM customers WHERE id = p_cust_id;

  -- EMBEDDED RULE: Tier 1 approval requires a score > 750
  IF v_credit_score > 750 THEN
      update_status(p_cust_id, 'AUTO_APPROVE');
  ELSE
      update_status(p_cust_id, 'MANUAL_REVIEW');
  END IF;
END;


CREATE TRIGGER orders_weekday BEFORE INSERT ON orders FOR EACH ROW
BEGIN
  -- EMBEDDED RULE: Orders cannot be placed for a Sunday
  IF TO_CHAR(:NEW.order_date, 'DY') = 'SUN' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Orders cannot be processed on weekends.');
  END IF;
END;


FUNCTION calculate_shipping (p_weight IN NUMBER, p_zone IN VARCHAR2) RETURN NUMBER IS
BEGIN
  -- EMBEDDED RULE: Flat rate for Zone A, weight-based for others
  IF p_zone = 'ZONE_A' THEN
    RETURN 10.00;
  ELSIF p_weight > 50 THEN
    RETURN p_weight * 1.5;
  ELSE
    RETURN p_weight * 1.1;
  END IF;
END;


FUNCTION bank_fee(v_balance IN, v_tx_amount IN, v_account_type IN)
BEGIN

    CASE
        WHEN v_balance > 1000000 THEN 
            v_fee_case := 0;
            
        WHEN v_account_type = 'SAVINGS' THEN 
            v_fee_case := 5;
            
        WHEN v_account_type = 'CHECKING' THEN 
            v_fee_case := GREATEST(v_tx_amount * 0.01, 1);
            
        ELSE 
            v_fee_case := 10;
    END CASE;

   RETURN v_fee_case;

END
  
PROCEDURE mark_as_shipped (p_order_id IN NUMBER) IS
  v_status VARCHAR2(20);
BEGIN
  SELECT status INTO v_status FROM orders WHERE id = p_order_id;

  -- EMBEDDED RULE: Status must be 'PAID' to transition to 'SHIPPED'
  IF v_status != 'PAID' THEN
    RAISE_APPLICATION_ERROR(-20002, 'Cannot ship unpaid orders.');
  END IF;
  
  UPDATE orders SET status = 'SHIPPED' WHERE id = p_order_id;
END;

PROCEDURE purge_old_logs IS
BEGIN
  -- EMBEDDED RULE: Retain error logs for 90 days, but success logs for only 7
  DELETE FROM system_logs 
  WHERE (log_level = 'INFO' AND log_date < SYSDATE - 7)
     OR (log_level = 'ERROR' AND log_date < SYSDATE - 90);
END;

