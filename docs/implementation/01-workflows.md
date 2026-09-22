# 01. 업무 흐름·상태 전이 상세 설계

기준: [요구사항](../requirements/README.md), [HTTP 계약](../api/README.md). 아래 UC와 TX는 구현·로그·테스트에서 재사용할 식별자입니다. transaction 사이에는 프로세스가 죽을 수 있다고 가정합니다. 모든 시각 비교는 주입 Clock/DB UTC Instant, 금액은 원 단위 정수입니다.

## 공통 command 처리와 lock 규칙

1. 세션/서비스 인증 → 최신 역할·소유권 → DTO 타입·정규화 → request hash 순서로 검증합니다. 중복 요청도 권한 검사를 생략하지 않습니다.
2. `(principal,operation,targetId,key)`를 unique로 확보합니다. 같은 hash면 기존 resource/current 상태를 반환하고 다른 hash면 IDEMPOTENCY_CONFLICT. unique 충돌로 실패한 transaction 안에서 계속 조회하지 말고 rollback 후 재조회합니다.
3. 필요한 행을 아래 순서로 lock하고 expectedVersion 및 업무 조건을 재검증합니다. lookup만 한 행은 lock 획득 후 상태가 바뀌었을 수 있습니다.
4. 업무·이력·멱등 결과·outbox·sequence를 한 transaction에서 commit합니다. 외부 호출은 commit 이후입니다. rollback된 변경에는 이벤트가 없어야 합니다.
5. deadlock/serialization failure만 최대3회, 50/150/450ms+jitter로 **로컬 transaction**을 재실행합니다. key와 DTO는 고정. PG 호출은 이 retry 범위에 포함하지 않습니다. 소진 시 영속 접수 전에는503, 접수 후에는202와 조회 ID를 돌려줍니다.

| DB | 잠금 순서(존재하는 단계만, 같은 종류는 UUID/복합키 오름차순) |
| --- | --- |
| Commerce 공통 전처리 | command_idempotency → 필요 시 consumer_stream_checkpoint/inbox → member/seller membership 또는 admin 권한/approval 행 |
| Commerce 주문·재무 | seller_financial_state(sellerId 순) → checkout → orders → order_shipping_group → order_item → order_item_unit → shipment/shipment_item → claim/claim_item → purchase_confirmation_state/hold → inventory(skuId 순) → reservation 및 기타 자식 → event_stream_sequence |
| Commerce 지급 fence | seller_financial_state → payout_fence; 주문 행은 잠그지 않음. account 변경도 seller_financial_state를 먼저 잠금 |
| Payment | consumer checkpoint/webhook inbox(해당할 때) → order_payment_guard → payment_attempt → payment → refund → payment_operation/result → allocation → event_stream_sequence |
| Settlement | consumer checkpoint/inbox(해당할 때) → seller/currency 직렬화 mutex → settlement → ledger/recognition(source ID 순) → allocation/hold/carry-forward → payout_attempt → event_stream_sequence |
| PG | merchant 생성 unique 경합 또는 pg_payment lock → pg_transaction → pg_webhook_outbox |
| Discovery | consumer checkpoint/inbox → generation → product projection/product analysis → event_stream_sequence |

Settlement의 seller/currency mutex는 별도 DB 연결 없이 transaction-level advisory lock을 사용합니다. UTF-8 `settlement:seller:{소문자 seller UUID}:KRW`의 SHA-256 앞 8바이트를 big-endian signed 64bit 정수로 해석한 key를 사용합니다. 모든 원장·정산·지급 로컬 writer가 같은 함수와 회귀 fixture를 사용합니다. hash 충돌은 직렬화만 증가시키며 정합성을 해치지 않습니다. 지급 영수증 저장은 모의 은행 adapter가 별도 transaction으로 처리합니다.

job은 후보 ID만 먼저 찾습니다. `FOR UPDATE SKIP LOCKED`로 자식부터 잠근 채 위 부모 lock을 나중에 획득하지 않습니다. lease 확보 transaction을 commit한 뒤, 업무 transaction에서 정해진 순서로 lock하고 lease token/version을 다시 확인합니다. 만료 worker의 결과는 정상 상태를 되돌릴 수 없습니다.

