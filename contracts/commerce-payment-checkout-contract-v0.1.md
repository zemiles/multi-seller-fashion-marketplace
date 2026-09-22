# Commerce–Payment Checkout 계약 v1

상태: **v1 목표 계약 확정, HTTP/영속 구현 미완료**. 기존 링크 보존을 위해 파일명 `v0.1`은 유지하며 본문의 버전이 기준입니다. [전체 요구사항](../docs/requirements/README.md), [OpenAPI 1.0](payment-service.openapi.yaml), [Payment 요구사항](../docs/requirements/03-payment-pg.md)을 함께 따릅니다.

## 책임·호출·인증

Commerce가 회원/판매자 소유권·판매 가능·가격·배송비·재고·Claim 수량을 검증합니다. Payment는 snapshot 합계·중복·만료·외부 금융 효과를 검증합니다. 타 서비스 DB를 조회하거나 상대 서비스를 대신해 주문/재고를 변경하지 않습니다.

브라우저는 Commerce의 `/api/v1/orders/{id}/payment`만 호출합니다. Commerce→Payment는 `/internal/v1/payment-attempts`, `/{id}/approve`와 조회/환불/취소/close-order API를 사용합니다. RS256 서비스 JWT, Commerce issuer/sub, payment-service audience, TTL60초 및 기능별 scope 검증. Idempotency-Key는 인증 수단이 아닙니다.

PG1=KAKAO, PG2=NAVER, paymentMethod=SIMULATED. 실제 PG SDK/카드/redirect는 사용하지 않습니다.

## 불변 CheckoutPaymentSnapshot

prepare 본문은 아래 필드를 포함하며 OpenAPI와 일치해야 합니다. 현재 내부 PreparePayment record는 이를 아직 표현하지 못하므로 그대로 Controller DTO에 사용하지 않습니다.

| 필드 | 필수 규칙 |
| --- | --- |
| checkoutId,checkoutRevision | UUID, revision>=1. 새 quote는 새 checkout |
| orderId,memberId | Commerce가 commit한 PENDING_PAYMENT 주문과 소유 회원 UUID |
| paymentRequestId | Commerce가 생성·영속한 logical attempt UUID |
| pricingPolicyVersion | 주문 당시 정책 버전 문자열 |
| provider,paymentMethod | KAKAO 또는 NAVER / SIMULATED |
| merchantTxId | `mp-{orderId}-{paymentRequestId}`, UUID는 소문자 하이픈 표준 형식 |
| amount | `{currency:"KRW",amount:정수}`, 1~100,000,000 |
| expiresAt | checkout 생성+15분 UTC. 최초 dispatch 허용 기한 |
| items[] | 1~100개, orderItemId/sellerId/quantity/productAmount/discountAmount/taxAmount/paidAmount/units |
| items[].units[] | quantity개, unitOrdinal=1..quantity, productAmount/discountAmount/paidAmount/commissionAmount |
| charges[] | 유료 판매자 배송비만. orderChargeId/sellerId/chargeType=SHIPPING/amount>0, seller당최대1개 |

SKU별 quantity=1~99, 중복 orderItemId/orderChargeId/unitOrdinal 금지. items 내 동일 seller는 허용, charges seller는 items에 존재해야 합니다. seller별 배송비는 1회이며 무료 배송의 0원 charge는 전송하지 않습니다. 주소·전화·개인 문서는 Payment snapshot에 필요 없으므로 포함하지 않습니다.

금액 검증:

```text
item.productAmount - item.discountAmount + item.taxAmount = item.paidAmount
v1 taxAmount = 0
sum(unit.productAmount/discountAmount/paidAmount) = 각각 대응하는 item 금액
0 <= unit.commissionAmount <= unit.paidAmount
sum(unit.commissionAmount) = floor(item.paidAmount * 1000 / 10000)
amount.amount = sum(item.paidAmount) + sum(charge.amount)
```

모든 금액은 JSON integer, 문자열/소수 거부, 0~100,000,000 범위. 할인/수수료/수량 잔여 원 단위 배분은 [MONEY-01](../docs/requirements/02-commerce.md)을 따릅니다. Payment는 Commerce 정책을 재가격 산정하지 않고 snapshot 산술·배분의 일관성을 검증합니다. PG 승인액과 snapshot amount는 정확히 같아야 합니다.

