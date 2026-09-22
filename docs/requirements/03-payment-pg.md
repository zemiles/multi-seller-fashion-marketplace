# 03. PG1/PG2 연결·결제·취소·환불·복구

## PG-01 연결 대상과 실제 지원 범위

사용자가 말한 현재 두 PG를 다음처럼 매핑합니다. 새 외부 PG 계약이나 실제 카카오/네이버 API를 전제로 개발하지 않습니다. provider ID를 바꾸거나 디렉터리를 rename하지 않습니다.

| 화면 이름 | provider | 기존 모듈 | host 개발 URL | Compose 내부 URL |
| --- | --- | --- | --- | --- |
| PG1 (모의 결제) | KAKAO | pg-kakao-simulator | http://localhost:8090 | http://pg-kakao-simulator:8090 |
| PG2 (모의 결제) | NAVER | pg-naver-simulator | http://localhost:8091 | http://pg-naver-simulator:8091 |

현재 두 PG는 동일 구조의 독립 API/DB입니다. `POST /pg/v1/payments/approve`, `POST /payments/{paymentId}/cancel`, `POST /payments/{paymentId}/refund`, `GET /payments/{paymentId}`가 구현되어 있습니다(뒤 세 경로도 `/pg/v1` prefix). 인증/웹훅/거래 목록/merchant 조회는 **아직 없습니다**. 개발·통합 실행은 영속 PostgreSQL을 사용합니다. H2 메모리 local 재시작으로 PG 기록이 사라지는 상태는 복구 테스트 환경이 아닙니다.

Payment 내부 provider adapter 2개가 같은 port를 구현합니다. base URL은 서버 설정 allowlist, 요청 본문의 임의 URL 금지. 브라우저 SDK·카드번호·redirect·외부 PG 가맹점 가입은 필요 없습니다. paymentMethod는 `SIMULATED`; 선택한 provider는 attempt에 고정. PG1 장애 때 PG2로 자동 failover하지 않습니다.

현재 응답=`paymentId,merchantTxId,currency,amount,status,refundedAmount`. Payment 응답의 `providerPaymentKey`는 PG paymentId 문자열. 현재 PG 승인 멱등 기준은 merchantTxId이고, refund/cancel은 `(paymentId,type,idempotencyKey)`입니다. 같은 승인 key라도 merchant가 다르면 PG는 별도 승인하므로 Payment가 주문 guard를 책임집니다.

## PAY-01 prepare와 주문 guard

Commerce만 prepare/approve/refund/cancel을 호출합니다. [공통 인증](01-security-api.md)과 [Checkout 계약](../../contracts/commerce-payment-checkout-contract-v0.1.md)을 적용합니다.

1. Commerce가 orderId와 별개의 paymentRequestId(UUID)를 생성·영속화. `merchantTxId=mp-{orderId}-{paymentRequestId}`, provider와 무관하게 동일 logical attempt에 고정. prepare key=`prepare:{paymentRequestId}`, approve key=`approve:{paymentRequestId}`. Payment DB에도 `(provider,merchantTxId)` unique.
2. 검증: provider 허용, KRW, 1~100,000,000원, snapshot 유효기간, items/charges 합계·소유 seller·수량·중복 ID·unit 배분, 인증된 Commerce, 전체 request hash.
3. `order_payment_guard(order_id PK, gate, active_attempt_id, successful_payment_id, version)`를 insert-or-lock. prepare/approve/close-order/실패 확정 모두 이 guard 사용. 행이 없을 때의 동시 insert unique 충돌도 실패 transaction 밖에서 재조회.
4. gate OPEN, 진행 attempt 없음, successful_payment_id 없음일 때만 CREATED. 미해결 시도나 한 번의 성공이 있으면 다른 provider/key도 409 ORDER_PAYMENT_BLOCKED. 전액 환불/void 후에도 같은 주문은 재결제 금지, 새 주문 필요.
5. snapshot 및 정책/배분은 불변 저장. prepare만으로 PG 호출 안 함. 동일 key/hash는 같은 attempt 반환; 다른 내용은 409. 만료 후라도 이미 만들어진 같은 key의 조회성 replay는 허용, 새로운 prepare는 410.

## PAY-02 승인 실행과 상태 전이

