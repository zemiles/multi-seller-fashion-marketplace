# 06. 검색·분석·사용자 화면·MFE

구현 시 [40개 화면 상세 명세](../implementation/05-screens.md)의 route·입력·버튼·API·에러/복구 흐름과 X 보완 계약을 함께 적용합니다. 화면 설계와 실제 구현 완료 상태는 구분합니다.

## DIS-01 검색과 상품 projection

Discovery는 검색/분석 원본만 소유, 상품 판매 원본과 재고 원장은 Commerce입니다. v1 검색 저장소는 Discovery PostgreSQL의 service-local product projection입니다. Elasticsearch/외부 SaaS는 필요조건이 아닙니다.

- ProductRevisionPublished/ProductAvailabilityChanged를 수신해 productId/revision/version, sellerId, title, category, brand, 판매가능 flag, 가격 범위, 승인 feature/concept, 주이미지 public URL, publishedAt를 projection. 주소/개인정보/원본 비공개 문서 제외.
- 기본 검색은 Unicode 정규화·trim, 1~100자, 제목/승인 feature/alias case-insensitive 포함 검색. 일치 점수는 제목 exact 100, 제목 포함30, feature10, concept alias5의 합; tie는 publishedAt desc,productId. v1에서 형태소/벡터 검색 정확도를 보장한다고 표시하지 않음.
- 필터: categoryId,brandId,sellerId,priceMin/Max,conceptIds(최대10),availableOnly. sort=relevance/newest/priceAsc/priceDesc. 결과20/최대100, cursor+filter hash. 유효하지 않은 sort/filter422.
- 판매 중지/비공개/제재 상품은 제거 tombstone 적용. stale 검색결과를 눌러도 Commerce 상세/checkout에서 최신 판매 가능 여부 확인. 재고/금액의 최종 권위는 검색 결과 아님.
- 재구축은 새 projection generation에 snapshot import+watermark 이후 이벤트 적용→row count/checksum/version 검증→active generation 원자적 전환. 기존 index/table 즉시 삭제 금지, 이전 generation24시간 보존. Commerce 내부 cursor snapshot API를 사용하며 Commerce DB 직접 query 금지.
- Discovery 장애 시 고객에 검색 일시불가와 Commerce의 기본 최신 상품 목록을 제공. 결제/주문/환불은 검색 장애와 무관하게 유지.

API: Commerce 공개 facade GET `/api/v1/products`와 `/api/v1/search`, 내부 Discovery GET `/internal/v1/search/products`. requestId,query,filters,cursor와 결과 productId/revisionId/score/price/availability/nextCursor 반환. 검색어에서 연락처 패턴은 저장 전 마스킹합니다.

## DIS-02 concept·분석

- taxonomy DRAFT→ACTIVE→RETIRED, 동시에 ACTIVE 1개. concept/alias는 taxonomy version 내 unique 정규화 key, cycle 금지. 게시 taxonomy를 수정하지 않고 새 version.
- 분석 run key=`productId:revisionId:taxonomyVersion:modelVersion:promptVersion`. QUEUED→RUNNING→SUCCEEDED/FAILED/CANCELLED. 중복 접수 같은 run 반환; 실패 재실행은 attempt만 증가, 결과 기준 run identity 유지.
- v1 `rule-simulator-v1`은 사전 정의 keyword→concept 규칙과 score를 적용, promptVersion=`none-v1`, 외부 AI API 호출 없음. 결과에 simulated=true, 원문 구간/featureId 등의 evidence와 analyzer version 저장. 모의 분석을 실제 LLM 추론으로 표시하지 않음.
- 판매자/관리자가 ACCEPTED/REJECTED/ADJUSTED 검토한 concept만 공개 검색에 반영. AI 추정 feature를 seller 입력 원본으로 덮어쓰기 금지. 가격/법적 인증/진품 여부/제재를 자동 판정하지 않음.
- 새 revision이 나오면 이전 run 결과가 최신 revision을 덮지 않음. 이전 근거는 분석 이력으로 유지. retry=10초/1분/5분 3회, 이후FAILED+운영재실행. 결제 경로가 분석 완료를 기다리지 않음.
- API: POST `/api/v1/sellers/{sellerId}/products/{productId}/analysis-runs`(revisionId), GET `/analysis-runs/{runId}`, POST `/concept-reviews`(runId,conceptId,decision,reason); 관리자 `/api/v1/admin/concept-taxonomies` 생성/게시.

## DIS-03 행동 데이터

eventType=SEARCH/IMPRESSION/PRODUCT_VIEW/WISHLIST/CART_ADD/PURCHASE. eventId UUID, actor pseudonym/sessionId, productId/revisionId?,requestId?,occurredAt,receivedAt,context allowlist. 브라우저는 SEARCH/IMPRESSION/PRODUCT_VIEW만 직접 제출, 구매/Cart/찜 전환은 서버 확정 사건으로 집계하여 클라이언트 위조 구매량 배제.

개별 POST `/api/v1/behavior-events` 또는 최대50건 batch. payload64KiB, 회원/세션당100회/분, eventId unique, 미래5분 초과/7일 초과 과거 입력422. analytics opt-in 없는 사용자는 지속적 개인 행동 추적 안 함; 서비스 품질용 익명 집계만. 주문 성립/금액을 행동데이터로 판단하지 않음. v1 추천은 승인 concept 유사도+최신순이며 개인 프로파일링 추천 제외.

