# 05. 프론트엔드 화면 상세 명세

정책: [FE-01~03](../requirements/06-discovery-frontend.md), 필드 정본: [Commerce public OpenAPI](../../contracts/commerce-public.openapi.json), 탐색: [API 뷰어](../api/index.html). 아래 `operationId`는 같은 명세의 이름입니다. HTTP 경로를 화면 route와 혼동하지 않습니다. 모든 화면은 목표이며 현재 front-end는 Vite starter입니다.

## 공통 화면 계약

- 처음 `getSession`, 관리자는 `adminSession`. 쿠키는 서버 관리, csrfToken은 메모리, 쓰기 요청에 X-CSRF-Token. role은 버튼 분기용이고 매 호출 서버 검증이 필수입니다.
- 화면 상태: BOOTSTRAPPING→LOADING→READY/EMPTY, 요청별 SUBMITTING→SUCCESS/PROCESSING/ERROR. 401=재로그인(returnTo는 same-origin 상대경로만), 403=권한 안내, 404=없음/타인 구분 없는 안내. admin 세션 만료는 admin login으로 이동합니다.
- mutation별 논리 action UUID를 생성, 동일 작업 double-click/timeout/retry에는 같은 Idempotency-Key. sessionStorage에는 resourceId/actionKey/provider/pending 상태만 저장하고 주소·계좌·비밀번호·token·payload 원문은 저장하지 않습니다. 저장 자체를 사용자 인증으로 신뢰하지 않습니다.
- expectedVersion 409는 현재 resource 재조회→사용자 변경내용 확인→새 action으로 재요청. 금융 UNKNOWN에 새 action을 생성하지 않습니다. 버튼은 처리중 disabled지만 서버 멱등성이 최종 보장입니다.
- loading skeleton, empty 안내+가능한 다음 행동, error code 기반 문구, keyboard label/focus 복원/aria-live 제공. 360px부터 가로 overflow 없이 카드/표를 전환합니다. 표는 행 ID key, 목록은 cursor/filter/sort를 URL에 보존합니다.
- 금액은 KRW integer를 표시만 하고 서버 가격·환불액을 덮어쓰지 않습니다. 주문 가격은 snapshot. 모든 결제/지급/모의 검증·택배 화면은 모의 동작임을 표시합니다.
- 사용자 문구에 내부 JWT/outbox/SQL 정보 노출 금지. traceId는 문의 복사에만 제공하고 error.details 중 민감정보를 그대로 출력하지 않습니다.
- area=`storefront`, `seller`, `admin`; 공유 UI/token/http/session만 import. 최종 `/`, `/seller/*`, `/admin/*` 세 SPA artifact 독립 배포/rollback. area 간 business store 공유 금지.

## 고객 화면