여러 판매자 주문에서 재무 상태를 건드릴 수 있는 command는 seller ID 목록을 snapshot에서 읽고 전체를 정렬해 먼저 lock합니다. 순환 의존을 만드는 새 writer는 위 순서를 확장하고 경합 시험을 추가해야 합니다.

## UC-01 회원·판매자·상품

| 작업 | transaction·결과 | 충돌/실패 처리 |
| --- | --- | --- |
| 가입/검증 | normalized email unique, PASSWORD credential은 member_auth_identity, token hash/expiry 저장. 검증 token 소비와 emailVerified 갱신 원자적 | 동일 이메일 신규 가입 충돌, token replay는 추가 효과 없음. 모의 메일함은 테스트 운영자만 조회 |
| 로그인/비밀번호 변경 | credential 검증 후 Redis session 발급/회전. password/sessionVersion DB commit 후 옛 sessionVersion 요청 거부 | Redis 장애503, DB version과 안 맞는 캐시 세션은 폐기. raw credential/event 발행 금지 |
| 주소/팀 | member 또는 seller lock, 기본주소 한 개/마지막 OWNER 불변식 검증 후 version 증가 | VERSION_CONFLICT는 최신 조회 후 새 사용자 의도로 재시도 |
| 계좌 변경/관리자 승인 | actor와 승인자 분리, payload hash 고정, seller_financial_state version 증가, 이전 계좌 비활성화 | 이전에 고정된 지급 snapshot 변경 없음. 권한 회수/만료/다른 hash 승인은 실행 거부 |
| 상품 게시 | immutable revision 검수→publish, current_revision 교체와 ProductRevisionPublished outbox commit | 분석 결과·오래된 검수의 revision이 다르면 게시 거부. 기존 게시본 보존 |
| 재고 조정 | inventory lock, onHand/reserved/safetyStock 검사, ledger append | 예약 아래로 줄이는 입력422, 음수 available 불가 |

## UC-02 Checkout → 주문 → 결제

| 단계 | owner/TX | lock 안에서 확정할 내용 | commit 후 동작 |
| --- | --- | --- | --- |
| quote·예약 | Commerce C1 | 회원별 미주문 checkout<=3, seller 판매 가능, SKU가격/주소 snapshot, 전체SKU available, RESERVED·15분expiry | checkoutId/revision 반환. 부분 예약 없음 |
| 주문 생성 | Commerce C2 | checkout 소유/revision/expiry, checkoutId unique, Order PENDING_PAYMENT와 item/unit/charge snapshot, cart 포함 수량만 차감 | orderId 반환, PG 효과 없음 |
| 결제 의도 | Commerce C3 | order 유효·미종결 시도 없음, paymentRequestId/merchant/provider/hash를 payment_dispatch_intent에 저장 | 동일 prepare key로 Payment 호출 |
| prepare | Payment P1 | order guard OPEN·성공 이력 없음·유효snapshot → CREATED attempt | 동일 attemptId 반환. PG 호출 없음 |
| dispatch 접수 | Payment P2 | gate/expiry 재확인, REQUESTED operation·payload·key·lease/version 저장 | transaction 밖에서 PG approve |
| PG 승인 | PG G1 | merchant unique, 요청 금액/currency 일치, 결제·APPROVE 거래·목표 webhook outbox 저장 | 같은 merchant 재요청은 같은 효과 |
| 결과 저장 | Payment P3 | receipt/요청/merchant/금액 일치, immutable resultVersion, APPROVED payment·SALE·배분·PaymentApproved outbox | 동기 응답과 event에 동일 operationId/resultVersion |
| 주문 반영 | Commerce C4 | 중복 결과키 검사, seller/order→unit→inventory→reservation, ACTIVE 예약 1회 소비, onHand/reserved 감소, PAID·OrderPaid | 여기까지 commit되어야 고객 성공 표시 |

Checkout item ID는 주문 전 quote 식별자이며 orderItemId는 C2에서 매핑·영속화합니다. C3부터 Payment에 보내는 item은 반드시 orderItemId를 사용합니다. 동기 응답·Kafka·poll이 C4의 단일 처리 함수를 공유하고 `(sourceOperationId,resultVersion)`를 처리키로 사용합니다. 적용 이력은 영속 inbox/command 결과에 남깁니다.