| from → to | 조건/동작 |
| --- | --- |
| CREATED → REQUESTED | gate와 expiresAt 검사, PG operation/요청 hash·key·lease 저장 후 commit |
| CREATED → CANCELLED | close-order가 dispatch 전에 승리. PG 호출 금지 |
| REQUESTED → SUCCEEDED | 유효한 승인 증거, Payment/SALE transaction/배분/outbox 원자적 저장 |
| REQUESTED → FAILED | PG 효과가 없다는 확정적 거절 증거. 단순 timeout·5xx·응답파싱 오류는 불가 |
| REQUESTED → PENDING | 작업이 접수됐으나 비동기 완료 대기(확장 PG의 명시 응답만) |
| REQUESTED/PENDING → UNKNOWN | 전달/commit/결과를 확정할 수 없음 |
| PENDING/UNKNOWN → SUCCEEDED/FAILED | 조회/같은 operation replay/webhook 검증으로 확정 |

외부 호출은 transaction 밖에서 connect timeout 2초/read timeout 5초. 자동 HTTP write retry는 끄고 영속 recovery worker만 실행. 2xx라도 merchant/currency/amount/providerPaymentKey/status가 맞지 않으면 UNKNOWN+대사 사건, 성공 처리 금지. 이미 성공한 상태를 늦은 FAILED로 덮어쓰지 않습니다.

유효한 성공은 attempt SUCCEEDED, Payment APPROVED, SALE 거래 SUCCEEDED를 한 transaction에 기록합니다. PG APPROVE→내부 SALE, CANCEL→VOID, REFUND→REFUND. AUTHORIZE/CAPTURE/CHARGEBACK은 v1 사용하지 않습니다. PaymentApproved에는 거래/배분 snapshot과 simulated=true가 들어갑니다.

operation에는 resultVersion별 immutable 결과를 보존합니다. 동기 응답과 이벤트는 같은 operationId/resultVersion의 사실입니다. 최신 Payment 조회는 후속 환불을 포함할 수 있으므로 과거 승인 사실 재적용에는 `GET /internal/v1/payment-operations/{id}`의 immutableResult(payment/refund/receipt 또는 noEffectEvidenceId)를 사용합니다. SUCCEEDED 승인/취소는 payment+receipt, 성공 환불은 refund+payment+receipt, FAILED/CANCELLED no-effect는 noEffectEvidenceId가 필수이며 세부 증거가 없는 상태를 확정 상태로 반환하지 않습니다.

승인 replay가 PG의 최신 CANCELLED/REFUNDED snapshot을 반환할 수 있습니다. 이를 신규 APPROVED 증거로 바로 사용하지 말고 개별 PG transaction 조회로 원 승인과 후속 거래를 복원합니다. 모순·외부 직접 조작 발견 시 quarantine하여 출고 차단. 현존 4개 경로만 연결하는 초기 단계에서는 이런 경우 수동 확인 상태를 유지해야 합니다.

## PAY-03 close-order handshake

목표 내부 API: POST `/internal/v1/order-payment-guards/{orderId}/close`, body `{reason:EXPIRED|CUSTOMER_CANCELLED|COMPENSATION,actorType,actorId?}`, 멱등 key 필수. Payment는 order guard를 생성/lock 후 gate를 CLOSED로 고정합니다.

- 미dispatch CREATED는 CANCELLED, 신규 prepare/approve 차단. 응답 `{orderId,outcome:"CLOSED_NO_EFFECT",guardVersion}`.
- REQUESTED/PENDING/UNKNOWN이면 `{outcome:"IN_FLIGHT",attemptId,status,guardVersion}`. 새 작업은 막되 기존 worker의 같은 operation 복구는 허용.
- 이미 승인됐으면 `{outcome:"PAYMENT_EXISTS",paymentId,guardVersion}`. Commerce는 배송 차단·보상 유스케이스 진행.
- 200으로 동일 결과 조회, 진행 중 202 가능. CLOSE는 주문의 미래 결제도 막는 tombstone이므로 금융/주문 이력 기간 동안 삭제하지 않음. PG 효과가 불명확한 채 CLOSED_NO_EFFECT를 반환하면 안 됨.

## PAY-04 취소·환불과 배분

고객 요청은 Commerce Claim의 수량/정책 검증을 거칩니다. Payment에 고객이 원하는 임의 환불액을 직접 제출하지 않습니다. 지원 관리자의 예외도 Commerce의 승인된 adjustmentId를 참조합니다.

