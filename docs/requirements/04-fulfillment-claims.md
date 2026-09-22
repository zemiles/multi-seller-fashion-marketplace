# 04. 배송·Claim·구매확정·리뷰·알림

## FUL-01 배송과 수량

Commerce owner. 한 shipment는 한 order/seller/address이고 여러 item 수량을 포함할 수 있습니다. 서로 다른 seller의 shipment 혼합 금지. `unitOrdinal`을 shipment_item에 배정하고 이미 취소/반품/다른 outbound에 배정된 원본 unit은 다시 출고하지 않습니다. 교환 replacement는 별도 lineage로 추적합니다.

- seller API POST `/api/v1/sellers/{sellerId}/shipments`: orderId,items[{orderItemId,unitOrdinals}],carrierCode,trackingNumber. PAID/PROCESSING 주문과 해당 판매자 권한, Claim hold 없는 수량만 READY로 준비.
- POST `/shipments/{id}/handover`: READY→HANDED_OVER; 그 뒤 고객의 단순 출고전 취소 불가. carrier 이벤트로 IN_TRANSIT→DELIVERED, 예외 LOST/FAILED. 취소는 READY 이전 또는 READY 미인계만 CANCELLED.
- v1 실제 택배사 연결 없음. 관리자 테스트 배송 API POST `/api/v1/admin/shipments/{id}/tracking-events`로 eventId,sequence,status,occurredAt 기록. simulated=true 표시, 미래 시각은 5분 초과 거부.
- `(carrier,eventId)` unique, 같은 ID 다른 내용409. 늦은 IN_TRANSIT이 DELIVERED를 되돌리지 않음. DELIVERED 사실 수정은 단순 update가 아니라 관리자 2인 승인 correction event; 구매확정/정산 후 수정은 재무 조정도 필요.
- 배송완료 수량만 confirmation 대상. LOST는 자동확정 제외, 운영 Claim 처리. 예상 출고일은 결제 후 3일, 초과24시간이면 incident 생성·구매자 지연 알림; 자동 환불/제재 부과는 하지 않음.

## FUL-02 수량별 구매확정

- 수동: 회원 소유 DELIVERED shipment item의 미확정·미반품·hold 없는 quantity. 지정 수량만 확정, unit 선택은 미확정 ordinal 오름차순. 중복 key 또는 중복 unit은 새 수익 없음.
- 자동: `eligibleAt=deliveredAt+192시간`. UTC Instant로 계산, 주말/휴일 포함. worker 1분 주기, DB now>=eligibleAt. 날짜를 잘라서 8일째 자정에 조기 확정하지 않음.
- Claim 접수와 confirmation은 같은 order item/confirmation 행 잠금 순서를 사용. 접수 winner는 hold 수량을 즉시 차감, 확정 winner 후 일반 Claim은 `ALREADY_CONFIRMED`로 거부하고 지원 예외 경로를 안내.
- 열린 RETURN/EXCHANGE/배송 분쟁 hold는 해당 unit만 차단, 다른 item/수량 확정 가능. hold 종료: REJECTED/CANCELLED이면 해제하고 기존 eligibleAt이 지났으면 다음 worker에서 확정. 환불/반품 완료 unit은 eligible에서 영구 제외. 교환 unit은 replacement 배송완료 기준으로 192시간 재계산.
- confirmation state/immutable event/PurchaseConfirmed outbox는 같은 transaction. 회원 요청 시각, eventId, unitIds, 정산용 금액·fee snapshot 포함. Settlement가 구매확정 상태를 직접 변경하지 않음.

## CLM-01 공통 Claim 규칙

Claim type=CANCEL/RETURN/EXCHANGE. 회원 본인, 판매자는 자기 물품의 판매자 귀책 접수 요청, 관리자는 사유·권한 하에 대리. order item 수량 및 실제 shipment item lineage를 지정합니다. 같은 unit에 열린 Claim 2개 금지; 접수 수량+이미 취소/반품 완료 수량은 원 구매 수량을 초과할 수 없음.