## 정상 순서와 결과 반영

1. Commerce: snapshot 검증·재고 reservation·PENDING_PAYMENT 주문 commit.
2. Commerce: order lock 하에 payment dispatch-intent와 paymentRequestId/provider/key 저장 후 commit.
3. Payment prepare: request hash와 order guard 검사, CREATED/snapshot/key 영속화.
4. Payment approve: expiresAt/order guard 재검증, REQUESTED operation·복구 자료 commit 후 PG HTTP 호출.
5. Payment: 승인·SALE 거래·배분·PaymentApproved outbox 원자적 저장.
6. Commerce: 동기 확인 또는 이벤트를 동일 applyPaymentResult로 반영, 예약 소비·PAID·OrderPaid outbox 원자적 저장.
7. 고객: Commerce PAID까지 완료되면200, 아니면202와 attemptId/statusUrl/simulated=true. GET 조회는 새 승인 호출을 하지 않음.

동기 결과와 이벤트의 dedup identity는 `operationId,resultVersion`. 따라서 성공 Payment/Refund 응답에도 resultVersion과 operationId를 포함해야 합니다. 이벤트 전송이 먼저 도착하거나 응답이 먼저 도착해도 재고 소비·Claim 완료는 한 번입니다. 재조회로 반환한 사실도 같은 처리키를 사용합니다.

## 멱등성·만료·보상

- prepare key=`prepare:{paymentRequestId}`, approve key=`approve:{paymentRequestId}`. 같은 provider/key는 전체 검증 snapshot·merchant·method hash가 같아야 함. 같은 key는 같은 resource의 현재 상태, 변경 내용409.
- provider+merchantTxId unique 외에 order guard로 provider 전환/성공 후 재결제 차단. VOID/전액환불 이후에도 같은 order로 새 결제 금지.
- CREATED 상태 최초 dispatch는 expiresAt 이전만. 이미 REQUESTED/PENDING/UNKNOWN인 operation은 새 key 없이 복구하며 만료 후에도 결과 확인/같은 모의 PG operation replay 가능.
- 만료·고객 취소에는 [ORD-05](../docs/requirements/02-commerce.md)의 close-order handshake. Payment가 CLOSED_NO_EFFECT를 확정하기 전에는 통신실패/404/시간초과만으로 예약 해제 금지.
- UNKNOWN15분 incident,24시간 자동 write 복구 중단/수동 사건. 재고/금액 hold는 효과 없음 또는 보상 완료가 확인될 때까지 유지.
- 승인됐지만 예약 소비 불가능/취소 의도 존재하면 출고 차단→void 또는 refund 보상→완료 후 주문 CANCELLED. 돈이 빠져나갔을 수 있는데 주문을 단순 실패/재결제 가능으로 만들지 않음.

## 환불·정산 연계

Commerce는 claimId/compensationId, 원 unit/charge 배분, actor, reason을 확정하고 Payment refund/cancel을 호출합니다. Payment는 남은 금액·수량·진행 operation을 잠금 검증한 뒤 PG 호출 전 금액을 예약합니다. UNKNOWN은 환불 예약을 유지합니다.

RefundSucceeded를 Commerce가 Claim 완료와 판매자 재무 조정으로 변환합니다. Settlement는 PurchaseConfirmed/SellerShippingRevenueRecognized/SellerFinancialAdjusted로 원장을 생성하며 원시 RefundSucceeded를 또 차감하지 않습니다. PaymentApproved만으로 지급 가능한 매출을 만들지 않습니다.

## 고정된 사항과 변경 방식

인증, merchant 발급, KRW/금액 직렬화, 15분 만료, UNKNOWN 처리, 쿠폰/포인트 제외, 동기조회+이벤트 반영은 v1로 결정되었습니다. 새 사업 정책이 필요하면 [결정 목록](../docs/requirements/README.md)을 버전 변경하고 이 계약·OpenAPI·AT 테스트를 함께 바꿉니다. 아직 없는 코드 때문에 요구사항을 다시 미정으로 되돌리지 않습니다.