| ID / route | API operationId | 입력·화면 필드 | 버튼 조건·예외 |
| --- | --- | --- | --- |
| SF-01 `/login`, `/signup` | login, registerMember, getSession | email, password12~128, nickname2~30, consentVersions | 제출중 중복금지, password trim 금지, 실패 동일문구. 가입후 검증필요 안내 |
| SF-02 `/auth/verify`, `/auth/reset-password` | verifyEmail, requestVerification, requestPasswordReset, resetPassword | token, email, newPassword | URL token을 로그/분석에 보내지 않고 처리후 URL에서 제거. 만료/사용됨은 재발급 안내, 회원존재 노출 금지 |
| SF-03 `/account/profile` | getMe, updateMe, withdrawMember, logout | nickname, version, emailVerified/status | 거래중 탈퇴409는 주문이동, SUSPENDED는 기존 주문/Claim 접근 유지 |
| SF-04 `/account/addresses` | listAddresses, createAddress, updateAddress, deleteAddress | 수령인/전화/5자리우편번호/address1/2/isDefault, version | 최대20개, 기본1개, 저장후 과거 주문주소는 변경되지 않음을 표시 |
| SF-05 `/`, `/products`, `/search` | listCategories, listBrands, listProducts, searchProducts | query<=100, category/brand/seller, priceMin/Max, conceptIds, sort, cursor | 결과0=필터 초기화, 검색장애=공개상품 목록 fallback. 품절은 구매불가 표시 |
| SF-06 `/products/:productId` | getProduct, listProductReviews, putCartItem, putWishlist, deleteWishlist, getCart | revision, 옵션별SKU, unitPrice/discount/paidUnitPrice, available, 배송정책 | 필수 옵션·수량1~99 선택후 구매/장바구니, 로그인 필요, 판매중지면 주문금지 |
| SF-07 `/wishlist` | listWishlist, putWishlist, deleteWishlist | product snapshot, available | tombstone/품절 표시, 삭제멱등, 삭제상품 상세로 자동진입 금지 |
| SF-08 `/cart` | getCart, putCartItem, deleteCartItem, createCheckout | 선택sku/quantity/addressId, cart version | 빈선택/품절 차단, 가격변경은 새 quote 재확인. selectedSkuQuantities만 서버에 전달 |
| SF-09 `/checkout/:checkoutId` | getCheckout, createOrder, startOrderPayment | 주소snapshot, item/unit, seller배송비, 합계, expiresAt, PG1/PG2 | RESERVED·시간유효·가격재확인 후 주문생성, 이어 결제. orderId 받은뒤 같은 checkout으로 재생성 금지 |
| SF-10 `/orders/:orderId/payment` | getOrder, getOrderPaymentStatus, startOrderPayment | provider, expectedVersion, statusUrl, payment/recovery 상태 | 미시작일 때만 PG 선택. 진행/UNKNOWN이면 PG 전환·재결제 차단, 새로고침은 GET만 |
| SF-11 `/orders`, `/orders/:orderId` | listOrders, getOrder, getOrderPaymentStatus | 주문/item·shippingGroups·payment/claim/recovery 각각 표시 | 서버 허용 수량에만 취소/반품/교환/확정 버튼. 일부 처리로 전체 주문을 완료 표시하지 않음 |
| SF-12 `/orders/:orderId/claims/new` | createClaim, getOrder, quoteClaim | CANCEL/RETURN/EXCHANGE, itemId/quantity/shipmentItemId, reason/evidenceIds/replacementSkuId | 사전 예상환불은 X-01 quote. 명시 동의후 제출. 기한/hold/가격 동일조건 서버결정 |
| SF-13 `/claims/:claimId` | getClaim, withdrawClaim, requestClaimReasonChange, listMyClaimReasonChanges, convertExchange | 진행상태, unit, 예상/확정금액, refundStatus | 효과 시작 전만 철회. REFUND_PENDING/UNKNOWN은 확인중. 회수·사유변경·교환동의는 보완계약 사용 |
| SF-14 `/orders/:orderId/confirm` | confirmPurchase, getOrder | shipmentItemId, quantity, expectedVersion | DELIVERED·무hold·미확정 수량만. 확정 클릭전 대상수량 명시, 409는 재조회 |
| SF-15 `/reviews/new`, `/reviews/:reviewId/edit` | listReviewEligibility, createReview, updateReview, deleteReview | eligibilityId, rating1~5, text1~2000, imageIds<=5, version | eligibility 재검증, 이미지검역 완료후 연결, 수정은 재검수 상태 표시 |
| SF-16 `/notifications`, `/account/preferences` | listNotifications, readNotification, getNotificationPreferences, updateNotificationPreferences | 알림/resourceId/readAt, marketingOptIn/analyticsOptIn/version | 앱내 거래알림은 opt-out과 별도. resource 진입시 권한 다시 검증 |

SF-09 결제 진행 상태는 `quote 조회→가격 확인→createOrder 성공→orderId 저장→결제 시작→조회`입니다. createOrder 응답이 유실되면 동일 key로 replay하여 같은 orderId를 찾습니다. startOrderPayment 응답 유실 후에는 상태조회로 복구하고 새 결제키를 만들지 않습니다.

결과 화면은 `Commerce PAID`일 때 “결제·주문 완료”, Payment 승인만이면 “주문 반영 중”, UNKNOWN은 “결제 결과 확인 중”, COMPENSATING은 “주문 취소 및 결제 취소 확인 중”, 확정 no-effect만 “결제 실패”입니다. 처음60초 2초, 다음5분까지5초, 이후30초 polling; foreground에서만 실행, 이탈/종결 시 중지합니다. polling 실패는 거래 실패가 아닙니다.

## 판매자 화면

모든 route는 `/seller/:sellerId` 아래이며 OWNER 또는 표의 업무역할이 필요합니다. sellerId를 바꿔 다른 판매자의 데이터를 볼 수 없어야 합니다.