| 유형 | 접수 조건 | 정상 흐름 |
| --- | --- | --- |
| CANCEL | 아직 HANDED_OVER 안 된 수량; UNKNOWN 결제는 취소 의도만 먼저 저장 | REQUESTED→APPROVED→REFUND_PENDING→COMPLETED; 미결제 no-effect는 APPROVED→COMPLETED |
| RETURN | DELIVERED, now<=deliveredAt+168h, 미확정 | REQUESTED→UNDER_REVIEW→APPROVED→PICKUP_PENDING→IN_TRANSIT→RECEIVED→INSPECTING→REFUND_PENDING→COMPLETED |
| EXCHANGE | RETURN 조건+동일상품·동일 실결제단가 대체 SKU | RETURN의 검수까지 동일→replacement RESERVED/SHIPPED/DELIVERED→COMPLETED |

REQUESTED/UNDER_REVIEW→REJECTED는 근거와 사유 필수. 배송/환불/교환 효과 시작 전만 고객 CANCELLED(철회) 가능. REFUND_PENDING/UNKNOWN은 철회해 잔액 예약을 풀 수 없음. rejected/withdrawn 후 재접수도 기간·남은 수량 재검증. Claim 진행중인 order가 COMPLETED로 표시될 수 없도록 별도 openClaimCount를 반환합니다.

- 일반 사유: CHANGE_OF_MIND/SIZE_MISMATCH(구매자), DEFECT/WRONG_ITEM(판매자), LOST_OR_DAMAGED(운송자), OTHER(검수 후 책임 확정). 책임 UNKNOWN은 환불액/수수료를 확정하지 않고 검토 상태.
- 사유 변경은 `claim_reason_change`에 요청→검수→승인 이력; 원 사유 overwrite 금지. Claim evidence는 소유권 검증된 비공개 파일, 설명 최대 2,000자. AI 검수는 참고만, 자동 거절/제재 불가.
- 판매자 검수 응답 기한 48시간, 초과하면 SUPPORT incident/알림, 자동 거절 금지. Claim이 열린 채 장기 경과해도 자동 구매확정 금지.
- 수동 확인 후 기한밖/확정후 Claim 허용은 ADMIN_SUPPORT 요청+다른 관리자 승인, 사유/증빙, 해당 정산 hold 및 역전 원장 필수. 법률상 요구를 v1의 168시간 규칙으로 자동 거부하는 서비스로 사용하지 않습니다.

## CLM-02 환불액·배송비

Commerce가 취소/반품된 unit의 원 실결제 배분을 합산합니다. 현재 상품가나 환율을 사용하지 않습니다. 즉시할인은 환급할 현금이 아니므로 `refundAmount=productRefundAmount-discountReversalAmount+taxRefundAmount`; 각 값은 원 unit 배분 이내.

- 출고전 판매자 그룹 전량 취소: 그 판매자 최초 유료 배송비 전액 환급. 일부 취소: 배송비 유지. 무료배송 기준을 다시 계산해 배송비를 새로 청구하지 않음.
- 배송후 구매자 귀책 반품: 최초 배송비 환급 없음. 판매자/운송자/플랫폼 귀책으로 해당 판매자 구매 unit 전량 반환 완료 시 최초 유료 배송비 전액 환급. 부분 귀책/부분 반품에는 최초 배송비 유지.
- 여러 Claim이 합쳐 전량이 되는 순간 charge 잔액을 한 번 환급. 그룹 lock 아래 누적 완료 unit·책임을 판단, 혼합 책임에서는 “모든 반환 unit이 비구매자 귀책” 조건을 충족할 때만 배송비 환급. 이미 성공/예약된 charge 환불 합계를 차감.
- 회수비/교환 배송비는 v1 0, RECHARGE/추가 카드 승인 없음. 환불 총액<=결제액. 모든 item을 반품해도 배송비가 남으면 Payment는 PARTIALLY_REFUNDED일 수 있고 이는 오류가 아님.
- 검수 일부 승인 시 claim_item에 승인/거절 수량을 분리. 승인 unit만 환불 예약, 나머지는 사유·반송/지원 처리. 전체 Claim COMPLETED는 모든 unit의 반환/환불/거절 후속 처리가 종결됐을 때.

