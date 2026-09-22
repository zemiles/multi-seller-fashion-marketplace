# v1 이벤트 필드 사전 · 생성본

[전체 JSON Schema](marketplace-events.schema.json) · [처리/순서 규칙](../../../docs/implementation/02-event-contracts.md) · [의도적 오류 fixture](invalid-examples.json)

19종 target 계약. raw JSON schema가 중첩 필드/필수/enum/상한을 정의합니다. 각 예시는 독립 합성 payload이며 실제 거래 이력은 아닙니다. 소스는 scripts/docs/event-model.mjs입니다.

## ProductRevisionPublished

- topic: marketplace.commerce.catalog.v1
- producer: commerce-service
- aggregate: PRODUCT
- groups: discovery-catalog-v1
- effect: 검색 projection 갱신; 원본 상품 수정 없음
- [정상 예시](examples/ProductRevisionPublished.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| productId | string | 필수 | uuid |
| revisionId | string | 필수 | uuid |
| revisionNumber | integer | 필수 | min=1; max=9007199254740991 |
| sellerId | string | 필수 | uuid |
| title | string | 필수 |  |
| categoryId | string | 필수 | uuid |
| brandId | string / null | 필수 |  |
| imageUrl | string | 필수 | uri; ^https?:// |
| features | array<Feature> | 필수 | items=0..100 |
| skuSummaries | array<{skuId, price, available}> | 필수 | items=1..500 |
| publishedAt | string | 필수 | date-time; Z$ |

## ProductAvailabilityChanged

- topic: marketplace.commerce.catalog.v1
- producer: commerce-service
- aggregate: PRODUCT
- groups: discovery-catalog-v1
- effect: 검색 projection 갱신; 원본 상품 수정 없음
- [정상 예시](examples/ProductAvailabilityChanged.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| productId | string | 필수 | uuid |
| revisionId | string | 필수 | uuid |
| saleStatus | string | 필수 | enum=DRAFT/IN_REVIEW/READY/ON_SALE/PAUSED/SOLD_OUT/ARCHIVED |
| available | boolean | 필수 |  |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |

## OrderPaid

- topic: marketplace.commerce.order.v1
- producer: commerce-service
- aggregate: ORDER
- groups: commerce-notification-v1, discovery-conversion-v1
- effect: 알림; OrderPaid만 구매 전환 집계
- [정상 예시](examples/OrderPaid.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderId | string | 필수 | uuid |
| memberPseudonym | string | 필수 | ^[0-9a-f]{64}$ |
| paymentId | string | 필수 | uuid |
| totalAmount | integer | 필수 | min=1; max=100000000 |
| items | array<{productId, revisionId, quantity}> | 필수 | items=1..100 |

## ShipmentDelivered

- topic: marketplace.commerce.order.v1
- producer: commerce-service
- aggregate: ORDER
- groups: commerce-notification-v1, discovery-conversion-v1
- effect: 알림; OrderPaid만 구매 전환 집계
- [정상 예시](examples/ShipmentDelivered.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderId | string | 필수 | uuid |
| shipmentId | string | 필수 | uuid |
| items | array<{shipmentItemId, orderItemId, unitOrdinals}> | 필수 | items=1..100 |
| deliveredAt | string | 필수 | date-time; Z$ |

## ClaimStatusChanged

- topic: marketplace.commerce.order.v1
- producer: commerce-service
- aggregate: ORDER
- groups: commerce-notification-v1, discovery-conversion-v1
- effect: 알림; OrderPaid만 구매 전환 집계
- [정상 예시](examples/ClaimStatusChanged.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderId | string | 필수 | uuid |
| claimId | string | 필수 | uuid |
| status | string | 필수 | enum=REQUESTED/UNDER_REVIEW/APPROVED/REJECTED/PICKUP_PENDING/IN_TRANSIT/RECEIVED/INSPECTING/REFUND_PENDING/COMPLETED/CANCELLED |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |
| affectedUnitIds | array<string> | 필수 | items=1..9900; uniqueItems |

## PurchaseConfirmed

- topic: marketplace.commerce.seller-financial.v1
- producer: commerce-service
- aggregate: ORDER_SELLER
- groups: settlement-ledger-v1
- effect: 매출·수수료·hold·역전 원장; 지급의 입력
- [정상 예시](examples/PurchaseConfirmed.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| confirmationId | string | 필수 | uuid |
| priorFinancialVersion | integer | 필수 | min=0; max=9007199254740991 |
| units | array<RecognitionUnit> | 필수 | items=1..9900 |
| currency | string | 필수 | const=KRW |
| policyVersion | string | 필수 |  |

## SellerShippingRevenueRecognized

- topic: marketplace.commerce.seller-financial.v1
- producer: commerce-service
- aggregate: ORDER_SELLER
- groups: settlement-ledger-v1
- effect: 매출·수수료·hold·역전 원장; 지급의 입력
- [정상 예시](examples/SellerShippingRevenueRecognized.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| orderChargeId | string | 필수 | uuid |
| amount | Money | 필수 |  |
| currency | string | 필수 | const=KRW |
| priorFinancialVersion | integer | 필수 | min=0; max=9007199254740991 |

## SellerFinancialAdjusted

- topic: marketplace.commerce.seller-financial.v1
- producer: commerce-service
- aggregate: ORDER_SELLER
- groups: settlement-ledger-v1
- effect: 매출·수수료·hold·역전 원장; 지급의 입력
- [정상 예시](examples/SellerFinancialAdjusted.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| adjustmentId | string | 필수 | uuid |
| refundId | string / null | 선택 |  |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |
| priorFinancialVersion | integer | 필수 | min=0; max=9007199254740991 |
| adjustments | array<FinancialAdjustment> | 필수 | items=1..10000 |
| currency | string | 필수 | const=KRW |

## SellerSettlementHoldChanged

- topic: marketplace.commerce.seller-financial.v1
- producer: commerce-service
- aggregate: ORDER_SELLER, SELLER_CONTROL
- groups: settlement-ledger-v1
- effect: 매출·수수료·hold·역전 원장; 지급의 입력
- [정상 예시](examples/SellerSettlementHoldChanged.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| sellerId | string | 필수 | uuid |
| orderId | string / null | 선택 |  |
| holdId | string | 필수 | uuid |
| holdVersion | integer | 필수 | min=1; max=9007199254740991 |
| action | string | 필수 | enum=PLACE/RELEASE |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |
| unitIds | array<string> | 필수 | items=0..9900; uniqueItems |
| amount | {currency, amount} | 필수 |  |
| currency | string | 필수 | const=KRW |

## SellerPenaltyApplied

- topic: marketplace.commerce.seller-financial.v1
- producer: commerce-service
- aggregate: SELLER_CONTROL
- groups: settlement-ledger-v1
- effect: 매출·수수료·hold·역전 원장; 지급의 입력
- [정상 예시](examples/SellerPenaltyApplied.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| sellerId | string | 필수 | uuid |
| penaltyId | string | 필수 | uuid |
| approvalId | string | 필수 | uuid |
| type | string | 필수 | enum=WARNING/FEE/LISTING_RESTRICTION/PAYOUT_HOLD/SUSPENSION/TERMINATION |
| amount | {currency, amount} | 필수 |  |
| currency | string | 필수 | const=KRW |
| action | string | 필수 | enum=APPLY/REVOKE |
| originalPenaltyId | string / null | 선택 |  |

## PaymentApproved

- topic: marketplace.payment.lifecycle.v1
- producer: payment-service
- aggregate: PAYMENT_FLOW
- groups: commerce-payment-v1, settlement-payment-audit-v1
- effect: Commerce 주문/Claim 반영; Settlement는 대사 projection만
- [정상 예시](examples/PaymentApproved.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| operationId | string | 필수 | uuid |
| resultVersion | integer | 필수 | min=1; max=9007199254740991 |
| orderId | string | 필수 | uuid |
| attemptId | string | 필수 | uuid |
| paymentId | string | 필수 | uuid |
| provider | string | 필수 | enum=KAKAO/NAVER |
| merchantTxId | string | 필수 | ^mp-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ |
| providerPaymentKey | string | 필수 | uuid |
| amount | Money | 필수 |  |
| approvedAt | string | 필수 | date-time; Z$ |
| snapshotHash | string | 필수 | ^[0-9a-f]{64}$ |
| items | array<HttpCheckoutPaymentItem> | 필수 | items=1..100 |
| charges | array<HttpCheckoutPaymentCharge> | 필수 | items=0..100 |

## PaymentFailed

- topic: marketplace.payment.lifecycle.v1
- producer: payment-service
- aggregate: PAYMENT_FLOW
- groups: commerce-payment-v1, settlement-payment-audit-v1
- effect: Commerce 주문/Claim 반영; Settlement는 대사 projection만
- [정상 예시](examples/PaymentFailed.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| operationId | string | 필수 | uuid |
| resultVersion | integer | 필수 | min=1; max=9007199254740991 |
| orderId | string | 필수 | uuid |
| attemptId | string | 필수 | uuid |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |
| noEffectEvidenceId | string | 필수 | uuid |

## PaymentUnknown

- topic: marketplace.payment.lifecycle.v1
- producer: payment-service
- aggregate: PAYMENT_FLOW
- groups: commerce-payment-v1, settlement-payment-audit-v1
- effect: Commerce 주문/Claim 반영; Settlement는 대사 projection만
- [정상 예시](examples/PaymentUnknown.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| operationId | string | 필수 | uuid |
| resultVersion | integer | 필수 | min=1; max=9007199254740991 |
| orderId | string | 필수 | uuid |
| attemptId | string / null | 선택 |  |
| paymentId | string / null | 선택 |  |
| kind | string | 필수 | enum=APPROVE/CANCEL/REFUND |
| firstUnknownAt | string | 필수 | date-time; Z$ |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |

## PaymentVoided

- topic: marketplace.payment.lifecycle.v1
- producer: payment-service
- aggregate: PAYMENT_FLOW
- groups: commerce-payment-v1, settlement-payment-audit-v1
- effect: Commerce 주문/Claim 반영; Settlement는 대사 projection만
- [정상 예시](examples/PaymentVoided.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| operationId | string | 필수 | uuid |
| resultVersion | integer | 필수 | min=1; max=9007199254740991 |
| orderId | string | 필수 | uuid |
| paymentId | string | 필수 | uuid |
| transactionId | string | 필수 | uuid |
| amount | Money | 필수 |  |
| reasonCode | string | 필수 | enum=CUSTOMER_CANCEL/ORDER_COMPENSATION |
| voidedAt | string | 필수 | date-time; Z$ |

## RefundSucceeded

- topic: marketplace.payment.lifecycle.v1
- producer: payment-service
- aggregate: PAYMENT_FLOW
- groups: commerce-payment-v1, settlement-payment-audit-v1
- effect: Commerce 주문/Claim 반영; Settlement는 대사 projection만
- [정상 예시](examples/RefundSucceeded.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| operationId | string | 필수 | uuid |
| resultVersion | integer | 필수 | min=1; max=9007199254740991 |
| orderId | string | 필수 | uuid |
| paymentId | string | 필수 | uuid |
| refundId | string | 필수 | uuid |
| claimId | string / null | 선택 |  |
| transactionId | string | 필수 | uuid |
| amount | Money | 필수 |  |
| items | array<HttpRefundItemAllocation> | 필수 | items=0..100 |
| charges | array<HttpRefundChargeAllocation> | 필수 | items=0..100 |
| completedAt | string | 필수 | date-time; Z$ |

## RefundFailed

- topic: marketplace.payment.lifecycle.v1
- producer: payment-service
- aggregate: PAYMENT_FLOW
- groups: commerce-payment-v1, settlement-payment-audit-v1
- effect: Commerce 주문/Claim 반영; Settlement는 대사 projection만
- [정상 예시](examples/RefundFailed.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| operationId | string | 필수 | uuid |
| resultVersion | integer | 필수 | min=1; max=9007199254740991 |
| orderId | string | 필수 | uuid |
| paymentId | string | 필수 | uuid |
| refundId | string | 필수 | uuid |
| reasonCode | string | 필수 | ^[A-Z][A-Z0-9_]*$ |
| noEffectEvidenceId | string | 필수 | uuid |

## SettlementPaid

- topic: marketplace.settlement.lifecycle.v1
- producer: settlement-service
- aggregate: SETTLEMENT
- groups: commerce-settlement-v1
- effect: 판매자 지급상태·알림 갱신
- [정상 예시](examples/SettlementPaid.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| settlementId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| payoutAttemptId | string | 필수 | uuid |
| bankReceiptId | string | 필수 | uuid |
| amount | SettlementMoney | 필수 |  |
| paidAt | string | 필수 | date-time; Z$ |

## PayoutUnknown

- topic: marketplace.settlement.lifecycle.v1
- producer: settlement-service
- aggregate: SETTLEMENT
- groups: commerce-settlement-v1
- effect: 판매자 지급상태·알림 갱신
- [정상 예시](examples/PayoutUnknown.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| settlementId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| payoutAttemptId | string | 필수 | uuid |
| amount | SettlementMoney | 필수 |  |
| firstUnknownAt | string | 필수 | date-time; Z$ |

## ProductAnalysisCompleted

- topic: marketplace.discovery.analysis.v1
- producer: discovery-data-service
- aggregate: PRODUCT_ANALYSIS
- groups: commerce-analysis-v1
- effect: revision별 검토 결과, 원본 자동게시 없음
- [정상 예시](examples/ProductAnalysisCompleted.json)

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| productId | string | 필수 | uuid |
| revisionId | string | 필수 | uuid |
| runId | string | 필수 | uuid |
| taxonomyVersion | string | 필수 |  |
| modelVersion | string | 필수 |  |
| promptVersion | string | 필수 |  |
| concepts | array<Concept> | 필수 | items=0..1000 |
| completedAt | string | 필수 | date-time; Z$ |

## 재사용 중첩 schema

### Money

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| currency | string | 필수 | const=KRW |
| amount | integer | 필수 | min=1; max=100000000 |

### SettlementMoney

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| currency | string | 필수 | const=KRW |
| amount | integer | 필수 | min=1; max=9007199254740991 |

### Feature

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| key | string | 필수 |  |
| value | string | 필수 |  |
| source | string | 필수 | enum=SELLER/ADMIN |

### RecognitionUnit

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderItemId | string | 필수 | uuid |
| unitOrdinal | integer | 필수 | min=1; max=99 |
| paidAmount | integer | 필수 | min=1; max=100000000 |
| commissionAmount | integer | 필수 | min=0; max=100000000 |

### FinancialAdjustment

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| sourceUnitOrChargeId | string | 필수 | ^(UNIT:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[1-9][0-9]?\|CHARGE:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$ |
| originalRecognitionId | string | 필수 | uuid |
| signedRevenueAmount | integer | 필수 | min=-100000000; max=0 |
| signedFeeAmount | integer | 필수 | min=0; max=100000000 |

### Concept

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| conceptId | string | 필수 | uuid |
| score | number | 필수 | min=0; max=1 |
| evidenceRefs | array<string> | 필수 | items=1..100 |

### HttpPaymentUnit

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| unitOrdinal | integer | 필수 | min=1; max=99 |
| productAmount | integer | 필수 | min=1; max=100000000 |
| discountAmount | integer | 필수 | min=0; max=100000000 |
| paidAmount | integer | 필수 | min=1; max=100000000 |
| commissionAmount | integer | 필수 | min=0; max=100000000 |

### HttpCheckoutPaymentItem

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderItemId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| quantity | integer | 필수 | min=1; max=99 |
| units | array<HttpPaymentUnit> | 필수 | items=1..99 |
| productAmount | integer | 필수 | min=0; max=100000000; int64 |
| discountAmount | integer | 필수 | min=0; max=100000000; int64 |
| taxAmount | integer | 필수 | const=0 |
| paidAmount | integer | 필수 | min=1; max=100000000; int64 |

### HttpCheckoutPaymentCharge

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderChargeId | string | 필수 | uuid |
| sellerId | string | 필수 | uuid |
| chargeType | string | 필수 | const=SHIPPING |
| amount | integer | 필수 | min=1; max=100000000; int64 |

### HttpRefundItemAllocation

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderItemId | string | 필수 | uuid |
| unitOrdinals | array<integer> | 필수 | items=1..99; uniqueItems |
| productRefundAmount | integer | 필수 | min=1; max=100000000 |
| discountReversalAmount | integer | 필수 | min=0; max=100000000 |
| taxRefundAmount | integer | 필수 | const=0 |
| refundAmount | integer | 필수 | min=1; max=100000000 |

### HttpRefundChargeAllocation

| 필드 | 타입 | 필수 | 검증 |
| --- | --- | --- | --- |
| orderChargeId | string | 필수 | uuid |
| amount | integer | 필수 | min=1; max=100000000 |