| ID / suffix | operationId | 입력/표시 | 역할·상태 조건 |
| --- | --- | --- | --- |
| SE-01 `/onboarding`, `/profile` | createSeller, getSeller, updateSeller, createSellerDocument, createSellerVerification | 판매자명/사업식별/연락처, 검증종류/documentIds | OWNER. 문서 업로드 권한/검역, 미검증은 신규판매 차단 |
| SE-02 `/team`, `/invitations/accept` | listSellerMembers, createInvitation, acceptSellerInvitation, updateSellerMember, removeSellerMember | email/OWNER·CATALOG·FULFILLMENT·FINANCE, token, version | OWNER. 마지막OWNER 제거금지, 초대24시간/1회. 수락페이지 sellerId는 token에서 서버결정 |
| SE-03 `/settlement-account` | createAccountChange, getSeller, getSellerSettlementAccount | bankCode/accountNumber/holderName/evidenceIds | OWNER. 평문계좌 재표시/로컬저장 금지, pending/승인 표시. 현재계좌 조회는 X-05 |
| SE-04 `/products`, `/products/new`, `/products/:productId/edit` | listSellerProducts, createProduct, getSellerProduct, editProduct, createProductRevision, listProductSkus, updateProductSkus | title/description/category/brand/image/feature/옵션/가격/배송정책 | OWNER/CATALOG. 옵션<=3, 조합<=500, 원가>=할인가, revision immutable |
| SE-05 `/products/:productId/review` | submitProductReview, publishProduct, pauseProduct | 검수결과/currentRevision/expectedVersion | READY·판매조건 충족 때 게시, 심사중 기존게시본 유지 |
| SE-06 `/inventory` | listInventory, adjustInventory | onHand/reserved/safety/available, delta·reason·version | OWNER/CATALOG. reserved는 읽기전용, 예약밑 재고조정 거부 |
| SE-07 `/orders`, `/shipments` | listSellerOrders, listSellerShipments, createShipment, handoverShipment | 자기item/unit, carrier/tracking, version | OWNER/FULFILLMENT. 다른seller 금액/개인정보 최소화, READY만 인계 |
| SE-08 `/claims`, `/claims/:claimId` | listSellerClaims, decideSellerClaim, inspectClaim, getSellerClaim, listSellerClaimReasonChanges, decideClaimReasonChange | 승인/거절, 책임, 증거, accepted/rejected unitOrdinals, restockable | OWNER/FULFILLMENT. 검수48시간 안내, UNKNOWN 직접성공 버튼 없음 |
| SE-09 `/reviews` | listProductReviews, createSellerReviewReply, updateSellerReviewReply | 자기상품 후기/text, version | OWNER/FULFILLMENT. 낮은평점 삭제/수정 권한 없음 |
| SE-10 `/ledger`, `/settlements`, `/settlements/:settlementId` | listSellerLedger, listSellerSettlements, getSellerSettlement | 원장/수수료/보류/이월/모의지급, 마스킹계좌 | OWNER/FINANCE 읽기. 음수채무와 지급액 구분, payoutUNKNOWN은 재지급 요청 없음 |
| SE-11 `/appeals` | createSellerAppeal, listSellerAppeals, getSellerAppeal | penaltyId/reason/evidenceIds | OWNER. 검토목표7일, 자동인용 아님. 목록/상세 X-05 |
| SE-12 `/products/:productId/analysis` | createProductAnalysis, getProductAnalysis, reviewProductConcept | revision/run, concept score/evidence, 검토결정 | OWNER/CATALOG. stale run은 현재revision 적용금지, ADJUSTED는 adjustedScore 필수 |

## 관리자 화면

별도 admin session/TOTP. `/admin` 뒤 route, 기능별 접근권한이 필요합니다. 명세에 없는 역할을 화면에서 자체 발급하지 않습니다.

