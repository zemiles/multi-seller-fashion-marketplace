# 04. 요구사항–구현 추적표

생성 기준일2026-09-22. [전체 기계 판독 추적표](traceability.json), [정책 정본](../requirements/README.md), [화면·보완 계약](05-screens.md). 원본 scripts/docs/trace-model.mjs와 OpenAPI x-requirements를 수정한 뒤 재생성합니다.

현재 PG4경로 외 업무 REST는 미구현, Payment 일부는 메모리 prototype입니다. AT/DT는 요구되는 시험이며 통과 표시가 아닙니다. SPECIFIED는 계약 명세 존재이며 X-01~11도 OpenAPI에 반영됐습니다. [보완 계약 연결](contract-extensions.json)에 실제 operationId를 기록합니다. CONTRACT_EXTENSION_REQUIRED는 이후 미반영 계약이 생겼을 때만 사용합니다. 단순 문서/빌드 성공으로 구현 상태를 바꾸지 않습니다. 테이블 목록은 관련 모델이며 타 서비스 DB 접근 권한이 아닙니다. API가 없는 규칙은 worker/공통middleware/검증gate에서 구현합니다.

| 요구 | owner / wave | 흐름 | API / event / table 수 | AT | 계약·현재 구현 |
| --- | --- | --- | --- | --- | --- |
| [SEC-01 고객·판매자 인증](../requirements/01-security-api.md) | Commerce / M1 | UC-01 | 8 / 0 / 5 | AT-01, AT-02 | SPECIFIED; NOT_IMPLEMENTED |
| [SEC-02 관리자·판매자 권한](../requirements/01-security-api.md) | Commerce / M1/M4 | UC-01 | 10 / 0 / 11 | AT-01 | SPECIFIED; NOT_IMPLEMENTED |
| [SEC-03 서비스 간 인증](../requirements/01-security-api.md) | 각 호출 owner / M1 | 공통 | 0 / 0 / 0 | AT-02 | SPECIFIED; NOT_IMPLEMENTED |
| [API-01 외부 진입과 직렬화](../requirements/01-security-api.md) | Commerce/각 owner / M1 | 공통 | 0 / 0 / 0 | DT-API-01 | SPECIFIED; NOT_IMPLEMENTED |
| [API-02 멱등성과 경합](../requirements/01-security-api.md) | 각 writer / M1/M2 | 공통 | 0 / 0 / 7 | AT-06 | SPECIFIED; NOT_IMPLEMENTED |
| [API-03 고객 진입 계약 목록](../requirements/01-security-api.md) | Commerce / M1~M5 | 전체 | 0 / 0 / 0 | DT-API-03 | SPECIFIED; NOT_IMPLEMENTED |
| [SEC-04 파일과 감사](../requirements/01-security-api.md) | Commerce / M1 | UC-01 | 6 / 0 / 4 | DT-SEC-04 | SPECIFIED; NOT_IMPLEMENTED |
| [COM-01 회원·주소](../requirements/02-commerce.md) | Commerce / M1 | UC-01 | 7 / 0 / 4 | DT-COM-01 | SPECIFIED; NOT_IMPLEMENTED |
| [COM-02 판매자·브랜드·카테고리](../requirements/02-commerce.md) | Commerce / M1/M4 | UC-01 | 16 / 0 / 20 | AT-32 | SPECIFIED; NOT_IMPLEMENTED |
| [CAT-01 상품 revision·SKU](../requirements/02-commerce.md) | Commerce / M3 | UC-01 | 16 / 2 / 12 | DT-CAT-01 | SPECIFIED; NOT_IMPLEMENTED |
| [INV-01 재고 원장과 예약](../requirements/02-commerce.md) | Commerce / M3 | UC-02/06 | 3 / 0 / 5 | AT-04 | SPECIFIED; NOT_IMPLEMENTED |
| [MONEY-01 가격·배송비와 배분](../requirements/02-commerce.md) | Commerce/Payment / M2/M3 | UC-02/05 | 0 / 0 / 6 | AT-03 | SPECIFIED; NOT_IMPLEMENTED |
| [ORD-01 장바구니](../requirements/02-commerce.md) | Commerce / M3 | UC-02 | 4 / 0 / 2 | DT-ORD-01 | SPECIFIED; NOT_IMPLEMENTED |
| [ORD-02 불변 checkout](../requirements/02-commerce.md) | Commerce / M3 | UC-02 | 2 / 0 / 5 | AT-04 | SPECIFIED; NOT_IMPLEMENTED |
| [ORD-03 주문 생성과 결제 시작](../requirements/02-commerce.md) | Commerce/Payment / M2/M3 | UC-02 | 2 / 0 / 9 | AT-05 | SPECIFIED; NOT_IMPLEMENTED |
| [ORD-04 주문 상태와 읽기 모델](../requirements/02-commerce.md) | Commerce / M3 | UC-02/04 | 4 / 9 / 17 | AT-16 | SPECIFIED; NOT_IMPLEMENTED |
| [ORD-05 만료·취소와 dispatch 경합](../requirements/02-commerce.md) | Commerce/Payment / M2/M3 | UC-03 | 0 / 0 / 5 | AT-07, AT-08 | SPECIFIED; NOT_IMPLEMENTED |
| [PG-01 연결 대상과 실제 지원 범위](../requirements/03-payment-pg.md) | PG1/PG2/Payment / M2 | UC-02/05 | 8 / 0 / 8 | AT-10 | SPECIFIED; CURRENT_PG_ROUTES_ONLY |
| [PAY-01 prepare와 주문 guard](../requirements/03-payment-pg.md) | Payment / M2 | UC-02 | 6 / 0 / 4 | AT-05 | SPECIFIED; IN_MEMORY_PROTOTYPE_ONLY |
| [PAY-02 승인 실행과 상태 전이](../requirements/03-payment-pg.md) | Payment / M2 | UC-02/04 | 1 / 6 / 10 | AT-09 | SPECIFIED; IN_MEMORY_PROTOTYPE_ONLY |
| [PAY-03 close-order handshake](../requirements/03-payment-pg.md) | Payment/Commerce / M2/M3 | UC-03 | 1 / 0 / 4 | DT-PAY-03 | SPECIFIED; NOT_IMPLEMENTED |
| [PAY-04 취소·환불과 배분](../requirements/03-payment-pg.md) | Payment/Commerce / M2/M3 | UC-05 | 2 / 6 / 13 | AT-11, AT-12, AT-13 | SPECIFIED; IN_MEMORY_PROTOTYPE_ONLY |
| [PAY-05 UNKNOWN 복구](../requirements/03-payment-pg.md) | Payment / M2 | UC-04/05 | 3 / 6 / 8 | AT-08, AT-09, AT-12 | SPECIFIED; NOT_IMPLEMENTED |
| [PG-02 기존 두 PG에 추가할 v1 완성 요구](../requirements/03-payment-pg.md) | PG1/PG2 / M2 | UC-02/04 | 4 / 0 / 8 | DT-PG-02 | SPECIFIED; NOT_IMPLEMENTED |
| [PG-03 webhook 서명·재전송](../requirements/03-payment-pg.md) | PG1/PG2/Payment / M2 | UC-04 | 1 / 0 / 5 | AT-14 | SPECIFIED; NOT_IMPLEMENTED |
| [PAY-06 PG 대사](../requirements/03-payment-pg.md) | Payment / M2 | UC-04 | 2 / 0 / 7 | AT-26 | SPECIFIED; NOT_IMPLEMENTED |
| [FUL-01 배송과 수량](../requirements/04-fulfillment-claims.md) | Commerce / M3 | UC-06 | 7 / 3 / 9 | AT-17 | SPECIFIED; NOT_IMPLEMENTED |
| [FUL-02 수량별 구매확정](../requirements/04-fulfillment-claims.md) | Commerce/Settlement / M3/M4 | UC-06/07 | 1 / 5 / 14 | AT-18, AT-19 | SPECIFIED; NOT_IMPLEMENTED |
| [CLM-01 공통 Claim 규칙](../requirements/04-fulfillment-claims.md) | Commerce / M3 | UC-05/06 | 15 / 3 / 11 | AT-17 | SPECIFIED; NOT_IMPLEMENTED |
| [CLM-02 환불액·배송비](../requirements/04-fulfillment-claims.md) | Commerce/Payment / M2/M3 | UC-05 | 2 / 0 / 15 | AT-20 | SPECIFIED; NOT_IMPLEMENTED |
| [CLM-03 교환](../requirements/04-fulfillment-claims.md) | Commerce / M3 | UC-06 | 1 / 0 / 13 | AT-21 | SPECIFIED; NOT_IMPLEMENTED |
| [EXP-01 찜](../requirements/04-fulfillment-claims.md) | Commerce/Discovery / M3/M5 | UC-08 | 4 / 0 / 1 | DT-EXP-01 | SPECIFIED; NOT_IMPLEMENTED |
| [EXP-02 리뷰·답글](../requirements/04-fulfillment-claims.md) | Commerce / M3 | UC-08 | 9 / 0 / 9 | AT-28 | SPECIFIED; NOT_IMPLEMENTED |
| [EXP-03 알림](../requirements/04-fulfillment-claims.md) | Commerce / M1/M3 | UC-08 | 4 / 5 / 3 | DT-EXP-03 | SPECIFIED; NOT_IMPLEMENTED |
| [SET-01 금융 사실과 원장](../requirements/05-settlement-operations.md) | Settlement/Commerce / M4 | UC-07 | 2 / 5 / 4 | AT-22 | SPECIFIED; NOT_IMPLEMENTED |
| [SET-02 정산 계산](../requirements/05-settlement-operations.md) | Settlement / M4 | UC-07 | 8 / 0 / 6 | AT-23, AT-24 | SPECIFIED; NOT_IMPLEMENTED |
| [SET-03 지급 승인·모의 은행](../requirements/05-settlement-operations.md) | Settlement/Commerce / M4 | UC-07 | 7 / 7 / 5 | AT-24, AT-25 | SPECIFIED; NOT_IMPLEMENTED |
| [SET-04 지급 후 환불·대사](../requirements/05-settlement-operations.md) | Settlement / M4 | UC-07 | 4 / 2 / 11 | AT-25, AT-26 | SPECIFIED; NOT_IMPLEMENTED |
| [OPS-01 운영·승인·감사](../requirements/05-settlement-operations.md) | Commerce / M4 | UC-01/07 | 28 / 0 / 17 | AT-32 | SPECIFIED; NOT_IMPLEMENTED |
| [OPS-02 API 작업 목록](../requirements/05-settlement-operations.md) | Commerce/각 owner / M1/M4 | UC-07 | 2 / 0 / 12 | DT-OPS-02 | SPECIFIED; NOT_IMPLEMENTED |
| [DIS-01 검색과 상품 projection](../requirements/06-discovery-frontend.md) | Discovery/Commerce / M5 | UC-08 | 8 / 2 / 6 | AT-31 | SPECIFIED; NOT_IMPLEMENTED |
| [DIS-02 concept·분석](../requirements/06-discovery-frontend.md) | Discovery / M5 | UC-08 | 12 / 1 / 6 | AT-28 | SPECIFIED; NOT_IMPLEMENTED |
| [DIS-03 행동 데이터](../requirements/06-discovery-frontend.md) | Discovery/Commerce / M5 | UC-08 | 6 / 3 / 3 | DT-DIS-03 | SPECIFIED; NOT_IMPLEMENTED |
| [FE-01 프론트 경계와 인증](../requirements/06-discovery-frontend.md) | Frontend/Commerce / M1~M5 | 전체 | 0 / 0 / 0 | AT-31 | SPECIFIED; NOT_IMPLEMENTED |
| [FE-02 화면 요구사항](../requirements/06-discovery-frontend.md) | Frontend / M1~M5 | 전체 | 0 / 0 / 0 | AT-29 | SPECIFIED; NOT_IMPLEMENTED |
| [FE-03 계약과 테스트](../requirements/06-discovery-frontend.md) | Frontend/각API owner / M1~M5 | 전체 | 0 / 0 / 0 | DT-FE-03 | SPECIFIED; NOT_IMPLEMENTED |
| [EVT-01 envelope·토픽·순서](../requirements/07-events-reliability.md) | 각 producer / M1 | 공통/UC-08 | 0 / 19 / 8 | DT-EVT-01 | SPECIFIED; NOT_IMPLEMENTED |
| [EVT-02 사건별 payload registry](../requirements/07-events-reliability.md) | 각 producer/consumer / M1 | 전체 | 0 / 19 / 12 | AT-27 | SPECIFIED; NOT_IMPLEMENTED |
| [EVT-03 outbox/inbox·재시도](../requirements/07-events-reliability.md) | 각 producer/consumer / M1 | 공통 | 6 / 19 / 16 | AT-15, AT-27 | SPECIFIED; NOT_IMPLEMENTED |
| [OPS-03 SLO·관측·스케줄](../requirements/07-events-reliability.md) | 각 owner/운영 / M1~M5 | 전체 | 0 / 0 / 0 | DT-OPS-03 | SPECIFIED; NOT_IMPLEMENTED |
| [OPS-04 보존·배포·복구](../requirements/07-events-reliability.md) | 운영/각 owner / M0~M7 | 전체 | 0 / 0 / 0 | AT-30 | SPECIFIED; NOT_IMPLEMENTED |
| [DATA-01 필요한 서비스-local 데이터 확장](../requirements/08-delivery-acceptance.md) | 각DB owner / M0~M7 | 전체 | 0 / 0 / 163 | DT-DATA-01 | SPECIFIED; NOT_IMPLEMENTED |
| [DEV-01 착수 순서와 gate](../requirements/08-delivery-acceptance.md) | 구현담당 / M0~M7 | 전체 | 0 / 0 / 0 | DT-DEV-01 | SPECIFIED; NOT_IMPLEMENTED |
| [TEST-01 필수 수용 시나리오](../requirements/08-delivery-acceptance.md) | 각기능담당 / M0~M7 | 전체 | 0 / 0 / 0 | DT-TEST-01 | SPECIFIED; NOT_IMPLEMENTED |
| [TEST-02 완료 산출물](../requirements/08-delivery-acceptance.md) | 검토담당 / M0~M7 | 전체 | 0 / 0 / 0 | DT-TEST-02 | SPECIFIED; NOT_IMPLEMENTED |