- 전액·출고 전·기존 환불 없음·다른 진행 금융 operation 없음이면 PG cancel 사용. Payment VOIDED, VOID 거래 성공, refundedAmount=0, voidedAmount=원 승인액. 환불 누적과 void를 중복 계산하지 않음.
- 일부 취소, 반품, 기존 부분 환불이 있는 전액 잔액 반환은 PG refund 사용. APPROVED→PARTIALLY_REFUNDED→REFUNDED. cancelled 요청과 refund는 같은 payment guard/operation queue에서 경합 제어.
- 환불 요청 필수: paymentId,claimId 또는 compensationId, amount, reasonCode, actor, `items[{orderItemId,unitOrdinals,productRefundAmount,discountReversalAmount,taxRefundAmount,refundAmount}]`, `charges[{orderChargeId,amount}]`. unit/charge 배분 합계=요청액; 이미 환불된 수량/금액 재사용 불가.
- reasonCode enum: CUSTOMER_CANCEL, BUYER_RETURN, SELLER_FAULT, LOST_SHIPMENT, EXCHANGE_UNAVAILABLE, ORDER_COMPENSATION, APPROVED_ADJUSTMENT. 자유 사유는 별도 500자 이내 텍스트, 멱등 hash에 포함.
- guard lock에서 `availableRefundable=approved-refunded-successfulVoid-pendingReservedRefunds` 검증 후 REQUESTED와 키·배분을 commit. REQUESTED/PROCESSING/UNKNOWN 모두 금액 예약. 같은 key에 변경된 수량/배분/actor/사유는 409.
- PG 실제 전송은 payment당 **한 operation씩**. queue에서 앞 UNKNOWN이 해소되기 전 후속 refund/cancel dispatch 금지. 다른 결제는 병렬 처리. lease 만료 worker의 늦은 응답도 동일 operationId/version 조건으로 한 번만 반영.
- 성공 시 Refund SUCCEEDED·REFUND 거래·배분·payment.refundedAmount·outbox 원자적 갱신. 금액 예약을 실제 누적액으로 대체. FAILED는 효과 없다는 증거 후에만 예약 해제. UNKNOWN에 새 key를 발급하지 않음.
- PG pending 결과는 HTTP202와 Refund ID/조회 URL. cancel은 operationId를 반환하며 GET `/internal/v1/payment-operations/{id}`에서 취소 UNKNOWN도 조회 가능.

현재 RefundUseCase/메모리 모델에는 unit/charge 배분과 cancel 영속 operation이 없습니다. API를 노출하기 전에 migration과 DTO를 확장해야 합니다.

## PAY-05 UNKNOWN 복구

- 최초 불명 이후 +5초,+30초,+2분,+5분,+15분, 이후 15분 간격. 재시도 횟수·nextAttemptAt를 DB 저장하고 최대 10% jitter. 24시간이면 자동 write replay를 중지하고 수동 사건, read-only 조회는 1시간 간격 유지.
- providerPaymentKey가 있으면 GET payment와 operation receipt를 확인. 없으면 merchant 조회 사용(확장 전에는 아래 제한적 승인 replay). NOT_FOUND만으로 진행 요청이 미래에 commit되지 않는다는 결론을 내리지 않음.
- 현존 두 PG의 승인: 동일 merchant/key/currency/amount replay로 한 번의 효과 보장. 이는 **이미 dispatch가 영속 기록된 operation**에 한정하며 expiresAt 이후에도 그 operation의 완료를 추적할 수 있음. 사용자 취소/만료 의도는 승인 확인 직후 void/refund로 보상; 출고는 금지.
- 현존 refund/cancel: 동일 payment/type/key/amount만 replay. PG는 최신 snapshot을 반환하므로 금액 증가만으로 임의 refund에 귀속하지 않음. 단일 writer·직렬 dispatch·저장된 누적액 baseline이 모두 확인될 때만 기대 delta를 대조. 조건 불충족 시 UNKNOWN 유지, 개별 receipt 확장 후 확인.
- refund 응답 유실 후 프로세스 재시작, 승인 성공 직후 DB 장애도 같은 operation을 복구. PG가 영속 기록을 잃은 것으로 의심되면 자동 승인 replay 중단·대사 사건. PG DB 초기화를 복구 방법으로 사용하지 않음.
- 수동 해결은 실제 PG receipt/조회 원문 hash와 2인 검토 필수. “24시간 경과”, HTTP404, 판매자 진술만으로 성공/실패 강제 수정 불가. confirmed no-effect 또는 성공+완료 보상 근거가 확보될 때만 Commerce 재고 해제.

## PG-02 기존 두 PG에 추가할 v1 완성 요구

아래는 새 PG를 도입하는 것이 아니라 현재 PG1/PG2를 똑같이 확장할 작업입니다. 초기 adapter는 기존 4개 경로로 착수 가능하지만, webhook·완전한 대사·자동 복구 완료 선언에는 확장 계약이 필요합니다.