| ID / suffix | operationId | 입력/표시 | 권한·최종 동작 |
| --- | --- | --- | --- |
| AD-01 `/login` | adminLogin, adminSession, adminLogout | email/password/TOTP6자리 | 유휴15분/절대8h, 공개관리자 가입 없음 |
| AD-02 `/seller-verifications` | decideSellerVerification, decideAccountChange, listSellerVerificationReviews, listAccountChangeReviews | document/검증결과/reason/version/approvalId | SUPPORT 검증, FINANCE 계좌. 목록/상세 X-04, 자기계좌변경 승인금지 |
| AD-03 `/catalog/reviews`, `/reviews` | decideProductReview, moderateReview, listProductReviewRequests, listReviewModerationRequests | revision/규정/사유/decision/version | CATALOG. 승인된revision만 게시, 콘텐츠 검수 사유 필수 |
| AD-04 `/shipments/:shipmentId`, `/orders/:orderId`, `/claims/:claimId` | recordTrackingEvent, correctShipment, recordReturnTracking, getOrderForSupport, getClaimForSupport, createClaimException | eventId/sequence/status/occurredAt | SUPPORT 모의배송. correction은 X-03+다른관리자 승인 |
| AD-05 `/settlements`, `/settlements/:settlementId` | listAdminSettlements, getAdminSettlement, calculateSettlement, requestSettlementApproval, requestPayout | cutoff/policyVersion/expectedVersion/approvalId | FINANCE. 보류0/승인유효/barrier충족, 성공 표시는 모의지급 완료 |
| AD-06 `/approvals`, `/approvals/:approvalId` | listApprovals, createApproval, decideApproval, getApproval | actionType/target/hash/reason/evidence/유효시각 | FINANCE/RISK/IAM/SUPPORT action별권한. 요청자=승인자 차단, 변경내용 hash 재확인 |
| AD-07 `/payment-operations` | listPaymentOperations, recoverPaymentOperation | operation/UNKNOWN age/provider/증거/nextRetry | FINANCE. 원 operation 복구만, 직접금액·PG·key 편집 없음 |
| AD-08 `/reconciliation` | listDiscrepancies, resolveDiscrepancy | PAYMENT/SETTLEMENT owner, 기대/실제/receipt/approval | FINANCE. 해결사유·증거·2인승인, 강제합계 덮어쓰기 없음 |
| AD-09 `/incidents`, `/penalties`, `/appeals` | listIncidents, createIncident, updateIncident, listPenalties, createPenalty, decideAppeal | 영향resource/원인/증거/제재/이의결정 | RISK, FEE/해제는2인승인. 취소는 reversal 기록 |
| AD-10 `/compliance`, `/taxonomies`, `/search-rebuilds` | listComplianceRules, createComplianceRule, createTaxonomy, publishTaxonomy, listConceptTaxonomies, createSearchRebuild, getSearchRebuild | immutable version, 적용일/조건/심각도/concepts | CATALOG. taxonomy publish 검증, 분석값으로 자동금융제재 금지 |
| AD-11 `/audit`, `/iam` | listAuditLogs, listAdministrators, getAdministrator, requestAdminRoleChange, executeAdminRoleChange, requestAdminMfaRecovery, executeAdminMfaRecovery | actor/target/time/correlation, 역할·계정 | IAM. IAM쓰기 X-06, 감사읽기 자체도 감사 |
| AD-12 `/event-queues`, `/recovery-jobs` | listEventQueues, replayEventQueue, getRecoveryJob | queue/sourceStream/age/retry/evidence/job상태 | FINANCE 금융replay, CATALOG 검색rebuild, IAM 권한통제. 자세한 절차는 운영문서 |

## 파일 업로드와 오류 표시

`createUpload(purpose,contentType,sizeBytes,sha256)→putUploadContent(bytes)→completeUpload→getUploadStatus로 VERIFIED 확인→image/evidence ID 연결`. 이미지<=5MiB, PDF<=10MiB, 형식 allowlist는 OpenAPI 사용. private 증빙 다운로드는 getDownloadUrl 권한검증 후5분 URL. 업로드 URL·token·문서원문은 analytics에 기록하지 않습니다. QUARANTINED/REJECTED 파일을 product/review/claim에 붙이지 않습니다.