## 기능별 연결과 추가 합격 기준

### SEC-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:registerMember`, `commerce-public.openapi.json:login`, `commerce-public.openapi.json:getSession`, `commerce-public.openapi.json:logout`, `commerce-public.openapi.json:verifyEmail`, `commerce-public.openapi.json:resetPassword`, `commerce-public.openapi.json:requestVerification`, `commerce-public.openapi.json:requestPasswordReset`
- 모델: commerce.member, commerce.member_auth_identity, commerce.member_profile, commerce.verification_token, commerce.command_idempotency
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-01, AT-02
- DT-SEC-01 (NOT_RUN): 같은 token 두 번 소비 효과1회, 비밀번호 변경 후 모든 이전 sessionVersion 거부
- 보완계약: 직접 보완 항목 없음

### SEC-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:adminLogin`, `commerce-public.openapi.json:adminSession`, `commerce-public.openapi.json:adminLogout`, `commerce-public.openapi.json:listAdministrators`, `commerce-public.openapi.json:getAdministrator`, `commerce-public.openapi.json:requestAdminRoleChange`, `commerce-public.openapi.json:executeAdminRoleChange`, `commerce-public.openapi.json:requestAdminMfaRecovery`, `commerce-public.openapi.json:executeAdminMfaRecovery`, `commerce-public.openapi.json:getApproval`
- 모델: commerce.seller_member, commerce.admin_user, commerce.admin_role, commerce.admin_user_role, commerce.admin_permission, commerce.admin_role_permission, commerce.admin_approval_request, commerce.admin_approval_step, commerce.admin_audit_log, commerce.admin_recovery_code, commerce.approval_execution
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-01
- DT-SEC-02 (NOT_RUN): 마지막 OWNER 제거·자기승인·권한회수 후 실행 거부, SUPPORT 예외승인 분리
- 보완계약: X-06, X-09

