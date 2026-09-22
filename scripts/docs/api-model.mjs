// Hand-authored target contracts from docs/requirements. Generated JSON is checked in.
import {registerExtensions} from './contract-extensions.mjs';
export const schemas={};
const ref=n=>({$ref:`#/components/schemas/${n}`});
const s=(min=1,max=200)=>({type:'string',minLength:min,maxLength:max});
const en=(...values)=>({type:'string',enum:values});
const i=(min=0,max=100000000)=>({type:'integer',minimum:min,maximum:max});
const uuid={type:'string',format:'uuid'},time={type:'string',format:'date-time'},date={type:'string',format:'date'},bool={type:'boolean'},version=i(0,9007199254740991),money=i(),signed=i(-9007199254740991,9007199254740991);
const arr=(items,min=0,max=100)=>({type:'array',items,minItems:min,maxItems:max});
const nullable=x=>({anyOf:[x,{type:'null'}]});
const obj=(properties,required=Object.keys(properties))=>({type:'object',properties,required,additionalProperties:false});
const def=(name,properties,required)=>{schemas[name]=obj(properties,required);return ref(name);};
const page=n=>{const name=n+'Page';if(!schemas[name])def(name,{items:arr(ref(n)),nextCursor:nullable(s(1,2048))});return name;};
const stamp={id:uuid,version,createdAt:time,updatedAt:time};
const reason={reason:s(1,2000),evidenceIds:arr(uuid,0,20)};
const ver={expectedVersion:version};
const simulated={type:'boolean',const:true};
def('Error',{code:s(),message:s(1,2000),traceId:{type:'string',pattern:'^[0-9a-f]{32}$'},details:{type:'object',additionalProperties:{type:'string'}}},['code','message','traceId']);
def('Accepted',{requestId:uuid,status:en('ACCEPTED')});
def('Money',{currency:{type:'string',const:'KRW'},amount:money});
def('SettlementMoney',{currency:{type:'string',const:'KRW'},amount:i(0,9007199254740991)});
def('Actor',{type:en('MEMBER','SELLER_MEMBER','ADMIN','SYSTEM'),id:nullable(uuid)});
def('ActorContext',{actor:ref('Actor'),correlationId:uuid,approvalId:nullable(uuid)},['actor','correlationId']);
def('Session',{actor:nullable(ref('Actor')),roles:arr(s()),sellerMemberships:arr(obj({sellerId:uuid,roles:arr(en('OWNER','CATALOG','FULFILLMENT','FINANCE'),1,4)})),csrfToken:s(32,256),expiresAt:time});
def('Member',{...stamp,email:{type:'string',format:'email'},nickname:s(2,30),status:en('ACTIVE','DORMANT','SUSPENDED','WITHDRAWN'),emailVerified:bool});
def('RegisterMember',{email:{type:'string',format:'email',maxLength:254},password:s(12,128),nickname:s(2,30),consentVersions:arr(s(1,50),1,20)});
def('Registration',{memberId:uuid,verificationRequired:bool});
def('Login',{email:{type:'string',format:'email'},password:s(12,128)});
def('AdminLogin',{email:{type:'string',format:'email'},password:s(12,128),totpCode:{type:'string',pattern:'^[0-9]{6}$'}});
def('EmailRequest',{email:{type:'string',format:'email'}});
def('TokenRequest',{token:s(32,256)});
def('PasswordReset',{token:s(32,256),newPassword:s(12,128)});
def('ProfileEdit',{nickname:s(2,30),...ver});
const address={recipient:s(1,100),phone:s(8,30),postalCode:{type:'string',pattern:'^[0-9]{5}$'},address1:s(1,300),address2:s(0,300),isDefault:bool};
def('AddressCreate',address);def('AddressEdit',{...address,...ver});def('Address',{...stamp,...address});
def('VersionCommand',ver);def('ReasonCommand',{...reason,...ver});
def('Category',{id:uuid,parentId:nullable(uuid),name:s(1,100),status:en('ACTIVE','INACTIVE','ARCHIVED')});
def('Brand',{id:uuid,name:s(1,100),status:en('ACTIVE','INACTIVE','MERGED')});
def('Feature',{key:s(1,80),value:s(1,500),source:en('SELLER','ADMIN')});
def('Sku',{id:uuid,optionValueIds:arr(uuid,0,3),unitPrice:i(1),discountPerUnit:money,paidUnitPrice:i(1),availableQuantity:i(0,2147483647),status:en('DRAFT','ACTIVE','SOLD_OUT','INACTIVE','ARCHIVED')});
def('ProductSummary',{id:uuid,revisionId:uuid,sellerId:uuid,title:s(1,200),imageUrl:{type:'string',format:'uri'},price:ref('Money'),available:bool,publishedAt:time});
def('ProductDetail',{...stamp,revisionId:uuid,sellerId:uuid,title:s(1,200),description:s(1,20000),categoryId:uuid,brandId:nullable(uuid),imageUrls:arr({type:'string',format:'uri'},1,20),features:arr(ref('Feature'),0,100),skus:arr(ref('Sku'),1,500),shippingPolicy:obj({version:s(),fee:money,freeThreshold:money}),saleStatus:en('DRAFT','IN_REVIEW','READY','ON_SALE','PAUSED','SOLD_OUT','ARCHIVED')});
const productInput={title:s(1,200),description:s(1,20000),brandId:nullable(uuid),categoryId:uuid,imageIds:arr(uuid,1,20),features:arr(ref('Feature'),0,100),optionGroups:arr(obj({name:s(1,50),values:arr(s(1,50),1,50)}),0,3),skus:arr(obj({skuCode:s(1,80),optionValues:arr(s(1,50),0,3),unitPrice:i(1),discountPerUnit:money}),1,500),shippingPolicyVersion:s()};
def('ProductCreate',productInput);def('ProductRevisionCreate',{...productInput,...ver});
def('SkuUpdate',{skus:arr(ref('Sku'),1,500),...ver});
def('Inventory',{skuId:uuid,onHand:i(0,2147483647),reserved:i(0,2147483647),safetyStock:i(0,2147483647),available:i(0,2147483647),version});
def('InventoryAdjustment',{deltaOnHand:i(-2147483647,2147483647),deltaSafetyStock:i(-2147483647,2147483647),reason:s(1,500),...ver});
def('CartItem',{skuId:uuid,quantity:i(1,99),selected:bool,displayPrice:ref('Money'),available:bool});
def('Cart',{id:uuid,version,items:arr(ref('CartItem'))});def('CartItemEdit',{quantity:i(1,99),selected:bool,...ver});
def('CheckoutCreate',{selectedSkuQuantities:arr(obj({skuId:uuid,quantity:i(1,99)}),1,100),addressId:uuid});
def('OrderUnit',{unitOrdinal:i(1,99),productAmount:money,discountAmount:money,paidAmount:i(1),commissionAmount:money});
def('OrderItem',{orderItemId:uuid,sellerId:uuid,productId:uuid,revisionId:uuid,skuId:uuid,title:s(1,200),optionLabels:arr(s()),quantity:i(1,99),productAmount:money,discountAmount:money,taxAmount:{type:'integer',const:0},paidAmount:i(1),units:arr(ref('OrderUnit'),1,99)});
schemas.CheckoutItem=structuredClone(schemas.OrderItem);
delete schemas.CheckoutItem.properties.orderItemId;
schemas.CheckoutItem.properties.checkoutItemId=uuid;
schemas.CheckoutItem.required=schemas.CheckoutItem.required.filter(n=>n!=='orderItemId').concat('checkoutItemId');
def('ShippingGroup',{sellerId:uuid,shippingAmount:money,policyVersion:s(),status:en('PENDING','READY','PARTIALLY_SHIPPED','SHIPPED','DELIVERED','CANCELLED'),address:ref('AddressCreate')});
def('Checkout',{checkoutId:uuid,revision:i(1),status:en('RESERVED','ORDER_CREATED','EXPIRED','CANCELLED'),expiresAt:time,items:arr(ref('CheckoutItem'),1),shippingGroups:arr(ref('ShippingGroup'),1),amount:ref('Money'),pricingPolicyVersion:s(),addressSnapshot:ref('AddressCreate'),availableProviders:{...arr(en('KAKAO','NAVER'),2,2),uniqueItems:true},simulated});
def('OrderCreate',{checkoutId:uuid,checkoutRevision:i(1)});
const orderState=en('PENDING_PAYMENT','PAID','PROCESSING','PARTIALLY_SHIPPED','SHIPPED','PARTIALLY_COMPLETED','COMPLETED','PAYMENT_FAILED','CANCELLED');
def('Order',{orderId:uuid,orderNumber:s(),orderStatus:orderState,paymentStatus:en('NOT_STARTED','CREATED','REQUESTED','PENDING','UNKNOWN','FAILED','APPROVED','VOIDED','PARTIALLY_REFUNDED','REFUNDED'),recoveryStatus:en('NONE','CHECKING','COMPENSATING','MANUAL_REVIEW'),claimStatus:en('NONE','OPEN','COMPLETED'),openClaimCount:i(),items:arr(ref('OrderItem'),1),shippingGroups:arr(ref('ShippingGroup'),1),amount:ref('Money'),version,createdAt:time,simulated});
def('PaymentStart',{provider:en('KAKAO','NAVER'),...ver});
def('OrderPaymentStatus',{orderId:uuid,attemptId:nullable(uuid),paymentId:nullable(uuid),status:en('NOT_STARTED','CREATED','REQUESTED','PENDING','UNKNOWN','SUCCEEDED','FAILED','CANCELLED'),orderStatus:orderState,statusUrl:s(1,500),simulated});
const claimState=en('REQUESTED','UNDER_REVIEW','APPROVED','REJECTED','PICKUP_PENDING','IN_TRANSIT','RECEIVED','INSPECTING','REFUND_PENDING','COMPLETED','CANCELLED');
def('ClaimCreate',{type:en('CANCEL','RETURN','EXCHANGE'),items:arr(obj({orderItemId:uuid,quantity:i(1,99),shipmentItemId:uuid},['orderItemId','quantity']),1),reasonCode:en('CHANGE_OF_MIND','SIZE_MISMATCH','DEFECT','WRONG_ITEM','LOST_OR_DAMAGED','OTHER'),evidenceIds:arr(uuid,0,20),replacementSkuId:uuid},['type','items','reasonCode','evidenceIds']);
schemas.ClaimCreate.allOf=[{if:{properties:{type:{const:'EXCHANGE'}},required:['type']},then:{required:['replacementSkuId']}}];
def('Claim',{id:uuid,orderId:uuid,type:en('CANCEL','RETURN','EXCHANGE'),status:claimState,version,refundId:nullable(uuid),refundStatus:nullable(en('REQUESTED','PROCESSING','UNKNOWN','SUCCEEDED','FAILED')),expectedRefund:ref('Money'),items:arr(obj({orderItemId:uuid,unitOrdinals:arr(i(1,99),1,99),status:claimState})),reasonCode:s(),createdAt:time});
def('ClaimDecision',{decision:en('APPROVE','REJECT'),responsibility:en('BUYER','SELLER','CARRIER','PLATFORM'),...reason,...ver});
def('ClaimInspection',{items:arr(obj({claimItemId:uuid,acceptedUnitOrdinals:arr(i(1,99)),rejectedUnitOrdinals:arr(i(1,99)),restockable:bool,reason:s(1,500)}),1),...ver});
def('ShipmentCreate',{orderId:uuid,items:arr(obj({orderItemId:uuid,unitOrdinals:arr(i(1,99),1,99)}),1),carrierCode:s(1,50),trackingNumber:s(1,100)});
def('Shipment',{id:uuid,orderId:uuid,sellerId:uuid,status:en('READY','HANDED_OVER','IN_TRANSIT','DELIVERED','LOST','FAILED','CANCELLED'),items:arr(obj({shipmentItemId:uuid,orderItemId:uuid,quantity:i(1,99)}),1),carrierCode:s(),trackingNumber:s(),version,simulated});
def('TrackingEvent',{eventId:uuid,sequence:i(1),status:en('IN_TRANSIT','DELIVERED','LOST','FAILED'),occurredAt:time});
def('ConfirmationCreate',{quantity:i(1,99),...ver});def('Confirmation',{confirmationId:uuid,confirmedQuantity:i(1,99),confirmedAt:time});
def('ReviewCreate',{eligibilityId:uuid,rating:i(1,5),text:s(1,2000),imageIds:arr(uuid,0,5)});
def('ReviewEdit',{rating:i(1,5),text:s(1,2000),imageIds:arr(uuid,0,5),...ver});
def('Review',{...stamp,orderItemId:uuid,productId:uuid,rating:i(1,5),text:s(1,2000),imageUrls:arr({type:'string',format:'uri'},0,5),status:en('PENDING_MODERATION','PUBLISHED','HIDDEN','DELETED'),verifiedPurchase:bool,returned:bool});
def('ReviewEligibility',{eligibilityId:uuid,orderItemId:uuid,eligibleQuantity:i(),canWrite:bool});
def('ReplyCreate',{text:s(1,2000)});def('ReplyEdit',{text:s(1,2000),...ver});def('Reply',{...stamp,reviewId:uuid,text:s(1,2000),status:en('PUBLISHED','HIDDEN','DELETED')});
def('Moderation',{decision:en('PUBLISH','HIDE','REJECT'),reason:s(1,1000),...ver});
def('Notification',{id:uuid,type:s(),title:s(),body:s(1,2000),resourceId:uuid,readAt:nullable(time),createdAt:time});
def('NotificationPreferences',{marketingOptIn:bool,analyticsOptIn:bool,version});def('NotificationPreferenceEdit',{marketingOptIn:bool,analyticsOptIn:bool,...ver});
def('SellerCreate',{displayName:s(1,100),businessIdentifier:s(1,100),ownerContact:s(1,200)});
def('SellerEdit',{displayName:s(1,100),...ver});def('Seller',{...stamp,displayName:s(1,100),status:en('ONBOARDING','ACTIVE','SUSPENDED','REJECTED','CLOSED'),verificationStatus:en('PENDING','VERIFIED','FAILED','EXPIRED')});
def('SellerDocumentCreate',{uploadId:uuid,documentType:en('BUSINESS','IDENTITY','BANK_ACCOUNT','BRAND','TAX')});
def('SellerDocument',{id:uuid,documentType:s(),status:en('ACTIVE','SUPERSEDED','DELETED'),createdAt:time});
def('SellerVerificationCreate',{type:en('BUSINESS','IDENTITY','BANK_ACCOUNT','BRAND','TAX'),documentIds:arr(uuid,1,20)});
def('SellerVerification',{id:uuid,type:s(),status:en('REQUESTED','PROCESSING','VERIFIED','FAILED','EXPIRED'),version});
def('AccountChangeCreate',{bankCode:s(1,20),accountNumber:s(1,40),holderName:s(1,100),evidenceIds:arr(uuid,1,20)});
def('AccountChange',{id:uuid,status:en('PENDING','VERIFIED','ACTIVE','REJECTED'),maskedAccount:s(),version,simulated});
def('InvitationCreate',{email:{type:'string',format:'email'},roles:arr(en('OWNER','CATALOG','FULFILLMENT','FINANCE'),1,4)});
def('Invitation',{id:uuid,email:{type:'string',format:'email'},roles:arr(s()),expiresAt:time,status:en('PENDING','ACCEPTED','EXPIRED','CANCELLED')});
def('TeamMember',{memberId:uuid,roles:arr(en('OWNER','CATALOG','FULFILLMENT','FINANCE'),1,4),version,status:en('ACTIVE','INACTIVE')});
def('TeamMemberEdit',{roles:arr(en('OWNER','CATALOG','FULFILLMENT','FINANCE'),1,4),...ver});
def('Decision',{decision:en('APPROVE','REJECT'),reason:s(1,2000),approvalId:uuid,...ver},['decision','reason','expectedVersion']);
def('LedgerEntry',{id:uuid,sellerId:uuid,entryType:en('SALE_PROCEEDS','SHIPPING_REVENUE','COMMISSION_FEE','REFUND','REVERSAL','PENALTY','ADJUSTMENT'),signedAmount:signed,currency:{type:'string',const:'KRW'},sourceId:uuid,recognizedAt:time});
def('Settlement',{id:uuid,sellerId:uuid,businessDate:date,status:en('DRAFT','CALCULATED','APPROVAL_PENDING','APPROVED','PAYOUT_PENDING','PAID','FAILED','VOID'),creditAmount:i(0,9007199254740991),debitAmount:i(0,9007199254740991),holdAmount:i(0,9007199254740991),netAmount:signed,payoutAmount:i(0,9007199254740991),carryForwardAmount:signed,currency:{type:'string',const:'KRW'},version,simulated});
def('SettlementCalculate',{sellerId:uuid,businessDate:date,cutoff:time,policyVersion:s(),...ver});
def('ApprovalCreate',{actionType:en('ACCOUNT_CHANGE','FINANCIAL_ADJUSTMENT','UNKNOWN_RESOLUTION','PAYOUT','PENALTY','PENALTY_REVOKE','ADMIN_ROLE_CHANGE'),targetId:uuid,payloadHash:{type:'string',pattern:'^[0-9a-f]{64}$'},reason:s(1,2000),evidenceIds:arr(uuid,0,20)});
def('Approval',{id:uuid,actionType:s(),targetId:uuid,payloadHash:{type:'string',pattern:'^[0-9a-f]{64}$'},requesterId:uuid,approverId:nullable(uuid),status:en('APPROVAL_PENDING','APPROVED','REJECTED','CANCELLED','EXPIRED'),expiresAt:time,version});
def('ApprovalDecision',{decision:en('APPROVE','REJECT'),reason:s(1,2000),...ver});
def('PayoutCreate',{approvalId:uuid,...ver});
def('Payout',{id:uuid,settlementId:uuid,status:en('REQUESTED','PROCESSING','SUCCEEDED','FAILED','UNKNOWN','CANCELLED'),amount:ref('SettlementMoney'),bankReceiptId:nullable(uuid),statusUrl:s(1,500),simulated});
def('FinancialOperation',{id:uuid,kind:en('APPROVE','CANCEL','REFUND','PAYOUT'),status:en('REQUESTED','PROCESSING','PENDING','UNKNOWN','SUCCEEDED','FAILED','CANCELLED'),orderId:nullable(uuid),provider:nullable(en('KAKAO','NAVER')),firstUnknownAt:nullable(time),nextRetryAt:nullable(time),version,simulated});
def('RecoveryRequest',{reason:s(1,1000),...ver});
def('Discrepancy',{id:uuid,owner:en('PAYMENT','SETTLEMENT'),kind:en('PROVIDER_ONLY','INTERNAL_ONLY','AMOUNT_MISMATCH','STATUS_MISMATCH','DUPLICATE'),status:en('OPEN','INVESTIGATING','RESOLVED','ACCEPTED','FALSE_POSITIVE'),expectedAmount:nullable(signed),actualAmount:nullable(signed),evidenceIds:arr(uuid),version});
def('DiscrepancyResolution',{resolutionType:en('APPLY_VERIFIED_RESULT','ACCEPT_WITH_EVIDENCE','FALSE_POSITIVE'),approvalId:uuid,...reason,...ver});
def('IncidentCreate',{sellerId:uuid,type:en('PAYMENT_UNKNOWN','DELIVERY_DELAY','RECONCILIATION','COMPLIANCE','OTHER'),resourceIds:arr(uuid,1,100),...reason});
def('Incident',{...stamp,sellerId:uuid,type:s(),status:en('OPEN','INVESTIGATING','RESOLVED','DISMISSED','CLOSED'),reason:s(1,2000)});
def('IncidentEdit',{status:en('INVESTIGATING','RESOLVED','DISMISSED','CLOSED'),...reason,...ver});
def('PenaltyCreate',{sellerId:uuid,type:en('WARNING','FEE','LISTING_RESTRICTION','PAYOUT_HOLD','SUSPENSION','TERMINATION'),amount:money,approvalId:uuid,...reason});
def('Penalty',{...stamp,sellerId:uuid,type:s(),amount:money,status:en('SCHEDULED','ACTIVE','COMPLETED','REVOKED','CANCELLED')});
def('AppealCreate',{penaltyId:uuid,...reason});def('Appeal',{...stamp,penaltyId:uuid,status:en('REQUESTED','UNDER_REVIEW','ACCEPTED','REJECTED'),reason:s(1,2000)});
def('AppealDecision',{decision:en('ACCEPT','REJECT'),approvalId:uuid,reason:s(1,2000),...ver});
def('ComplianceRuleCreate',{name:s(1,100),ruleType:en('FORBIDDEN_WORD','REQUIRED_FEATURE','REQUIRED_IMAGE'),terms:arr(s(1,100)),severity:en('WARNING','BLOCK'),categoryIds:arr(uuid),effectiveAt:time});
def('ComplianceRule',{...stamp,name:s(),ruleType:s(),status:en('ACTIVE','SUSPENDED','RETIRED')});
def('AuditLog',{id:uuid,actor:ref('Actor'),action:s(),targetId:uuid,reason:s(0,2000),occurredAt:time,correlationId:uuid});
def('SearchResult',{requestId:uuid,items:arr(obj({product:ref('ProductSummary'),score:{type:'number',minimum:0}})),nextCursor:nullable(s(1,2048))});
def('AnalysisCreate',{revisionId:uuid});
def('ConceptEvidence',{kind:en('PRODUCT_TEXT','FEATURE','IMAGE','HUMAN_NOTE'),referenceId:s(),text:s(0,1000)});
def('AnalysisRun',{id:uuid,productId:uuid,revisionId:uuid,taxonomyVersion:s(),modelVersion:s(),promptVersion:s(),status:en('QUEUED','RUNNING','SUCCEEDED','FAILED','CANCELLED'),concepts:arr(obj({conceptId:uuid,score:{type:'number',minimum:0,maximum:1},evidence:arr(ref('ConceptEvidence'))})),simulated});
def('ConceptReview',{runId:uuid,conceptId:uuid,decision:en('ACCEPTED','REJECTED','ADJUSTED'),reason:s(1,2000),adjustedScore:{type:'number',minimum:0,maximum:1}},['runId','conceptId','decision','reason']);
def('TaxonomyCreate',{name:s(1,100),version:s(),concepts:arr(obj({id:uuid,name:s(),parentId:nullable(uuid),aliases:arr(s())}),1,1000)});
def('Taxonomy',{id:uuid,name:s(),taxonomyVersion:s(),status:en('DRAFT','ACTIVE','RETIRED'),version});
def('BehaviorEvent',{eventId:uuid,eventType:en('SEARCH','IMPRESSION','PRODUCT_VIEW'),productId:uuid,revisionId:uuid,requestId:uuid,occurredAt:time,context:obj({placement:s(),query:s(1,100)},[])},['eventId','eventType','occurredAt','context']);
def('BehaviorBatch',{events:arr(ref('BehaviorEvent'),1,50)});
def('UploadCreate',{purpose:en('PRODUCT_IMAGE','REVIEW_IMAGE','SELLER_DOCUMENT','CLAIM_EVIDENCE'),contentType:en('image/jpeg','image/png','image/webp','application/pdf'),sizeBytes:i(1,10485760),sha256:{type:'string',pattern:'^[0-9a-f]{64}$'}});
def('Upload',{id:uuid,status:en('PENDING','QUARANTINED','VERIFIED','REJECTED'),uploadUrl:s(1,500),expiresAt:time});
def('Download',{url:{type:'string',format:'uri'},expiresAt:time});
def('StreamWatermark',{aggregateType:s(),aggregateId:s(),requiredVersion:version});
def('FinancialBarrier',{sellerStateVersion:version,streams:arr(ref('StreamWatermark'),0,10000),activeHoldIds:arr(uuid),accountVersion:version,accountSnapshotHash:{type:'string',pattern:'^[0-9a-f]{64}$'}});
def('FenceCreate',{settlementId:uuid,payoutAttemptId:uuid,expectedSellerStateVersion:version,accountSnapshotHash:{type:'string',pattern:'^[0-9a-f]{64}$'},consumedStreamVersions:arr(ref('StreamWatermark'),0,10000)});
def('Fence',{fenceId:uuid,fenceVersion:version,expiresAt:time});def('FenceConsume',{payoutAttemptId:uuid,fenceVersion:version,operationHash:{type:'string',pattern:'^[0-9a-f]{64}$'}});def('DispatchPermit',{dispatchPermitId:uuid,consumedAt:time});
def('ApprovalConsume',{actionId:uuid,payloadHash:{type:'string',pattern:'^[0-9a-f]{64}$'}});
def('CatalogSnapshot',{snapshotId:uuid,asOf:time,items:arr(ref('ProductDetail')),watermarks:arr(ref('StreamWatermark')),nextCursor:nullable(s(1,2048))});
def('ProjectionRebuild',{generationId:uuid,status:en('BUILDING','VERIFYING','ACTIVE','FAILED'),sourceSnapshotId:uuid});
def('RebuildCreate',{snapshotId:uuid});

