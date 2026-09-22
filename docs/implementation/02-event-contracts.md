# 02. Kafka 이벤트 상세 계약

정책 정본은 [EVT-01~03](../requirements/07-events-reliability.md), 기계 검증 정본은 [v1 JSON Schema](../../contracts/events/v1/marketplace-events.schema.json)입니다. [이벤트별 필드·파일 목록](../../contracts/events/v1/README.md)에 19종 payload, producer/topic/group, 합성 예시를 제공합니다. 아직 producer/consumer가 실행되는 계약은 아닙니다.

## 전송 규격과 공통 envelope

UTF-8 JSON, JSON Schema Draft 2020-12. timestamp는 UTC `Z`, UUID는 표준 UUID 문자열, 정수는 JSON number이며 문자열/소수 coercion을 하지 않습니다. object의 미정의 필드는 거부합니다. payload의 optional은 필드 생략 허용, nullable은 schema에 null이 명시된 경우만 허용합니다. NO_BRAND의 `brandId`는 **필수 nullable**입니다.

| 필드 | 타입/검증 | 생성 주체·의미 |
| --- | --- | --- |
| eventId | UUID, 필수 | producer가 outbox ID로 발급, retry/replay 불변 |
| eventType / eventVersion | 19종 중 하나 / integer const1 | 타입과 topic/producer 조합도 검증 |
| producer | 서비스 ID const | 서비스 설정에서 생성, 요청 본문에서 전달받지 않음 |
| aggregateType / aggregateId | 아래 stream별 enum/ID | partition key와 동일한 업무 경계 |
| aggregateVersion | integer 1..JS safe max | stream에 발행한 사건의 연속 번호 |
| occurredAt | UTC date-time | 업무 사실을 확정한 시각, 전송/재시도 때 변경 금지 |
| correlationId / causationId | UUID / UUID | 전체 흐름 연결 / 원인 operation·run·event ID |
| traceId | 32자리 소문자 hex | 관측용, 비밀번호/계좌/세션 ID 금지 |
| payload | eventType별 object | [필드 사전](../../contracts/events/v1/README.md) |
| simulated | boolean consttrue | v1 모든 사건 |

partition key는 UTF-8 `aggregateType:aggregateId`. event key는 여기에 `:aggregateVersion`을 붙입니다. request DTO 정규화와 별개로, 발행한 JSON bytes/hash를 outbox에 보존하고 같은 eventId 재전송에 byte 변경을 허용하지 않습니다. schemaVersion을 올렸다고 과거 raw body를 재작성하지 않습니다.

## 토픽·소비 책임

| 토픽 suffix (`marketplace.` 이후) | 발행자 | stream | group / 효과 |
| --- | --- | --- | --- |
| commerce.catalog.v1 | Commerce | PRODUCT / productId | discovery-catalog-v1: 게시본·판매 가능 projection |
| commerce.order.v1 | Commerce | ORDER / orderId | commerce-notification-v1: 알림, discovery-conversion-v1: OrderPaid 구매전환 |
| commerce.seller-financial.v1 | Commerce | ORDER_SELLER / orderId:sellerId 또는 SELLER_CONTROL / sellerId | settlement-ledger-v1: 원장·hold |
| payment.lifecycle.v1 | Payment | PAYMENT_FLOW / orderId | commerce-payment-v1: 주문/Claim, settlement-payment-audit-v1: 대사 참고 |
| settlement.lifecycle.v1 | Settlement | SETTLEMENT / settlementId | commerce-settlement-v1: 지급상태·알림 |
| discovery.analysis.v1 | Discovery | PRODUCT_ANALYSIS / productId | commerce-analysis-v1: 검토용 분석 projection |

partition=6, local replication1, 공유 HA환경 replication3/minISR2, acks=all. 상품/주문/금융 aggregate를 같은 숫자 version으로 서로 비교하지 않습니다. 한 topic의 여러 eventType은 같은 stream sequence를 공유합니다. 예를 들어 금융 seq1 hold, seq2 purchase, seq3 release는 셋 모두 반영/승인된 no-op 후에만 checkpoint=3입니다.