### SEC-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-02
- DT-SEC-03 (NOT_RUN): 서비스별 iss/sub/aud/kid/scope/expiry allowlist와 actorContext 위조를 거부
- 보완계약: 직접 보완 항목 없음

### API-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-API-01 (NOT_RUN): 금액 문자열·소수·safe integer 초과 및 임의 타임존·미지정필드를 계약대로 거부
- 보완계약: 직접 보완 항목 없음

### API-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: commerce.consumer_inbox, payment.consumer_inbox, settlement.consumer_inbox, discovery.consumer_inbox, commerce.command_idempotency, payment.order_payment_guard, payment.payment_operation
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-06
- DT-API-02 (NOT_RUN): 동일 key/hash replay 같은resource, 변경payload409, rollback후 다른transaction 재조회
- 보완계약: 직접 보완 항목 없음

### API-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-API-03 (NOT_RUN): 공개 route가 internal/PG 주소·서비스credential을 노출하지 않고 소유권 검사
- 보완계약: X-01, X-02, X-03, X-04, X-05, X-06, X-07, X-08, X-09, X-10, X-11

### SEC-04

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createUpload`, `commerce-public.openapi.json:putUploadContent`, `commerce-public.openapi.json:completeUpload`, `commerce-public.openapi.json:getDownloadUrl`, `commerce-public.openapi.json:getSellerSettlementAccount`, `commerce-public.openapi.json:getUploadStatus`
- 모델: commerce.seller_document, commerce.claim_evidence, commerce.admin_audit_log, commerce.upload_asset
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-SEC-04 (NOT_RUN): 검역중 파일 연결 거부, 타인 private 다운로드 거부, 로그 secret0
- 보완계약: X-05

### COM-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:getMe`, `commerce-public.openapi.json:updateMe`, `commerce-public.openapi.json:withdrawMember`, `commerce-public.openapi.json:listAddresses`, `commerce-public.openapi.json:createAddress`, `commerce-public.openapi.json:updateAddress`, `commerce-public.openapi.json:deleteAddress`
- 모델: commerce.member, commerce.member_auth_identity, commerce.member_profile, commerce.shipping_address
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-COM-01 (NOT_RUN): 배송지20개·기본주소1개·진행거래 탈퇴거부, 과거 주소snapshot 불변
- 보완계약: 직접 보완 항목 없음

### COM-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createSeller`, `commerce-public.openapi.json:getSeller`, `commerce-public.openapi.json:updateSeller`, `commerce-public.openapi.json:createSellerDocument`, `commerce-public.openapi.json:createSellerVerification`, `commerce-public.openapi.json:createAccountChange`, `commerce-public.openapi.json:createInvitation`, `commerce-public.openapi.json:acceptSellerInvitation`, `commerce-public.openapi.json:listSellerMembers`, `commerce-public.openapi.json:updateSellerMember`, `commerce-public.openapi.json:removeSellerMember`, `commerce-public.openapi.json:decideSellerVerification`, `commerce-public.openapi.json:decideAccountChange`, `commerce-public.openapi.json:listSellerVerificationReviews`, `commerce-public.openapi.json:listAccountChangeReviews`, `commerce-public.openapi.json:getSellerSettlementAccount`
- 모델: commerce.seller, commerce.seller_member, commerce.seller_document, commerce.seller_verification, commerce.seller_settlement_account, commerce.brand, commerce.seller_brand_relation, commerce.brand_registration_request, commerce.category, commerce.seller_review_reply, commerce.admin_approval_request, commerce.admin_approval_step, commerce.seller_incident, commerce.seller_penalty, commerce.seller_health_metric, commerce.seller_appeal, commerce.seller_compliance_task, commerce.seller_compliance_task_item, commerce.seller_invitation, commerce.seller_financial_state
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-32
- DT-COM-02 (NOT_RUN): 초대1회/24시간·최종OWNER·계좌version·정지seller 신규구매와 기존처리 분리
- 보완계약: X-04, X-05

### CAT-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listCategories`, `commerce-public.openapi.json:listBrands`, `commerce-public.openapi.json:listProducts`, `commerce-public.openapi.json:getProduct`, `commerce-public.openapi.json:listSellerProducts`, `commerce-public.openapi.json:createProduct`, `commerce-public.openapi.json:getSellerProduct`, `commerce-public.openapi.json:editProduct`, `commerce-public.openapi.json:createProductRevision`, `commerce-public.openapi.json:submitProductReview`, `commerce-public.openapi.json:publishProduct`, `commerce-public.openapi.json:pauseProduct`, `commerce-public.openapi.json:listProductSkus`, `commerce-public.openapi.json:updateProductSkus`, `commerce-public.openapi.json:decideProductReview`, `commerce-public.openapi.json:listProductReviewRequests`
- 모델: commerce.brand, commerce.brand_registration_request, commerce.category, commerce.product, commerce.product_revision, commerce.product_image, commerce.product_feature, commerce.option_group, commerce.option_value, commerce.sku, commerce.sku_option_value, commerce.product_compliance_finding
- 이벤트: ProductRevisionPublished, ProductAvailabilityChanged
- 수용시험: 기존 AT 직접연결 없음
- DT-CAT-01 (NOT_RUN): 검수중 기존게시본 유지, 옵션조합 중복/미검증이미지/비활성카테고리 게시거부
- 보완계약: X-04

