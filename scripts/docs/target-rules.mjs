// SQL constraints/indexes in the target model; never applied to an existing DB here.
export function applyTargetRules(model){
 const changed=new Set();
 const table=id=>{const t=model.tables.find(t=>t.id===id);if(!t)throw Error('Unknown target table '+id);return t;};
 const mark=t=>{if(t.status!=='planned'){t.status='modified';changed.add(t.id);}};
 const check=(id,name,expression)=>{const t=table(id);t.constraints.push(`CONSTRAINT ${name} CHECK (${expression})`);mark(t);};
 const index=(id,name,expression,unique=false)=>{const t=table(id);t.indexes.push({name,unique,partial:/\bWHERE\b/.test(expression),status:'planned',sql:`CREATE ${unique?'UNIQUE ':''}INDEX ${name} ON ${t.schema}.${t.name} ${expression};`});mark(t);};
 const replace=(id,name,expression)=>{const t=table(id);if(!t.constraints.some(c=>c.startsWith('CONSTRAINT '+name+' ')))throw Error('Missing old constraint '+name);t.constraints=t.constraints.filter(c=>!c.startsWith('CONSTRAINT '+name+' '));check(id,name,expression);};
 const states=(id,column,values)=>check(id,table(id).name+'_'+column+'_v1_ck',`${column} IN (${values.split(',').map(v=>"'"+v+"'").join(', ')})`);
 for(const t of model.tables.filter(t=>t.status!=='current')){
  const has=n=>t.columns.some(c=>c.name===n);
  for(const c of t.columns.filter(c=>c.status==='planned')){
   if(['version','session_version','state_version','account_version','hold_version','fence_version','source_version','last_sequence','attempt_count','lease_version','result_version'].includes(c.name))check(t.id,t.name+'_'+c.name+'_v1_ck',`${c.name} >= 0`);
   if(['request_hash','payload_hash','evidence_hash','operation_hash','body_hash','account_snapshot_hash','receipt_hash','snapshot_hash','payment_snapshot_hash','expected_hash','sha256'].includes(c.name))check(t.id,t.name+'_'+c.name+'_v1_ck',`${c.name} ~ '^[0-9a-f]{64}$'`);
  }
  if(has('currency')&&t.status==='planned')check(t.id,t.name+'_currency_v1_ck',"currency = 'KRW'");
 }
 for(const ns of ['commerce','payment','settlement','discovery']){
  const inbox=ns+'.consumer_inbox',outbox=ns+'.outbox_event',job=ns+'.event_recovery_job';
  states(inbox,'status','RECEIVED,WAITING_GAP,PROCESSING,PROCESSED,IGNORED,FAILED,QUARANTINED');
  check(inbox,'consumer_inbox_sequence_v1_ck','aggregate_version >= 1');
  check(inbox,'consumer_inbox_payload_v1_ck',"jsonb_typeof(payload) = 'object'");
  check(inbox,'consumer_inbox_lease_v1_ck','(lease_token IS NULL) = (lease_expires_at IS NULL)');
  index(inbox,'ix_consumer_inbox_due_v1','(status, next_retry_at, entry_id)');
  index(inbox,'ix_consumer_inbox_lease_v1','(lease_expires_at, entry_id) WHERE lease_expires_at IS NOT NULL');
  check(outbox,'outbox_envelope_v1_ck',"aggregate_version >= 1 AND event_version = 1 AND jsonb_typeof(payload) = 'object' AND trace_id ~ '^[0-9a-f]{32}$' AND octet_length(serialized_body) > 0");
  index(outbox,'uq_outbox_stream_sequence_v1','(aggregate_type, aggregate_id, aggregate_version)',true);
  index(outbox,'ix_outbox_due_v1',"(available_at, outbox_event_id) WHERE status IN ('PENDING','FAILED')");
  index(outbox,'ix_outbox_lease_v1',"(lease_expires_at, outbox_event_id) WHERE status = 'PUBLISHING'");
  states(job,'status','QUEUED,RUNNING,SUCCEEDED,FAILED');
  states(job,'queue_type','OUTBOX,INBOX');
  check(job,'event_recovery_job_target_v1_ck',"(queue_type = 'INBOX' AND consumer_name IS NOT NULL) OR (queue_type = 'OUTBOX' AND consumer_name IS NULL)");
  check(job,'event_recovery_job_terminal_v1_ck',"(status IN ('QUEUED','RUNNING') AND completed_at IS NULL) OR (status IN ('SUCCEEDED','FAILED') AND completed_at IS NOT NULL)");
  index(job,'ix_event_recovery_job_due_v1',"(status, next_retry_at, job_id) WHERE status IN ('QUEUED','RUNNING')");
  index(job,'ix_event_recovery_job_source_v1','(entry_id, created_at, job_id)');
 }
 states('commerce.admin_user','mfa_state','ENROLLED,RE_ENROLLMENT_REQUIRED');
 check('commerce.admin_user','admin_user_mfa_secret_v1_ck',"(mfa_state = 'ENROLLED' AND totp_secret_cipher IS NOT NULL) OR (mfa_state = 'RE_ENROLLMENT_REQUIRED' AND totp_secret_cipher IS NULL)");
 check('commerce.claim_quote','claim_quote_expiry_v1_ck',"expires_at = created_at + interval '5 minutes'");
 check('commerce.claim_quote','claim_quote_snapshot_v1_ck',"jsonb_typeof(quote_snapshot) = 'object'");
 index('commerce.claim_quote','ix_claim_quote_expiry_v1','(expires_at, quote_id)');
 index('commerce.claim_quote','ix_claim_quote_owner_v1','(member_id, order_id, created_at)');
 check('commerce.claim_reason_change','claim_reason_evidence_v1_ck',"jsonb_typeof(evidence_ids) = 'array'");
 index('commerce.claim_reason_change','uq_claim_reason_open_v1',"(claim_id) WHERE status = 'REQUESTED'",true);
 index('commerce.command_idempotency','ix_command_resource_v1','(resource_id) WHERE resource_id IS NOT NULL');
 check('commerce.order_item_unit','order_item_unit_money_v1_ck','unit_ordinal BETWEEN 1 AND 99 AND product_amount >= 1 AND discount_amount >= 0 AND paid_amount = product_amount - discount_amount AND paid_amount > 0 AND commission_amount BETWEEN 0 AND paid_amount AND fulfillment_generation >= 0');
 index('commerce.payout_fence','uq_payout_fence_live_v1',"(payout_attempt_id) WHERE status IN ('ACTIVE','CONSUMED')",true);
 states('commerce.payout_fence','status','ACTIVE,CONSUMED,EXPIRED');
 check('commerce.payout_fence','payout_fence_consumed_v1_ck',"(status = 'CONSUMED' AND consumed_at IS NOT NULL AND dispatch_permit_id IS NOT NULL AND operation_hash IS NOT NULL) OR (status <> 'CONSUMED' AND consumed_at IS NULL AND dispatch_permit_id IS NULL)");
 states('payment.order_payment_guard','gate','OPEN,CLOSED');
 states('payment.payment_operation','kind','APPROVE,CANCEL,REFUND');
 states('payment.payment_operation','status','REQUESTED,PROCESSING,PENDING,UNKNOWN,SUCCEEDED,FAILED,CANCELLED');
 index('payment.payment_operation','uq_payment_operation_dispatch_v1',"(payment_id) WHERE payment_id IS NOT NULL AND status IN ('PROCESSING','PENDING','UNKNOWN')",true);
 index('payment.payment_operation','ix_payment_operation_due_v1','(status, next_retry_at, operation_id)');
 index('payment.payment_operation','ix_payment_operation_lease_v1','(lease_expires_at, operation_id) WHERE lease_expires_at IS NOT NULL');
 check('payment.payment','payment_voided_balance_v1_ck',"currency = 'KRW' AND total_payment_amount <= 100000000 AND voided_amount >= 0 AND refunded_amount + voided_amount <= total_payment_amount AND ((status = 'VOIDED' AND voided_amount = total_payment_amount AND refunded_amount = 0) OR (status <> 'VOIDED' AND voided_amount = 0))");
 check('payment.refund','refund_source_v1_ck',"claim_id IS NOT NULL OR compensation_id IS NOT NULL");
 check('payment.refund','refund_requester_v1_ck',"requested_by_type = 'SYSTEM' OR requested_by_id IS NOT NULL");
 check('payment.refund','refund_limit_v1_ck',"currency = 'KRW' AND requested_amount <= 100000000 AND (status <> 'SUCCEEDED' OR actual_refunded_amount = requested_amount)");
 check('payment.refund_unit_allocation','refund_unit_allocation_amount_v1_ck','unit_ordinal BETWEEN 1 AND 99 AND amount BETWEEN 1 AND 100000000');
 check('settlement.settlement','ck_settlement_gross_net_v1','gross_net_amount = credit_amount - debit_amount');
 replace('settlement.settlement','ck_settlement_payout_limit','payout_amount <= GREATEST(gross_net_amount - hold_amount, 0)');
 check('settlement.settlement','ck_settlement_hold_limit_v1','hold_amount <= GREATEST(gross_net_amount, 0)');
 const ledger=table('settlement.seller_ledger_entry');
 ledger.constraints=ledger.constraints.filter(c=>!c.startsWith('CONSTRAINT uq_seller_ledger_reversal '));
 ledger.unique=ledger.unique.filter(k=>!(k.length===1&&k[0]==='reversal_of_entry_id'));
 ledger.note=(ledger.note||'')+' MIG-REVERSAL: partial reversals use owner lock and cumulative absolute sum <= original; source_key remains unique. No direct updates/deletes.';
 check(ledger.id,'ck_ledger_not_self_reversal_v1','reversal_of_entry_id IS NULL OR reversal_of_entry_id <> seller_ledger_entry_id');
 index(ledger.id,'ix_seller_ledger_reversal_v1','(reversal_of_entry_id, seller_ledger_entry_id) WHERE reversal_of_entry_id IS NOT NULL');
 check('settlement.seller_recognition_unit','seller_recognition_amounts_v1_ck','recognized_amount > 0 AND commission_amount BETWEEN 0 AND recognized_amount AND reversed_amount BETWEEN 0 AND recognized_amount AND reversed_fee_amount BETWEEN 0 AND commission_amount');
 check('settlement.seller_carry_forward','seller_carry_forward_amount_v1_ck','signed_amount <> 0 AND (target_settlement_id IS NULL OR target_settlement_id <> source_settlement_id)');
 for(const id of ['settlement.simulated_bank_receipt','settlement.bank_reconciliation_receipt']){
  states(id,'status','SUCCEEDED,FAILED');check(id,table(id).name+'_amount_v1_ck','amount BETWEEN 1 AND 9007199254740991');
  index(id,'ix_'+table(id).name+'_cursor_v1','(occurred_at, bank_receipt_id)');
 }
 states('settlement.bank_reconciliation_run','status','RUNNING,SUCCEEDED,FAILED');
 check('settlement.bank_reconciliation_run','bank_reconciliation_run_completed_v1_ck',"(status = 'RUNNING' AND completed_at IS NULL) OR (status IN ('SUCCEEDED','FAILED') AND completed_at IS NOT NULL)");
 index('settlement.bank_reconciliation_run','ix_bank_reconciliation_run_due_v1','(status, business_date, run_id)');
 states('settlement.bank_reconciliation_discrepancy','kind','PROVIDER_ONLY,INTERNAL_ONLY,AMOUNT_MISMATCH,STATUS_MISMATCH,DUPLICATE');
 states('settlement.bank_reconciliation_discrepancy','status','OPEN,INVESTIGATING,RESOLVED,ACCEPTED,FALSE_POSITIVE');
 check('settlement.bank_reconciliation_discrepancy','bank_discrepancy_resolution_v1_ck',"(status IN ('OPEN','INVESTIGATING') AND resolved_at IS NULL AND resolution_event IS NULL) OR (status IN ('RESOLVED','ACCEPTED','FALSE_POSITIVE') AND resolved_at IS NOT NULL AND approval_id IS NOT NULL AND resolution_event IS NOT NULL AND jsonb_typeof(resolution_event) = 'object')");
 for(const id of ['settlement.bank_reconciliation_receipt','settlement.bank_reconciliation_discrepancy']){
  for(const c of table(id).columns.filter(c=>c.type==='jsonb'))check(id,table(id).name+'_'+c.name+'_v1_ck',`${c.name} IS NULL OR jsonb_typeof(${c.name}) = 'object'`);
 }
 index('settlement.bank_reconciliation_discrepancy','ix_bank_discrepancy_open_v1',"(recorded_at, discrepancy_id) WHERE status IN ('OPEN','INVESTIGATING')");
 index('settlement.bank_reconciliation_discrepancy','ix_bank_discrepancy_run_v1','(run_id, status, discrepancy_id)');
 index('settlement.bank_reconciliation_discrepancy','ix_bank_discrepancy_payout_v1','(payout_attempt_id) WHERE payout_attempt_id IS NOT NULL');
 index('discovery.search_projection_generation','uq_search_generation_active_v1',"(status) WHERE status = 'ACTIVE'",true);
 states('discovery.search_projection_generation','status','BUILDING,VERIFYING,ACTIVE,RETIRED,FAILED');
 index('discovery.search_product_projection','ix_search_price_v1','(generation_id, category_id, min_price, product_id)');
 index('discovery.search_product_projection','ix_search_newest_v1','(generation_id, published_at DESC, product_id)');
 replace('commerce.shipment_event','shipment_event_received_at_ck',"received_at >= occurred_at - interval '5 minutes'");
 for(const ns of ['pg1','pg2']){
  index(ns+'.pg_transaction','ix_pg_transaction_cursor_v1','(created_at, transaction_id)');
  index(ns+'.pg_webhook_outbox','ix_pg_webhook_due_v1','(status, next_retry_at, event_id)');
 }
 for(const id of changed)model.changes.push({table:id,kind:'ALTER_CONSTRAINTS_INDEXES',note:'v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates.'});
}
