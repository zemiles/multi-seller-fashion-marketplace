# 01. 인증·인가와 공통 API 요구사항

이하 전체는 v1 구현 요구이며 현재 동작 설명이 아닙니다. [결정 목록](README.md)의 DEC-15/16/19를 구체화합니다.

## SEC-01 고객·판매자 인증

- Commerce가 회원 credential, 세션, 판매자 membership을 소유합니다. 별도 Identity 업무 서비스를 추가하지 않습니다.
- 가입: 이메일(trim·소문자 정규화, unique), 비밀번호 12~128자, 닉네임 2~30자, 필수 약관 버전 동의. 비밀번호 공백을 임의 trim하지 않습니다. 해시는 Argon2id(메모리 19MiB 이상, iterations 2 이상, parallelism 1)와 개별 salt를 사용합니다. 평문/가역 암호 저장 금지. 기준 근거: [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
- 검증/비밀번호 재설정은 256bit 난수 token의 hash만 저장, 10분, 1회 사용. v1 전달은 로컬 모의 메일함이며 인증된 테스트 운영자만 조회합니다. 공개 가입 화면에 token 반환 금지. 외부 이메일 발송 없이 운영 가능한 것은 데모 환경에 한정합니다.
- 로그인 실패는 계정 유무와 무관한 동일 401. IP당 20회/분, 계정당 연속 5회 실패 시 15분 잠금. 로그인/비밀번호 변경 시 session ID 회전, 비밀번호 변경/탈퇴 시 모든 세션 폐기.
- 256bit opaque session ID; Redis에는 hash 및 memberId/sessionVersion/expiry 저장. 유휴 30분, 절대 12시간. Redis 장애에는 인증이 필요한 쓰기를 503으로 닫고 익명 공개 조회만 허용합니다.
- 쿠키 `__Host-marketplace-session`: HttpOnly, Secure, SameSite=Lax, Path=/, Domain 없음. localhost HTTP 개발만 `marketplace-session`으로 Secure 예외. 관리자 쿠키는 별도 이름·별도 principal.
- 브라우저 mutation은 CSRF token+Origin 검증. GET `/api/v1/session`으로 현재 사용자와 session-bound csrfToken을 받아 메모리에 보관, `X-CSRF-Token` 제출. 로그인/로그아웃/가입에도 pre-auth 세션 토큰을 적용합니다. SameSite만으로 대체하지 않습니다. 근거: [OWASP CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).
- 회원 상태 ACTIVE만 신규 구매 가능. SUSPENDED는 신규 거래 차단하되 자기 기존 주문/배송/환불·지원 접근은 허용. WITHDRAWN은 로그인 불가. 미종결 주문/Claim이 있으면 탈퇴는 409 ACTIVE_TRANSACTION이며 완료 후 재신청.

## SEC-02 관리자·판매자 권한

관리자는 별도 계정·세션, 로그인 시 TOTP 필수, 유휴 15분/절대 8시간. 최초 관리자 생성은 로컬 운영 CLI의 일회성 절차이며 공개 회원가입으로 관리자 승격 불가. 기본/공유 비밀번호를 seed하지 않습니다. 복구 코드는 hash, 1회용이며 MFA 해제는 다른 IAM 관리자 승인·감사 필수입니다.

서버는 매 요청 member/admin 상태와 seller membership/권한 버전을 검증합니다. JWT나 화면 숨김만으로 판매자 소유권을 판정하지 않습니다.

| 주체 | 허용 | 금지 |
| --- | --- | --- |
| MEMBER | 자신의 주문/Claim/주소/리뷰 | 타인의 ID 조회, 금액/역할/회원 ID 지정 |
| SELLER_OWNER | 자기 판매자 팀·상품·출고·계좌 변경 요청 | 계좌 검증/지급 스스로 승인 |
| SELLER_CATALOG | 자기 상품/재고 | 타 판매자·정산 계좌 변경 |
| SELLER_FULFILLMENT | 자기 판매자 주문 항목/배송/Claim | 다른 판매자 항목·고객 전체 주문 금융 정보 |
| SELLER_FINANCE | 자기 정산·원장 읽기 | 원장 수정·PG 환불 직접 실행 |
| ADMIN_SUPPORT | 고객 지원·Claim 검토 | 지급/계좌 변경 승인 |
| ADMIN_CATALOG | 상품·브랜드·콘텐츠 검수 | 금융 조정 |
| ADMIN_RISK | 제재·해제·분쟁 | 자기 요청 최종 승인 |
| ADMIN_FINANCE | 대사·조정·지급 승인 | 단독 지급, 근거 없는 UNKNOWN 성공 처리 |
| ADMIN_IAM | 역할·계정 관리 | 자신의 권한 증대 승인 |

타인 소유 리소스는 404, 자기 리소스의 부족한 기능 권한은 403. 본문 requestedById/type는 인증 컨텍스트에서 생성·검증하며 사용자가 보낸 값으로 권한을 올리지 않습니다. 금융·계좌·제재·권한 변경은 요청자와 승인자가 달라야 합니다.

## SEC-03 서비스 간 인증

- 서비스별 RSA private key로 RS256 JWT를 발급, `kid`별 공개키 allowlist로 검증. 허용 알고리즘 고정, 토큰 제공 URL에서 키 다운로드 금지.
- 필수 claims: iss/sub=호출 서비스 ID, aud=대상 서비스 ID, iat/nbf/exp, jti(UUID), scope(공백 구분). TTL 60초, 시계 오차 5초. scope는 자체 발급했다고 신뢰하지 않고 발급자별 허용 범위와 교차 검증. JWT 표준 필드 근거: [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html).
- Commerce→Payment `payment:prepare payment:approve payment:read payment:refund payment:cancel`; Commerce→Settlement `settlement:read settlement:admin`; Commerce→Discovery `discovery:read discovery:write discovery:server-behavior`; Commerce→각 업무 owner `operations:read operations:replay`(aud=실제 대상 service, 금융 replay는 추가 2인승인); Payment→각 PG `pg:write pg:read`; 복구 배치는 해당 owner 내부 권한만.
- 사용자 대리 command에는 actorType/actorId, sellerId(해당 시), correlationId를 별도 검증 가능한 본문으로 기록. Payment는 Commerce principal만 사용자 대리를 허용. actor 정보는 감사 근거이지 단독 권한 근거가 아닙니다.
- 키는 환경별 secret 파일/환경 주입, 저장소·이미지·브라우저·로그 제외. 90일 회전, 구키 검증은 5분만 중첩. 유출 시 즉시 폐기.
- 공개 환경 TLS 필수. DB/Kafka/Redis/PG/Payment/Settlement/Discovery 직접 외부 노출 금지. webhook은 서명 검증 전용 내부 수신 경로이며 고객 session을 사용하지 않습니다.

## API-01 외부 진입과 직렬화

v1 외부 reverse proxy는 `/api/v1/**`를 Commerce의 고객/판매자/관리자 facade로 전달합니다. Commerce가 인증·소유권을 확인하고 필요한 서비스를 호출합니다. 업무 서비스는 4개 그대로이며 별도 Gateway Java 서비스를 만들지 않습니다. 브라우저는 `/internal/**`, PG 또는 Payment host를 직접 호출하지 않습니다.

개발 목표: Vite `/api` proxy → `http://localhost:8081`; 브라우저는 same-origin 상대 URL. 배포도 same-origin. cross-origin CORS는 기본 차단하며 임의 `*`+credentials 금지. 이 proxy는 아직 설정되지 않았습니다.

- UUID는 문자열, timestamp는 UTC RFC3339 문자열, 표시만 Asia/Seoul. 날짜-only는 YYYY-MM-DD.
- Money=`{currency:"KRW", amount:10000}`. 주문 관련 금액은 0~100,000,000, 승인/환불 요청은 1 이상. 정산·원장 API 집계는 절대값 9,007,199,254,740,991 이하; 초과하면 범위를 나누고 422 AMOUNT_RANGE_EXCEEDED. Java의 덧셈/곱셈 overflow도 검사합니다.
- JSON integer만 허용, decimal/string/null/NaN/무한 값 거부. 누락과 null은 다름. 변경 API는 허용 필드 allowlist, 알 수 없는 쓰기 필드는 400 UNKNOWN_FIELD.
- 응답은 DTO 객체, 목록은 `{items:[],nextCursor:null}`. 기본 20/최대 100, opaque cursor는 sort key+UUID+filter hash로 서버 검증. 정렬 필드 allowlist, 뒤에 UUID tie-break. 총개수는 기본 제공하지 않습니다.
- 오류=`{code,message,traceId,details}`; code가 분기 기준. details는 field/reason 등 공개 가능한 값만. stack trace, SQL, 비밀키 반환 금지.
- 400 형식, 401 미인증, 403 권한, 404 없음/타인, 409 상태·멱등·version 충돌, 410 만료 checkout, 422 정책·금액 오류, 429 제한, 503 인프라 일시 장애. 처리 접수 후 결과 불명은 202+resourceId/status/조회 URL이며 단순 500으로 잃지 않습니다.

## API-02 멱등성과 경합

- 금융/checkout/주문/출고/Claim/확정/정산 명령은 `Idempotency-Key` 1~200 ASCII `[A-Za-z0-9._:-]`. UI는 logical action별 UUID를 생성해 결과 확정까지 유지. 사용자 새 행동만 새 키.
- scope는 `(principal,operation,targetId,key)`. Payment prepare는 추가 `(provider,key)`, PG 승인은 merchantTxId가 고유 기준. JSON 필드 순서와 무관한 검증된 DTO canonical hash로 요청 비교; 배열은 계약상 순서로 정규화하고 누락/default도 정규화. 금액·배분·요청자·사유 변경은 409 IDEMPOTENCY_CONFLICT.
- 같은 키는 같은 resource ID와 현재 상태 반환. 최초 HTTP body를 영구 캐시한다는 의미가 아님. 인증/소유권 검사는 replay에서도 실행. 새 key로도 업무 unique 조건을 우회할 수 없음.
- 금융/주문 키는 해당 거래 보존기간 동안 유지. 일반 비금융 command 기록은 완료+7일; 찜 등 본래 unique인 작업은 key 만료 후에도 중복 생성 안 됨.
- 편집 작업은 expectedVersion 필수, stale이면 409 VERSION_CONFLICT. 재고/수량/잔액은 DB 행 lock 또는 조건부 update, 여러 행은 UUID 오름차순으로 잠금. 외부 HTTP를 기다리는 동안 lock 유지 금지.
- idempotency 저장·업무 변경·outbox는 같은 transaction. 외부 효과는 영속 operation+lease/fencing version으로 복구. DB 결과와 요청 로그가 분리되어 중복 효과를 만들면 불합격.

## API-03 고객 진입 계약 목록

아래는 목표 경로입니다. 해당 ID 문서의 검증·상태·권한이 계약 일부이며, [정식 OpenAPI](../api/README.md)와 예제에 반영됐습니다. X-01~11의 화면/운영 계약도 포함합니다. 현재 Controller가 있다는 뜻이 아닙니다.

| 경로 | 필수 입력 → 주요 출력 | 근거 |
| --- | --- | --- |
| POST /api/v1/members | email,password,nickname,consentVersions → memberId,verificationRequired | SEC-01 |
| POST /api/v1/sessions · DELETE /api/v1/session | email,password / CSRF → 세션 쿠키 / 204 | SEC-01 |
| GET /api/v1/session | → actor,roles,sellerMemberships,csrfToken,expiresAt | SEC-01 |
| POST /api/v1/auth/verifications · /password-resets | token / token,newPassword → 204 | SEC-01 |
| POST /api/v1/auth/verification-requests · /password-reset-requests | email → 항상 202 | SEC-01 |
| GET/PATCH /api/v1/me · DELETE /api/v1/me | nickname,expectedVersion / 탈퇴 → 프로필 / 204 | COM-01 |
| GET/POST /api/v1/me/addresses · PATCH/DELETE /{addressId} | recipient,phone,postalCode,address1,address2,isDefault,expectedVersion → 주소 | COM-01 |
| GET /api/v1/products · /products/{productId} | query/filter/cursor → ProductSummary/ProductDetail | CAT-01, DIS-01 |
| GET/PUT/DELETE /api/v1/me/wishlist/{productId} | GET 목록은 /wishlist → 찜 / 204 | EXP-01 |
| GET /api/v1/cart · PUT/DELETE /cart/items/{skuId} | quantity,selected,expectedVersion → cart | ORD-01 |
| POST /api/v1/checkouts · GET /checkouts/{id} | selectedSkuQuantities,addressId → immutable quote,expiresAt,revision | ORD-02 |
| POST /api/v1/orders | checkoutId,checkoutRevision → orderId,PENDING_PAYMENT | ORD-03 |
| POST /api/v1/orders/{id}/payment | provider(KAKAO/NAVER),expectedVersion → orderId,attemptId,status,statusUrl,simulated | PAY-01 |
| GET /api/v1/orders · /orders/{id} · /orders/{id}/payment-status | → items,shippingGroups,totals,order/payment/claim各状態,version | ORD-04 |
| POST /api/v1/orders/{id}/claims | type,items[{orderItemId,quantity,shipmentItemId?}],reasonCode,evidenceIds,replacementSkuId?,expectedVersion,quoteId? → claimId,status | CLM-01 |
| GET /api/v1/claims/{id} · POST /claims/{id}/withdraw | → claim / current state | CLM-01 |
| POST /api/v1/shipment-items/{id}/confirmations | quantity,expectedVersion → confirmationId,confirmedQuantity | FUL-02 |
| POST /api/v1/reviews · PATCH/DELETE /reviews/{id} | eligibilityId,rating,text,imageIds,expectedVersion → review / 204 | EXP-02 |
| GET /api/v1/notifications · POST /notifications/{id}/read | → items/unreadCount / 204 | EXP-03 |
| GET/PATCH /api/v1/notification-preferences | marketingOptIn,expectedVersion → 설정 | EXP-03 |

POST /orders/{id}/payment는 Commerce가 prepare→approve를 조정하며 브라우저의 금액을 받지 않습니다. 주문까지 동기 반영됐으면 200, 처리 중이면 202입니다. 결제 결과 화면은 반드시 주문을 재조회합니다.

## SEC-04 파일과 감사

업로드는 Commerce가 소유권/용도를 발급한 uploadId에 연결합니다. JPEG/PNG/WebP 최대 5MiB·긴 변 4096px, 문서는 PDF 최대 10MiB; MIME과 실제 내용 검증, 악성 파일 격리, 파일명 재생성. HTML/SVG/실행파일 및 사용자 URL의 서버 임의 fetch 금지. 미검증 파일은 공개하지 않습니다. 상품/리뷰 이미지 공개, 입점 문서/Claim 증빙/계좌 자료 비공개, 다운로드 URL 5분 만료. 로컬 저장소 구현 뒤 object storage port 교체 가능; 개인 문서 경로를 이벤트에 넣지 않습니다.

감사는 actor·권한·대상·사유·before/after hash·requestId·시각을 append-only 저장. 금융 이벤트에는 주소/전화/이메일/계좌번호/비밀번호/토큰을 넣지 않습니다. 실제 주민등록번호·카드정보 수집은 v1 제외입니다.
