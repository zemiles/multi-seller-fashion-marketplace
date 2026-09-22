# 02. 회원·판매자·상품·재고·주문

owner는 모두 Commerce입니다. 아래 ID는 구현과 테스트에서 참조합니다. [공통 규칙](01-security-api.md)이 모든 command에 적용됩니다.

## COM-01 회원·주소

회원당 프로필 1개, 배송지 최대 20개/기본 배송지 최대 1개. 기본 주소 변경은 회원 lock 아래 같은 transaction에서 교체. 주소 수정·삭제는 이미 만든 checkout/order snapshot을 바꾸지 않습니다. 닉네임/주소/전화 등 조회는 소유자 또는 사유를 남긴 지원 관리자만 가능합니다. 탈퇴는 credential/세션 폐기와 프로필 비식별화 예약을 수행하되 거래 참조 ID와 금융 이력은 유지합니다.

## COM-02 판매자·브랜드·카테고리

- 입점 상태 ONBOARDING→ACTIVE 또는 REJECTED. 사업자/신원/계좌/브랜드 검증을 모의 검수로 수행하고 운영자가 근거 documentId와 결정 사유를 남깁니다. 검수 만료 시 신규 판매만 제한, 기존 배송/Claim/환불 의무는 유지합니다.
- 팀은 OWNER/CATALOG/FULFILLMENT/FINANCE 권한. 마지막 ACTIVE OWNER 제거 금지. 초대 token 24시간·1회, 상대 회원 수락 전 권한 없음. 탈퇴/권한 회수는 즉시 다음 요청부터 반영.
- 판매자 SUSPENDED는 신규 checkout 제외, 기존 처리 허용. CLOSED는 열린 주문/Claim/미지급 원장이 있으면 409. CLOSED 상품/거래의 snapshot은 남깁니다.
- 정산계좌 ACTIVE는 판매자당 1개. 변경 요청은 PENDING 검증→다른 관리자의 승인→ACTIVE, 이전 계좌 INACTIVE. 지급 준비 시점 snapshot이 고정되며 지급 요청 후 계좌 변경으로 송금 대상을 바꾸지 않습니다. 이미 변경된 계좌를 원하는 경우 미dispatch 지급 취소 후 새 승인.
- 브랜드 승인 또는 일반 `NO_BRAND` 선택 필수. 미승인 브랜드를 다른 브랜드 ID로 우회하지 않습니다. 카테고리는 관리자 관리, cycle 금지, 비활성 카테고리 신규 게시 불가. 참조 중인 브랜드/카테고리는 hard delete 대신 inactive.
- API: POST `/api/v1/sellers`; GET/PATCH `/api/v1/sellers/{sellerId}`; POST `/documents`, `/verifications`, `/settlement-account-change-requests`, `/team-invitations`; PATCH/DELETE `/members/{memberId}`는 해당 seller 하위. 검증/계좌 최종 승인은 `/api/v1/admin/sellers/{sellerId}/.../decisions`에서 수행.

## CAT-01 상품 revision·SKU

판매자 상품 입력: title(1~200), description(1~20,000), brandId/categoryId, 원단·색상 등 features, 검증된 imageIds(1~20), optionGroups(최대 3, 각 1~50 값), SKU 조합(최대 500), KRW 정수 정상가와 즉시할인액, 배송 정책 version. SKU 조합은 product 내 unique이며 활성 옵션값은 각 group당 정확히 1개입니다.