`SellerSettlementHoldChanged`: orderId가 있으면 ORDER_SELLER, 없거나 null이면 SELLER_CONTROL. `SellerPenaltyApplied`는 SELLER_CONTROL. 나머지 financial 사건은 ORDER_SELLER이며 priorFinancialVersion은 aggregateVersion-1입니다. seller barrier에는 두 종류 stream을 모두 포함합니다.

## 필드 의미와 서비스 간 동일 식별

- `amount`는 `{currency:'KRW',amount:integer}` Money입니다. `paidAmount`, `totalAmount`, `signedRevenueAmount`, `price`처럼 명시된 수치 필드는 KRW integer입니다. Settlement 집계/hold Money는 JS safe integer, 주문·환불 Money는 최대100,000,000원입니다. 부호 있는 원장은 signed 필드로만 표현합니다.
- 단위 ID는 `orderItemId:unitOrdinal`(ordinal 1~99), 원장 source ID는 `UNIT:orderItemId:unitOrdinal` 또는 `CHARGE:orderChargeId`입니다. unit 배열의 순서는 item UUID/ordinal 오름차순, 중복 금지입니다.
- recognition ID는 양 서비스가 동일하게 계산합니다. UUIDv5 namespace=`00000000-0000-4000-8000-000000000900`, name=UTF-8 `sourceEventId|sourceUnitOrChargeId`. sourceEventId는 원 PurchaseConfirmed 또는 SellerShippingRevenueRecognized의 eventId입니다. Settlement의 seller_recognition_unit.recognition_id에 이 값을 사용합니다. Commerce는 자기 outbox/confirmation 사실로 originalRecognitionId를 재현하므로 타 DB 조회가 필요 없습니다.
- 원장 source_key는 `sellerId|KRW|sourceEventId|sourceUnitOrChargeId|entryType`. eventId만 unique로 삼아 여러 unit의 매출을 한 건으로 누락하지 않습니다. commissionAmount=0이면 금액0 ledger 행을 만들지 않습니다.
- `priorFinancialVersion`은 원 recognition의 version이 아니라 **이번 사건 바로 앞 stream sequence**입니다. 다른 타입의 hold 사건이 끼었어도 그 sequence를 포함합니다.
- PaymentApproved의 items/charges와 RefundSucceeded의 배분은 [Payment OpenAPI](../../contracts/payment-service.openapi.yaml) schema의 필드 구조를 생성 시 참조해 복제하고 이벤트 object에는 additionalProperties=false를 적용합니다. 변경하면 두 계약을 함께 재생성·검증합니다.
- memberPseudonym은 서버 비밀 salt를 사용한 비가역 식별의 64hex입니다. event에 이메일/member ID/세션 원문을 복제하지 않습니다. salt 회전 시 집계 버전과 재식별 불가 정책을 함께 적용합니다.
- ProductAnalysisCompleted의 evidenceRefs는 같은 run의 근거 식별자입니다. private storage URL/파일 바이트는 실지 않습니다. revision이 다르면 현재 상품을 변경하지 않습니다.

## JSON Schema 이후 반드시 검사할 업무 불변식

| event | 추가 검증 | 위반 시 |
| --- | --- | --- |
| 전체 | topic/producer/key와 envelope 일치, aggregateId와 payload ID 일치, 같은eventId 동일hash, occurredAt 원본 유지 | quarantine, stream block |
| PaymentApproved | item 합계+charge=amount, unit 합계=item, quantity=unique ordinal 수, merchant의 order/request ID가 저장된 attempt와 일치 | 승인효과 반영 보류, 운영 사건 |
| RefundSucceeded | item refund 산식·배분합계=amount, 원 snapshot 잔액·unit 소유권·중복예약 확인 | Claim 완료/원장 차감 금지 |
| PurchaseConfirmed | unit 실제 확정, 원금/fee 원 snapshot 일치, 같은unit의 재인식 없음 | 원장 추가 금지 |
| SellerFinancialAdjusted | originalRecognitionId/source 일치, 기존 인식·누적 역전 한도, revenue<=0/fee>=0, 둘 다0 금지 | 근거 확보까지 hold |
| SellerShippingRevenueRecognized | 그룹종결·열린Claim0, 원 charge의 미환급잔액과 일치, 인식1회 | 지급원장 제외 |
| Hold/Penalty | owner scope·holdVersion·승인 근거, RELEASE/REVOKE 원 이력 참조, FEE만 양수 | 동일금액을 신규 수수료로 생성 금지 |
| SettlementPaid | receipt/key/account hash·승인·permit 일치, 금액은 실제 payout snapshot | 단순 UI 성공으로 변경 금지 |