const securitySchemes={sessionCookie:{type:'apiKey',in:'cookie',name:'__Host-marketplace-session',description:'HttpOnly, Secure, SameSite=Lax; localhost uses marketplace-session.'},adminCookie:{type:'apiKey',in:'cookie',name:'__Host-marketplace-admin-session',description:'Separate admin session, TOTP required.'},preAuthSession:{type:'apiKey',in:'cookie',name:'__Host-marketplace-session',description:'Pre-auth opaque session issued by GET /session; not a logged-in principal.'},csrfToken:{type:'apiKey',in:'header',name:'X-CSRF-Token',description:'Session-bound synchronizer token; Origin must also be verified.'},serviceJWT:{type:'http',scheme:'bearer',bearerFormat:'JWT',description:'RS256, allowlisted iss/sub, service audience, 60-second exp, operation scopes. Never browser credentials.'}};
const param=(name,schema,where='query',required=false)=>({name,in:where,required,schema});
const paging=[param('cursor',s(1,2048)),param('limit',{...i(1,100),default:20})];
const filters=[param('from',time),param('to',time),param('status',s())];
const searchParams=[...paging,param('query',s(1,100)),param('categoryId',uuid),param('brandId',uuid),param('sellerId',uuid),param('priceMin',money),param('priceMax',money),param('conceptIds',arr(uuid,0,10)),param('availableOnly',bool),param('sort',{...en('relevance','newest','priceAsc','priceDesc'),default:'relevance'})];
function spec(title,owner,port){return {openapi:'3.1.0',info:{title,version:'1.0.0',description:'v1 구현 목표 계약. 명세에 존재한다고 현재 Controller가 구현된 것은 아닙니다. x-implementation과 x-requirements 참조.'},'x-owner-service':owner,servers:[{url:`http://localhost:${port}`,description:'목표 로컬 서비스. 고객 브라우저는 same-origin /api 경로로 접근.'}],paths:{},components:{securitySchemes,schemas:{}}};}
function add(doc,method,path,id,tag,summary,req,response,requirements,options={}){
 const write=!['get','head'].includes(method),internal=path.startsWith('/internal/'),admin=path.includes('/admin/');
 const parameters=[...Array.from(path.matchAll(/\{(\w+)\}/g),m=>param(m[1],uuid,'path',true)),...(options.params||[])];
 if(write&&options.idempotent!==false)parameters.push(param('Idempotency-Key',{type:'string',minLength:1,maxLength:200,pattern:'^[A-Za-z0-9._:-]+$'},'header',true));
 const status=String(options.status||(method==='post'?201:method==='delete'?204:200));
 const responses={};responses[status]={description:summary+(write?' — 동일 멱등 요청은 같은 리소스의 현재 상태.':'')};
 if(status!=='204'&&response)responses[status].content={'application/json':{schema:ref(response)}};
 if(options.pending)responses['202']={description:'영속 접수됨; 결과 조회 URL을 사용하고 새 키로 재실행하지 않음.',content:{'application/json':{schema:ref(options.pending)}}};
 for(const code of ['400','401','403','404','409','410','422','429','503'])responses[code]={description:({'400':'형식 오류','401':'인증 실패','403':'권한/CSRF 거부','404':'없음 또는 다른 소유자','409':'상태/멱등/버전 충돌','410':'만료된 자원','422':'업무 정책/금액 오류','429':'요청 제한','503':'일시적 인프라 장애'})[code],content:{'application/json':{schema:ref('Error')}}};
 let security=internal?[{serviceJWT:[]}]:options.public?(write?[{preAuthSession:[],csrfToken:[]}]:[]):[{[admin?'adminCookie':'sessionCookie']:[],...(write?{csrfToken:[]}:{})}];
 const op={operationId:id,tags:[tag],summary,description:options.description||'정상/예외/상태 전이는 x-requirements에 연결된 v1 요구사항을 따릅니다. 타인 소유 ID는 404, 같은 key의 다른 payload는 409. 입력되지 않은 필드를 임의 추론하지 않습니다.',security,parameters,responses,'x-implementation':'planned','x-requirements':requirements.split(','),'x-authorized-roles':options.roles||[internal?'SERVICE':options.public?'ANONYMOUS':admin?'ADMIN_'+tag.toUpperCase():'MEMBER'],'x-idempotency':write&&options.idempotent!==false?'principal + operation + targetId + key; compare normalized payload hash':'not-applicable'};
 if(req)op.requestBody={required:true,content:{'application/json':{schema:ref(req)}}};
 if(internal)op['x-service-scope']=options.scope||`${doc['x-owner-service'].replace('-service','')}:${write?'write':'read'}`;
 if(!doc.paths[path])doc.paths[path]={};if(doc.paths[path][method])throw Error(`Duplicate ${method} ${path}`);doc.paths[path][method]=op;
 return op;
}