| 목표 경로 | 입력/출력·규칙 |
| --- | --- |
| GET /pg/v1/payments/by-merchant/{merchantTxId} | 기존 PaymentResponse 또는 404. 신규 효과 없음 |
| GET /pg/v1/payments/{id}/transactions | type(APPROVE/CANCEL/REFUND),idempotencyKey 필터 → immutable receipt 목록 |
| GET /pg/v1/transactions | from(포함),to(제외),cursor,limit<=100 → receipt 목록과 nextCursor/asOf |
| 기존 write API | Payment JWT 검증, simulated=true 추가, operationId/transactionId를 선택 추가 필드로 반환; 기존 필드 의미 유지 |
| POST /pg/internal/v1/fault-scenarios | local/stage 테스트 principal만, 다음 N회 fault 종류·delay 설정; 실제 prod 요청에서는 비활성 |

receipt 필수: transactionId,paymentId,merchantTxId,transactionType,idempotencyKey,amount,currency,status,occurredAt,simulated. 한 요청 receipt 불변; snapshot과 혼동하지 않음. 승인 receipt 조회는 merchant 기준으로도 연결 가능해야 합니다. 대사 목록은 첫 페이지 asOf를 고정하고 `(occurredAt,transactionId)` cursor, 동일 파라미터에서 누락/중복 없는 페이지를 제공합니다.

PG 상태 변경·pg_transaction·webhook outbox는 같은 PG DB transaction. fault는 BEFORE_COMMIT_ERROR(no effect), AFTER_COMMIT_DROP_RESPONSE, DELAY_RESPONSE, DUPLICATE_WEBHOOK, OUT_OF_ORDER_WEBHOOK, INVALID_SIGNATURE를 지원. 테스트 설정으로 실제 거래 record 값을 손으로 변조하지 않습니다.

## PG-03 webhook 서명·재전송

Payment 수신 경로 `/internal/v1/payment-webhooks/{provider}`. 본문 JSON UTF-8 raw bytes 보존. 필수 헤더 `X-Provider-Event-Id`(UUID), `X-Provider-Timestamp`(Unix seconds), `X-Key-Id`, `X-Signature`.

서명 입력은 `timestamp + "." + eventId + "." + rawBody`의 UTF-8 byte sequence. 값은 `v1=`+HMAC-SHA256 소문자 hex. provider/환경별 독립 256bit secret, constant-time 비교, abs(now-timestamp)<=300초. key ID는 서버 allowlist만. body eventId/provider와 URL/header 일치 검증. 재시도는 같은 eventId/body를 쓰고 timestamp와 서명은 새로 생성.

본문 필수: eventId,provider,eventType(PaymentApproved/PaymentCancelled/PaymentRefunded),occurredAt,transaction receipt,payment snapshot,simulated=true. 검증 전 파싱으로 업무 변경 금지, 256KiB 초과 413. 인증 실패401, 내용 충돌409. 유효 이벤트는 `(provider,eventId)`와 body hash를 inbox에 commit한 뒤202, 같은 ID/같은 body도202. 같은 ID/다른 body409+경보. DB 장애503으로 재전송 유도.

처리는 request/receipt/금액과 대조 후 기존 결과 반영 함수 호출. webhook만으로 모르는 주문을 새로 생성하지 않음. 미연결 event는 quarantine하고 merchant mapping 복구. PG outbox delivery는 5초/30초/2분/10분/1시간, 이후 1시간 간격 24시간까지; 초과 DEAD 보관·수동 replay. Payment poll과 webhook 중 누가 먼저 와도 금융 이력 1건.

## PAY-06 PG 대사

Payment 소유. 매일 01:00 KST에 전일 `[00:00,다음00:00)` KST를 UTC로 변환하여 PG1/PG2 receipt 조회. 기준 key=`provider,transactionId`, 보조 비교=merchant/type/key/currency/amount/status. PG만 존재/내부만 존재/금액·상태 차이/중복으로 분류. 정상 합계는 승인액-VOID액-REFUND액이며 CANCELLED의 refundedAmount=0을 반영합니다.

run key=`provider,businessDate,sourceAsOf,algorithmVersion`; 원문 페이지/hash와 실행 결과 보존. 같은 run 재실행은 새 금융 효과를 만들지 않음. 지연 수신을 위해 최근 3일 매일 재비교하되 동일 discrepancy identity 유지. 확정 receipt로 미반영 operation을 복구할 수 있지만 임의 차액 승인/환불/원장 수정 금지. 불일치 열린 payment는 추가 write 차단·운영 화면 표시. PG DB 직접 SQL 조회로 서비스 경계를 우회하지 않습니다.
