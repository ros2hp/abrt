-- ==========================================================================
-- br-4.sql — Single procedure with two embedded business rules
-- mixed with non-business-rule processing logic
-- ==========================================================================

PROCEDURE process_claim_settlement (p_claim_id IN NUMBER) IS
  v_claim_status     VARCHAR2(20);
  v_claim_amount     NUMBER;
  v_policy_id        NUMBER;
  v_policy_type      VARCHAR2(30);
  v_coverage_limit   NUMBER;
  v_deductible       NUMBER;
  v_claimant_id      NUMBER;
  v_assessor_id      NUMBER;
  v_settlement_amt   NUMBER;
  v_payment_ref      VARCHAR2(40);
  v_batch_id         NUMBER;
  v_retry_count      NUMBER := 0;
  v_lock_acquired    BOOLEAN := FALSE;
BEGIN
  --  acquire advisory lock to prevent concurrent settlement ***
  WHILE v_retry_count < 3 AND NOT v_lock_acquired LOOP
    BEGIN
      SELECT claim_id INTO v_claim_status
        FROM claim_locks WHERE claim_id = p_claim_id FOR UPDATE NOWAIT;
      v_lock_acquired := TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        v_retry_count := v_retry_count + 1;
        DBMS_LOCK.SLEEP(0.5);
    END;
  END LOOP;

  IF NOT v_lock_acquired THEN
    RAISE_APPLICATION_ERROR(-20050, 'Unable to acquire lock on claim record.');
  END IF;

  --  fetch claim and policy details ***
  SELECT c.status, c.claim_amount, c.policy_id, c.claimant_id,
         p.policy_type, p.coverage_limit, p.deductible
    INTO v_claim_status, v_claim_amount, v_policy_id, v_claimant_id,
         v_policy_type, v_coverage_limit, v_deductible
    FROM claims c
    JOIN policies p ON c.policy_id = p.id
   WHERE c.id = p_claim_id;

  --  assign assessor using round-robin from available pool ***
  SELECT assessor_id INTO v_assessor_id
    FROM (
      SELECT assessor_id, ROW_NUMBER() OVER (ORDER BY last_assigned_date ASC) rn
        FROM assessors
       WHERE status = 'AVAILABLE' AND specialisation = v_policy_type
    ) WHERE rn = 1;

  UPDATE assessors SET last_assigned_date = SYSDATE WHERE assessor_id = v_assessor_id;

  -- Claim must be in ASSESSED status and amount must not exceed coverage limit minus deductible
  IF v_claim_status != 'ASSESSED' THEN
    RAISE_APPLICATION_ERROR(-20051, 'Claim must be fully assessed before settlement.');
  END IF;

  v_settlement_amt := LEAST(v_claim_amount, v_coverage_limit - v_deductible);

  IF v_settlement_amt <= 0 THEN
    UPDATE claims SET status = 'DENIED', denial_reason = 'Claim amount within deductible', updated_date = SYSDATE
     WHERE id = p_claim_id;
    RETURN;
  END IF;

  --  generate payment reference and get next batch ***
  v_payment_ref := 'PAY-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' || LPAD(claim_payment_seq.NEXTVAL, 8, '0');

  SELECT NVL(MAX(batch_id), 0) + 1 INTO v_batch_id
    FROM settlement_batches WHERE batch_date = TRUNC(SYSDATE);

  --  log the settlement attempt for audit trail ***
  INSERT INTO settlement_audit_log (claim_id, assessor_id, action, action_date, details)
  VALUES (p_claim_id, v_assessor_id, 'SETTLEMENT_INITIATED', SYSDATE,
          'Amount: ' || TO_CHAR(v_settlement_amt, 'FM$999,999,990.00'));

  -- Settlements over $50,000 require senior approval; under that amount are auto-approved
  IF v_settlement_amt > 50000 THEN
    UPDATE claims
       SET status = 'PENDING_SENIOR_APPROVAL',
           settlement_amount = v_settlement_amt,
           assigned_assessor = v_assessor_id,
           payment_ref = v_payment_ref,
           updated_date = SYSDATE
     WHERE id = p_claim_id;

    INSERT INTO approval_queue (claim_id, approval_type, requested_amount, requested_by, request_date, status)
    VALUES (p_claim_id, 'SENIOR_SETTLEMENT', v_settlement_amt, v_assessor_id, SYSDATE, 'PENDING');
  ELSE
    UPDATE claims
       SET status = 'SETTLED',
           settlement_amount = v_settlement_amt,
           assigned_assessor = v_assessor_id,
           payment_ref = v_payment_ref,
           settlement_date = SYSDATE,
           updated_date = SYSDATE
     WHERE id = p_claim_id;

    INSERT INTO payments (payment_ref, claim_id, claimant_id, amount, payment_date, batch_id, status)
    VALUES (v_payment_ref, p_claim_id, v_claimant_id, v_settlement_amt, SYSDATE, v_batch_id, 'QUEUED');
  END IF;

  --  release advisory lock ***
  DELETE FROM claim_locks WHERE claim_id = p_claim_id;

  COMMIT;
END;
