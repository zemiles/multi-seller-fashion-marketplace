// X-01..11 are target HTTP contracts, not implemented endpoints.
export function registerExtensions({c,ci,st,d,ops},h){
 const {schemas,def,ref,s,en,i,uuid,time,bool,version,arr,nullable,obj,page,reason,ver,param,paging,add}=h;
 const hash={type:'string',pattern:'^[0-9a-f]{64}$'},roles=en('SUPPORT','CATALOG','RISK','FINANCE','IAM');
 const owner=en('COMMERCE','PAYMENT','SETTLEMENT','DISCOVERY');
 const unitId={type:'string',pattern:'^[0-9a-f-]{36}:[1-9][0-9]?$',example:'11111111-1111-4111-8111-111111111111:1'};
 const uniqueIds={...arr(uuid,0,20),uniqueItems:true};
 const clone=n=>structuredClone(schemas[n]);
 schemas.UploadCreate.allOf=[{if:{properties:{contentType:{enum:['image/jpeg','image/png','image/webp']}},required:['contentType']},then:{properties:{sizeBytes:{maximum:5242880}}}}];
 schemas.ClaimQuoteRequest=clone('ClaimCreate');
 schemas.ClaimCreate.properties.quoteId=uuid;
 schemas.ClaimCreate.properties.expectedVersion=version;
 schemas.ClaimCreate.required.push('expectedVersion');
 def('ClaimQuoteItem',{orderItemId:uuid,unitOrdinals:{...arr(i(1,99),1,99),uniqueItems:true},productRefundAmount:i(),discountReversalAmount:i(),taxRefundAmount:{type:'integer',const:0},refundAmount:i()});
 def('ClaimQuoteCharge',{orderChargeId:uuid,sellerId:uuid,refundAmount:i()});
 def('ClaimQuote',{quoteId:uuid,expiresAt:time,orderVersion:version,requestHash:hash,eligibleUnitIds:{...arr(unitId,0,9900),uniqueItems:true},items:arr(ref('ClaimQuoteItem')),charges:arr(ref('ClaimQuoteCharge')),totalRefund:ref('Money'),allowedActions:arr(en('CANCEL','RETURN','EXCHANGE'),0,3),reasons:arr(s(1,100))});
 def('ClaimReasonChangeCreate',{reasonCode:schemas.ClaimCreate.properties.reasonCode,evidenceIds:uniqueIds,...ver});
 def('ClaimReasonChange',{requestId:uuid,claimId:uuid,oldReasonCode:schemas.ClaimCreate.properties.reasonCode,newReasonCode:schemas.ClaimCreate.properties.reasonCode,evidenceIds:uniqueIds,status:en('REQUESTED','APPROVED','REJECTED','CANCELLED'),decisionReason:nullable(s(1,2000)),version,createdAt:time});
 def('ClaimReasonDecision',{decision:en('APPROVE','REJECT'),reason:s(1,2000),expectedClaimVersion:version,...ver});
 def('ReturnTrackingEvent',{eventId:uuid,sequence:i(1),status:en('PICKUP_PENDING','IN_TRANSIT','RECEIVED'),occurredAt:time,...ver});
 def('ShipmentCorrection',{approvalId:uuid,originalEventId:uuid,correctedStatus:en('IN_TRANSIT','DELIVERED','LOST','FAILED'),correctedOccurredAt:time,reason:s(1,2000),evidenceIds:uniqueIds,...ver});
 def('SellerVerificationReview',{verification:ref('SellerVerification'),sellerId:uuid,documentIds:arr(uuid,1,20),requestedAt:time});
 def('ProductReviewRequest',{requestId:uuid,product:ref('ProductDetail'),submittedRevisionId:uuid,status:en('REQUESTED','APPROVED','REJECTED'),version,submittedAt:time});
 def('ReviewModerationRequest',{review:ref('Review'),revisionId:uuid,evidenceIds:uniqueIds,submittedAt:time});
 def('AccountChangeReview',{sellerId:uuid,request:ref('AccountChange'),evidenceIds:uniqueIds,approvalId:nullable(uuid),createdAt:time});
 def('MaskedSettlementAccount',{accountId:uuid,bankCode:s(1,20),maskedAccountNumber:s(4,40),holderNameMasked:s(1,100),status:en('ACTIVE','INACTIVE'),accountVersion:version});
 def('SellerSettlementAccount',{sellerId:uuid,current:nullable(ref('MaskedSettlementAccount')),pendingRequest:nullable(ref('AccountChange')),version});
 def('UploadStatus',{id:uuid,purpose:schemas.UploadCreate.properties.purpose,status:schemas.Upload.properties.status,sizeBytes:i(1,10485760),sha256:hash,rejectionCode:nullable(s(1,100)),version,expiresAt:time});
 def('Administrator',{id:uuid,email:{type:'string',format:'email'},roles:{...arr(roles,1,5),uniqueItems:true},status:en('ACTIVE','SUSPENDED','DISABLED'),mfaStatus:en('ENROLLED','RE_ENROLLMENT_REQUIRED'),version});
 def('AdminRoleChangeCreate',{roles:{...arr(roles,1,5),uniqueItems:true},...reason,...ver});
 def('AdminMfaRecoveryCreate',{...reason,...ver});
 def('ApprovedAdminExecute',{approvalId:uuid,expectedApprovalVersion:version,...ver});
 const actionRoles={ACCOUNT_CHANGE:'FINANCE',FINANCIAL_ADJUSTMENT:'FINANCE',UNKNOWN_RESOLUTION:'FINANCE',PAYOUT:'FINANCE',PENALTY:'RISK',PENALTY_REVOKE:'RISK',ADMIN_ROLE_CHANGE:'IAM',DELIVERY_CORRECTION:'SUPPORT',CLAIM_EXCEPTION:'SUPPORT',MFA_RECOVERY:'IAM',FINANCIAL_EVENT_REPLAY:'FINANCE'};
 schemas.ApprovalCreate.properties.actionType=en(...Object.keys(actionRoles));
 schemas.Approval.properties.actionType=en(...Object.keys(actionRoles));
 Object.assign(schemas.Approval.properties,{reason:s(1,2000),evidenceIds:uniqueIds,changeSummary:arr(obj({field:s(1,100),before:nullable(s(0,500)),after:nullable(s(0,500))}),0,100)});
 schemas.Approval.required.push('reason','evidenceIds','changeSummary');
 def('ExchangeConversion',{decision:en('ACCEPT_RETURN','KEEP_EXCHANGE'),reason:s(1,2000),...ver});
 def('ExchangeConversionResult',{originalClaimId:uuid,linkedReturnClaimId:nullable(uuid),status:en('RETURN_CREATED','EXCHANGE_RETAINED'),claim:ref('Claim')});
 schemas.ClaimExceptionCreate=clone('ClaimCreate');
 delete schemas.ClaimExceptionCreate.properties.quoteId;
 Object.assign(schemas.ClaimExceptionCreate.properties,{approvalId:uuid,reason:s(1,2000)});
 schemas.ClaimExceptionCreate.required.push('approvalId','reason');
 def('ServerBehaviorEvent',{eventId:uuid,type:en('WISHLIST','CART_ADD'),memberPseudonym:hash,productId:uuid,revisionId:uuid,quantity:i(1,99),occurredAt:time,sourceCommandId:uuid,consentVersion:s(1,80),analyticsOptIn:{type:'boolean',const:true}},['eventId','type','memberPseudonym','productId','revisionId','occurredAt','sourceCommandId','consentVersion','analyticsOptIn']);
 schemas.ServerBehaviorEvent.allOf=[{if:{properties:{type:{const:'CART_ADD'}},required:['type']},then:{required:['quantity']},else:{not:{required:['quantity']}}}];
 def('SearchRebuildCreate',{snapshotId:uuid,reason:s(1,2000)});
 def('EventQueueEntry',{entryId:uuid,owner,queueType:en('OUTBOX','INBOX'),consumer:nullable(s(1,100)),eventId:uuid,eventType:s(1,100),topic:s(1,150),aggregateType:s(1,100),aggregateId:s(1,150),aggregateVersion:i(1,9007199254740991),lastSequence:version,payloadHash:hash,status:en('PENDING','PUBLISHING','PUBLISHED','FAILED','DEAD','RECEIVED','WAITING_GAP','PROCESSING','PROCESSED','IGNORED','QUARANTINED'),attemptCount:i(0,2147483647),nextRetryAt:nullable(time),leaseExpiresAt:nullable(time),financial:bool,lastErrorCode:nullable(s(1,100)),version,occurredAt:time});
 def('EventReplayCreate',{owner,queueType:en('OUTBOX','INBOX'),consumer:s(1,100),expectedHash:hash,approvalId:uuid,reason:s(1,2000),evidenceIds:uniqueIds,...ver},['owner','queueType','expectedHash','reason','evidenceIds','expectedVersion']);
 schemas.EventReplayCreate.allOf=[{if:{properties:{queueType:{const:'INBOX'}},required:['queueType']},then:{required:['consumer']},else:{not:{required:['consumer']}}}];
 def('RecoveryJob',{jobId:uuid,owner,entryId:uuid,eventId:uuid,queueType:en('OUTBOX','INBOX'),status:en('QUEUED','RUNNING','SUCCEEDED','FAILED'),failureCode:nullable(s(1,100)),statusUrl:s(1,500),createdAt:time,completedAt:nullable(time),version});
 const errors={'400':['UNKNOWN_FIELD','INVALID_INPUT'],'403':['FORBIDDEN','APPROVAL_SELF_DECISION'],'404':['RESOURCE_NOT_FOUND'],'409':['VERSION_CONFLICT','IDEMPOTENCY_CONFLICT','APPROVAL_PAYLOAD_MISMATCH','INVALID_STATE'],'410':['RESOURCE_EXPIRED'],'422':['POLICY_VIOLATION'],'503':['DEPENDENCY_UNAVAILABLE']};
 function x(doc,group,method,path,id,request,response,req,opt={}){
  const action=add(doc,method,path,id,'보완 '+group,id,request,response,req,opt);
  action['x-contract-extension']=group;action['x-error-codes']=structuredClone(errors);
  return action;
 }
 const pub=(group,method,path,id,request,response,req,opt)=>x(c,group,method,'/api/v1'+path,id,request,response,req,opt);
 const seller='/sellers/{sellerId}',admin='/admin';
 const support={roles:['ADMIN_SUPPORT']},catalog={roles:['ADMIN_CATALOG']},iam={roles:['ADMIN_IAM']},finance={roles:['ADMIN_FINANCE']},fulfillment={roles:['SELLER_OWNER','SELLER_FULFILLMENT']};
 pub('X-01','post','/orders/{orderId}/claim-quotes','quoteClaim','ClaimQuoteRequest','ClaimQuote','CLM-01,CLM-02',{status:200,description:'소유 주문의 현재 unit/charge snapshot으로 5분 quote를 저장합니다. 재고/환불 예약 효과는 없습니다. quoteId가 있는 createClaim은 회원/order/version/정규화 입력 hash/expiry를 대조합니다. 불가 unit은 reasons로 반환, 실제 접수 시 다시 검증합니다.'});
 c.paths['/api/v1/orders/{orderId}/claims'].post.description+=' expectedVersion은 주문 version입니다. quoteId가 있으면 같은 입력 hash와 5분 만료를 검증합니다. quote 없이 접수하면 동일 원본 규칙으로 서버 재계산합니다.';
 pub('X-02','post','/claims/{claimId}/reason-change-requests','requestClaimReasonChange','ClaimReasonChangeCreate','ClaimReasonChange','CLM-01',{description:'Claim 소유 회원만. 열린 사유변경은 하나, 환불 dispatch 후 금액에 영향을 주는 변경 거부. 원 사유를 덮어쓰지 않고 변경 요청 이력 저장.'});
 pub('X-02','get','/claims/{claimId}/reason-change-requests','listMyClaimReasonChanges',null,page('ClaimReasonChange'),'CLM-01',{params:paging});
 pub('X-02','get',seller+'/claims/{claimId}','getSellerClaim',null,'Claim','CLM-01',fulfillment);
 pub('X-02','get',seller+'/claims/{claimId}/reason-change-requests','listSellerClaimReasonChanges',null,page('ClaimReasonChange'),'CLM-01',{...fulfillment,params:paging});
 pub('X-02','post',seller+'/claims/{claimId}/reason-change-requests/{requestId}/decisions','decideClaimReasonChange','ClaimReasonDecision','ClaimReasonChange','CLM-01',{...fulfillment,status:200,description:'자기 판매자 unit만 포함하는 Claim. request version과 expectedClaimVersion을 함께 검증합니다. 승인 시 책임/배분/hold를 같은 transaction에서 다시 계산하며 원 사유와 검수 이력은 보존합니다.'});
 pub('X-03','post',admin+'/claims/{claimId}/return-tracking-events','recordReturnTracking','ReturnTrackingEvent','Claim','CLM-01,FUL-01',{...support,status:200,description:'모의 회수 상태만 append. 미래 5분 초과 거부, 같은 eventId/내용은 멱등, 변경 내용409. IN_TRANSIT 이전/이후 순서를 검증하고 실제 검수·환불·재입고를 대신하지 않습니다.'});
 pub('X-03','post',admin+'/shipments/{shipmentId}/corrections','correctShipment','ShipmentCorrection','Shipment','FUL-01,OPS-01',{...support,status:200,description:'다른 SUPPORT가 승인한 DELIVERY_CORRECTION의 target/version/payloadHash 검증 후 correction event append. 확정/지급된 unit은 원 기록을 지우지 않고 hold/재무조정 절차를 연결합니다. 보정 사유만으로 금액 변경 금지.'});
 for(const [path,id,response,req,opt]of [
  ['/seller-verifications','listSellerVerificationReviews','SellerVerificationReview','COM-02',support],
  ['/product-review-requests','listProductReviewRequests','ProductReviewRequest','CAT-01',catalog],
  ['/review-moderation-requests','listReviewModerationRequests','ReviewModerationRequest','EXP-02',catalog],
  ['/concept-taxonomies','listConceptTaxonomies','Taxonomy','DIS-02',catalog],
  ['/settlement-account-change-requests','listAccountChangeReviews','AccountChangeReview','COM-02',finance]
 ])pub('X-04','get',admin+path,id,null,page(response),req,{...opt,params:[...paging,param('status',s(1,50))],description:'권한별 검토 대상을 cursor로 조회합니다. revision/document/evidence ID와 현재 version을 제공하며 private 증빙 원문/계좌번호/비밀정보는 반환하지 않습니다. 문서 열기는 별도 권한 검증 download 경로를 사용합니다.'});
 pub('X-05','get',seller+'/settlement-account','getSellerSettlementAccount',null,'SellerSettlementAccount','COM-02,SEC-04',{roles:['SELLER_OWNER','SELLER_FINANCE']});
 pub('X-05','get',seller+'/appeals','listSellerAppeals',null,page('Appeal'),'OPS-01',{roles:['SELLER_OWNER'],params:paging});
 pub('X-05','get',seller+'/appeals/{appealId}','getSellerAppeal',null,'Appeal','OPS-01',{roles:['SELLER_OWNER']});
 pub('X-05','get','/uploads/{uploadId}','getUploadStatus',null,'UploadStatus','SEC-04',{description:'발급 owner만 조회. 서명 URL/저장소 경로/파일 바이트를 반환하지 않으며 VERIFIED만 게시·Claim 연결 가능. 만료 슬롯410, 검역 실패 이유는 공개 코드로 제한합니다.'});
 pub('X-06','get',admin+'/administrators','listAdministrators',null,page('Administrator'),'SEC-02',{...iam,params:paging});
 pub('X-06','get',admin+'/administrators/{adminId}','getAdministrator',null,'Administrator','SEC-02',iam);
 for(const [leaf,createId,executeId,request,actionType]of [
  ['role-change-requests','requestAdminRoleChange','executeAdminRoleChange','AdminRoleChangeCreate','ADMIN_ROLE_CHANGE'],
  ['mfa-recovery-requests','requestAdminMfaRecovery','executeAdminMfaRecovery','AdminMfaRecoveryCreate','MFA_RECOVERY']
 ]){
  pub('X-06','post',admin+'/administrators/{adminId}/'+leaf,createId,request,'Approval','SEC-02,OPS-01',{...iam,description:`대상 admin version과 정규화 입력을 보존하고 ${actionType} 승인 요청을 생성합니다. 요청 ID는 approval ID입니다. 자기 권한 증대/자기 MFA 복구 실행 금지, 마지막 ACTIVE IAM 제거 금지. 요청자와 승인자 및 대상 IAM의 이해관계를 검증합니다.`});
  pub('X-06','post',admin+'/administrators/{adminId}/'+leaf+'/{requestId}/execute',executeId,'ApprovedAdminExecute','Administrator','SEC-02,OPS-01',{...iam,status:200,description:`requestId=approvalId, 대상 admin/version·승인 version·actionType=${actionType}·24h 만료·payloadHash 확인. 같은 action 1회 소비. 변경 후 모든 이전 관리자 세션을 폐기합니다. MFA 복구는 RE_ENROLLMENT_REQUIRED로 잠그고 TOTP secret/옛 복구코드를 폐기; 재등록은 본인확인된 로컬 운영 CLI로만 완료하며 일반 관리자 API 접근을 허용하지 않습니다.`});
 }
 pub('X-06','get',admin+'/approval-requests/{approvalId}','getApproval',null,'Approval','OPS-01,SEC-02',{roles:['ADMIN_FINANCE','ADMIN_RISK','ADMIN_IAM','ADMIN_SUPPORT'],description:'actionType별 승인 역할만 접근. 서버가 생성한 마스킹 변경 요약·이유·증거 ID·payload hash를 조회합니다. 비밀정보 원문은 승인 화면에도 노출하지 않습니다.'});
 const queueParams=[param('owner',owner,'query',true),param('queueType',en('OUTBOX','INBOX')),param('consumer',s(1,100)),param('status',s(1,50)),...paging];
 pub('X-07','get',admin+'/event-queues','listEventQueues',null,page('EventQueueEntry'),'EVT-03,OPS-02',{roles:['ADMIN_FINANCE','ADMIN_CATALOG'],params:queueParams,description:'owner는 서비스 allowlist입니다. FINANCE는 금융 stream, CATALOG는 catalog/analysis stream만 조회합니다. raw body/PII는 숨기고 ID/hash/순서/오류 코드만 반환합니다. IAM 역할만으로 업무 replay 권한을 얻지 않습니다.'});
 pub('X-07','post',admin+'/event-queues/{entryId}/replays','replayEventQueue','EventReplayCreate','RecoveryJob','EVT-03,OPS-01',{roles:['ADMIN_FINANCE','ADMIN_CATALOG'],status:202,description:'원 owner/type/consumer/entryId/hash/version을 고정합니다. 살아있는 lease/종결 성공은 재접수하지 않습니다. 금융 여부는 서버 registry에서 판정하고 금융이면 다른 FINANCE의 FINANCIAL_EVENT_REPLAY approvalId 필수. 공개 facade는 jobId→owner 연결만 저장; owner는 원 body/sequence/key를 유지하며 같은 요청을 1회 접수합니다.'});
 pub('X-07','get',admin+'/recovery-jobs/{jobId}','getRecoveryJob',null,'RecoveryJob','EVT-03,OPS-02',{roles:['ADMIN_FINANCE','ADMIN_CATALOG'],description:'Commerce에 저장된 jobId/owner/업무 권한 연결로 조회하며 클라이언트가 내부 주소를 지정할 수 없습니다. OUTBOX의 SUCCEEDED는 broker ACK와 owner outbox PUBLISHED commit, INBOX의 SUCCEEDED는 업무 효과 또는 검증된 멱등 no-op과 checkpoint commit입니다. OUTBOX 성공은 downstream 처리 완료를 뜻하지 않으며 운영자는 각 consumer checkpoint를 별도 확인합니다.'});
 pub('X-08','post','/claims/{claimId}/exchange-conversions','convertExchange','ExchangeConversion','ExchangeConversionResult','CLM-03',{status:200,description:'소유 회원, 미출고 EXCHANGE에만 허용. ACCEPT_RETURN은 같은 결제 unit의 RETURN을 1회 연결하고 원 교환 이력 보존. KEEP_EXCHANGE는 기존 7일 예약 만료를 연장하지 않음. timeout/replay에도 새 Claim 생성 금지.'});
 pub('X-09','get',admin+'/orders/{orderId}','getOrderForSupport',null,'Order','CLM-01,ORD-04',support);
 pub('X-09','get',admin+'/claims/{claimId}','getClaimForSupport',null,'Claim','CLM-01',support);
 pub('X-09','post',admin+'/orders/{orderId}/claim-exceptions','createClaimException','ClaimExceptionCreate','Claim','CLM-01,OPS-01',{...support,description:'기한/구매확정 예외만 우회. 다른 SUPPORT의 CLAIM_EXCEPTION 승인에 원 order/version/unit/입력 hash 고정. 소유 관계·남은 수량·중복 Claim·PG 잔액 제한은 우회 불가. 인식된 원장에 hold/조정을 연결하고 아직 환불되지 않은 작업을 완료로 표시하지 않습니다.'});
 const server=x(d,'X-10','post','/internal/v1/server-behavior-events','ingestServerBehavior','ServerBehaviorEvent','Accepted','DIS-03,EXP-01,ORD-01',{roles:['commerce-service'],scope:'discovery:server-behavior',status:202,idempotent:false,description:'Commerce가 opt-in 및 원 command 성공을 검증해 생성한 전환만 허용. eventId+payload hash 멱등, 같은 ID 다른 body409. 64KiB/미래5분/과거7일 제한. CART_ADD만 quantity 필수. OrderPaid PURCHASE는 Kafka만 집계합니다. actorContext는 SYSTEM 또는 검증된 MEMBER이며 memberPseudonym과 원문 신원을 로그에 함께 쓰지 않습니다.'});
 server['x-idempotency']='eventId + canonical payload hash; replay unchanged sourceCommandId';
 pub('X-11','post',admin+'/search-rebuilds','createSearchRebuild','SearchRebuildCreate','ProjectionRebuild','DIS-01',{...catalog,status:202,description:'CATALOG가 시작하는 비금융 rebuild. 같은 snapshotId/key는 같은 generation. Commerce facade는 인증·감사 후 Discovery rebuild 호출, 검증/catch-up 성공 전 ACTIVE 교체 금지.'});
 pub('X-11','get',admin+'/search-rebuilds/{generationId}','getSearchRebuild',null,'ProjectionRebuild','DIS-01',catalog);
 // Read dependencies and the owner-local replay port close the facade-to-owner contract.
 x(d,'X-04','get','/internal/v1/concept-taxonomies','queryTaxonomies',null,page('Taxonomy'),'DIS-02',{roles:['commerce-service'],scope:'discovery:read',params:paging});
 for(const [method,path,id,request,response]of [
  ['get','/internal/v1/event-queues','queryLocalEventQueues',null,page('EventQueueEntry')],
  ['post','/internal/v1/event-queues/{entryId}/replays','replayLocalEventQueue','EventReplayCreate','RecoveryJob'],
  ['get','/internal/v1/recovery-jobs/{jobId}','queryLocalRecoveryJob',null,'RecoveryJob']
 ])x(ops,'X-07',method,path,id,request,response,'EVT-03,OPS-01',{roles:['commerce-service'],scope:method==='get'?'operations:read':'operations:replay',status:method==='post'?202:200,params:path.endsWith('event-queues')?queueParams.filter(p=>p.name!=='owner'):[],description:'동일 계약을 각 owner DB 안에서만 구현하는 내부 port입니다. aud는 실제 대상 service ID, owner 입력은 자기 서비스와 일치해야 합니다. Commerce의 actorContext와 금융 승인의 action/hash/actor를 재검증합니다. consumer+eventId를 포함한 대상을 식별하고 원 이벤트 불변·checkpoint 순서·dedup을 유지합니다. 타 서비스 DB 접근 금지.'});
 for(const [doc,method,path]of [[c,'post','/api/v1/admin/approval-requests'],[c,'get','/api/v1/admin/approval-requests'],[c,'post','/api/v1/admin/approval-requests/{approvalId}/decisions'],[c,'get','/api/v1/admin/approval-requests/{approvalId}']]){
  const action=doc.paths[path][method];action['x-authorized-roles']=['ADMIN_FINANCE','ADMIN_RISK','ADMIN_IAM','ADMIN_SUPPORT'];action['x-approval-role-map']=actionRoles;
  action.description='actionType별 역할을 서버에서 검증: '+Object.entries(actionRoles).map(([k,v])=>k+'=ADMIN_'+v).join(', ')+'. 대상 owner가 계산한 원 action/version/payloadHash와 일치해야 하며 자기 승인 금지. 변경 요약은 마스킹하고 실행은 승인 소비 및 멱등 처리로 분리합니다.';
 }
 // Evidence belongs to the action scope, not necessarily the administrator uploading it.
 c.paths['/api/v1/uploads/{uploadId}/download'].get['x-authorized-roles']=['MEMBER','SELLER_OWNER','ADMIN_SUPPORT','ADMIN_CATALOG','ADMIN_FINANCE','ADMIN_RISK'];
 c.paths['/api/v1/uploads/{uploadId}/download'].get.description+=' 관리자도 연결된 검수/Claim/승인 대상의 업무 역할과 접근 범위를 검사합니다. uploadId만으로 모든 파일에 접근할 수 없습니다.';
 ci.paths['/internal/v1/admin-approval-requests/{approvalId}'].get['x-authorized-roles']=['settlement-service','payment-service','discovery-data-service'];
 ci.paths['/internal/v1/admin-approval-requests/{approvalId}'].get.description+=' 호출 서비스가 실행할 해당 action/target에 연결된 승인만 조회 가능. 운영 replay는 FINANCIAL_EVENT_REPLAY 전용 hash를 검증합니다.';
}