예시는 필드와 산술을 검증할 합성 자료입니다. 서로 다른 사건 파일을 연결한 end-to-end 이력이나 실DB에 존재하는 권한/재고의 증거가 아닙니다. origin snapshot/receipt/승인 검증은 repository 통합시험이 별도로 담당합니다.

## Publisher와 consumer 알고리즘

1. 업무 transaction에서 event_stream_sequence를 lock하여 last+1을 발급하고 도메인 이력과 outbox를 commit합니다. 발행할 사건이 없는 update는 sequence를 소비하지 않습니다.
2. publisher는 PENDING/FAILED due 중 앞 sequence만 lease30초로 claim→commit→Kafka 발행→ACK 후 PUBLISHED 갱신. heartbeat10초. lease token/version이 바뀐 worker는 성공 여부를 덮어쓰지 않습니다.
3. consumer ingress는 type/schema/hash 검증, `(consumer,eventId)` inbox 저장 후 commit하고 offset을 commit합니다. 이 시점에는 실제 업무 반영이 끝나지 않았을 수 있습니다.
4. inbox worker는 stream checkpoint lock 아래 last+1만 적용합니다. 업무+PROCESSED+checkpoint를 같이 commit. seq<=last는 저장된eventId/hash와 대조, seq>last+1은 WAITING_GAP. 다른 stream은 계속 처리합니다.
5. 해당 group이 사용하지 않는 **알려진** 타입도 envelope·schema·hash 검증 후 IGNORED 이력과 checkpoint를 같은 transaction에 기록합니다. unknown type/version은 순서를 넘기지 않습니다.
6. 1초/5초/30초/2분/10분/30분, 이후30분 간격 총10회. 횟수·nextRetryAt 영속화. 스키마/인가/금액 위반은 즉시 QUARANTINED. 15분 gap/소진 시 사건과 `<topic>.<group>.dlq.v1`, 원 inbox/block은 보존합니다.

같은 ID의 byte/hash 충돌은 자동 merge하지 않습니다. 금융 payload를 DLQ에 실을 때 원 private 데이터 금지 규칙을 그대로 적용합니다. DLQ는 새로운 거래 명령이 아니며 replay도 원 ID/sequence/body를 사용합니다.

## 재처리·호환 전환·시험

- `v1`에 필드를 추가해도 strict schema의 기존 consumer는 거부할 수 있습니다. producer 단독 변경 금지. compatible reader 배포→fixture 시험→producer 전환, 의미/필수 필드 변경은 v2 topic과 병행 consumer 계획을 사용합니다.
- v1/v2를 동시에 받아 두 번 원장에 반영하지 않도록 source operation/result 또는 business source identity를 유지합니다. 새 topic이라는 이유로 eventId를 무작위 재발급하지 않습니다.
- catalog/analysis는 원본 snapshot+watermark로 새 generation 재구축 가능. 금융 stream은 임의 skip/snapshot 덮어쓰기로 회계 gap을 가리지 않습니다. [RB-02/06](06-runbooks.md)를 따릅니다.
- `build-implementation-docs.mjs --check`로 생성 차이, `verify-implementation.py`로 19종 정상 예시·의도적 오류 예시·상호 참조·업무 산술을 검증합니다. AT-09/14/15/22/27/28/30/31은 실제 DB/worker 구현 후 수행합니다.

## HTTP 보조 사건과 registry 범위

Kafka v1은 위19종입니다. WISHLIST/CART_ADD는 서버가 원 작업 성공 후 내부 행동수집 command로 전달하는 별도 계약이며 브라우저 입력에 허용하지 않습니다. Shipment/Claim 상세 알림은 원 Commerce transaction의 알림 intent 또는 정의된 ORDER event로 생성합니다. registry 밖 문자열을 임의 Kafka eventType으로 발행하지 않습니다. 내부 행동수집 및 운영 command의 보완 계약은 [화면 명세](05-screens.md#계약-보완-목록)에 명시합니다.