### INV-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createCheckout`, `commerce-public.openapi.json:listInventory`, `commerce-public.openapi.json:adjustInventory`
- 모델: commerce.inventory, commerce.inventory_ledger, commerce.inventory_reservation, commerce.inventory_reservation_item, commerce.order_item_unit
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-04
- DT-INV-01 (NOT_RUN): 예약합계=reserved, 승인시 소비1회, 출고시 재차감0, 검수 입고1회
- 보완계약: 직접 보완 항목 없음

### MONEY-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: commerce.checkout_item, commerce.order_item, commerce.order_charge, payment.payment_item, commerce.order_item_unit, payment.refund_unit_allocation
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-03
- DT-MONEY-01 (NOT_RUN): 10001원·3단위 및 fee1000 배분의 부분/일괄 합계가 동일
- 보완계약: 직접 보완 항목 없음

### ORD-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:getCart`, `commerce-public.openapi.json:putCartItem`, `commerce-public.openapi.json:deleteCartItem`, `discovery-internal.openapi.json:ingestServerBehavior`
- 모델: commerce.cart, commerce.cart_item
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-ORD-01 (NOT_RUN): 주문생성 사이 추가한 cart 수량을 보존하고 stale version을 거부
- 보완계약: 직접 보완 항목 없음

### ORD-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createCheckout`, `commerce-public.openapi.json:getCheckout`
- 모델: commerce.checkout, commerce.checkout_shipping_group, commerce.checkout_item, commerce.inventory_reservation, commerce.inventory_reservation_item
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-04
- DT-ORD-02 (NOT_RUN): 최대3개 quote, 실패 전체rollback, 15분 가격존중·긴급판매금지 우선
- 보완계약: 직접 보완 항목 없음

### ORD-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createOrder`, `commerce-public.openapi.json:startOrderPayment`
- 모델: commerce.orders, commerce.order_shipping_group, commerce.order_item, commerce.order_charge, commerce.order_state_event, payment.payment_attempt, commerce.payment_dispatch_intent, commerce.order_item_unit, payment.order_payment_guard
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-05
- DT-ORD-03 (NOT_RUN): C2/C3/P2/P3/C4 각commit후 crash 시 같은주문·결제·예약효과1회
- 보완계약: 직접 보완 항목 없음

### ORD-04

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listOrders`, `commerce-public.openapi.json:getOrder`, `commerce-public.openapi.json:getOrderPaymentStatus`, `commerce-public.openapi.json:getOrderForSupport`
- 모델: commerce.inventory_reservation, commerce.inventory_reservation_item, commerce.orders, commerce.order_shipping_group, commerce.order_item, commerce.order_charge, commerce.order_state_event, commerce.claim, commerce.claim_item, commerce.claim_item_source_allocation, commerce.claim_evidence, commerce.claim_reason_change, commerce.claim_review, commerce.claim_event, commerce.claim_quote, commerce.order_item_unit, commerce.claim_item_unit
- 이벤트: OrderPaid, ShipmentDelivered, ClaimStatusChanged, PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed
- 수용시험: AT-16
- DT-ORD-04 (NOT_RUN): 일부배송/환불/확정에서 order/payment/recovery/claim 상태를 각각 반환
- 보완계약: 직접 보완 항목 없음

### ORD-05

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: commerce.inventory_reservation, commerce.inventory_reservation_item, commerce.orders, commerce.payment_dispatch_intent, payment.order_payment_guard
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-07, AT-08
- DT-ORD-05 (NOT_RUN): close-before-prepare 및 P2-after-expiry 거부, UNKNOWN예약보호
- 보완계약: 직접 보완 항목 없음

### PG-01

- 상태: SPECIFIED / CURRENT_PG_ROUTES_ONLY
- API: `pg-current.openapi.json:pgApprove`, `pg-current.openapi.json:pgCancel`, `pg-current.openapi.json:pgRefund`, `pg-current.openapi.json:pgGetPayment`, `pg-target.openapi.json:pgApprove`, `pg-target.openapi.json:pgCancel`, `pg-target.openapi.json:pgRefund`, `pg-target.openapi.json:pgGetPayment`
- 모델: pg1.pg_payment, pg1.pg_transaction, pg2.pg_payment, pg2.pg_transaction, pg1.pg_webhook_outbox, pg1.pg_fault_scenario, pg2.pg_webhook_outbox, pg2.pg_fault_scenario
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-10
- DT-PG-01 (NOT_RUN): 두 PG 독립 DB와 기존4경로 replay·환불·전액VOID 검증, 실금융효과0
- 보완계약: 직접 보완 항목 없음

### PAY-01

- 상태: SPECIFIED / IN_MEMORY_PROTOTYPE_ONLY
- API: `commerce-public.openapi.json:startOrderPayment`, `payment-service.openapi.json:preparePaymentAttempt`, `payment-service.openapi.json:getPaymentAttempt`, `payment-service.openapi.json:getPayment`, `payment-service.openapi.json:cancelPayment`, `payment-service.openapi.json:getPaymentOperation`
- 모델: payment.payment_attempt, payment.order_payment_guard, payment.payment_operation, payment.payment_operation_result
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-05
- DT-PAY-01 (NOT_RUN): provider 변경으로 order guard 우회 불가, 성공후환불도 재승인 불가
- 보완계약: 직접 보완 항목 없음

### PAY-02

- 상태: SPECIFIED / IN_MEMORY_PROTOTYPE_ONLY
- API: `payment-service.openapi.json:approvePaymentAttempt`
- 모델: payment.payment_attempt, payment.payment, payment.payment_item, payment.payment_charge_allocation, payment.payment_transaction, payment.payment_transaction_allocation, payment.outbox_event, payment.order_payment_guard, payment.payment_operation, payment.payment_operation_result
- 이벤트: PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed
- 수용시험: AT-09
- DT-PAY-02 (NOT_RUN): immutable resultVersion 동기/event 일치, 최신 환불snapshot을 신규승인으로 오인하지 않음
- 보완계약: 직접 보완 항목 없음

### PAY-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `payment-service.openapi.json:closeOrderPaymentGuard`
- 모델: payment.payment_attempt, payment.order_payment_guard, payment.payment_operation, payment.payment_operation_result
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-PAY-03 (NOT_RUN): CLOSED tombstone 부재행에도생성, IN_FLIGHT와NO_EFFECT 증거구분
- 보완계약: 직접 보완 항목 없음

### PAY-04

- 상태: SPECIFIED / IN_MEMORY_PROTOTYPE_ONLY
- API: `payment-service.openapi.json:getRefund`, `payment-service.openapi.json:requestRefund`
- 모델: payment.payment_attempt, payment.payment, payment.payment_item, payment.payment_charge_allocation, payment.payment_transaction, payment.payment_transaction_allocation, payment.refund, payment.refund_item, payment.refund_charge_adjustment, payment.order_payment_guard, payment.payment_operation, payment.payment_operation_result, payment.refund_unit_allocation
- 이벤트: PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed
- 수용시험: AT-11, AT-12, AT-13
- DT-PAY-04 (NOT_RUN): VOID/REFUND 산식·unit/charge 배분·단일dispatch·금액예약 한도
- 보완계약: 직접 보완 항목 없음

### PAY-05

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:getOrderPaymentStatus`, `commerce-public.openapi.json:recoverPaymentOperation`, `commerce-public.openapi.json:listPaymentOperations`
- 모델: payment.payment_attempt, payment.refund, payment.refund_item, payment.refund_charge_adjustment, payment.pg_webhook_inbox, payment.payment_operation, payment.payment_operation_result, payment.refund_unit_allocation
- 이벤트: PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed
- 수용시험: AT-08, AT-09, AT-12
- DT-PAY-05 (NOT_RUN): 24h write재시도중지/read조회유지, no-effect증거없는404는UNKNOWN
- 보완계약: 직접 보완 항목 없음