- DRAFT→IN_REVIEW→READY→ON_SALE. 관리자 검수 탈락은 DRAFT로 이유 반환. ON_SALE→PAUSED/ARCHIVED; 재게시도 판매자/브랜드/규정 조건 재검증. SOLD_OUT은 활성 SKU available=0인 파생 판매 상태이며 재입고 후 조건이 유효하면 ON_SALE.
- 편집은 새 product_revision을 생성. 게시 revision은 immutable, 심사 중에도 이전 게시 revision을 표시. publish 시 current_revision을 원자적으로 교체하고 ProductRevisionPublished outbox 기록.
- 주문에는 revisionId, 상품명, 판매자명, 옵션 label/value, 단가/할인/배송정책 snapshot을 저장. 과거 주문 화면을 현재 상품명/가격으로 다시 구성하지 않습니다.
- 게시 필수: ACTIVE seller, 승인된 브랜드권한, 유효 category, 주이미지, 실결제 단가>=1, 정상가>=실결제액, 활성 SKU, 금칙어/필수속성 규정 통과. 재고0 게시 자체는 가능하나 구매 불가 표시.
- 판매자 작성 feature와 분석 concept를 분리. 분석 결과는 상품 가격/사실/게시 여부를 자동 덮어쓰지 않습니다.
- API: POST `/api/v1/sellers/{sellerId}/products`; GET/PATCH `/products/{productId}`; POST `/products/{productId}/revisions`, `/submit-review`, `/publish`, `/pause`; GET/PUT `/products/{productId}/skus`. 관리자 검수는 `/api/v1/admin/products/{productId}/review-decisions`.

## INV-01 재고 원장과 예약

`available = onHand - reserved - safetyStock >= 0`. v1에서 onHand는 “아직 판매로 배정되지 않은 재고”이며 결제 확정 시 차감합니다. 출고 시 다시 차감하지 않습니다.

- 입고/조정은 delta와 reason/근거 필요, inventory 갱신+inventory_ledger insert 동일 transaction. 재고를 이미 예약한 수량 아래로 조정 금지. ledger는 수정/삭제하지 않고 반대 조정.
- checkout 예약 시 SKU UUID 순서로 lock, 모든 SKU available>=quantity를 확인 후 reserved 증가 및 reservation 기록. 하나라도 부족하면 전체 rollback, 부분 예약 checkout 없음.
- 승인 반영: reserved와 onHand를 같은 수량 감소, reservation CONSUMED. 미승인 종료: reserved만 감소, RELEASED/EXPIRED. 이미 terminal인 reservation을 다시 변경해 이중 해제/소비하지 않습니다.
- 결제 전 재고 hold의 기준은 DB expiresAt. Redis TTL/캐시/배치 지연은 DB 불변식을 바꾸지 않음. Redis를 비워도 oversell이 없어야 함.
- 출고 전 취소 완료는 판매 배정 수량을 한 번 반환. 배송 후 반품은 검수 ACCEPTED+재판매 가능 판정으로만 입고; 단순 환불 성공이 반품 물류 입고의 증거는 아님. LOST/파손/폐기는 판매 재고로 되돌리지 않음.
- 결제 UNKNOWN 동안 reservation ACTIVE+recoveryHold 유지. 다른 SKU/판매자 전환, 자동 해제 금지. 자세한 만료 경합은 ORD-05.
- seller API: GET `/api/v1/sellers/{sellerId}/inventory`; POST `/inventory/{skuId}/adjustments` 입력 deltaOnHand/deltaSafetyStock/reason/expectedVersion. 예약 수량 직접 수정 API 없음.

## MONEY-01 가격·배송비와 배분

v1 할인은 SKU별 즉시할인(`discountPerUnit`, 판매자 부담)만. 각 수량 단위에 정상가/할인/실결제/수수료 snapshot을 저장합니다. 동일 SKU 라인은 checkout에서 합치며 최대 100개 SKU, SKU당 1~99개. 수량 단위를 `orderItemId + unitOrdinal(1..quantity)`로 안정 식별하여 분할 배송/환불·정산 잔여 원 단위를 추적합니다.

