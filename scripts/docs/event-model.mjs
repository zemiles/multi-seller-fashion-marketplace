// Authored event v1 contract. No producer or consumer implementation is implied.
const id={type:'string',format:'uuid'},instant={type:'string',format:'date-time',pattern:'Z$'};
const text=(max=200)=>({type:'string',minLength:1,maxLength:max});
const integer=(min=0,max=9007199254740991)=>({type:'integer',minimum:min,maximum:max});
const amount=integer(0,100000000),positive=integer(1,100000000),sequence=integer(1);
const enumeration=(...values)=>({type:'string',enum:values});
const array=(items,min=0,max=100)=>({type:'array',items,minItems:min,maxItems:max});
const object=(properties,required=Object.keys(properties))=>({type:'object',properties,required,additionalProperties:false});
const nullable=s=>({anyOf:[s,{type:'null'}]});
const ref=n=>({$ref:'#/$defs/'+n});
const uuidPattern='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
export const unitPattern='^'+uuidPattern+':[1-9][0-9]?$';
const unitId={type:'string',pattern:unitPattern};
const orderSeller={type:'string',pattern:'^'+uuidPattern+':'+uuidPattern+'$'};
const sourceId={type:'string',pattern:'^(UNIT:'+uuidPattern+':[1-9][0-9]?|CHARGE:'+uuidPattern+')$'};
const code={...text(80),pattern:'^[A-Z][A-Z0-9_]*$'},hash={type:'string',pattern:'^[0-9a-f]{64}$'};
const currency={const:'KRW',type:'string'},provider=enumeration('KAKAO','NAVER');
const ordinals={...array(integer(1,99),1,99),uniqueItems:true};
const common={
 Money:object({currency,amount:positive}),SettlementMoney:object({currency,amount:integer(1)}),
 Feature:object({key:text(80),value:text(500),source:enumeration('SELLER','ADMIN')}),
 RecognitionUnit:object({orderItemId:id,unitOrdinal:integer(1,99),paidAmount:positive,commissionAmount:amount}),
 FinancialAdjustment:object({sourceUnitOrChargeId:sourceId,originalRecognitionId:id,signedRevenueAmount:integer(-100000000,0),signedFeeAmount:amount}),
 Concept:object({conceptId:id,score:{type:'number',minimum:0,maximum:1},evidenceRefs:array(text(200),1,100)})
};
const states={claim:enumeration('REQUESTED','UNDER_REVIEW','APPROVED','REJECTED','PICKUP_PENDING','IN_TRANSIT','RECEIVED','INSPECTING','REFUND_PENDING','COMPLETED','CANCELLED'),sale:enumeration('DRAFT','IN_REVIEW','READY','ON_SALE','PAUSED','SOLD_OUT','ARCHIVED')};
const defs={
 ProductRevisionPublished:object({productId:id,revisionId:id,revisionNumber:sequence,sellerId:id,title:text(200),categoryId:id,brandId:nullable(id),imageUrl:{type:'string',format:'uri',pattern:'^https?://'},features:array(ref('Feature')),skuSummaries:array(object({skuId:id,price:positive,available:{type:'boolean'}}),1,500),publishedAt:instant}),
 ProductAvailabilityChanged:object({productId:id,revisionId:id,saleStatus:states.sale,available:{type:'boolean'},reasonCode:code}),
 OrderPaid:object({orderId:id,memberPseudonym:hash,paymentId:id,totalAmount:positive,items:array(object({productId:id,revisionId:id,quantity:integer(1,99)}),1,100)}),
 ShipmentDelivered:object({orderId:id,shipmentId:id,items:array(object({shipmentItemId:id,orderItemId:id,unitOrdinals:ordinals}),1,100),deliveredAt:instant}),
 ClaimStatusChanged:object({orderId:id,claimId:id,status:states.claim,reasonCode:code,affectedUnitIds:{...array(unitId,1,9900),uniqueItems:true}}),
 PurchaseConfirmed:object({orderId:id,sellerId:id,confirmationId:id,priorFinancialVersion:integer(),units:array(ref('RecognitionUnit'),1,9900),currency,policyVersion:text(80)}),
 SellerShippingRevenueRecognized:object({orderId:id,sellerId:id,orderChargeId:id,amount:ref('Money'),currency,priorFinancialVersion:integer()}),
 SellerFinancialAdjusted:object({orderId:id,sellerId:id,adjustmentId:id,refundId:nullable(id),reasonCode:code,priorFinancialVersion:integer(),adjustments:array(ref('FinancialAdjustment'),1,10000),currency},['orderId','sellerId','adjustmentId','reasonCode','priorFinancialVersion','adjustments','currency']),
 SellerSettlementHoldChanged:object({sellerId:id,orderId:nullable(id),holdId:id,holdVersion:sequence,action:enumeration('PLACE','RELEASE'),reasonCode:code,unitIds:{...array(unitId,0,9900),uniqueItems:true},amount:object({currency,amount:integer()}),currency},['sellerId','holdId','holdVersion','action','reasonCode','unitIds','amount','currency']),
 SellerPenaltyApplied:object({sellerId:id,penaltyId:id,approvalId:id,type:enumeration('WARNING','FEE','LISTING_RESTRICTION','PAYOUT_HOLD','SUSPENSION','TERMINATION'),amount:object({currency,amount}),currency,action:enumeration('APPLY','REVOKE'),originalPenaltyId:nullable(id)},['sellerId','penaltyId','approvalId','type','amount','currency','action']),
 PaymentApproved:object({operationId:id,resultVersion:sequence,orderId:id,attemptId:id,paymentId:id,provider,merchantTxId:{type:'string',pattern:'^mp-'+uuidPattern+'-'+uuidPattern+'$'},providerPaymentKey:id,amount:ref('Money'),approvedAt:instant,snapshotHash:hash,items:array(ref('HttpCheckoutPaymentItem'),1,100),charges:array(ref('HttpCheckoutPaymentCharge'))}),
 PaymentFailed:object({operationId:id,resultVersion:sequence,orderId:id,attemptId:id,reasonCode:code,noEffectEvidenceId:id}),
 PaymentUnknown:object({operationId:id,resultVersion:sequence,orderId:id,attemptId:nullable(id),paymentId:nullable(id),kind:enumeration('APPROVE','CANCEL','REFUND'),firstUnknownAt:instant,reasonCode:code},['operationId','resultVersion','orderId','kind','firstUnknownAt','reasonCode']),
 PaymentVoided:object({operationId:id,resultVersion:sequence,orderId:id,paymentId:id,transactionId:id,amount:ref('Money'),reasonCode:enumeration('CUSTOMER_CANCEL','ORDER_COMPENSATION'),voidedAt:instant}),
 RefundSucceeded:object({operationId:id,resultVersion:sequence,orderId:id,paymentId:id,refundId:id,claimId:nullable(id),transactionId:id,amount:ref('Money'),items:array(ref('HttpRefundItemAllocation')),charges:array(ref('HttpRefundChargeAllocation')),completedAt:instant},['operationId','resultVersion','orderId','paymentId','refundId','transactionId','amount','items','charges','completedAt']),
 RefundFailed:object({operationId:id,resultVersion:sequence,orderId:id,paymentId:id,refundId:id,reasonCode:code,noEffectEvidenceId:id}),
 SettlementPaid:object({settlementId:id,sellerId:id,payoutAttemptId:id,bankReceiptId:id,amount:ref('SettlementMoney'),paidAt:instant}),
 PayoutUnknown:object({settlementId:id,sellerId:id,payoutAttemptId:id,amount:ref('SettlementMoney'),firstUnknownAt:instant}),
 ProductAnalysisCompleted:object({productId:id,revisionId:id,runId:id,taxonomyVersion:text(80),modelVersion:text(80),promptVersion:text(80),concepts:array(ref('Concept'),0,1000),completedAt:instant})
};
defs.PaymentUnknown.allOf=[{if:{properties:{kind:{const:'APPROVE'}}},then:{required:['attemptId'],properties:{attemptId:id}},else:{required:['paymentId'],properties:{paymentId:id}}}];
defs.SellerPenaltyApplied.allOf=[{if:{properties:{action:{const:'REVOKE'}}},then:{required:['originalPenaltyId'],properties:{originalPenaltyId:id}}},{if:{properties:{type:{const:'FEE'}}},then:{properties:{amount:ref('Money')}},else:{properties:{amount:object({currency,amount:{type:'integer',const:0}})}}}];
const domains={
 catalog:{topic:'marketplace.commerce.catalog.v1',producer:'commerce-service',aggregates:['PRODUCT'],groups:['discovery-catalog-v1'],requirements:['CAT-01','DIS-01'],effect:'검색 projection 갱신; 원본 상품 수정 없음'},
 order:{topic:'marketplace.commerce.order.v1',producer:'commerce-service',aggregates:['ORDER'],groups:['commerce-notification-v1','discovery-conversion-v1'],requirements:['ORD-04','FUL-01','CLM-01','EXP-03','DIS-03'],effect:'알림; OrderPaid만 구매 전환 집계'},
 financial:{topic:'marketplace.commerce.seller-financial.v1',producer:'commerce-service',aggregates:['ORDER_SELLER'],groups:['settlement-ledger-v1'],requirements:['SET-01','SET-03','FUL-02'],effect:'매출·수수료·hold·역전 원장; 지급의 입력'},
 payment:{topic:'marketplace.payment.lifecycle.v1',producer:'payment-service',aggregates:['PAYMENT_FLOW'],groups:['commerce-payment-v1','settlement-payment-audit-v1'],requirements:['PAY-02','PAY-04','PAY-05','ORD-04'],effect:'Commerce 주문/Claim 반영; Settlement는 대사 projection만'},
 settlement:{topic:'marketplace.settlement.lifecycle.v1',producer:'settlement-service',aggregates:['SETTLEMENT'],groups:['commerce-settlement-v1'],requirements:['SET-03','SET-04','EXP-03'],effect:'판매자 지급상태·알림 갱신'},
 analysis:{topic:'marketplace.discovery.analysis.v1',producer:'discovery-data-service',aggregates:['PRODUCT_ANALYSIS'],groups:['commerce-analysis-v1'],requirements:['DIS-02'],effect:'revision별 검토 결과, 원본 자동게시 없음'}
};
const names={catalog:['ProductRevisionPublished','ProductAvailabilityChanged'],order:['OrderPaid','ShipmentDelivered','ClaimStatusChanged'],financial:['PurchaseConfirmed','SellerShippingRevenueRecognized','SellerFinancialAdjusted','SellerSettlementHoldChanged','SellerPenaltyApplied'],payment:['PaymentApproved','PaymentFailed','PaymentUnknown','PaymentVoided','RefundSucceeded','RefundFailed'],settlement:['SettlementPaid','PayoutUnknown'],analysis:['ProductAnalysisCompleted']};
export const eventMetadata=Object.entries(names).flatMap(([domain,events])=>events.map(eventType=>({...domains[domain],eventType,domain,aggregates:eventType==='SellerPenaltyApplied'?['SELLER_CONTROL']:eventType==='SellerSettlementHoldChanged'?['ORDER_SELLER','SELLER_CONTROL']:domains[domain].aggregates})));