### PG-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `pg-target.openapi.json:pgGetByMerchant`, `pg-target.openapi.json:pgGetPaymentTransactions`, `pg-target.openapi.json:pgListTransactions`, `pg-target.openapi.json:pgSetFaultScenario`
- 모델: pg1.pg_payment, pg1.pg_transaction, pg2.pg_payment, pg2.pg_transaction, pg1.pg_webhook_outbox, pg1.pg_fault_scenario, pg2.pg_webhook_outbox, pg2.pg_fault_scenario
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-PG-02 (NOT_RUN): fixed asOf receipt cursor 완전성, commit-then-timeout·prod fault거부
- 보완계약: 직접 보완 항목 없음

### PG-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `payment-service.openapi.json:receivePaymentWebhook`
- 모델: payment.pg_webhook_inbox, payment.payment_operation, payment.payment_operation_result, pg1.pg_webhook_outbox, pg2.pg_webhook_outbox
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-14
- DT-PG-03 (NOT_RUN): rawbody/key/timestamp 서명, 같은event 다른body409, poll경합효과1회
- 보완계약: 직접 보완 항목 없음

### PAY-06

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:resolveDiscrepancy`, `commerce-public.openapi.json:listDiscrepancies`
- 모델: payment.payment_transaction, payment.payment_transaction_allocation, payment.payment_operation, payment.payment_operation_result, payment.pg_reconciliation_run, payment.pg_reconciliation_receipt, payment.pg_reconciliation_discrepancy
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-26
- DT-PAY-06 (NOT_RUN): 전일+3일 비교, provider/transaction identity, 불일치 write차단·중복보정0
- 보완계약: 직접 보완 항목 없음

### FUL-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listSellerOrders`, `commerce-public.openapi.json:listSellerShipments`, `commerce-public.openapi.json:createShipment`, `commerce-public.openapi.json:handoverShipment`, `commerce-public.openapi.json:recordTrackingEvent`, `commerce-public.openapi.json:recordReturnTracking`, `commerce-public.openapi.json:correctShipment`
- 모델: commerce.inventory, commerce.inventory_ledger, commerce.inventory_reservation, commerce.inventory_reservation_item, commerce.shipment, commerce.shipment_item, commerce.shipment_event, commerce.order_item_unit, commerce.shipment_item_unit
- 이벤트: OrderPaid, ShipmentDelivered, ClaimStatusChanged
- 수용시험: AT-17
- DT-FUL-01 (NOT_RUN): 인계/취소 경합·carrier sequence 역행·교환generation 중복출고0
- 보완계약: X-03

### FUL-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:confirmPurchase`
- 모델: commerce.purchase_confirmation_state, commerce.purchase_confirmation_event, commerce.purchase_confirmation_hold, commerce.claim, commerce.claim_item, commerce.claim_item_source_allocation, commerce.claim_evidence, commerce.claim_reason_change, commerce.claim_review, commerce.claim_event, commerce.claim_quote, commerce.order_item_unit, commerce.claim_item_unit, commerce.purchase_confirmation_unit
- 이벤트: PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged, SellerPenaltyApplied
- 수용시험: AT-18, AT-19
- DT-FUL-02 (NOT_RUN): +191:59:59 미확정/+192h 대상, held unit만 제외·완료수량중복0
- 보완계약: 직접 보완 항목 없음

### CLM-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createClaim`, `commerce-public.openapi.json:getClaim`, `commerce-public.openapi.json:withdrawClaim`, `commerce-public.openapi.json:listSellerClaims`, `commerce-public.openapi.json:decideSellerClaim`, `commerce-public.openapi.json:quoteClaim`, `commerce-public.openapi.json:requestClaimReasonChange`, `commerce-public.openapi.json:listMyClaimReasonChanges`, `commerce-public.openapi.json:getSellerClaim`, `commerce-public.openapi.json:listSellerClaimReasonChanges`, `commerce-public.openapi.json:decideClaimReasonChange`, `commerce-public.openapi.json:recordReturnTracking`, `commerce-public.openapi.json:getOrderForSupport`, `commerce-public.openapi.json:getClaimForSupport`, `commerce-public.openapi.json:createClaimException`
- 모델: commerce.purchase_confirmation_hold, commerce.claim, commerce.claim_item, commerce.claim_item_source_allocation, commerce.claim_evidence, commerce.claim_reason_change, commerce.claim_review, commerce.claim_event, commerce.claim_quote, commerce.claim_item_unit, commerce.active_unit_claim_guard
- 이벤트: OrderPaid, ShipmentDelivered, ClaimStatusChanged
- 수용시험: AT-17
- DT-CLM-01 (NOT_RUN): 168h 경계·동일unit 열린claim1개, effects후철회금지·예외2인승인
- 보완계약: X-01, X-02, X-09

### CLM-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:inspectClaim`, `commerce-public.openapi.json:quoteClaim`
- 모델: commerce.order_charge, commerce.claim, commerce.claim_item, commerce.claim_item_source_allocation, commerce.claim_evidence, commerce.claim_reason_change, commerce.claim_review, commerce.claim_event, payment.refund, payment.refund_item, payment.refund_charge_adjustment, commerce.claim_quote, commerce.order_item_unit, commerce.claim_item_unit, payment.refund_unit_allocation
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-20
- DT-CLM-02 (NOT_RUN): 복수claim 합계전량의 배송비1회, 구매자/혼합귀책은 배송비유지
- 보완계약: 직접 보완 항목 없음

### CLM-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:convertExchange`
- 모델: commerce.inventory_reservation, commerce.inventory_reservation_item, commerce.claim, commerce.claim_item, commerce.claim_item_source_allocation, commerce.claim_evidence, commerce.claim_reason_change, commerce.claim_review, commerce.claim_event, commerce.exchange_line, commerce.claim_quote, commerce.shipment_item_unit, commerce.claim_item_unit
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-21
- DT-CLM-03 (NOT_RUN): 동일상품/실단가·1회교환, 7일미출고만료와 대체품 인계 경합
- 보완계약: X-08