## FE-01 프론트 경계와 인증

현재 front-end는 React/Vite starter이며 아래는 구현 목표입니다. 처음에는 `areas/storefront`, `areas/seller`, `areas/admin` route-level lazy load로 구현, area 사이 deep import와 shared business store 금지. 공용은 UI primitive/design token/http runtime/세션 계약. 스타일은 CSS Modules, reset/token만 전역.

v1 후반 완료 조건은 세 영역이 각각 독립 build/test/artifact/rollout/rollback인 SPA로 추출되는 것입니다. storefront 먼저, seller 다음, admin 마지막. 동일 origin의 `/`, `/seller/*`, `/admin/*`를 reverse proxy가 각 artifact로 라우팅. 런타임 Module Federation/독립 팀 전제는 제외. 단일 배포 단계에서는 “MFE-ready”, 추출 완료 후에만 “MFE”로 보고합니다.

인증은 [01 문서](01-security-api.md)대로 cookie+CSRF. localStorage에 access/refresh token 저장 금지. session bootstrap 결과의 roles는 화면 분기용, 서버 인가 대체 불가. 관리자 로그아웃은 관리자 세션만, 전체 로그아웃 명령은 고객 세션도 명시적으로 폐기.

## FE-02 화면 요구사항

| 영역/화면 | 정상 동작 | 반드시 처리할 예외 |
| --- | --- | --- |
| 상품 목록/검색 | 필터·정렬·cursor, 검색상태 URL 복원 | 빈 결과, 검색불가 fallback, stale 가격/품절 |
| 상품 상세 | 게시 revision·옵션·실결제가격·판매자 배송비, 장바구니/찜 | 비활성 SKU, 품절, 판매중지, 로그인 필요 |
| Cart/Checkout | 최신 quote·판매자별 배송비·주소·15분 잔여시간 | 가격변경 재확인, 재고부족, 만료, 주소검증 |
| 결제 | PG1/PG2 명시 선택, 모의 거래 안내, 1회 logical key | double click, 뒤로가기/새로고침, 202/UNKNOWN, 다른PG 전환 차단 |
| 결제 결과 | Commerce order 상태 재조회, 처리중/성공/실패 구분 | PG승인/주문반영 지연, 보상중, 장시간 확인중 지원 링크 |
| 주문 상세 | item별 배송/취소/반품·수량·금액, 판매자별 그룹 | 일부만 환불/출고/확정, 결제상태와 주문상태 차이 |
| Claim | 허용 unit·기한·예상환불/배송비를 서버 계산으로 제시 | 같은unit 중복, 기간경과, 교환재고없음, UNKNOWN 환불 |
| 구매확정/리뷰 | 확정 가능 수량·hold 이유, eligibility 기반 작성 | claim 경합409, 이미확정, 반품자격변경 |
| 판매자 상품·재고 | revision 편집/검수/게시, 원장 기반 재고조정 | stale version, 예약아래 재고감소, 타판매자 차단 |
| 판매자 출고/Claim | 자기항목만, 인계/검수 근거 기록 | 과출고, 같은송장중복, 접수/출고 경합 |
| 판매자 정산 | 원장·수수료·보류·이월·모의지급 분리 | 음수채무, account pending, 지급UNKNOWN |
| 관리자 | 권한별 검수·2인승인·대사·복구·감사 | 자기승인 금지, 증빙누락, 오래된 승인 hash, 직접강제성공 금지 |

결제 status polling은 처음60초 2초 간격, 이후5분까지5초, 이후30초 간격(탭 foreground에서만), 화면 이탈 시 중단. 네트워크 timeout은 “확인 중”, 최대 UI 대기 후에도 실패라고 표시하지 않습니다. mutation 재전송은 같은 key, GET 재조회는 새 approve 호출이 아님. 버튼 disable만으로 서버 멱등성을 대체하지 않습니다.

모든 화면 loading/empty/error/unauthorized/forbidden/not-found 상태, 키보드 조작·focus 복원·label·alert live region, 360px부터 가로 넘침 없는 레이아웃을 제공합니다. 금액은 서버 integer 포맷팅, 클라이언트 할인/환불액 재계산은 표시 참고만. i18n v1 한국어/Asia-Seoul, 통화KRW.

## FE-03 계약과 테스트

각 기능 시작 시 해당 서버 OpenAPI에서 TypeScript DTO 생성하고 runtime response 검증을 추가합니다. 현재 없는 endpoint를 구현됨으로 가정하지 않습니다. 계약 mock은 `simulated/mock` 표시와 fixture 버전을 두고 E2E 단계에서 실제 서비스로 교체. 인증·payment·claim·정산 mock만 통과한 것으로 E2E 완료 불가.

area별 단위 테스트, API 계약 테스트, Playwright 브라우저 E2E를 목표로 합니다. 관리자 bundle 로딩 여부와 무관하게 비관리자 API 접근403, CSRF 누락403, 상품 script text의 XSS 방어, PG 선택 후 timeout/새로고침 단일 금융 효과를 검증합니다. 아직 이러한 도구/테스트는 front-end에 설치되지 않았습니다.