P3 commit 후 C4 실패는 PG를 다시 승인할 사유가 아닙니다. retry 가능한 DB 장애는 같은 결과로 C4 재실행. 예약 파손/판매 금지로 이행 불가가 확정되면 recoveryStatus=COMPENSATING, 출고 차단, 전액 VOID/REFUND intent를 영속화합니다. 보상 완료 전에 CANCELLED로 종결하거나 재고를 해제하지 않습니다.

## UC-03 만료·취소 경합

| 경합 시점 | winner | loser/후속 처리 |
| --- | --- | --- |
| C3 이전 만료 vs 결제 시작 | Commerce order/checkout lock 아래 gate를 닫은 worker | 후발 결제410. dispatch-intent가 없음을 확인한 경우만 예약 해제 |
| C3 이후 close vs prepare | Payment guard를 닫은 close | 아직 attempt가 없어도 CLOSED tombstone 생성. 후발 prepare/approve 차단 |
| P2 commit vs close | dispatch가 먼저 commit | close=IN_FLIGHT, 예약 ACTIVE+recoveryHold. 동일 operation만 복구 |
| 승인 저장 후 close | PAYMENT_EXISTS | Commerce 취소 의도 유지, 보상 완료까지 출고 차단 |
| close 응답 유실 | 판단 불명 | 같은 close key로 재호출/상태조회. 404·timeout·15분 경과만으로 해제 없음 |
| CLOSED_NO_EFFECT 확인 vs 재고 해제 | Commerce C5 | order/reservation terminal 여부 재검증 후 reserved만 1회 반환 |

만료 시각 이후에는 새 dispatch를 받지 않습니다. 이미 P2가 commit된 작업은 만료 후에도 원 key로 복구할 수 있습니다. 성공한 주문은 전액 취소/환불 후에도 guard의 successful_payment_id를 비우지 않습니다.

## UC-04 결제 상태와 immutable 결과

| 객체 | 허용 전이 | 전제 |
| --- | --- | --- |
| attempt | CREATED→REQUESTED 또는 CANCELLED | 각각 dispatch 접수 또는 미dispatch close |
| attempt | REQUESTED→PENDING/UNKNOWN/SUCCEEDED/FAILED | PENDING은 PG가 명시한 접수, FAILED는 확정 no-effect 증거 |
| operation | REQUESTED→PROCESSING→PENDING/UNKNOWN/SUCCEEDED/FAILED | PG 호출 전에 PROCESSING/lease를 commit. 동일 payment의 앞 UNKNOWN이 있으면 REQUESTED에서 대기 |
| attempt/operation | PENDING/UNKNOWN→SUCCEEDED/FAILED | receipt·검증된 동일 요청 복구·no-effect 증거 |
| payment | APPROVED→VOIDED | 전액·출고 전·이전 환불0·대기 refund0 |
| payment | APPROVED→PARTIALLY_REFUNDED→REFUNDED | 성공 환불 누적에 의해 결정. 배송비 잔액이 있으면 PARTIALLY_REFUNDED 유지 |
| refund | REQUESTED→PROCESSING→UNKNOWN/SUCCEEDED/FAILED | UNKNOWN도 예약액에 포함, 성공 terminal 불변 |
| order | PENDING_PAYMENT→PAID/PAYMENT_FAILED/CANCELLED | 예약소비 완료/확정no-effect/종료 handshake 또는 보상 완료 |

attempt에는 PROCESSING 상태를 추가하지 않습니다. operation이 PROCESSING인 승인 attempt는 REQUESTED로 표시합니다. 환불 operation이 명시적 PG PENDING이면 Refund는 PROCESSING을 유지하고, 결과 불명이면 둘 다 UNKNOWN입니다. P2에서 승인 dispatch 의도를 commit한 뒤 실제 전송 전 중단돼도 close는 IN_FLIGHT로 취급하며 동일 operation 복구만 허용합니다.

동일 operation의 불명 상태와 확정 결과가 바뀔 때 resultVersion은 단조 증가합니다. 확정 사실은 append-only 결과로 보존하며 최신 payment snapshot과 분리합니다. 더 낮은 version은 재반영하지 않고, 같은 version의 다른 evidenceHash는 격리합니다. 성공 후 늦은 실패는 무시하되 모순 증거를 사건으로 남깁니다.

## UC-05 Claim → VOID/부분환불