### EXP-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listWishlist`, `commerce-public.openapi.json:putWishlist`, `commerce-public.openapi.json:deleteWishlist`, `discovery-internal.openapi.json:ingestServerBehavior`
- 모델: commerce.wishlist_item
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-EXP-01 (NOT_RUN): PUT/DELETE멱등·품절tombstone·서버만 행동변환 발행
- 보완계약: 직접 보완 항목 없음

### EXP-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listReviewEligibility`, `commerce-public.openapi.json:createReview`, `commerce-public.openapi.json:updateReview`, `commerce-public.openapi.json:deleteReview`, `commerce-public.openapi.json:listProductReviews`, `commerce-public.openapi.json:createSellerReviewReply`, `commerce-public.openapi.json:updateSellerReviewReply`, `commerce-public.openapi.json:moderateReview`, `commerce-public.openapi.json:listReviewModerationRequests`
- 모델: commerce.purchase_confirmation_state, commerce.purchase_confirmation_event, commerce.purchase_confirmation_hold, commerce.review_eligibility, commerce.review, commerce.review_revision, commerce.review_image, commerce.seller_review_reply, commerce.purchase_confirmation_unit
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-28
- DT-EXP-02 (NOT_RUN): orderItem당리뷰1, 수정revision검수, 반품후기 자동삭제0
- 보완계약: X-04

### EXP-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listNotifications`, `commerce-public.openapi.json:readNotification`, `commerce-public.openapi.json:getNotificationPreferences`, `commerce-public.openapi.json:updateNotificationPreferences`
- 모델: commerce.notification, commerce.notification_preference, commerce.notification_delivery
- 이벤트: OrderPaid, ShipmentDelivered, ClaimStatusChanged, SettlementPaid, PayoutUnknown
- 수용시험: 기존 AT 직접연결 없음
- DT-EXP-03 (NOT_RUN): 수신자/event/template1회, opt-out과거래알림분리, delivery실패 거래rollback0
- 보완계약: 직접 보완 항목 없음

### SET-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listSellerLedger`, `settlement-internal.openapi.json:queryLedger`
- 모델: settlement.seller_ledger_entry, settlement.consumer_inbox, settlement.consumer_stream_checkpoint, settlement.seller_recognition_unit
- 이벤트: PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged, SellerPenaltyApplied
- 수용시험: AT-22
- DT-SET-01 (NOT_RUN): 확정unit원장만, fee0행없음, rawrefund와financialadjustment중복차감0
- 보완계약: 직접 보완 항목 없음

### SET-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listSellerSettlements`, `commerce-public.openapi.json:getSellerSettlement`, `commerce-public.openapi.json:calculateSettlement`, `commerce-public.openapi.json:listAdminSettlements`, `commerce-public.openapi.json:getAdminSettlement`, `settlement-internal.openapi.json:querySettlements`, `settlement-internal.openapi.json:querySettlement`, `settlement-internal.openapi.json:runSettlementCalculation`
- 모델: settlement.seller_ledger_entry, settlement.settlement, settlement.settlement_allocation, settlement.settlement_hold, settlement.settlement_payout_attempt, settlement.seller_carry_forward
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-23, AT-24
- DT-SET-02 (NOT_RUN): cutoff/늦은원장·소액/음수이월·hold 전후net 의미·중복배분0
- 보완계약: 직접 보완 항목 없음

### SET-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-internal.openapi.json:getFinancialBarrier`, `commerce-internal.openapi.json:createPayoutFence`, `commerce-internal.openapi.json:consumePayoutFence`, `commerce-public.openapi.json:requestSettlementApproval`, `commerce-public.openapi.json:requestPayout`, `settlement-internal.openapi.json:dispatchSimulatedPayout`, `settlement-internal.openapi.json:queryPayout`
- 모델: settlement.settlement_payout_attempt, commerce.seller_financial_state, commerce.payout_fence, commerce.approval_execution, settlement.simulated_bank_receipt
- 이벤트: PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged, SellerPenaltyApplied, SettlementPaid, PayoutUnknown
- 수용시험: AT-24, AT-25
- DT-SET-03 (NOT_RUN): fence30초/permit replay/2인승인·bank commit후timeout 같은receipt복구
- 보완계약: 직접 보완 항목 없음

### SET-04

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:resolveDiscrepancy`, `commerce-public.openapi.json:listDiscrepancies`, `settlement-internal.openapi.json:queryBankDiscrepancies`, `settlement-internal.openapi.json:resolveBankDiscrepancy`
- 모델: settlement.reconciliation_file, settlement.reconciliation_raw_row, settlement.reconciliation_run, settlement.reconciliation_match, settlement.reconciliation_discrepancy, settlement.bank_deposit_match, settlement.seller_carry_forward, settlement.simulated_bank_receipt, settlement.bank_reconciliation_run, settlement.bank_reconciliation_receipt, settlement.bank_reconciliation_discrepancy
- 이벤트: SettlementPaid, PayoutUnknown
- 수용시험: AT-25, AT-26
- DT-SET-04 (NOT_RUN): 지급후refund 음수채무보존, legacy PG대사를 bank대사로 오인하지 않음
- 보완계약: 직접 보완 항목 없음

### OPS-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-internal.openapi.json:getApprovalForExecution`, `commerce-internal.openapi.json:consumeApproval`, `commerce-public.openapi.json:createSellerAppeal`, `commerce-public.openapi.json:listSellerAppeals`, `commerce-public.openapi.json:createApproval`, `commerce-public.openapi.json:listApprovals`, `commerce-public.openapi.json:decideApproval`, `commerce-public.openapi.json:createIncident`, `commerce-public.openapi.json:listIncidents`, `commerce-public.openapi.json:createPenalty`, `commerce-public.openapi.json:listPenalties`, `commerce-public.openapi.json:createComplianceRule`, `commerce-public.openapi.json:listComplianceRules`, `commerce-public.openapi.json:decideAppeal`, `commerce-public.openapi.json:listAuditLogs`, `commerce-public.openapi.json:updateIncident`, `commerce-public.openapi.json:correctShipment`, `commerce-public.openapi.json:getSellerAppeal`, `commerce-public.openapi.json:requestAdminRoleChange`, `commerce-public.openapi.json:executeAdminRoleChange`, `commerce-public.openapi.json:requestAdminMfaRecovery`, `commerce-public.openapi.json:executeAdminMfaRecovery`, `commerce-public.openapi.json:getApproval`, `commerce-public.openapi.json:replayEventQueue`, `commerce-public.openapi.json:createClaimException`, `operations-internal.openapi.json:queryLocalEventQueues`, `operations-internal.openapi.json:replayLocalEventQueue`, `operations-internal.openapi.json:queryLocalRecoveryJob`
- 모델: commerce.admin_user, commerce.admin_role, commerce.admin_user_role, commerce.admin_permission, commerce.admin_role_permission, commerce.admin_approval_request, commerce.admin_approval_step, commerce.admin_audit_log, commerce.seller_incident, commerce.seller_penalty, commerce.seller_appeal, commerce.compliance_rule, commerce.compliance_rule_version, commerce.seller_compliance_task, commerce.seller_compliance_task_item, commerce.admin_recovery_code, commerce.approval_execution
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-32
- DT-OPS-01 (NOT_RUN): 동일actor 승인금지·action/hash고정·재실행같은action 효과1회
- 보완계약: X-06, X-07, X-09