export function buildApiSpecs(){
 const c=spec('Commerce 고객 · 판매자 · 관리자 API','commerce-service',8081);
 const api='/api/v1';
 const op=(method,path,id,tag,title,request,response,req,opt)=>add(c,method,api+path,id,tag,title,request,response,req,opt);
 op('post','/members','registerMember','회원','회원 가입','RegisterMember','Registration','SEC-01',{public:true});
 op('post','/sessions','login','회원','고객/판매자 로그인','Login','Session','SEC-01',{public:true,status:200,idempotent:false});
 op('get','/session','getSession','회원','익명 포함 세션·CSRF 조회',null,'Session','SEC-01',{public:true});
 op('delete','/session','logout','회원','고객 세션 폐기',null,null,'SEC-01',{idempotent:false});
 for(const [path,id,req]of [['verifications','verifyEmail','TokenRequest'],['password-resets','resetPassword','PasswordReset'],['verification-requests','requestVerification','EmailRequest'],['password-reset-requests','requestPasswordReset','EmailRequest']])op('post','/auth/'+path,id,'회원',id,req,path.endsWith('requests')?'Accepted':null,'SEC-01',{public:true,status:path.endsWith('requests')?202:204,idempotent:false});
 op('get','/me','getMe','회원','내 회원 정보',null,'Member','COM-01');op('patch','/me','updateMe','회원','닉네임 수정','ProfileEdit','Member','COM-01');op('delete','/me','withdrawMember','회원','열린 거래 없는 회원 탈퇴','VersionCommand',null,'COM-01');
 op('get','/me/addresses','listAddresses','회원','내 배송지',null,page('Address'),'COM-01',{params:paging});op('post','/me/addresses','createAddress','회원','배송지 추가','AddressCreate','Address','COM-01');op('patch','/me/addresses/{addressId}','updateAddress','회원','배송지·기본주소 수정','AddressEdit','Address','COM-01');op('delete','/me/addresses/{addressId}','deleteAddress','회원','배송지 삭제','VersionCommand',null,'COM-01');
 op('get','/categories','listCategories','상품','활성 카테고리',null,page('Category'),'CAT-01',{public:true,params:paging});op('get','/brands','listBrands','상품','브랜드 조회',null,page('Brand'),'CAT-01',{public:true,params:paging});
 op('get','/products','listProducts','상품','상품 검색·목록',null,page('ProductSummary'),'CAT-01,DIS-01',{public:true,params:searchParams});op('get','/products/{productId}','getProduct','상품','현재 판매 상품 상세',null,'ProductDetail','CAT-01',{public:true});op('get','/search','searchProducts','검색','검색·랭킹 결과',null,'SearchResult','DIS-01',{public:true,params:searchParams});
 op('get','/me/wishlist','listWishlist','찜','내 찜 목록',null,page('ProductSummary'),'EXP-01',{params:paging});op('put','/me/wishlist/{productId}','putWishlist','찜','찜 추가',null,null,'EXP-01',{status:204});op('delete','/me/wishlist/{productId}','deleteWishlist','찜','찜 삭제',null,null,'EXP-01');
 op('get','/cart','getCart','주문','장바구니',null,'Cart','ORD-01');op('put','/cart/items/{skuId}','putCartItem','주문','장바구니 수량·선택 변경','CartItemEdit','Cart','ORD-01');op('delete','/cart/items/{skuId}','deleteCartItem','주문','장바구니 항목 삭제','VersionCommand',null,'ORD-01');
 op('post','/checkouts','createCheckout','주문','가격 확정·15분 재고 예약','CheckoutCreate','Checkout','ORD-02,INV-01');op('get','/checkouts/{checkoutId}','getCheckout','주문','불변 주문서 조회',null,'Checkout','ORD-02');op('post','/orders','createOrder','주문','PG 호출 전 주문 생성','OrderCreate','Order','ORD-03');
 op('post','/orders/{orderId}/payment','startOrderPayment','주문','PG1 또는 PG2 모의 결제','PaymentStart','OrderPaymentStatus','PAY-01,ORD-03',{status:200,pending:'OrderPaymentStatus'});op('get','/orders','listOrders','주문','내 주문 목록',null,page('Order'),'ORD-04',{params:[...paging,...filters]});op('get','/orders/{orderId}','getOrder','주문','주문·배송·클레임 상태',null,'Order','ORD-04');op('get','/orders/{orderId}/payment-status','getOrderPaymentStatus','주문','새 승인 없는 결제 조회',null,'OrderPaymentStatus','ORD-04,PAY-05');
 op('post','/orders/{orderId}/claims','createClaim','클레임','취소·반품·교환 접수','ClaimCreate','Claim','CLM-01');op('get','/claims/{claimId}','getClaim','클레임','내 클레임 조회',null,'Claim','CLM-01');op('post','/claims/{claimId}/withdraw','withdrawClaim','클레임','효과 시작 전 클레임 철회','VersionCommand','Claim','CLM-01',{status:200});op('post','/shipment-items/{shipmentItemId}/confirmations','confirmPurchase','배송','수량별 구매확정','ConfirmationCreate','Confirmation','FUL-02');
 op('get','/me/review-eligibilities','listReviewEligibility','리뷰','작성 가능 구매 항목',null,page('ReviewEligibility'),'EXP-02',{params:paging});op('post','/reviews','createReview','리뷰','구매 리뷰 작성','ReviewCreate','Review','EXP-02');op('patch','/reviews/{reviewId}','updateReview','리뷰','리뷰 revision 작성','ReviewEdit','Review','EXP-02');op('delete','/reviews/{reviewId}','deleteReview','리뷰','리뷰 비공개 삭제','VersionCommand',null,'EXP-02');op('get','/products/{productId}/reviews','listProductReviews','리뷰','공개 리뷰',null,page('Review'),'EXP-02',{public:true,params:paging});
 op('get','/notifications','listNotifications','알림','앱 내 알림',null,page('Notification'),'EXP-03',{params:paging});op('post','/notifications/{notificationId}/read','readNotification','알림','읽음 처리',null,null,'EXP-03',{status:204});op('get','/notification-preferences','getNotificationPreferences','알림','알림·분석 동의',null,'NotificationPreferences','EXP-03,DIS-03');op('patch','/notification-preferences','updateNotificationPreferences','알림','알림·분석 동의 변경','NotificationPreferenceEdit','NotificationPreferences','EXP-03,DIS-03');
 op('post','/uploads','createUpload','파일','업로드 슬롯 발급','UploadCreate','Upload','SEC-04');const upload=op('put','/uploads/{uploadId}/content','putUploadContent','파일','검역 전 파일 바이트 업로드',null,'Upload','SEC-04',{status:200});upload.requestBody={required:true,content:{'application/octet-stream':{schema:{type:'string',format:'binary'}}}};op('post','/uploads/{uploadId}/complete','completeUpload','파일','해시 검증·검역 요청',null,'Upload','SEC-04',{status:202});op('get','/uploads/{uploadId}/download','getDownloadUrl','파일','권한 검증된 5분 다운로드 주소',null,'Download','SEC-04');
 op('post','/behavior-events','recordBehavior','검색','동의된 행동 이벤트 기록','BehaviorEvent','Accepted','DIS-03',{status:202});op('post','/behavior-events/batch','recordBehaviorBatch','검색','행동 이벤트 최대50개 기록','BehaviorBatch','Accepted','DIS-03',{status:202});
 const seller='/sellers/{sellerId}';const sellerRoles=['SELLER_OWNER','SELLER_CATALOG','SELLER_FULFILLMENT','SELLER_FINANCE'];
 op('post','/sellers','createSeller','판매자','입점 신청','SellerCreate','Seller','COM-02');op('get',seller,'getSeller','판매자','내 판매자 조회',null,'Seller','COM-02',{roles:sellerRoles});op('patch',seller,'updateSeller','판매자','판매자 표시정보 수정','SellerEdit','Seller','COM-02',{roles:['SELLER_OWNER']});
 for(const [leaf,id,req,res]of [['documents','SellerDocument','SellerDocumentCreate','SellerDocument'],['verifications','SellerVerification','SellerVerificationCreate','SellerVerification'],['settlement-account-change-requests','AccountChange','AccountChangeCreate','AccountChange'],['team-invitations','Invitation','InvitationCreate','Invitation']])op('post',seller+'/'+leaf,'create'+id,'판매자',leaf,req,res,'COM-02',{roles:['SELLER_OWNER']});
 op('post','/seller-invitations/accept','acceptSellerInvitation','판매자','회원이 팀 초대 수락','TokenRequest','TeamMember','COM-02');op('get',seller+'/members','listSellerMembers','판매자','팀원 조회',null,page('TeamMember'),'COM-02',{roles:['SELLER_OWNER'],params:paging});op('patch',seller+'/members/{memberId}','updateSellerMember','판매자','팀 권한 변경','TeamMemberEdit','TeamMember','COM-02',{roles:['SELLER_OWNER']});op('delete',seller+'/members/{memberId}','removeSellerMember','판매자','마지막 OWNER 제외 팀원 제거','VersionCommand',null,'COM-02',{roles:['SELLER_OWNER']});
 const cat={roles:['SELLER_OWNER','SELLER_CATALOG']};
 op('get',seller+'/products','listSellerProducts','상품','자기 판매자 상품·초안',null,page('ProductDetail'),'CAT-01',{...cat,params:paging});op('post',seller+'/products','createProduct','상품','상품 초안 생성','ProductCreate','ProductDetail','CAT-01',cat);op('get',seller+'/products/{productId}','getSellerProduct','상품','판매자 상품 상세',null,'ProductDetail','CAT-01',cat);op('patch',seller+'/products/{productId}','editProduct','상품','게시본을 보존하는 새 revision 편집','ProductRevisionCreate','ProductDetail','CAT-01',cat);op('post',seller+'/products/{productId}/revisions','createProductRevision','상품','상품 revision 작성','ProductRevisionCreate','ProductDetail','CAT-01',cat);
 for(const [leaf,id]of [['submit-review','submitProductReview'],['publish','publishProduct'],['pause','pauseProduct']])op('post',seller+'/products/{productId}/'+leaf,id,'상품',leaf,'VersionCommand','ProductDetail','CAT-01',{...cat,status:200});op('get',seller+'/products/{productId}/skus','listProductSkus','상품','SKU 목록',null,page('Sku'),'CAT-01',{...cat,params:paging});op('put',seller+'/products/{productId}/skus','updateProductSkus','상품','SKU 전체 검증 갱신','SkuUpdate',page('Sku'),'CAT-01',cat);
 op('get',seller+'/inventory','listInventory','재고','재고 수량 조회',null,page('Inventory'),'INV-01',{...cat,params:paging});op('post',seller+'/inventory/{skuId}/adjustments','adjustInventory','재고','재고 원장 조정','InventoryAdjustment','Inventory','INV-01',cat);
 const fulfillment={roles:['SELLER_OWNER','SELLER_FULFILLMENT']};
 op('get',seller+'/orders','listSellerOrders','배송','자기 판매자 항목만 주문 조회',null,page('Order'),'FUL-01',{...fulfillment,params:[...paging,...filters],description:'다른 seller 항목·charge는 반환하지 않음. amount는 자기 seller 소계. 전체 고객 주문 금융 정보 비노출.'});op('get',seller+'/shipments','listSellerShipments','배송','배송 목록',null,page('Shipment'),'FUL-01',{...fulfillment,params:paging});op('post',seller+'/shipments','createShipment','배송','수량별 분할 출고 준비','ShipmentCreate','Shipment','FUL-01',fulfillment);op('post',seller+'/shipments/{shipmentId}/handover','handoverShipment','배송','택배 인계','VersionCommand','Shipment','FUL-01',{...fulfillment,status:200});
 op('get',seller+'/claims','listSellerClaims','클레임','판매자별 클레임',null,page('Claim'),'CLM-01',{...fulfillment,params:paging});op('post',seller+'/claims/{claimId}/decisions','decideSellerClaim','클레임','클레임 검수 결정','ClaimDecision','Claim','CLM-01',{...fulfillment,status:200});op('post',seller+'/claims/{claimId}/inspections','inspectClaim','클레임','반품 unit별 검수·재입고 판단','ClaimInspection','Claim','CLM-02',{...fulfillment,status:200});
 op('post',seller+'/reviews/{reviewId}/reply','createSellerReviewReply','리뷰','판매자 답글','ReplyCreate','Reply','EXP-02',fulfillment);op('patch',seller+'/reviews/{reviewId}/reply','updateSellerReviewReply','리뷰','판매자 답글 수정','ReplyEdit','Reply','EXP-02',fulfillment);
 const finance={roles:['SELLER_OWNER','SELLER_FINANCE']};op('get',seller+'/ledger','listSellerLedger','정산','판매자 원장',null,page('LedgerEntry'),'SET-01',{...finance,params:[...paging,...filters]});op('get',seller+'/settlements','listSellerSettlements','정산','판매자 정산 목록',null,page('Settlement'),'SET-02',{...finance,params:[...paging,...filters]});op('get',seller+'/settlements/{settlementId}','getSellerSettlement','정산','정산·이월·보류 조회',null,'Settlement','SET-02',finance);op('post',seller+'/appeals','createSellerAppeal','운영','제재 이의신청','AppealCreate','Appeal','OPS-01',{roles:['SELLER_OWNER']});
 op('post',seller+'/products/{productId}/analysis-runs','createProductAnalysis','검색','모의 concept 분석 요청','AnalysisCreate','AnalysisRun','DIS-02',{...cat,status:202});op('get',seller+'/products/{productId}/analysis-runs/{runId}','getProductAnalysis','검색','분석 결과·근거',null,'AnalysisRun','DIS-02',cat);op('post',seller+'/products/{productId}/concept-reviews','reviewProductConcept','검색','분석 concept 검토','ConceptReview','AnalysisRun','DIS-02',{...cat,status:200});
 const admin='/admin';op('post',admin+'/sessions','adminLogin','IAM','관리자 TOTP 로그인','AdminLogin','Session','SEC-02',{public:true,status:200,idempotent:false});op('get',admin+'/session','adminSession','IAM','관리자 세션 조회',null,'Session','SEC-02',{roles:['ADMIN_IAM','ADMIN_SUPPORT','ADMIN_CATALOG','ADMIN_RISK','ADMIN_FINANCE']});op('delete',admin+'/session','adminLogout','IAM','관리자 세션 폐기',null,null,'SEC-02',{idempotent:false,roles:['ADMIN_IAM','ADMIN_SUPPORT','ADMIN_CATALOG','ADMIN_RISK','ADMIN_FINANCE']});
 for(const [p,id,req,res,role,rid]of [
  ['/sellers/{sellerId}/verifications/{verificationId}/decisions','decideSellerVerification','Decision','SellerVerification','ADMIN_SUPPORT','COM-02'],
  ['/sellers/{sellerId}/settlement-account-change-requests/{requestId}/decisions','decideAccountChange','Decision','AccountChange','ADMIN_FINANCE','COM-02'],
  ['/products/{productId}/review-decisions','decideProductReview','Decision','ProductDetail','ADMIN_CATALOG','CAT-01'],
  ['/shipments/{shipmentId}/tracking-events','recordTrackingEvent','TrackingEvent','Shipment','ADMIN_SUPPORT','FUL-01'],
  ['/reviews/{reviewId}/moderation','moderateReview','Moderation','Review','ADMIN_CATALOG','EXP-02'],
  ['/settlements/{settlementId}/calculate','calculateSettlement','SettlementCalculate','Settlement','ADMIN_FINANCE','SET-02'],
  ['/settlements/{settlementId}/approval-requests','requestSettlementApproval','ApprovalCreate','Approval','ADMIN_FINANCE','SET-03'],
  ['/settlements/{settlementId}/payout','requestPayout','PayoutCreate','Payout','ADMIN_FINANCE','SET-03'],
  ['/payment-operations/{operationId}/recover','recoverPaymentOperation','RecoveryRequest','FinancialOperation','ADMIN_FINANCE','PAY-05'],
  ['/reconciliation-discrepancies/{discrepancyId}/resolutions','resolveDiscrepancy','DiscrepancyResolution','Discrepancy','ADMIN_FINANCE','PAY-06,SET-04'],
  ['/approval-requests','createApproval','ApprovalCreate','Approval','ADMIN_FINANCE','OPS-01'],
  ['/approval-requests/{approvalId}/decisions','decideApproval','ApprovalDecision','Approval','ADMIN_FINANCE','OPS-01'],
  ['/incidents','createIncident','IncidentCreate','Incident','ADMIN_RISK','OPS-01'],
  ['/seller-penalties','createPenalty','PenaltyCreate','Penalty','ADMIN_RISK','OPS-01'],
  ['/compliance-rules','createComplianceRule','ComplianceRuleCreate','ComplianceRule','ADMIN_CATALOG','OPS-01'],
  ['/appeals/{appealId}/decisions','decideAppeal','AppealDecision','Appeal','ADMIN_RISK','OPS-01'],
  ['/concept-taxonomies','createTaxonomy','TaxonomyCreate','Taxonomy','ADMIN_CATALOG','DIS-02'],
  ['/concept-taxonomies/{taxonomyId}/publish','publishTaxonomy','VersionCommand','Taxonomy','ADMIN_CATALOG','DIS-02']
 ])op('post',admin+p,id,role.replace('ADMIN_',''),id,req,res,rid,{roles:[role],status:p.endsWith('/payout')||p.endsWith('/recover')?202:201});
 for(const [p,id,res,role,rid]of [['settlements','listAdminSettlements','Settlement','ADMIN_FINANCE','SET-02'],['payment-operations','listPaymentOperations','FinancialOperation','ADMIN_FINANCE','PAY-05'],['reconciliation-discrepancies','listDiscrepancies','Discrepancy','ADMIN_FINANCE','PAY-06,SET-04'],['approval-requests','listApprovals','Approval','ADMIN_FINANCE','OPS-01'],['incidents','listIncidents','Incident','ADMIN_RISK','OPS-01'],['seller-penalties','listPenalties','Penalty','ADMIN_RISK','OPS-01'],['compliance-rules','listComplianceRules','ComplianceRule','ADMIN_CATALOG','OPS-01'],['audit-logs','listAuditLogs','AuditLog','ADMIN_IAM','OPS-01']])op('get',admin+'/'+p,id,role.replace('ADMIN_',''),id,null,page(res),rid,{roles:[role],params:[...paging,...filters]});
 op('get',admin+'/settlements/{settlementId}','getAdminSettlement','FINANCE','정산 계산 근거',null,'Settlement','SET-02',{roles:['ADMIN_FINANCE']});op('patch',admin+'/incidents/{incidentId}','updateIncident','RISK','사건 상태 변경','IncidentEdit','Incident','OPS-01',{roles:['ADMIN_RISK']});
 const ci=spec('Commerce 내부 협력 API','commerce-service',8081);
 for(const [method,path,id,req,res,rid,scope]of [
 ['get','/internal/v1/sellers/{sellerId}/financial-barrier','getFinancialBarrier',null,'FinancialBarrier','SET-03','commerce:financial-barrier'],
 ['post','/internal/v1/sellers/{sellerId}/payout-fences','createPayoutFence','FenceCreate','Fence','SET-03','commerce:payout-fence'],
 ['post','/internal/v1/payout-fences/{fenceId}/consume','consumePayoutFence','FenceConsume','DispatchPermit','SET-03','commerce:payout-fence'],
 ['get','/internal/v1/admin-approval-requests/{approvalId}','getApprovalForExecution',null,'Approval','OPS-01','commerce:approval-read'],
 ['post','/internal/v1/admin-approval-requests/{approvalId}/consume','consumeApproval','ApprovalConsume','Approval','OPS-01','commerce:approval-consume'],
 ['get','/internal/v1/catalog/snapshot','getCatalogSnapshot',null,'CatalogSnapshot','DIS-01','commerce:catalog-read']
 ])add(ci,method,path,id,'내부',id,req,res,rid,{scope,params:path.endsWith('snapshot')?[...paging,param('snapshotId',uuid)]:[],roles:[path.includes('catalog')?'discovery-data-service':'settlement-service']});
 const st=spec('Settlement 내부 API','settlement-service',8083);
 for(const [method,path,id,req,res,rid]of [
 ['get','/internal/v1/sellers/{sellerId}/ledger','queryLedger',null,page('LedgerEntry'),'SET-01'],['get','/internal/v1/settlements','querySettlements',null,page('Settlement'),'SET-02'],['get','/internal/v1/settlements/{settlementId}','querySettlement',null,'Settlement','SET-02'],['post','/internal/v1/settlements/{settlementId}/calculate','runSettlementCalculation','SettlementCalculate','Settlement','SET-02'],['post','/internal/v1/settlements/{settlementId}/payout','dispatchSimulatedPayout','PayoutCreate','Payout','SET-03'],['get','/internal/v1/payouts/{payoutId}','queryPayout',null,'Payout','SET-03'],['get','/internal/v1/reconciliation-discrepancies','queryBankDiscrepancies',null,page('Discrepancy'),'SET-04'],['post','/internal/v1/reconciliation-discrepancies/{discrepancyId}/resolutions','resolveBankDiscrepancy','DiscrepancyResolution','Discrepancy','SET-04']
 ])add(st,method,path,id,'정산',id,req,res,rid,{roles:['commerce-service'],scope:method==='get'?'settlement:read':'settlement:admin',params:method==='get'&&!path.endsWith('}')?[...paging,...(path.includes('{sellerId}')?[]:[param('sellerId',uuid)]),...filters]:[],status:path.endsWith('payout')?202:undefined});
 const d=spec('Discovery 내부 API','discovery-data-service',8084);
 for(const [method,path,id,req,res,rid]of [
 ['get','/internal/v1/search/products','querySearchProducts',null,'SearchResult','DIS-01'],['post','/internal/v1/products/{productId}/analysis-runs','queueAnalysis','AnalysisCreate','AnalysisRun','DIS-02'],['get','/internal/v1/analysis-runs/{runId}','queryAnalysis',null,'AnalysisRun','DIS-02'],['post','/internal/v1/products/{productId}/concept-reviews','applyConceptReview','ConceptReview','AnalysisRun','DIS-02'],['post','/internal/v1/concept-taxonomies','addTaxonomy','TaxonomyCreate','Taxonomy','DIS-02'],['post','/internal/v1/concept-taxonomies/{taxonomyId}/publish','activateTaxonomy','VersionCommand','Taxonomy','DIS-02'],['post','/internal/v1/behavior-events/batch','ingestBehavior','BehaviorBatch','Accepted','DIS-03'],['post','/internal/v1/search/rebuilds','rebuildProjection','RebuildCreate','ProjectionRebuild','DIS-01'],['get','/internal/v1/search/rebuilds/{generationId}','queryProjectionRebuild',null,'ProjectionRebuild','DIS-01']
 ])add(d,method,path,id,'검색',id,req,res,rid,{roles:['commerce-service'],scope:method==='get'?'discovery:read':'discovery:write',params:path.endsWith('/search/products')?searchParams:[],status:method==='post'&&/analysis-runs|rebuilds|behavior/.test(path)?202:undefined});
 for(const route of ['/api/v1/admin/approval-requests','/api/v1/admin/approval-requests/{approvalId}/decisions'])for(const action of Object.values(c.paths[route])){
  action['x-authorized-roles']=['ADMIN_FINANCE','ADMIN_RISK','ADMIN_IAM'];
  action.description+=' actionType별 권한: ACCOUNT_CHANGE/FINANCIAL_ADJUSTMENT/UNKNOWN_RESOLUTION/PAYOUT=ADMIN_FINANCE, PENALTY/PENALTY_REVOKE=ADMIN_RISK, ADMIN_ROLE_CHANGE=ADMIN_IAM. 요청자와 승인자는 다른 사람이어야 하며 다른 actionType의 승인을 실행할 수 없습니다.';
 }
 const ops=spec('업무 서비스 공통 운영 내부 API','business-service',8081);
 ops.info.description='Commerce/Payment/Settlement/Discovery 각각의 로컬 queue/recovery port 계약. 별도 서비스를 추가하지 않습니다. 각 서버 aud는 실제 서비스 ID이며 Commerce만 사용자 대리를 허용합니다.';
 ops.servers=[['commerce-service',8081],['payment-service',8082],['settlement-service',8083],['discovery-data-service',8084]].map(([service,port])=>({url:`http://localhost:${port}`,description:service+' own DB only','x-jwt-audience':service}));
 registerExtensions({c,ci,st,d,ops},{schemas,def,ref,s,en,i,uuid,time,bool,version,arr,nullable,obj,page,reason,ver,param,paging,add});
 for(const doc of [st,d,ops])for(const methods of Object.values(doc.paths))for(const action of Object.values(methods))if(action.requestBody){
  const media=action.requestBody.content['application/json'],baseName=media.schema.$ref.split('/').at(-1),name=baseName+'WithActorContext';
  schemas[name]=structuredClone(schemas[baseName]);schemas[name].properties.actorContext=ref('ActorContext');schemas[name].required.push('actorContext');media.schema=ref(name);
  action.description+=' actorContext는 인증된 Commerce가 세션·권한 검사 후 생성합니다. 브라우저가 보낸 actor를 신뢰하지 않습니다.';
 }
 const documents={'commerce-public':c,'commerce-internal':ci,'settlement-internal':st,'discovery-internal':d,'operations-internal':ops};
 for(const doc of Object.values(documents))doc.components.schemas=prune(doc,schemas);
 return documents;
}
export function prune(doc,all){const names=new Set();const visit=node=>{if(!node||typeof node!=='object')return;if(node.$ref){const name=node.$ref.split('/').at(-1);if(!all[name])throw Error(`Missing schema ${name}`);if(!names.has(name)){names.add(name);visit(all[name]);}}for(const [key,value]of Object.entries(node))if(key!=='components')visit(value);};visit(doc.paths);return Object.fromEntries([...names].sort().map(n=>[n,all[n]]));}