1. Commerce seller financial→order/group/item/unit→shipment→claim→confirmation hold lock으로 소유권·배송·168h·수량을 검사합니다. 같은 unit의 active_unit_claim_guard를 확보하고 Claim/hold/ClaimStatusChanged를 commit합니다. 환불 예정액은 원 unit과 charge snapshot으로만 계산합니다.
2. 미결제 취소는 UC-03. 이미 승인된 전액 출고전 취소는 VOID 가능 조건을 검사합니다. 그 외는 RefundRequest입니다. Claim에 요청키와 operation/refund 연결 의도를 저장한 뒤 외부 호출합니다.
3. Payment payment lock 아래 `승인-성공환불-성공VOID-진행환불예약`을 검사하고 배분·REQUESTED를 저장합니다. 같은 unit/charge에 이미 예약/성공한 액수를 다시 쓰지 않습니다.
4. payment당 한 worker만 dispatch합니다. 앞 UNKNOWN이 있으면 뒤 operation은 대기합니다. lease 만료는 새 요청을 허용하지 않고 같은 operation만 회수합니다.
5. 성공 시 Refund/REFUND transaction/payment 누적/outbox/result를 commit합니다. 실패가 확정되면 해당 예약만 해제, UNKNOWN은 유지합니다.
6. Commerce가 성공을 반영하면서 Claim unit·charge 누적을 갱신합니다. 수익 인식 이력이 있는 unit/charge만 SellerFinancialAdjusted 생성, 미확정 unit에는 Settlement 매출 역전이 없습니다.

VOID 결과는 voidedAmount=원금, refundedAmount=0입니다. 환불 성공과 물류 입고는 서로 다른 사실입니다. 출고전 취소는 배정재고 1회 반환, 배송후 반품은 검수에서 재판매 가능으로 인정된 수량만 inventory_ledger에 입고합니다.

| Claim 상태 | 가능한 다음 상태/행동 | 금지 |
| --- | --- | --- |
| REQUESTED/UNDER_REVIEW | APPROVED/REJECTED, 효과 전 CANCELLED | 사유 없이 자동 거절 |
| APPROVED | CANCEL은 REFUND_PENDING 또는 미결제 COMPLETED; RETURN/EXCHANGE는 PICKUP_PENDING | 이미 인계된 unit을 출고전 취소로 변경 |
| PICKUP_PENDING→IN_TRANSIT→RECEIVED→INSPECTING | 회수·검수 증거를 append | 검수 없이 자동 재입고 |
| INSPECTING | 승인 unit REFUND_PENDING, 거절 unit 사유/후속 처리, 교환 replacement 처리 | 거절 unit까지 환불 |
| REFUND_PENDING | 성공 후 COMPLETED, 확정실패 후 UNDER_REVIEW | UNKNOWN 상태 철회/새 환불key |
| COMPLETED/REJECTED/CANCELLED | 이력 보존; 필요하면 새 연결 Claim | 기존 성공을 덮어쓰기 |

