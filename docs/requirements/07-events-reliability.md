# 07. 이벤트 계약·운영 신뢰성

## EVT-01 envelope·토픽·순서

이 문서의 필드/타입/필수 규칙이 v1 이벤트 계약입니다. [상세 처리 규칙](../implementation/02-event-contracts.md), [typed JSON Schema·golden fixture](../../contracts/events/v1/README.md)를 함께 사용합니다. payload를 자유 json으로 추측하지 않습니다. 버전1의 breaking change는 v2 토픽·consumer 병행 migration으로 수행합니다.

envelope 필수: eventId(UUID),eventType(아래 registry),eventVersion(integer=1),producer(service ID),aggregateType,aggregateId(string),aggregateVersion(integer>=1),occurredAt(UTC),correlationId(UUID),causationId(UUID),traceId(32hex),payload(object),simulated(boolean=true). 시스템 최초 원인 causationId는 operationId 또는 runId이며 null 금지. producer는 user-supplied 값을 사용하지 않습니다.

outbox row ID=eventId, event_key=`aggregateType:aggregateId:aggregateVersion`; retry/replay는 eventId/body 불변. aggregateVersion은 **이 stream에 발행한 사건의 연속 sequence**이며 entity의 임의 수정 version과 다릅니다. 사건이 2개면 sequence를 2개 발급, 발행하지 않은 DB update로 gap 생성 금지.