- productAmount=unitPrice*quantity, discountAmount=discountPerUnit*quantity, taxAmount=0, paidAmount=productAmount-discountAmount>0.
- 판매자별 할인 후 item 합계가 50,000 이상이면 shipping=0, 아니면 3,000. 판매자 등록 배송정책은 기본값에서 변경 가능하되 fee 0~100,000/무료기준 0~100,000,000이며 checkout에 version을 고정. v1 도서산간 추가금 없음.
- order payable=sum(item paidAmount)+sum(shipping charge amount). 상품 item에 배송비를 중복 더하지 않음. 동일 seller 배송비 charge 최대 1개. 분할 출고/교환에도 추가 승인하지 않음.
- 다수 수량에 합계 X원을 배분할 때 `floor(X/n)`+unitOrdinal 앞쪽부터 X%n개에 1원. 가중 배분이 필요한 조정은 `floor(X*w/sum(w))` 후 소수 나머지 큰 순/동률 ID 순으로 1원. 배분 결과 자체를 저장하고 부분 처리 때 재계산하지 않음.
- 수수료는 item 전체 실결제액*1000/10000의 내림값을 위 수량 배분법으로 단위에 고정. 일반 합계 배분 알고리즘의 시험 예로 X=10,001,n=3이면 3,334/3,334/3,333, fee 합계1,000이면334/333/333입니다. v1 동일 SKU의 정상 주문 금액은 정수 단가×수량이므로 항상 이런 불균등 실결제 배분이 생긴다는 뜻은 아닙니다. refund는 선택 unit의 원래 금액과 수수료를 역전.
- 모든 중간 산술 overflow 검사, 합계 mismatch는 PG 호출 전 422 AMOUNT_MISMATCH. 부가세 표시/신고 금액을 taxAmount에 추측하여 다시 가산하지 않음.

## ORD-01 장바구니

회원당 ACTIVE cart 1개, `(cart,sku)` unique. 금액 캐시는 표시용이며 결제 근거 아님. 품절·가격변경·판매정지를 표시하되 장바구니 항목을 조용히 제거하지 않습니다. checkout은 선택 상품을 다시 검증. 동시 수정은 expectedVersion 충돌로 응답. 주문 생성 후 포함된 수량만 제거, 중간에 사용자가 추가한 수량은 보존.

## ORD-02 불변 checkout

POST checkouts는 소유 주소·SKU·판매자·가격·규정·합계 검증과 예약을 한 Commerce transaction으로 수행합니다. OPEN→PRICED→RESERVED를 기록할 수 있으나 외부에는 전부 성공한 RESERVED snapshot만 반환합니다. expiresAt=생성시각+15분, revision=1부터. 실패하면 checkout·예약 모두 rollback.

주소/상품/수량/가격을 바꾸려면 새 checkout/key를 생성합니다. 기존 것을 in-place repricing하지 않으며 이전 예약을 먼저 해제할 때 결제 시작 여부를 검사합니다. 회원당 살아 있는 미주문 checkout 최대 3개. order 생성 후에는 같은 checkout으로 두 번째 주문 금지.

조회 응답: checkoutId,revision,status,expiresAt,items,shippingGroups,amount,pricingPolicyVersion,addressSnapshot,availableProviders=[KAKAO,NAVER],simulated=true. 검색 표시 가격과 달라지면 새 quote를 보여 주고 구매자 재확인 후 주문 생성; 이전 UI 표시액을 승인하지 않습니다.

## ORD-03 주문 생성과 결제 시작

1. checkout 소유권/revision/RESERVED/DB now<expiresAt, seller 판매 가능·긴급 판매금지 여부를 검사. 일반 가격 변경은 살아 있는 quote 가격을 15분간 존중. 안전·규정 판매금지는 quote보다 우선하여 409 PRODUCT_BLOCKED 및 예약 해제.
2. checkout lock 하에 orders(PENDING_PAYMENT), item/unit/shipping/charge/address snapshot을 commit. `(checkoutId)` unique와 회원 command key를 보존. 이때 PG 호출 없음.
3. POST order/payment에서 Commerce가 주문별 영속 dispatch-intent를 먼저 기록하고 Payment prepare/approve 호출. 본문 금액 입력은 금지. 현재 [Checkout 계약](../../contracts/commerce-payment-checkout-contract-v0.1.md)의 전체 snapshot 전송.
4. Payment 승인 결과 동기 응답 또는 PaymentApproved event를 같은 `applyPaymentResult` 처리기로 반영. `(sourceOperationId,resultVersion)` 처리키로 중복 방지. order lock→inventory UUID lock→reservation 소비→PAID/outbox 한 transaction.
5. 고객에게 PAID는 Commerce 반영 완료 후만 반환. PG 성공이지만 Commerce 반영 대기이면 PAYMENT_PROCESSING 표시/202. 재조회는 추가 approve를 호출하지 않음.