사유 변경·회수 이벤트·교환 대체품 동의 등 보조 command는 [화면 계약 보완](05-screens.md#계약-보완-목록)을 따릅니다.

## UC-06 배송·확정·교환

- 출고 생성은 PAID/PROCESSING, 자기 seller·미취소·무hold unit만 READY로 배정합니다. 같은 generation에서 active outbound 중복 금지. handover와 CANCEL은 동일 order item/unit lock에서 하나만 성공합니다.
- READY→HANDED_OVER→IN_TRANSIT→DELIVERED. 이벤트는 `(carrier,eventId)` 중복 검사, 배송 sequence 역행은 이력만 보존하고 상태를 되돌리지 않습니다. LOST/FAILED는 지원 Claim을 통해 처리합니다.
- 구매확정은 DELIVERED+hold 없음인 미확정 unit을 ordinal 순으로 선택합니다. 자동확정은 deliveredAt+192h 이후. confirmation unit/event/PurchaseConfirmed는 원자적입니다. Claim이 lock을 먼저 얻으면 해당 unit hold, 확정이 먼저면 일반 Claim ALREADY_CONFIRMED.
- 교환은 원 결제 unit에 fulfillment_generation+1을 연결합니다. 대체 SKU는 동일 product/seller/실결제 단가, 재교환은 금지. 검수/회수 대기 예약 최대7일, 출고 시에만 대체 inventory의 onHand/reserved를 소비합니다.
- 대체품 미출고 만료는 예약 해제→연결 RETURN/환불 전환. 이미 출고된 대체품을 만료로 해제하지 않습니다. 재배송완료 시 confirmation 시각 재계산, 원 결제 unit을 새 매출 unit으로 복제하지 않습니다.

## UC-07 원장·정산·지급

| 단계 | owner/원자적 쓰기 | 장애 후 재개 기준 |
| --- | --- | --- |
| 금융 event 소비 | Settlement inbox/checkpoint + seller mutex + recognition/ledger + processed commit | 같은 event/unit/type unique, priorFinancialVersion=직전 ORDER_SELLER sequence |
| 정산 계산 | seller/currency mutex, 미배분 원장 cutoff, allocation/CALCULATED/carry-forward 저장 | 동일 seller:currency:businessDate:policyVersion 재실행은 같은 계산 |
| 2인 승인 | Commerce actionId/target/hash/version/expiry 고정, 다른 FINANCE가 승인 | 권한 변경·payload 변경은 새 승인, 원 요청자 자기 승인 금지 |
| 지급 준비 | Settlement 고정 amount/account/key·REQUESTED attempt commit | 아직 외부효과 없는 준비 상태도 영속 조회 가능 |
| barrier/fence | Commerce seller lock, stream watermark·hold·accountVersion 검증, 30초 fence 발급 | 미달이면 대기. 만료 unconsumed fence는 같은 attempt의 새 fenceVersion |
| permit 소비 | Commerce seller lock, fenceId/version/operationHash 동일 → durable permit 1회 | 응답 유실은 동일 consume replay, 새 지급key 없음 |
| 모의 은행 호출 | transaction 밖에서 adapter, bank key/hash/receipt는 독립 transaction | commit-then-timeout을 같은 key receipt 조회로 복구 |
| 지급 확정 | Settlement attempt SUCCEEDED/settlement PAID/outbox 원자적 | 동기/복구 중복에도 SettlementPaid와 지급효과 1회 |

fence 발급 뒤 새 Claim은 수락하고 postFenceAdjustment로 기록합니다. permit consume 성공이면 지급후 조정, consume 전에 만료되어 재획득하면 신규 hold가 barrier를 막습니다. consume된 permit의 동일 operation 복구는 fence TTL 경과만으로 실패 처리하지 않습니다. TTL은 **미소비 허가의 신규 소비**를 막는 기준입니다.

UNKNOWN payout은 PAYOUT_PENDING settlement에 남고 새 revision 지급을 금지합니다. no-effect FAILED 영수증이 확인된 경우만 재계산/새 승인/새 payoutRevision 허용. 지급 후 환불은 기존 매출과 fee 역전, 다음 정산 음수이월이며 다른 seller 수익과 상계하지 않습니다.

## UC-08 검색·리뷰·알림

| 기능 | 쓰기 경계 | 지연/중복 처리 |
| --- | --- | --- |
| 검색 projection | Discovery inbox+sourceVersion+generation row | tombstone/현재revision 검증, old event 역행 금지, 새 generation 검증 후 원자적 ACTIVE 교체 |
| 분석 | product/revision/taxonomy/model/prompt 고정 run, 결과·근거·ProductAnalysisCompleted | 오래된 revision 결과는 이력만, 현재 상품 자동변경 없음 |
| 리뷰 | Commerce 구매자격 lock, orderItem당 리뷰1개, revision append | 반품 사실 표시, 원 구매후기 자동삭제 금지 |
| 알림 | sourceEvent+수신자+templateVersion unique | 알림실패는 원 거래 rollback 사유 아님, 원 event 재처리도 중복 없음 |

## 구현 시 남길 검증 증거

UC-02/03: AT-04~09/16, UC-05: AT-11~14/17/20, UC-06: AT-18~21, UC-07: AT-22~27/32, UC-08: AT-28/31. 각 경합은 서로 다른 DB 연결/HTTP 인스턴스로 수행하고 P2/G1/P3/C4/permit/bank commit 직후 crash 위치를 기록합니다. 성공 건수뿐 아니라 reserved/잔액/원장/stream sequence와 실패 요청의 효과0을 확인합니다. 상세 연결은 [추적표](04-traceability.md)에서 관리합니다.