export function eventSchema(paymentSpec){
 const $defs=structuredClone(common),imported=new Set();
 function copyHttp(name){if(imported.has(name))return;imported.add(name);const schema=structuredClone(paymentSpec.components.schemas[name]);if(!schema)throw Error('Missing payment contract '+name);function walk(x){if(!x||typeof x!=='object')return;if(x.$ref){const n=x.$ref.split('/').at(-1);copyHttp(n);x.$ref='#/$defs/Http'+n;}if(x.type==='object')x.additionalProperties=false;for(const v of Object.values(x))walk(v);}walk(schema);$defs['Http'+name]=schema;}
 for(const name of ['CheckoutPaymentItem','CheckoutPaymentCharge','RefundItemAllocation','RefundChargeAllocation'])copyHttp(name);
 for(const meta of eventMetadata){
  const properties={eventId:id,eventType:{type:'string',const:meta.eventType},eventVersion:{type:'integer',const:1},producer:{type:'string',const:meta.producer},aggregateType:enumeration(...meta.aggregates),aggregateId:meta.aggregates.length===1&&meta.aggregates[0]==='ORDER_SELLER'?orderSeller:meta.aggregates.length===1?id:{anyOf:[id,orderSeller]},aggregateVersion:sequence,occurredAt:instant,correlationId:id,causationId:id,traceId:{type:'string',pattern:'^[0-9a-f]{32}$'},payload:defs[meta.eventType],simulated:{type:'boolean',const:true}};
  $defs['Event'+meta.eventType]={...object(properties),'x-topic':meta.topic,'x-consumer-groups':meta.groups};
 }
 return {$schema:'https://json-schema.org/draft/2020-12/schema',$id:'urn:marketplace:events:v1',title:'Marketplace v1 events — target contract',description:'Typed target contract; current producers/consumers are not implemented. Business invariants in docs/implementation/02-event-contracts.md also apply.',oneOf:eventMetadata.map(m=>ref('Event'+m.eventType)),$defs};
}