Kafka key=`aggregateType:aggregateId`. 토픽당 partition=6, local replication1, 공유 HA환경 replication3/minISR2, producer acks=all/idempotence on. business exactly-once를 보장한다고 주장하지 않으며 inbox로 DB 효과를 멱등 처리합니다. 전달·순서 보장의 배경은 [Apache Kafka design](https://kafka.apache.org/41/design/design/)을 참고하되 DB와의 원자성은 아래 프로젝트 규칙으로 해결합니다.

| 토픽 | producer | aggregateType/key 대상 | 소비 group |
| --- | --- | --- | --- |
| marketplace.commerce.catalog.v1 | commerce-service | PRODUCT/productId | discovery-catalog-v1 |
| marketplace.commerce.order.v1 | commerce-service | ORDER/orderId | commerce-notification-v1, discovery-conversion-v1 |
| marketplace.commerce.seller-financial.v1 | commerce-service | ORDER_SELLER/orderId:sellerId | settlement-ledger-v1 |
| marketplace.payment.lifecycle.v1 | payment-service | PAYMENT_FLOW/orderId | commerce-payment-v1, settlement-payment-audit-v1 |
| marketplace.settlement.lifecycle.v1 | settlement-service | SETTLEMENT/settlementId | commerce-settlement-v1 |
| marketplace.discovery.analysis.v1 | discovery-data-service | PRODUCT_ANALYSIS/productId | commerce-analysis-v1 |

seller 전체 제재/hold는 seller-financial 토픽의 `SELLER_CONTROL/sellerId` stream을 사용합니다. 지급 전 barrier는 ORDER_SELLER 관련 watermark 및 SELLER_CONTROL version을 포함합니다. 동일 seller라는 이유로 다른 order stream의 버전을 비교하지 않습니다.

## EVT-02 사건별 payload registry

아래 목록의 모든 필드는 필수입니다. `?`는 생략 가능하며 null 허용 여부는 JSON Schema를 따릅니다. 예외로 NO_BRAND의 brandId는 필수 nullable입니다. UUID 이름은 UUID 문자열, amount는 KRW integer를 담은 Money 객체, `*Amount`/price는 KRW integer, version/quantity는 양의 integer입니다. 배열이 비어도 필드는 포함합니다. ID는 타 서비스 FK가 아니라 상관관계용 외부 참조입니다.

| eventType / 토픽 영역 | payload 필수 내용·효과 |
| --- | --- |
| ProductRevisionPublished / catalog | productId,revisionId,revisionNumber,sellerId,title,categoryId,brandId,imageUrl,features[],skuSummaries[{skuId,price,available}],publishedAt; 공개 snapshot으로 projection |
| ProductAvailabilityChanged / catalog | productId,revisionId,saleStatus,available,reasonCode; 판매중지 tombstone 포함 |
| OrderPaid / order | orderId,memberPseudonym,paymentId,totalAmount,items[{productId,revisionId,quantity}]; 알림·서버 구매 집계 |
| ShipmentDelivered / order | orderId,shipmentId,items[{shipmentItemId,orderItemId,unitOrdinals}],deliveredAt; 알림 |
| ClaimStatusChanged / order | orderId,claimId,status,reasonCode,affectedUnitIds; 비공개 증빙/주소 제외 |
| PurchaseConfirmed / seller-financial | orderId,sellerId,confirmationId,priorFinancialVersion,units[{orderItemId,unitOrdinal,paidAmount,commissionAmount}],currency,policyVersion; 매출·fee 원장 |
| SellerShippingRevenueRecognized / seller-financial | orderId,sellerId,orderChargeId,amount,currency,priorFinancialVersion; 남은 유료 배송 수익 |
| SellerFinancialAdjusted / seller-financial | orderId,sellerId,adjustmentId,refundId?,reasonCode,priorFinancialVersion,adjustments[{sourceUnitOrChargeId,originalRecognitionId,signedRevenueAmount,signedFeeAmount}],currency; 이미 인식한 금액만 역전 |
| SellerSettlementHoldChanged / seller-financial | sellerId,orderId?,holdId,holdVersion,action(PLACE/RELEASE),reasonCode,unitIds,amount,currency; 지급 eligibility 보류/해제 |
| SellerPenaltyApplied / seller-financial | sellerId,penaltyId,approvalId,type,amount,currency,action(APPLY/REVOKE),originalPenaltyId?; 금전 조정 또는 판매자 hold |
| PaymentApproved / payment | operationId,resultVersion,orderId,attemptId,paymentId,provider,merchantTxId,providerPaymentKey,amount,approvedAt,snapshotHash,items[],charges[]; Commerce 예약 소비 |
| PaymentFailed / payment | operationId,resultVersion,orderId,attemptId,reasonCode,noEffectEvidenceId; 재시도/만료 여부 판정 |
| PaymentUnknown / payment | operationId,resultVersion,orderId,attemptId?,paymentId?,kind,firstUnknownAt,reasonCode; 재고/금액 hold |
| PaymentVoided / payment | operationId,resultVersion,orderId,paymentId,transactionId,amount,reasonCode,voidedAt; 취소 완료, refundedAmount와 별개 |
| RefundSucceeded / payment | operationId,resultVersion,orderId,paymentId,refundId,claimId?,transactionId,amount,items[],charges[],completedAt; Commerce Claim·재무조정 |
| RefundFailed / payment | operationId,resultVersion,orderId,paymentId,refundId,reasonCode,noEffectEvidenceId; 예약액 해제·Claim 검토 |
| SettlementPaid / settlement | settlementId,sellerId,payoutAttemptId,bankReceiptId,amount,paidAt; 모의 지급 완료 조회/알림 |
| PayoutUnknown / settlement | settlementId,sellerId,payoutAttemptId,amount,firstUnknownAt; 운영/판매자 표시 |
| ProductAnalysisCompleted / analysis | productId,revisionId,runId,taxonomyVersion,modelVersion,promptVersion,concepts[{conceptId,score,evidenceRefs}],completedAt; 검토용, 자동 상품 수정 금지 |

Payment의 items/charges는 [Checkout 계약](../../contracts/commerce-payment-checkout-contract-v0.1.md) 또는 [환불 배분](03-payment-pg.md)의 불변 구조 그대로이며 식별자와 금액을 생략하지 않습니다. `amount`는 Money 객체, `*Amount` 수치 필드는 KRW 정수입니다. noEffectEvidenceId는 Payment 내부의 provider 확정 거절/미dispatch 종결 증거 ID. 로그 문자열을 근거로 사용하지 않음.

새 eventType 추가는 registry·schema·모든 해당 stream consumer의 ignore/advance 정책을 함께 배포. 소비하지 않는 알려진 event도 sequence를 advance해야 하며 선택 구독으로 gap을 만들어서는 안 됩니다. 알 수 없는 eventType/version은 조용히 ignore하지 않습니다.

## EVT-03 outbox/inbox·재시도

- 업무 transaction에서 outbox insert. publisher는 DB lease로 최대100건 claim하고 외부 전송 전에 commit. 같은 stream은 앞 sequence ACK/완료 후 다음 전송; 죽은 worker 회수 lease30초, heartbeat10초. Kafka ACK후 DB update 실패는 같은 eventId 재전송.
- 소비자는 envelope/schema 검증 후 `(consumer,eventId)` unique inbox와 원 payload/hash를 commit한 뒤 Kafka offset commit. 동일 ID 다른 hash는 poison/quarantine. broker offset commit만 하고 DB 저장 누락 금지.
- inbox worker는 aggregate별 앞 순서를 처리, 업무 변경+PROCESSED+lastSequence를 같은 transaction. last+1만 적용, <=last는 eventId/hash와 함께 중복 확인, gap은 WAITING_GAP. 다른 aggregate 처리는 계속 가능.
- 일시 장애는 1초/5초/30초/2분/10분/30분, 이후 30분 간격 총10회. schema/권한/금액불변식 오류는 즉시 QUARANTINED. 15분 gap 또는 retry 소진은 운영 사건+`<source-topic>.<consumer-group>.dlq.v1`.
- DLQ 후에도 원 inbox와 stream block을 유지, 뒤 금융 event를 건너뛰어 적용하지 않음. 운영자는 producer outbox/재구축 API로 누락 사건을 복구하거나 schema 배포 후 replay. replay는 eventId/sequence/body 불변, 새 event처럼 발급 금지.
- publishing DEAD도 원 outbox 보존·경보, 거래 자체를 실패로 되돌리지 않음. publisher/inbox worker를 껐다 켜도 중복 재고 소비/환불/원장이 없어야 함.

## OPS-03 SLO·관측·스케줄

다음은 v1 목표와 시험 합격 기준이지 달성된 운영 수치가 아닙니다. 돈·수량 불변식은 성능보다 우선합니다.

| 대상 | 목표/경보 |
| --- | --- |
| 중복 승인/환불/지급·oversell | 0건 허용 |
| 고객 조회/일반 command | PG 제외 p95<500ms, p99<2초; 테스트100 동시 사용자 기준 |
| 모의 PG 정상 승인 E2E | p95<3초, 5초 넘으면 처리중 UI |
| 이벤트 반영 | 정상 p95<5초; oldest outbox/inbox>60초 경고, >5분 incident |
| UNKNOWN | 1분 메트릭 경고, 15분 incident, 24시간 수동 write 복구 전환 |
| checkout 만료/자동확정 | worker1분, 정상환경 due+2분 이내; 결제 hold는 예외 |
| 데모 공유환경 가용성 | 월99.5% 목표, 실제 계측 전 달성 주장 금지 |
| 백업 | PostgreSQL 암호화 일일 전체+연속 WAL, RPO<=5분/RTO<=60분 목표 |

correlationId/operationId/eventId를 HTTP/DB/outbox 로그에 연결. 카드/토큰/주소/계좌/비밀번호 로그 금지. metrics: prepare/approve/refund outcomes, reservation quantity mismatch, unknown age, queue latency, duplicate conflicts, settlement hold/debt, reconciliation discrepancy. Actuator readiness는 DB 상태, liveness는 프로세스 상태; PG에도 명시적으로 추가해야 하며 현재 endpoint가 있다고 가정하지 않음.

스케줄 기준: checkout/confirmation1분, UNKNOWN은 PAY-05, PG대사01:00, 정산02:00, 은행대사03:00 KST. clock 주입 테스트와 DB now 경합 검증 필수. 로컬 시계 변경·DST·브라우저 시간이 거래 기한을 결정하지 않음.

## OPS-04 보존·배포·복구

v1은 합성 데이터/모의 거래용. 다음 기간은 데모 운영 정책이며 개인정보·전자상거래 관련 법적 보존 준수의 주장이나 실서비스 승인이 아닙니다.

- 금융/주문/정산/승인 감사와 financial idempotency: 최소365일, 진행 거래/UNKNOWN/분쟁은 해결+365일. 원 이벤트 replay가 가능한 동안 inbox dedup tombstone도 동일 유지.
- Kafka 일반 토픽7일, DLQ30일, published outbox hot30일 후 원문 불변 archive365일; DEAD/PENDING는 해결 전 purge 금지. archive replay에도 동일 eventId 사용.
- 일반 로그14일(민감정보 제외), 개인 행동 raw30일 후 pseudonym 분리 집계, 앱 알림90일, 임시 미연결 업로드24시간. 삭제 job은 dry-run 보고→권한 있는 승인→batch/audit, 금융 원본 삭제와 분리.
- 세션 TTL 종료 삭제, 탈퇴 PII는 열린 거래 종료 후30일 이내 비식별화. 실제 개인정보로 공개 운영하기 전 법적 보존·약관·세금·결제 규정 검토가 별도 출시 gate이며 v1 구현의 공급자 미정 항목은 아님.
- CI: build/test, PostgreSQL migration, 계약 snapshot, E2E, 비밀정보/취약성 검사. stage 배포 자동, prod 프로필 배포는 사용자/운영자 명시 승인. 문서 작성 요청으로 배포하지 않음.
- migration expand→backfill→검증→consumer/producer 호환 전환→나중 contract 제거. destructive down migration 금지. DB backup/복원 리허설 월1회; 실패하면 출시 gate 차단.
- 서비스별 DB를 서로 다른 시점으로 복원하면 전역 일관성이 보장되지 않음. 쓰기/배치를 잠시 막고 DB복원→각 watermark 확인→outbox/archive replay→PG/은행 대사→재고/원장 합계 확인→2인 검토 후 쓰기 재개. UNKNOWN을 초기화하지 않음.