### OPS-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listEventQueues`, `commerce-public.openapi.json:getRecoveryJob`
- 모델: commerce.outbox_event, payment.outbox_event, settlement.outbox_event, discovery.outbox_event, commerce.consumer_inbox, commerce.event_recovery_job, payment.consumer_inbox, payment.event_recovery_job, settlement.consumer_inbox, settlement.event_recovery_job, discovery.consumer_inbox, discovery.event_recovery_job
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-OPS-02 (NOT_RUN): 운영목록과조치가 역할·owner·evidence·version·approval에 연결
- 보완계약: X-04, X-05, X-07

### DIS-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-internal.openapi.json:getCatalogSnapshot`, `commerce-public.openapi.json:listProducts`, `commerce-public.openapi.json:searchProducts`, `commerce-public.openapi.json:createSearchRebuild`, `commerce-public.openapi.json:getSearchRebuild`, `discovery-internal.openapi.json:querySearchProducts`, `discovery-internal.openapi.json:rebuildProjection`, `discovery-internal.openapi.json:queryProjectionRebuild`
- 모델: discovery.search_request, discovery.search_impression, discovery.consumer_inbox, discovery.consumer_stream_checkpoint, discovery.search_projection_generation, discovery.search_product_projection
- 이벤트: ProductRevisionPublished, ProductAvailabilityChanged
- 수용시험: AT-31
- DT-DIS-01 (NOT_RUN): generation snapshot/catch-up/atomic switch, tombstone·sourceVersion 보존
- 보완계약: X-11

### DIS-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:createProductAnalysis`, `commerce-public.openapi.json:getProductAnalysis`, `commerce-public.openapi.json:reviewProductConcept`, `commerce-public.openapi.json:createTaxonomy`, `commerce-public.openapi.json:listConceptTaxonomies`, `commerce-public.openapi.json:publishTaxonomy`, `discovery-internal.openapi.json:queueAnalysis`, `discovery-internal.openapi.json:queryAnalysis`, `discovery-internal.openapi.json:applyConceptReview`, `discovery-internal.openapi.json:addTaxonomy`, `discovery-internal.openapi.json:queryTaxonomies`, `discovery-internal.openapi.json:activateTaxonomy`
- 모델: discovery.concept_taxonomy_version, discovery.concept, discovery.concept_alias, discovery.product_analysis_run, discovery.product_concept, discovery.product_concept_evidence
- 이벤트: ProductAnalysisCompleted
- 수용시험: AT-28
- DT-DIS-02 (NOT_RUN): 같은 입력 결정적결과, 근거·버전추적, stale revision 무효
- 보완계약: X-04

### DIS-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:getNotificationPreferences`, `commerce-public.openapi.json:updateNotificationPreferences`, `commerce-public.openapi.json:recordBehavior`, `commerce-public.openapi.json:recordBehaviorBatch`, `discovery-internal.openapi.json:ingestBehavior`, `discovery-internal.openapi.json:ingestServerBehavior`
- 모델: discovery.search_request, discovery.search_impression, discovery.user_behavior_event
- 이벤트: OrderPaid, ShipmentDelivered, ClaimStatusChanged
- 수용시험: 기존 AT 직접연결 없음
- DT-DIS-03 (NOT_RUN): 동의없음 지속개인추적0, 브라우저 PURCHASE/WISHLIST/CART_ADD 위조거부
- 보완계약: X-10

### FE-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-31
- DT-FE-01 (NOT_RUN): 3개area 경계 및 최종3artifact 독립rollout/rollback, 쿠키/CSRF
- 보완계약: 직접 보완 항목 없음

### FE-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-29
- DT-FE-02 (NOT_RUN): SF/SE/AD 화면 loading/empty/error/권한·UNKNOWN·360px·keyboard
- 보완계약: X-01, X-02, X-03, X-04, X-05, X-06, X-07, X-08, X-09, X-10, X-11

### FE-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-FE-03 (NOT_RUN): OpenAPI DTO/runtime검증·mock버전·실제 PG1/PG2 E2E 구분
- 보완계약: 직접 보완 항목 없음

### EVT-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: commerce.outbox_event, payment.outbox_event, settlement.outbox_event, discovery.outbox_event, commerce.event_stream_sequence, payment.event_stream_sequence, settlement.event_stream_sequence, discovery.event_stream_sequence
- 이벤트: ProductRevisionPublished, ProductAvailabilityChanged, OrderPaid, ShipmentDelivered, ClaimStatusChanged, PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged, SellerPenaltyApplied, PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed, SettlementPaid, PayoutUnknown, ProductAnalysisCompleted
- 수용시험: 기존 AT 직접연결 없음
- DT-EVT-01 (NOT_RUN): 19종 envelope/producer/topic/key/version/hash의 정합과 발행순서
- 보완계약: 직접 보완 항목 없음

### EVT-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: commerce.outbox_event, payment.outbox_event, settlement.outbox_event, discovery.outbox_event, commerce.consumer_inbox, commerce.consumer_stream_checkpoint, payment.consumer_inbox, payment.consumer_stream_checkpoint, settlement.consumer_inbox, settlement.consumer_stream_checkpoint, discovery.consumer_inbox, discovery.consumer_stream_checkpoint
- 이벤트: ProductRevisionPublished, ProductAvailabilityChanged, OrderPaid, ShipmentDelivered, ClaimStatusChanged, PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged, SellerPenaltyApplied, PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed, SettlementPaid, PayoutUnknown, ProductAnalysisCompleted
- 수용시험: AT-27
- DT-EVT-02 (NOT_RUN): 19종 payload schema·산술·known ignored type checkpoint·unknown quarantine
- 보완계약: 직접 보완 항목 없음

### EVT-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: `commerce-public.openapi.json:listEventQueues`, `commerce-public.openapi.json:replayEventQueue`, `commerce-public.openapi.json:getRecoveryJob`, `operations-internal.openapi.json:queryLocalEventQueues`, `operations-internal.openapi.json:replayLocalEventQueue`, `operations-internal.openapi.json:queryLocalRecoveryJob`
- 모델: commerce.outbox_event, payment.outbox_event, settlement.outbox_event, discovery.outbox_event, commerce.consumer_inbox, commerce.consumer_stream_checkpoint, commerce.event_recovery_job, payment.consumer_inbox, payment.consumer_stream_checkpoint, payment.event_recovery_job, settlement.consumer_inbox, settlement.consumer_stream_checkpoint, settlement.event_recovery_job, discovery.consumer_inbox, discovery.consumer_stream_checkpoint, discovery.event_recovery_job
- 이벤트: ProductRevisionPublished, ProductAvailabilityChanged, OrderPaid, ShipmentDelivered, ClaimStatusChanged, PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged, SellerPenaltyApplied, PaymentApproved, PaymentFailed, PaymentUnknown, PaymentVoided, RefundSucceeded, RefundFailed, SettlementPaid, PayoutUnknown, ProductAnalysisCompleted
- 수용시험: AT-15, AT-27
- DT-EVT-03 (NOT_RUN): ACK/DB commit 사이 crash·lease회수·gap/DLQ불변replay 효과1회
- 보완계약: X-07