| 서버 code/상태 | 사용자 표시 | 재시도 |
| --- | --- | --- |
| VERSION_CONFLICT /409 | 다른 변경이 반영되어 새 정보를 확인해야 함 | GET후 명시 재제출, 기존 금융요청 변경 금지 |
| IDEMPOTENCY_CONFLICT /409 | 진행 중 요청과 입력 내용이 다름 | 원 요청 상태 조회, 자동 새key 없음 |
| ORDER_PAYMENT_BLOCKED /409 | 결제 진행 또는 완료 이력이 있음 | 주문결제상태 조회 |
| AMOUNT_MISMATCH /422 | 주문금액 재확인 필요 | checkout/서버검증 확인, 클라이언트 계산값 제출 금지 |
| PRODUCT_BLOCKED /409 | 현재 주문할 수 없는 상품 | 상품/예약 상태 재조회 |
| ALREADY_CONFIRMED /409 | 이미 구매확정됨, 지원 문의 가능 | 자동 Claim 재접수 없음 |
| ACTIVE_TRANSACTION /409 | 진행 중 거래 종료 후 탈퇴 가능 | 관련 주문/Claim 이동 |
| UNSUPPORTED_FEATURE /422 | 현재 지원하지 않는 기능 | 입력수정 |
| 410 | 주문서/초대/인증 유효기간 만료 | 기존 금융진행 확인후 새checkout 또는 token재발급 |
| 429 | 잠시 후 재시도 | Retry-After가 있으면 준수 |
| 503 또는 timeout | 연결/처리 상태 확인 필요 | 조회는 재시도, mutation은 같은 key+상태조회 |
| 202 / UNKNOWN | 결과 확인 중 | polling, PG 변경·새결제 차단 |

위 code는 기존 요구사항에 있는 값입니다. 세부 재고/검수 오류를 추가하면 Error.code 사전·OpenAPI 예시·화면 처리·테스트를 동시에 추가합니다. raw exception/message 문자열 비교로 UI를 분기하지 않습니다.

## 계약 보완 목록

아래 11개 묶음은 **정식 OpenAPI 반영 완료(SPECIFIED)**입니다. 총 8개 계약의 205개 operation 중 보완 operation은 38개입니다. [보완 계약 manifest](contract-extensions.json)에 각 경로·operationId·소속 계약을 연결했습니다. [추적표](04-traceability.md)의 구현 상태는 별도이며 실제 서버가 동작한다는 뜻이 아닙니다. ID/enum/금액 타입은 기존 schema를 재사용합니다. 브라우저 mutation에는 CSRF·Idempotency-Key·기존 자원의 expectedVersion·인가·감사를 적용하며, 조회형 quote나 새 job 생성에는 원자적으로 검증할 대상 snapshot/hash를 사용합니다. X-10만 서비스 JWT 기반 내부 command로 CSRF 대상이 아니며 eventId로 멱등 처리합니다. 나머지 보완 API는 Commerce facade이고 PG/서비스 내부 주소를 브라우저에 노출하지 않습니다.

| ID | 추가 target 경로 | 입력 → 응답 / 권한·조건 |
| --- | --- | --- |
| X-01 | POST `/api/v1/orders/{orderId}/claim-quotes` | ClaimCreate 입력 → quoteId,expiresAt(5분),orderVersion,eligibleUnitIds,items/charges/totalRefund,allowedActions,reasons. MEMBER소유. 예약/환불효과 없는 계산. createClaim에 quoteId 선택추가, 있으면 같은 version/hash 검증; 없으면 서버 재계산 |
| X-02 | POST `/api/v1/claims/{claimId}/reason-change-requests`; POST seller 하위 `/claims/{claimId}/reason-change-requests/{requestId}/decisions` | 새reasonCode/evidenceIds/version → requestId,status; 검수 decision/reason/expectedClaimVersion/expectedVersion → ClaimReasonChange. MEMBER요청, 자기seller FULFILLMENT검토, 환불 dispatch후 금액영향 변경금지 |
| X-03 | POST `/api/v1/admin/claims/{claimId}/return-tracking-events`; POST `/api/v1/admin/shipments/{shipmentId}/corrections` | 회수 eventId/sequence/status/occurredAt/version → Claim; correction approvalId/reason/기존eventId/정정사실/version → Shipment. SUPPORT, correction 2인승인. 공개 택배실연동 없음 |
| X-04 | GET `/api/v1/admin/seller-verifications`, `/product-review-requests`, `/review-moderation-requests`, `/concept-taxonomies`, `/settlement-account-change-requests` | cursor/limit/status → 해당 검수항목page(revision/document/evidence ID 포함). SUPPORT/CATALOG/FINANCE별 권한. 결정 API를 호출할 대상 조회용 |
| X-05 | GET seller 하위 `/settlement-account`, `/appeals`, `/appeals/{appealId}`; GET `/api/v1/uploads/{uploadId}` | 계좌 마스킹·pendingRequest/version, Appeal page/detail, Upload status. 자기seller OWNER/FINANCE는 계좌읽기, Appeal OWNER, upload owner만 |
| X-06 | POST `/api/v1/admin/administrators/{adminId}/role-change-requests`; POST 같은 경로 `/{requestId}/execute` | roles/reason/evidenceIds/version → approval; approvalId/version → admin 권한version. IAM, 다른IAM승인, 자기증대 금지. TOTP복구도 별도 `mfa-recovery-requests` 동일 승인방식 |
| X-07 | GET `/api/v1/admin/event-queues`; POST `/api/v1/admin/event-queues/{entryId}/replays`; GET `/api/v1/admin/recovery-jobs/{jobId}` | owner/consumer/status/cursor → redacted queue page; expectedHash/reason/evidenceIds/approvalId/version →202 jobId/statusUrl. 원body/key/sequence 수정불가, 금융replay는2인승인 |
| X-08 | POST `/api/v1/claims/{claimId}/exchange-conversions` | decision=ACCEPT_RETURN/KEEP_EXCHANGE,reason,expectedVersion → 연결Claim/기존상태. MEMBER, 재고불가 때 명시 동의; 7일예약만료 정책의 자동RETURN은 원동의/약관version 기록 |
| X-09 | POST `/api/v1/admin/orders/{orderId}/claim-exceptions` | ClaimCreate+reason/evidenceIds/approvalId/expectedVersion → Claim/financial hold. SUPPORT요청·다른SUPPORT승인, 확정후/기한후 예외, 원장인식조회 후 조정 |
| X-10 | POST `/internal/v1/server-behavior-events` (Discovery 내부) | eventId,type=WISHLIST/CART_ADD,memberPseudonym,product/revision/quantity?,occurredAt,sourceCommandId,consentVersion,analyticsOptIn=true →202 Accepted. Commerce service JWT만, 동의검사·eventId멱등. OrderPaid 구매집계는 Kafka만 |
| X-11 | POST `/api/v1/admin/search-rebuilds`; GET `/api/v1/admin/search-rebuilds/{generationId}` | snapshotId/reason →202 ProjectionRebuild; CATALOG. 기존 Discovery rebuild API를 대리, 같은 generation/key 재조회 |