## ORD-04 주문 상태와 읽기 모델

orderStatus와 paymentStatus/claimStatus/recoveryStatus를 별도 필드로 반환합니다. UNKNOWN은 결제 상태이며 V1 orders CHECK에 없는 값을 억지로 order_status에 넣지 않습니다.

| 현재 | 다음 | 조건 |
| --- | --- | --- |
| PENDING_PAYMENT | PAID | 확정 승인+예약 소비 commit |
| PENDING_PAYMENT | PAYMENT_FAILED | Payment가 효과 없는 실패 확정, 재결제는 유효기간 내 새 attempt만 |
| PAYMENT_FAILED | PENDING_PAYMENT | 만료 전·활성 예약·새 attempt 허가 |
| PENDING_PAYMENT/PAYMENT_FAILED | CANCELLED | 미dispatch 종료 handshake 또는 확정 취소/보상 완료 |
| PAID | PROCESSING | 판매자 출고 준비 |
| PAID/PROCESSING | PARTIALLY_SHIPPED/SHIPPED | 유효 미취소 수량 중 일부/전부 인계 |
| 배송 진행 상태 | PARTIALLY_COMPLETED/COMPLETED | 일부/모든 수량이 구매확정 또는 취소·반품·교환 종결 |
| 출고 전 모든 수량 | CANCELLED | 모든 금융/재고 취소 종결 |

상태는 item 수량과 사실에 의해 산출합니다. 반품 완료 후 과거 배송 이력을 되돌리지 않고 claim/refund 상태를 병기. 배송 전 일부 취소는 주문 전체를 CANCELLED로 만들지 않음. 승인 사실 후 inventory 정합성이 깨졌다면 fulfillment 차단·recoveryStatus=COMPENSATING, 전액 void/refund 완료 후 CANCELLED; 돈이 남아 있는데 PAYMENT_FAILED로 숨기지 않음.

## ORD-05 만료·취소와 dispatch 경합

15분은 최초 결제 실행 허용 기한이지 이미 접수된 금융 작업을 삭제하는 TTL이 아닙니다.

- 아직 dispatch-intent 없는 checkout/order: 같은 order/checkout lock을 사용하는 만료 worker와 결제 시작 중 하나만 성공. 만료 winner는 CLOSED gate를 기록하고 예약 해제; 이후 payment 시작은 410.
- dispatch-intent가 있거나 prepare 통신이 불명확하면 Payment `close-order`를 호출합니다. Payment는 order guard를 영구 CLOSED로 만들거나 이미 진행된 operation을 반환. UNKNOWN/dispatch된 operation이면 예약 유지. Payment 404/HTTP timeout은 해제 근거가 아님.
- close-order는 prepare와 같은 order guard lock에서 직렬화하며, guard가 없어도 CLOSED tombstone을 만듭니다. 이후 늦은 prepare/approve가 주문을 부활시킬 수 없습니다. 응답이 `CLOSED_NO_EFFECT`인 경우만 Commerce가 만료/취소 후 예약 해제.
- REQUESTED/UNKNOWN이면 expire 화면에도 “확인 중” 표시. PG1/PG2의 같은 operation replay는 이미 수락된 실행의 복구이므로 만료 후에도 허용; 새 attempt/새 key/다른 PG 전환은 불가. 취소 의도가 있으면 늦은 승인 즉시 보상하고 배송 금지.
- 클라이언트 결제 버튼 중복, expiry batch, 두 provider 동시 요청, close-order-before-prepare까지 통합 테스트 필수. 영속 close-order/gate 없이는 자동 만료 기능을 완료 처리하지 않습니다.