export function pgSpecs(){
 const pg=spec('PG1 · PG2 현재 구현 API','pg-simulator',8090);pg.info.version='current-2026-09-21';pg.info.description='현재 코드에 구현된 공통 4개 경로. 무인증, 임의 대문자 3자리 통화, 양수 long. v1 목표 인증/통화 제한/웹훅/조회 확장은 별도 명세.';pg.servers=[{url:'http://localhost:8090',description:'PG1 / KAKAO'},{url:'http://localhost:8091',description:'PG2 / NAVER'}];pg.components={schemas:{},securitySchemes:{}};
 const ps={PgApprove:obj({merchantTxId:{type:'string',pattern:'\\S'},currency:{type:'string',pattern:'^[A-Z]{3}$'},amount:{type:'integer',format:'int64',minimum:1},idempotencyKey:{type:'string',pattern:'\\S'}}),PgCancel:obj({idempotencyKey:{type:'string',pattern:'\\S'}}),PgRefund:obj({amount:{type:'integer',format:'int64',minimum:1},idempotencyKey:{type:'string',pattern:'\\S'}}),PgPayment:obj({paymentId:uuid,merchantTxId:s(),currency:{type:'string',pattern:'^[A-Z]{3}$'},amount:{type:'integer',format:'int64',minimum:1},status:en('APPROVED','CANCELLED','PARTIALLY_REFUNDED','REFUNDED'),refundedAmount:{type:'integer',format:'int64',minimum:0}}),PgError:obj({code:s(),message:s(1,2000),timestamp:time,path:s(1,500)})};
 for(const [method,p,id,req]of [['post','/pg/v1/payments/approve','pgApprove','PgApprove'],['post','/pg/v1/payments/{paymentId}/cancel','pgCancel','PgCancel'],['post','/pg/v1/payments/{paymentId}/refund','pgRefund','PgRefund'],['get','/pg/v1/payments/{paymentId}','pgGetPayment',null]]){
  const responses={'200':{description:'최신 PG payment snapshot. 최초 응답 캐시/불변 거래 영수증이 아님.',content:{'application/json':{schema:ref('PgPayment')}}}};for(const code of ['400','404','409','500'])responses[code]={description:'provider별 오류 코드 KAKAO_PG_xxx/NAVER_PG_xxx 또는 HTTP_xxx',content:{'application/json':{schema:ref('PgError')}}};const o={operationId:id,summary:id,tags:['현재 PG'],security:[],parameters:p.includes('{')?[param('paymentId',uuid,'path',true)]:[],responses,'x-implementation':'implemented','x-requirements':['PG-01'],'x-authorized-roles':['LOCAL_NETWORK_ONLY']};if(req)o.requestBody={required:true,content:{'application/json':{schema:ref(req)}}};pg.paths[p]={[method]:o};
 }
 // Current DTOs do not declare unknown-property rejection or string length caps.
 for(const schema of Object.values(ps))delete schema.additionalProperties;
 ps.PgPayment.properties.merchantTxId={type:'string'};
 pg.components.schemas=ps;
 const target=structuredClone(pg);target.info={title:'PG1 · PG2 목표 v1 확장 API',version:'1.0.0',description:'현재 2개 PG에 추가할 목표 계약. 기존 current 명세를 구현 상태의 기준으로 사용. 인증·merchant/receipt 조회·webhook outbox·fault injection은 미구현.'};target.components.securitySchemes={serviceJWT:securitySchemes.serviceJWT};
 target.components.schemas.PgPayment.properties.simulated=simulated;target.components.schemas.PgPayment.required.push('simulated');
 for(const n of ['PgApprove','PgPayment']){target.components.schemas[n].properties.currency={type:'string',const:'KRW'};target.components.schemas[n].properties.amount=i(1);}
 target.components.schemas.PgRefund.properties.amount=i(1);
 target.components.schemas.PgReceipt=obj({transactionId:uuid,paymentId:uuid,merchantTxId:s(),transactionType:en('APPROVE','CANCEL','REFUND'),idempotencyKey:s(),amount:i(1),currency:{type:'string',const:'KRW'},status:en('SUCCEEDED','FAILED'),occurredAt:time,simulated});
 target.components.schemas.PgReceiptPage=obj({items:arr(ref('PgReceipt')),nextCursor:nullable(s(1,2048)),asOf:time});
 target.components.schemas.PgFault=obj({scenarioId:uuid,type:en('BEFORE_COMMIT_ERROR','AFTER_COMMIT_DROP_RESPONSE','DELAY_RESPONSE','DUPLICATE_WEBHOOK','OUT_OF_ORDER_WEBHOOK','INVALID_SIGNATURE'),remainingUses:i(1,100),delayMs:i(0,30000),expiresAt:time});
 for(const item of Object.values(target.paths))for(const o of Object.values(item)){o.security=[{serviceJWT:[]}];o['x-implementation']='planned-upgrade';o['x-service-scope']=o.operationId==='pgGetPayment'?'pg:read':'pg:write';for(const code of ['401','403'])o.responses[code]={description:'서비스 인증/권한 거부',content:{'application/json':{schema:ref('PgError')}}};}
 for(const [p,id,response,parameters]of [['/pg/v1/payments/by-merchant/{merchantTxId}','pgGetByMerchant','PgPayment',[param('merchantTxId',s(1,200),'path',true)]],['/pg/v1/payments/{paymentId}/transactions','pgGetPaymentTransactions','PgReceiptPage',[param('paymentId',uuid,'path',true),param('type',en('APPROVE','CANCEL','REFUND')),param('idempotencyKey',s()),...paging]],['/pg/v1/transactions','pgListTransactions','PgReceiptPage',[param('from',time,'query',true),param('to',time,'query',true),param('asOf',time),...paging]]])target.paths[p]={get:{operationId:id,tags:['목표 조회'],summary:id,security:[{serviceJWT:[]}],parameters,responses:{'200':{description:'읽기 전용 확정 사실. from 포함/to 제외, asOf/cursor 고정.',content:{'application/json':{schema:ref(response)}}},'404':{description:'현재 기록 없음; 진행 중 요청의 최종 무효 증거가 아님.'}},'x-implementation':'planned','x-requirements':['PG-02'],'x-service-scope':'pg:read'}};
 target.paths['/pg/internal/v1/fault-scenarios']={post:{operationId:'pgSetFaultScenario',tags:['테스트 전용'],summary:'local/stage 전용 실패 주입',description:'prod profile에서 403; test principal + pg:test scope. 소비 횟수 원자적 차감.',security:[{serviceJWT:[]}],requestBody:{required:true,content:{'application/json':{schema:ref('PgFault')}}},responses:{'201':{description:'제한된 테스트 시나리오',content:{'application/json':{schema:ref('PgFault')}}},'403':{description:'production 또는 테스트 권한 없음'}},'x-implementation':'planned','x-requirements':['PG-02'],'x-service-scope':'pg:test'}};
 return {'pg-current':pg,'pg-target':target};
}