OpenAPI에 반영한 승인 actionType은 X-03 `DELIVERY_CORRECTION`, X-09 `CLAIM_EXCEPTION`(SUPPORT), X-06 `MFA_RECOVERY`(IAM), X-07 `FINANCIAL_EVENT_REPLAY`(FINANCE)를 기존 enum/권한검증에 포함합니다. 승인용 payload에는 resource ID/version/원본hash/변경내용hash가 포함되며 reason만 승인해서 임의 다른 작업에 재사용할 수 없습니다. 이 enum 확장은 요구사항 SEC-02/OPS-01의 기존 2인 통제 원칙을 구체화합니다.

공통 운영 내부 API는 [operations-internal](../../contracts/operations-internal.openapi.json)에 정의합니다. Commerce facade가 실제 owner의 aud/scope로 호출하며 다른 서비스 DB를 조회하지 않습니다. `entryId`는 inbox의 consumer+event 행 또는 outbox 행 ID이고 replay는 원 hash/version/lease를 검사합니다. OUTBOX job 성공은 발행 ACK+PUBLISHED 저장, INBOX는 업무/no-op+checkpoint 저장입니다. 소비자별 최종 반영은 별도 확인합니다.

IAM MFA 복구는 2인승인 뒤 기존 secret/복구코드와 세션을 폐기하고 RE_ENROLLMENT_REQUIRED로 잠급니다. 본인확인된 로컬 운영 CLI로 재등록하기 전 관리자 API 접근을 허용하지 않습니다. 공개 API는 secret/복구코드를 반환하지 않습니다.

## 화면 수용 시험과 계약 fixture

FE-AT-01 세션 bootstrap 실패·401/403/404·복귀URL, FE-AT-02 옵션·0/소수/최대수량·stale가격, FE-AT-03 checkout 15분 경계·response loss·double click, FE-AT-04 UNKNOWN 새로고침/뒤로가기/provider전환차단, FE-AT-05 부분출고/부분환불/hold수량별 버튼, FE-AT-06 자기승인·역할회수·hash변경, FE-AT-07 업로드격리·private URL만료, FE-AT-08 작은화면/키보드/스크린리더 alert, FE-AT-09 area 독립 rollout/rollback, FE-AT-10 7일교환예약/반품동의 및 사유변경. mock/actual 플래그와 fixture 버전을 기록하고 AT-01/02/20/28/29/31/32와 연결합니다. 테스트 ID는 계획이며 실행 완료로 표시하지 않습니다.