### OPS-03

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-OPS-03 (NOT_RUN): 고정부하p95/p99·unknown age·queue경보·clock주입·민감로그0
- 보완계약: 직접 보완 항목 없음

### OPS-04

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: AT-30
- DT-OPS-04 (NOT_RUN): 서로다른시점DB복원+dedup/receipt대사, RPO/RTO 실제측정·보존정책
- 보완계약: 직접 보완 항목 없음

### DATA-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: commerce.member, commerce.member_auth_identity, commerce.member_profile, commerce.shipping_address, commerce.seller, commerce.seller_member, commerce.seller_document, commerce.seller_verification, commerce.seller_settlement_account, commerce.brand, commerce.seller_brand_relation, commerce.brand_registration_request, commerce.category, commerce.product, commerce.product_revision, commerce.product_image, commerce.product_feature, commerce.option_group, commerce.option_value, commerce.sku, commerce.sku_option_value, commerce.inventory, commerce.inventory_ledger, commerce.cart, commerce.cart_item, commerce.checkout, commerce.checkout_shipping_group, commerce.checkout_item, commerce.inventory_reservation, commerce.inventory_reservation_item, commerce.orders, commerce.order_shipping_group, commerce.order_item, commerce.order_charge, commerce.order_state_event, commerce.shipment, commerce.shipment_item, commerce.shipment_event, commerce.purchase_confirmation_state, commerce.purchase_confirmation_event, commerce.purchase_confirmation_hold, commerce.claim, commerce.claim_item, commerce.claim_item_source_allocation, commerce.claim_evidence, commerce.claim_reason_change, commerce.claim_review, commerce.claim_event, commerce.exchange_line, commerce.review_eligibility, commerce.review, commerce.review_revision, commerce.review_image, commerce.seller_review_reply, commerce.wishlist_item, commerce.notification, commerce.notification_preference, commerce.notification_delivery, commerce.admin_user, commerce.admin_role, commerce.admin_user_role, commerce.admin_permission, commerce.admin_role_permission, commerce.admin_approval_request, commerce.admin_approval_step, commerce.admin_audit_log, commerce.seller_incident, commerce.seller_penalty, commerce.seller_health_metric, commerce.seller_appeal, commerce.compliance_rule, commerce.compliance_rule_version, commerce.product_compliance_finding, commerce.seller_compliance_task, commerce.seller_compliance_task_item, commerce.outbox_event, payment.payment_attempt, payment.payment, payment.payment_item, payment.payment_charge_allocation, payment.payment_transaction, payment.payment_transaction_allocation, payment.refund, payment.refund_item, payment.refund_charge_adjustment, payment.pg_webhook_inbox, payment.outbox_event, settlement.seller_ledger_entry, settlement.settlement, settlement.settlement_allocation, settlement.settlement_hold, settlement.settlement_payout_attempt, settlement.reconciliation_file, settlement.reconciliation_raw_row, settlement.reconciliation_run, settlement.reconciliation_match, settlement.reconciliation_discrepancy, settlement.bank_deposit_match, settlement.outbox_event, discovery.concept_taxonomy_version, discovery.concept, discovery.concept_alias, discovery.product_analysis_run, discovery.product_concept, discovery.product_concept_evidence, discovery.search_request, discovery.search_impression, discovery.user_behavior_event, discovery.outbox_event, pg1.pg_payment, pg1.pg_transaction, pg2.pg_payment, pg2.pg_transaction, commerce.consumer_inbox, commerce.consumer_stream_checkpoint, commerce.event_stream_sequence, commerce.event_recovery_job, payment.consumer_inbox, payment.consumer_stream_checkpoint, payment.event_stream_sequence, payment.event_recovery_job, settlement.consumer_inbox, settlement.consumer_stream_checkpoint, settlement.event_stream_sequence, settlement.event_recovery_job, discovery.consumer_inbox, discovery.consumer_stream_checkpoint, discovery.event_stream_sequence, discovery.event_recovery_job, commerce.admin_recovery_code, commerce.verification_token, commerce.seller_invitation, commerce.command_idempotency, commerce.claim_quote, commerce.payment_dispatch_intent, commerce.order_item_unit, commerce.shipment_item_unit, commerce.claim_item_unit, commerce.active_unit_claim_guard, commerce.purchase_confirmation_unit, commerce.seller_financial_state, commerce.payout_fence, commerce.approval_execution, commerce.upload_asset, payment.order_payment_guard, payment.payment_operation, payment.payment_operation_result, payment.refund_unit_allocation, payment.pg_reconciliation_run, payment.pg_reconciliation_receipt, payment.pg_reconciliation_discrepancy, settlement.seller_recognition_unit, settlement.seller_carry_forward, settlement.simulated_bank_receipt, settlement.bank_reconciliation_run, settlement.bank_reconciliation_receipt, settlement.bank_reconciliation_discrepancy, pg1.pg_webhook_outbox, pg1.pg_fault_scenario, pg2.pg_webhook_outbox, pg2.pg_fault_scenario, discovery.search_projection_generation, discovery.search_product_projection
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-DATA-01 (NOT_RUN): 빈DB/기존DB upgrade·backfill중단재개·누락FK0·불변합계·schema의미차이
- 보완계약: 직접 보완 항목 없음

### DEV-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-DEV-01 (NOT_RUN): A~H 단계gate 증거와 선행영속guard/인증을 먼저 충족
- 보완계약: 직접 보완 항목 없음

### TEST-01

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-TEST-01 (NOT_RUN): AT-01~32 실제PostgreSQL/복수인스턴스·fault위치·합계증거
- 보완계약: 직접 보완 항목 없음

### TEST-02

- 상태: SPECIFIED / NOT_IMPLEMENTED
- API: 직접 HTTP 없음; 공통규칙/worker/상위사용사례에서 검증
- 모델: 직접 DB 모델 없음; API/설정/클라이언트/운영 규칙
- 이벤트: 직접 발행 event 없음; 관련 workflow의 사건을 사용
- 수용시험: 기존 AT 직접연결 없음
- DT-TEST-02 (NOT_RUN): 완료기능마다 code/DB/계약/UI/운영 증거, 미실행 시험 별도표시
- 보완계약: 직접 보완 항목 없음

## 변경·완료 기록 규칙

실제 기능을 구현할 때 요구사항별 코드/실제 migration 파일/테스트 경로·실행환경·결과·날짜·잔여 X항목을 evidence에 기록합니다. 문서가 있다고 APPLIED/PASSED로 승격하지 않습니다. 기존 x-requirements와 정책 변경을 같이 반영하고 미연결 요구·미정의 event/API/table을 검증에서 거부합니다.