REFUND_PENDING에서 Payment operation ID를 영속 저장하고 조회/이벤트로 완료 확인. HTTP timeout을 새 refund key 생성 근거로 삼지 않음. RefundSucceeded는 refundId와 unit/charge 합계 검증 후 Claim을 완료하고 판매자 재무 조정을 발행합니다. RefundFailed는 Claim 검토로 복귀·사유 알림, 이미 환불됐을 가능성이 있으면 UNKNOWN 그대로 유지.

## CLM-03 교환

동일 product, 동일 seller, 동일 통화와 원 실결제 단가만. 교환 승낙 시 replacement reservation 생성, receipt/검수까지 최대 7일 hold; 부족하면 EXCHANGE_UNAVAILABLE로 반품 전환 의사를 받아 RETURN으로 새 연결 Claim 생성(원 Claim 전환 이력 보존). 임의 다른 SKU/차액 결제 금지.

7일 경과 시 아직 replacement 미출고이면 고객·운영자에게 알리고 replacement 예약을 해제한 뒤 반품환불 절차로 전환합니다. 이는 PG UNKNOWN 재고 예약과 별개입니다. 이미 replacement 출고됐으면 해제 금지. 반품 원본은 검수 결과 재판매 가능일 때만 입고, 대체품은 교환 출고 commit 시 onHand/reserved를 차감합니다.

교환은 원 결제/정산 unit lineage를 유지해 수익을 두 번 인식하지 않습니다. replacement 재교환은 v1 1회 제한 초과로 RETURN만 허용. 재배송완료 후 해당 unit의 구매확정·리뷰 자격 시계를 다시 시작합니다.

## EXP-01 찜

Commerce 소유 `(memberId,productId)` unique, 중복 PUT/DELETE는 같은 결과. 목록에서 품절/중단 표시, 삭제된 상품은 tombstone 표기 후 사용자가 제거. 검색/추천 행동 이벤트는 원본 찜 성공 후 발행, 개인정보 없는 member pseudonym만 사용.

## EXP-02 리뷰·답글

- 자격은 orderItem 기준 최소 1개 unit 구매확정 때 부여, 회원당 orderItem별 리뷰 1개. 전체 취소/반품 후 최초 작성 자격 없음; 일부 보유면 허용. 이미 작성한 후 전량 반품해도 리뷰를 조용히 삭제하지 않고 verifiedPurchase/returned 표시 갱신.
- rating 정수1~5, text 1~2,000자, 이미지0~5개. 작성→PENDING_MODERATION→PUBLISHED/HIDDEN. 금칙어/개인정보/불법 콘텐츠 규정으로 검수; 평점이 낮다는 이유로 판매자 삭제 불가.
- 수정 시 review_revision append, 최신 공개본은 재검수 통과 후 교체. 삭제는 DELETED+tombstone, 과거 revision은 권한 제한 감사 보존. 판매자는 자기 상품 리뷰에 공개 답글 1개, 수정 이력/검수 동일. 회원 이외의 review rating 조작 금지.
- API seller POST/PATCH `/api/v1/sellers/{sellerId}/reviews/{reviewId}/reply`; admin POST `/api/v1/admin/reviews/{reviewId}/moderation`. 구매자 공개 조회는 `/api/v1/products/{productId}/reviews`.

## EXP-03 알림

Commerce가 앱 내 notification/delivery 소유. 주문 승인·결제 확인중·출고·배송완료·Claim 진행·환불완료·판매자 정산·운영 요청을 수신자+sourceEventId+templateVersion unique로 1회 생성. 전송 실패가 원 거래 rollback 사유가 되지 않음.

읽음은 소유자만, 여러 기기에서 멱등. 필수 거래 알림은 마케팅 수신거부와 별개로 앱 내 제공, 마케팅은 opt-in만. 이메일/SMS/푸시는 v1 실제 발송하지 않고 delivery channel=IN_APP 또는 명시적 MOCK으로 표시. 알림에 주소/계좌/전체 금액 payload를 복제하지 말고 권한 검증되는 상세 페이지 resourceId를 연결합니다.