export const uid=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const t='2026-09-22T00:00:00Z',order=uid(1),seller=uid(2),product=uid(3),revision=uid(4),item=uid(5),charge=uid(6),payment=uid(7),attempt=uid(8),request=uid(9),operation=uid(10),settlement=uid(11),unit=item+':1';
const basePayment={operationId:operation,resultVersion:1,orderId:order},cash={currency:'KRW',amount:10000};
const samplePayloads={
 ProductRevisionPublished:{productId:product,revisionId:revision,revisionNumber:1,sellerId:seller,title:'모의 상품',categoryId:uid(12),brandId:null,imageUrl:'https://example.test/product.png',features:[{key:'material',value:'cotton',source:'SELLER'}],skuSummaries:[{skuId:uid(13),price:10000,available:true}],publishedAt:t},
 ProductAvailabilityChanged:{productId:product,revisionId:revision,saleStatus:'PAUSED',available:false,reasonCode:'SELLER_PAUSED'},
 OrderPaid:{orderId:order,memberPseudonym:'a'.repeat(64),paymentId:payment,totalAmount:13000,items:[{productId:product,revisionId:revision,quantity:1}]},
 ShipmentDelivered:{orderId:order,shipmentId:uid(14),items:[{shipmentItemId:uid(15),orderItemId:item,unitOrdinals:[1]}],deliveredAt:t},
 ClaimStatusChanged:{orderId:order,claimId:uid(16),status:'REQUESTED',reasonCode:'DEFECT',affectedUnitIds:[unit]},
 PurchaseConfirmed:{orderId:order,sellerId:seller,confirmationId:uid(17),priorFinancialVersion:0,units:[{orderItemId:item,unitOrdinal:1,paidAmount:10000,commissionAmount:1000}],currency:'KRW',policyVersion:'pricing-v1'},
 SellerShippingRevenueRecognized:{orderId:order,sellerId:seller,orderChargeId:charge,amount:{currency:'KRW',amount:3000},currency:'KRW',priorFinancialVersion:0},
 SellerFinancialAdjusted:{orderId:order,sellerId:seller,adjustmentId:uid(18),refundId:uid(19),reasonCode:'APPROVED_RETURN',priorFinancialVersion:0,adjustments:[{sourceUnitOrChargeId:'UNIT:'+unit,originalRecognitionId:uid(20),signedRevenueAmount:-10000,signedFeeAmount:1000}],currency:'KRW'},
 SellerSettlementHoldChanged:{sellerId:seller,orderId:order,holdId:uid(21),holdVersion:1,action:'PLACE',reasonCode:'CLAIM_OPENED',unitIds:[unit],amount:{currency:'KRW',amount:9000},currency:'KRW'},
 SellerPenaltyApplied:{sellerId:seller,penaltyId:uid(22),approvalId:uid(23),type:'FEE',amount:{currency:'KRW',amount:1000},currency:'KRW',action:'APPLY'},
 PaymentApproved:{...basePayment,attemptId:attempt,paymentId:payment,provider:'KAKAO',merchantTxId:'mp-'+order+'-'+request,providerPaymentKey:uid(24),amount:{currency:'KRW',amount:13000},approvedAt:t,snapshotHash:'b'.repeat(64),items:[{orderItemId:item,sellerId:seller,quantity:1,productAmount:10000,discountAmount:0,taxAmount:0,paidAmount:10000,units:[{unitOrdinal:1,productAmount:10000,discountAmount:0,paidAmount:10000,commissionAmount:1000}]}],charges:[{orderChargeId:charge,sellerId:seller,chargeType:'SHIPPING',amount:3000}]},
 PaymentFailed:{...basePayment,attemptId:attempt,reasonCode:'PROVIDER_DECLINED',noEffectEvidenceId:uid(25)},
 PaymentUnknown:{...basePayment,attemptId:attempt,kind:'APPROVE',firstUnknownAt:t,reasonCode:'RESPONSE_TIMEOUT'},
 PaymentVoided:{...basePayment,paymentId:payment,transactionId:uid(26),amount:{currency:'KRW',amount:13000},reasonCode:'CUSTOMER_CANCEL',voidedAt:t},
 RefundSucceeded:{...basePayment,paymentId:payment,refundId:uid(19),claimId:uid(16),transactionId:uid(27),amount:cash,items:[{orderItemId:item,unitOrdinals:[1],productRefundAmount:10000,discountReversalAmount:0,taxRefundAmount:0,refundAmount:10000}],charges:[],completedAt:t},
 RefundFailed:{...basePayment,paymentId:payment,refundId:uid(19),reasonCode:'PROVIDER_DECLINED',noEffectEvidenceId:uid(28)},
 SettlementPaid:{settlementId:settlement,sellerId:seller,payoutAttemptId:uid(29),bankReceiptId:uid(30),amount:{currency:'KRW',amount:12000},paidAt:t},
 PayoutUnknown:{settlementId:settlement,sellerId:seller,payoutAttemptId:uid(29),amount:{currency:'KRW',amount:12000},firstUnknownAt:t},
 ProductAnalysisCompleted:{productId:product,revisionId:revision,runId:uid(31),taxonomyVersion:'taxonomy-v1',modelVersion:'rules-v1',promptVersion:'none-v1',concepts:[{conceptId:uid(32),score:0.8,evidenceRefs:['FEATURE:material']}],completedAt:t}
};
export function eventExamples(){return eventMetadata.map((m,i)=>{const payload=structuredClone(samplePayloads[m.eventType]);const aggregateType=m.aggregates[0],aggregateId=aggregateType==='ORDER_SELLER'?order+':'+seller:aggregateType==='SELLER_CONTROL'?seller:aggregateType==='SETTLEMENT'?settlement:['PRODUCT','PRODUCT_ANALYSIS'].includes(aggregateType)?product:order;return {eventId:uid(100+i),eventType:m.eventType,eventVersion:1,producer:m.producer,aggregateType,aggregateId,aggregateVersion:1,occurredAt:t,correlationId:uid(40),causationId:operation,traceId:'c'.repeat(32),payload,simulated:true};});}
