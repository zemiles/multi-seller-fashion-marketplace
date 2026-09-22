# 백엔드 구현 설계 기준

기준일: 2026-09-21. 이 문서는 현재 백엔드 개발의 진입점이며, 대화 링크를 다시 읽지 않고 작업할 수 있도록 요구·결정·코드 위치·미구현 범위를 모았습니다.

**앞으로 구현할 로직의 기준은 [v1 전체 요구사항](requirements/README.md)입니다.** 인증·통화·할인·만료·UNKNOWN·구매확정·webhook·Kafka·정산 정책을 결정 ID와 상세 규칙으로 확정했습니다. 아래 현재 구현 표와 목표 요구사항을 구분해서 읽습니다. PG1은 기존 KAKAO, PG2는 기존 NAVER이며 실 PG 연결은 하지 않습니다.

## 1. 문서와 코드의 기준

- 구현 순서·transaction·동시성·이벤트 필드·DB 전환·화면·복구 절차는 [구현 상세 문서 6종](implementation/README.md)을 사용합니다. 요구사항 55개의 API/테이블/이벤트/시험 연결과 현재 미구현 범위는 [추적표](implementation/04-traceability.md)에 있습니다. X-01~11은 정식 OpenAPI에 반영했고 M4 구조/제약은 목표 ERD와 [DDL](ddl/README.md)에 반영했습니다. [검증 기록](implementation/VERIFICATION.md)은 계약 완료와 미구현을 구분합니다.

- 테이블별 컬럼/키/관계는 [현재·목표 ERD](erd/README.md), HTTP 경로/필드/예시는 [API 명세서](api/README.md)를 사용합니다. 목표 ERD는 migration이 적용된 상태가 아니며 목표 API는 배포된 Controller가 아닙니다. 생성본의 정본과 변경 방법은 [문서 도구](../scripts/docs/README.md)에 있습니다.

- 현재 아키텍처는 **4개 업무 서비스 + 2개 독립 PG simulator + 1개 HTTP 계약 라이브러리**입니다. 과거 10개 배포 단위 안과 단일 앱 안은 현재 구현 기준에서 제외합니다.
- 서비스의 현재 계약·상태는 이 문서, 실행은 [MSA.md](../MSA.md), HTTP 필드는 [contracts](../contracts/README.md)를 따릅니다.
- 파일 수정 시각으로 설계 우선순위를 판단하지 않습니다. 과거 대화 백업과 분석은 이력입니다. 새 사용자 요구가 우선하며 변경한 결정은 이 문서와 영향받는 계약·테스트에 반영합니다.
- 현재 동작은 코드·migration·테스트로 확인합니다. 구현과 문서가 다르면 원인을 확인하고 함께 수정합니다. 설계가 문서에 있다고 구현 완료로 취급하지 않습니다.
- 이 문서의 “현재”는 확인한 구현, “구현 기준”은 앞으로 지킬 규칙입니다. 과거 미정 사항은 v1 요구사항으로 대체됐습니다. 새로운 요구 변경 외에는 정책을 임의로 다시 미정 처리하지 않습니다.
- 실제 저장소 루트는 `back-end/multi-seller-fashtion-marketplace`입니다. 디렉터리 오타는 유지합니다. Gradle 이름은 `multi-seller-fashion-marketplace`, Java prefix는 `multi.com.marketplace`입니다.

## 2. 프로젝트 목적과 핵심 모델

AI를 개발 과정에 활용하는 멀티셀러 패션 마켓플레이스입니다. 결제·주문·재고·정산의 중복 요청, 동시성, 장애, 지연 응답과 복구를 설명하고 검증하는 것이 핵심입니다. Java 17, Spring Boot 4.1.1, Gradle Wrapper 9.7.1을 사용합니다. PostgreSQL이 거래 기준이며 Redis는 보조 수단, Kafka는 비동기 사실 전파용입니다. 의존성·테이블 존재만으로 연동 완료를 의미하지 않습니다.

- Product → revision → 특징·옵션·SKU. 판매자 입력 특징과 AI concept를 분리하고 분석 근거·taxonomy/model/prompt 버전을 남깁니다.
- Cart → immutable Checkout → DB 재고 예약 → `PENDING_PAYMENT` Order → 결제 시도 → 승인 → 주문 확정 → 배송 → 구매확정 → 판매자 원장 → 정산·지급·대사.
- PG 호출 전에 주문을 commit합니다. 공유 대화의 “결제 후 주문 생성” 안은 검토 중 복구 가능한 위 방식으로 보정됐습니다.
- 주문은 여러 판매자를 포함하며 배송비는 주문 내 판매자별 한 번 계산합니다. 주문 항목·가격·할인·옵션·주소·배송 조건은 당시 snapshot을 보존합니다.
- Payment는 승인 결제, PaymentItem/ChargeAllocation은 금액 귀속, PaymentTransaction은 승인·취소·환불의 거래 이력입니다.
- 부분 반품·분할 배송·구매확정은 수량 기반으로 처리합니다. 구매확정은 ShipmentItem 단위이며 열린 Claim은 hold를 겁니다.
- Redis TTL이나 네트워크 timeout만으로 예약 해제·결제 실패·재결제 가능 상태를 판단하지 않습니다.
- 판매자 지급 대상 원장은 구매확정과 환불·제재 조정에 근거합니다. 결제 승인만으로 판매자에게 지급 가능한 원장을 생성하지 않습니다.

## 3. 현재 서비스 경계와 구현 상태

| 모듈 | 소유 업무 | 현재 실행되는 업무 로직 |
| --- | --- | --- |
| commerce-service | 회원·판매자·상품·재고·Cart/Checkout·Order·배송·구매확정·Claim·리뷰·운영 | Boot, DB migration, 업무별 package-info만 있음 |
| payment-service | 결제 시도·승인·취소·환불·PG webhook·PG 거래 대사 | 순수 Java 메모리 reference implementation과 단위 테스트. HTTP/DB 업무 처리 없음 |
| settlement-service | 판매자 원장·정산·지급·은행 대사 | Boot, DB migration, package-info만 있음 |
| discovery-data-service | 검색·전시·concept·상품 분석·행동 데이터 | Boot, DB migration, package-info만 있음 |
| pg-kakao-simulator | 카카오 역할의 모의 승인·취소·환불·조회 | REST → application → JPA → PG DB 구현 |
| pg-naver-simulator | 네이버 역할의 모의 승인·취소·환불·조회 | REST → application → JPA → PG DB 구현 |
| pg-simulator-common | 두 simulator의 HTTP DTO와 HTTP 오류 코드 | 라이브러리만 존재, 서버·DB 없음 |

실제 카카오/네이버 프로토콜 호환 구현이 아닙니다. 이름은 provider 역할 구분이며 모든 환경에서 모의 거래만 만듭니다. Payment가 simulator를 HTTP로 호출하는 adapter는 아직 없습니다. Gateway, 고객 API, 인증 계약, Kafka producer/consumer, Outbox publisher, consumer inbox, 주문-결제 연동도 미구현입니다.

구매확정의 writer는 **Commerce**입니다. Settlement는 PurchaseConfirmed를 소비합니다. 상품 원본은 Commerce, AI concept 원본은 Discovery입니다. 판매자 정산 계좌 원본은 Commerce이며 Settlement는 권한 있는 조회로 지급 시점 계좌 snapshot을 확보해야 합니다.

### 코드 배치

`<service>/src/main/java/multi/com/marketplace/<service>/<업무>/{api,application,domain,infrastructure}`를 사용합니다. Discovery package 이름은 `discovery`입니다.

| 서비스 | 현재 업무 패키지 |
| --- | --- |
| Commerce | member, seller, catalog, inventory, cart, order, fulfillment, claim, review |
| Payment | transaction, refund, webhook |
| Settlement | ledger, calculation, payout, reconciliation |
| Discovery | search, concept, analysis, behavior |

Controller는 전송·검증, application은 유스케이스·트랜잭션·외부 port, domain은 규칙, infrastructure는 DB·HTTP·메시징을 맡습니다. 새 업무는 필요한 때 패키지를 추가합니다. 업무 서비스 간 Java 프로젝트 의존성·JPA 관계·공유 entity를 만들지 않습니다. PG HTTP DTO 공유만 현재 예외이며 PG domain/DB는 독립입니다.

## 4. 데이터 소유권과 변경 방법

각 서비스는 별도 database를 쓰며 업무 서비스 schema 이름은 모두 `marketplace`입니다. 같은 schema 이름이어도 DB가 다릅니다. 타 DB query/write와 cross-service FK를 금지합니다. 외부 ID·snapshot·API·event projection으로 연동합니다.

| 서비스 | 업무 테이블 | 내부 FK (V1 + V2) | migration |
| --- | ---: | ---: | --- |
| Commerce | 76 | 136 | V1 |
| Payment | 11 | 14 | V1 + V2 |
| Settlement | 12 | 14 | V1 + V2 |
| Discovery | 10 | 7 | V1 + V2 |
| 각 PG simulator | 2 | 1 | 각 provider V1 |

업무 테이블 합계 109는 원래 106개 논리 테이블에 공통 outbox를 각 서비스 DB로 복제한 결과입니다. PG 4개 테이블과 Flyway 이력은 별도입니다. 일반 Kafka consumer inbox는 아직 없습니다. `pg_webhook_inbox`는 provider webhook 전용입니다.

서비스별 물리 기준은 `<service>/src/main/resources/db/migration/V*.sql` 누적 결과입니다. 통합 워크스페이스 `database/_parts`는 전체 논리 모델이며 서비스 DB에 합본을 직접 적용하지 않습니다. 백엔드만 clone해도 서비스 migration은 실행할 수 있습니다. 논리 모델 비교 생성에는 상위 database 폴더가 필요합니다.

기존 V1은 수정하거나 재생성해 덮어쓰지 않습니다. 변경은 V2/V3 등 새 migration으로 추가합니다. `scripts/generate-service-migrations.ps1`는 이제 `build/schema-preview`에만 비교 후보를 만듭니다. 후보 파일은 기존 DB에 적용할 migration이 아닙니다. `scripts/verify-service-schema.ps1`는 논리 원본의 서비스 내부 FK와 누적 migration을 대조합니다.

V2는 생성기의 다중 ADD CONSTRAINT 필터 오류로 빠진 내부 FK 22개를 복원합니다. 기존 orphan이 있으면 적용이 실패합니다. 오류의 table/constraint를 기준으로 orphan을 조사하고 원본 거래를 대조해야 하며, 데이터 삭제·V1 수정·Flyway repair로 우회하지 않습니다.

### 소유 테이블 목록

**Commerce**: `member`, `member_auth_identity`, `member_profile`, `shipping_address`, `seller`, `seller_member`, `seller_document`, `seller_verification`, `seller_settlement_account`, `brand`, `seller_brand_relation`, `brand_registration_request`, `category`, `product`, `product_revision`, `product_image`, `product_feature`, `option_group`, `option_value`, `sku`, `sku_option_value`, `inventory`, `inventory_ledger`, `cart`, `cart_item`, `checkout`, `checkout_shipping_group`, `checkout_item`, `inventory_reservation`, `inventory_reservation_item`, `orders`, `order_shipping_group`, `order_item`, `order_charge`, `order_state_event`, `shipment`, `shipment_item`, `shipment_event`, `purchase_confirmation_state`, `purchase_confirmation_event`, `purchase_confirmation_hold`, `claim`, `claim_item`, `claim_item_source_allocation`, `claim_evidence`, `claim_reason_change`, `claim_review`, `claim_event`, `exchange_line`, `review_eligibility`, `review`, `review_revision`, `review_image`, `seller_review_reply`, `wishlist_item`, `notification`, `notification_preference`, `notification_delivery`, `admin_user`, `admin_role`, `admin_user_role`, `admin_permission`, `admin_role_permission`, `admin_approval_request`, `admin_approval_step`, `admin_audit_log`, `seller_incident`, `seller_penalty`, `seller_health_metric`, `seller_appeal`, `compliance_rule`, `compliance_rule_version`, `product_compliance_finding`, `seller_compliance_task`, `seller_compliance_task_item`, `outbox_event`.

**Payment**: `payment_attempt`, `payment`, `payment_item`, `payment_charge_allocation`, `payment_transaction`, `payment_transaction_allocation`, `refund`, `refund_item`, `refund_charge_adjustment`, `pg_webhook_inbox`, `outbox_event`.

**Settlement**: `seller_ledger_entry`, `settlement`, `settlement_allocation`, `settlement_hold`, `settlement_payout_attempt`, `reconciliation_file`, `reconciliation_raw_row`, `reconciliation_run`, `reconciliation_match`, `reconciliation_discrepancy`, `bank_deposit_match`, `outbox_event`.

**Discovery**: `concept_taxonomy_version`, `concept`, `concept_alias`, `product_analysis_run`, `product_concept`, `product_concept_evidence`, `search_request`, `search_impression`, `user_behavior_event`, `outbox_event`.

Settlement V1에 `reconciliation_*` 테이블이 있으나 일부 컬럼은 과거 PG 대사 논리 모델에서 왔습니다. 현재 ownership 이전을 수행하지 않았습니다. **향후 PG 거래 대사는 Payment가 새 service-local migration으로 모델링**하고, Settlement는 은행/지급 대사만 실행합니다. Payment가 Settlement의 해당 테이블을 직접 쓰는 것으로 해결하지 않습니다. 마이그레이션 설계에서 기존 테이블의 용도·데이터 유무·폐기 절차를 함께 확정합니다.

금액은 최소 화폐 단위 long/bigint, 시간은 UTC Instant/timestamptz입니다. 현재 코드는 통화 3자리 형식만 검사하지만 v1 목표는 KRW 단일 통화·JSON 정수·주문 상한 1억원입니다. [MONEY-01](requirements/02-commerce.md)의 할인·세금·배송비·수량 배분을 적용합니다. 여러 행 합계는 FK만으로 보장되지 않으므로 owner transaction과 lock/조건부 갱신으로 보호합니다.

## 5. 현재 Payment reference implementation

위치: `payment-service/.../transaction/application/PaymentLifecycleService.java`. Spring Bean이 아니므로 앱을 띄워도 HTTP로 호출할 수 없습니다. 프로세스 내 Map과 synchronized를 사용하는 테스트용 구현이며 재시작·다중 인스턴스 안전성을 보장하지 않습니다.

### 현재 제공하는 메서드

| 메서드 | 입력 | 현재 동작 |
| --- | --- | --- |
| prepare | checkoutId, orderId, provider, merchantTxId, idempotencyKey, paymentMethod, PaymentAmount | CREATED attempt 생성, 재요청 내용 비교 |
| approve | attemptId | REQUESTED 기록 → provider port 호출 → Payment/SUCCEEDED, 불명확 결과는 UNKNOWN |
| request | paymentId, claimId, idempotencyKey, amount, reason, requester type/id | 사전 검증·금액 예약 → provider refund → 성공 잔액 반영 또는 UNKNOWN |
| findAttempt/findPayment/findRefund | UUID | 메모리 snapshot 조회 |

prepare는 provider별 key와 merchantTxId를 구분하며, 같은 주문에 미해결 또는 성공한 시도가 있으면 다른 provider를 통한 시도도 차단합니다. 영속 구현은 DB lock/제약으로 같은 규칙을 보장해야 합니다. 현재 V1의 부분 unique index는 `(order_id, provider)`의 미해결 상태만 보호하므로 **provider 변경·성공 후 재시도 차단까지 충족하지 않습니다**. 영속 prepare 도입 시 order 기준 가드 migration/transaction을 먼저 추가합니다.

동일 refund key는 payment 범위에서 금액·통화·claim·사유·요청자 type/id가 모두 같아야 합니다. SYSTEM 외 요청자는 ID가 필수이며, 이것은 필수값 검증일 뿐 권한 검증 구현은 아닙니다. 요청 검증과 refund 생성은 provider 호출보다 먼저 수행합니다.

잔액에서 REQUESTED/PROCESSING/UNKNOWN 환불 요청 금액을 차감해 새 요청의 상한을 정합니다. UNKNOWN 재요청은 기존 refund를 반환하며 PG를 다시 호출하지 않습니다. 현재 UNKNOWN 확정·해제 기능은 없습니다. 프로세스 재시작을 복구 수단으로 사용하지 않습니다.

`PaymentProviderPort`는 승인 시 provider·merchantTxId·idempotencyKey·amount, 환불 시 provider·providerPaymentKey·idempotencyKey·amount를 전달합니다. 내부 paymentId만으로 외부 PG를 식별하지 않습니다.

### 상태 전이 — 구현 및 다음 구현의 기준

| 대상 | 허용 흐름 | 불명확 결과 처리 |
| --- | --- | --- |
| PaymentAttempt | CREATED → REQUESTED → SUCCEEDED / PENDING / FAILED / UNKNOWN | 현재 prototype은 성공 또는 UNKNOWN만 생성. UNKNOWN/PENDING에서 approve 재호출 금지 |
| Payment | APPROVED → PARTIALLY_REFUNDED → REFUNDED | VOIDED/CHARGEBACK enum은 있으나 처리 유스케이스 없음 |
| Refund | REQUESTED → PROCESSING → SUCCEEDED / FAILED / UNKNOWN | prototype은 REQUESTED → SUCCEEDED/UNKNOWN. UNKNOWN 금액 예약 유지 |
| PG payment | APPROVED → CANCELLED 또는 PARTIALLY_REFUNDED → REFUNDED | 현재 PG는 동기 성공/오류만 제공, 지연·webhook 미구현 |

FAILED/CANCELLED는 “실제 provider에 효과가 없음을 확인한 경우”에만 종결합니다. 금액 불일치·빈 provider key·응답 유실은 재시도 가능한 실패로 단정하지 않습니다. 이미 성공한 상태를 늦은 실패 이벤트로 되돌리지 않습니다. 영속 구현의 복구는 provider 조회 결과와 저장된 요청/거래 식별자를 대조해야 합니다.

## 6. 현재 PG simulator 계약

각 provider의 base URL은 로컬 8090/8091이며 아래 경로가 실제 구현돼 있습니다.

| method/path | 입력 | 결과 |
| --- | --- | --- |
| POST /pg/v1/payments/approve | merchantTxId, currency, amount, idempotencyKey | 결제 생성 또는 기존 merchant transaction 조회 |
| POST /pg/v1/payments/{paymentId}/cancel | idempotencyKey | 승인 상태 전액 취소 |
| POST /pg/v1/payments/{paymentId}/refund | amount, idempotencyKey | 부분/전체 환불 |
| GET /pg/v1/payments/{paymentId} | UUID | 최신 결제 상태 |

응답: `paymentId, merchantTxId, currency, amount, status, refundedAmount`. HTTP 성공은 200, 입력 오류는 400, 없는 결제는 404, 상태/금액/멱등 충돌은 409입니다. 오류 본문은 `code, message, timestamp, path`이고 메시지는 한글, 판단 기준은 code입니다. 상세 코드는 [Kakao](../pg-kakao-simulator/README.md), [Naver](../pg-naver-simulator/README.md)에 있습니다.

금액 JSON은 정수만 받습니다. 소수(`1000.5`)나 문자열(`"1000"`)을 long으로 자동 변환하지 않고 HTTP 400으로 거부합니다.

- 승인 중복 기준은 **merchantTxId**입니다. 같은 통화·금액이면 현재 결제를 반환하고 다르면 409입니다. 승인 idempotencyKey는 거래 이력에 저장되며 다른 merchantTxId까지 포괄하는 전역 unique key가 아닙니다.
- 취소·환불은 `(paymentId, transactionType, idempotencyKey)` 범위입니다. 같은 환불 키에 다른 금액은 409입니다. 중복 응답은 최초 HTTP 응답 캐시가 아니라 현재 payment snapshot입니다.
- 승인 uniqueness 경합은 실패 트랜잭션 종료 뒤 새 트랜잭션에서 기존 결제를 확인합니다. DB unique가 복수 인스턴스의 중복 승인도 막습니다.
- 취소·환불은 payment 행을 비관적 잠금하고 상태 변경·거래 이력을 같은 트랜잭션에 기록합니다. 글로벌 JVM 잠금에 의존하지 않습니다.
- CANCELLED는 void와 같은 전액 취소이며 refundedAmount는 0으로 유지됩니다. 환불 합계에 취소 금액을 다시 더하지 않습니다.
- 두 PG는 인증·webhook·merchantTxId GET·거래 목록 대사 API·실패 주입·simulated 응답 필드를 아직 제공하지 않습니다. `/actuator/health`도 없습니다.
- 응답을 받기 전 승인 연결이 끊긴 경우 같은 merchantTxId/내용으로 승인 재요청하면 중복 효과 없이 조회되지만, 일반 실제 PG adapter로 이 정책을 확장해 가정하지 않습니다.
- 공유 환경에 노출하기 전 service-to-service 인증/네트워크 접근 제어를 구현해야 합니다. 현재 Compose는 로컬 검증용입니다.

## 7. Commerce–Payment 구현 계약

상세 필드는 [Checkout v1 계약](../contracts/commerce-payment-checkout-contract-v0.1.md)과 [목표 OpenAPI v1](../contracts/payment-service.openapi.yaml)에 있습니다. 아래는 아직 연결되지 않은 구현 기준입니다.

1. Commerce가 회원 소유권, 상품 판매 가능 여부, Checkout revision/만료, 가격·배송비와 재고 예약을 검증합니다.
2. Commerce DB에서 PENDING_PAYMENT Order와 immutable snapshot을 commit합니다. 외부 PG 호출을 DB transaction 안에서 기다리지 않습니다.
3. 인증된 Commerce만 Payment의 prepare를 호출합니다. 브라우저가 임의 주문·금액·배분을 제출하지 못하게 합니다.
4. snapshot에는 checkoutId/revision, orderId, memberId, amount {currency, amount}, expiresAt, items[], charges[]를 보존합니다. items.paidAmount = productAmount - discountAmount + taxAmount이며 양수, 총액은 item 합계 + charge 합계입니다. 중복 item/charge ID와 overflow도 거부합니다.
5. Payment는 주문별 단일 미해결/성공 시도, provider별 요청 키와 전체 payload 일치를 DB에서 확인하고 PG 요청 정보를 commit합니다.
6. PG 결과 확정 후 Payment·PaymentTransaction·배분·Outbox를 한 transaction으로 기록합니다.
7. Commerce는 PaymentApproved를 inbox로 한 번 반영하고 주문/예약을 갱신합니다. 승인 후 재고 소비가 불가능하면 void/refund 보상을 진행하고 완료 전 주문 성공으로 표시하지 않습니다.
8. 배송·Claim·구매확정은 Commerce가 처리합니다. PurchaseConfirmed 및 RefundSucceeded 등 정산 사건을 Settlement가 소비합니다.

주문과 결제 시도 생성 사이의 통신 장애에는 같은 키와 snapshot으로 재요청합니다. [ORD-05](requirements/02-commerce.md)의 close-order handshake와 [PAY-05](requirements/03-payment-pg.md)의 UNKNOWN 정책(15분 incident/24시간 수동 전환, 시간만으로 예약 해제 금지)을 적용합니다. 결제 승인만으로 판매자 지급을 시작하지 않습니다.

Payment HTTP API는 **내부용 목표 계약으로 확정했으나 전부 미구현**입니다. 경로는 `/internal/v1`, Commerce 서명 JWT·scope를 검증합니다. 현재 내부 PreparePayment record에는 전체 snapshot 필드가 없으므로 영속화 구현 시 확장해야 합니다. requester 신원은 인증된 호출자로부터 검증하며 본문을 그대로 신뢰하지 않습니다.

OpenAPI는 정수 int64이며 v1 주문 금액은 1억원 이하, 정산 집계 API는 JS safe integer 범위로 제한합니다. 문자열 금액은 사용하지 않습니다. 범위와 합계 검증은 서버가 수행합니다.

## 8. 이벤트·구매확정·정산 구현 기준

아직 producer/consumer와 소비 inbox는 구현하지 않았습니다. 토픽·필수 payload·version·retry/DLQ는 [이벤트 v1 계약](requirements/07-events-reliability.md)으로 확정했습니다. 아래는 요약이며 상세 registry가 우선합니다.

| 사건 | producer | consumer 및 효과 |
| --- | --- | --- |
| ProductRevisionPublished | Commerce | Discovery 검색/분석 입력 갱신 |
| PaymentApproved/PaymentFailed/PaymentUnknown | Payment | Commerce 주문·결제 표시 갱신. Settlement는 조회 projection만 가능 |
| ShipmentDelivered/PurchaseConfirmed | Commerce | 배송 조회 및 Settlement 지급 대상 원장 |
| RefundSucceeded | Payment | Commerce Claim 완료 및 SellerFinancialAdjusted 생성; Settlement에서는 대사 projection만 |
| SellerFinancialAdjusted | Commerce | Settlement 기존 인식 매출/수수료 역전, 원시 RefundSucceeded와 중복 차감 금지 |
| SellerPenaltyApplied | Commerce | Settlement 제재 조정 |
| SettlementPaid/PayoutUnknown | Settlement | Commerce 판매자 조회·지원 화면 |

이벤트 공통 필드: eventId, eventType, eventVersion, producer, aggregateType, aggregateId, aggregateVersion, occurredAt(UTC), correlationId, causationId, traceId, payload, simulated=true. `aggregateType:aggregateId`를 partition key로 사용합니다. domain 변경과 local outbox insert는 같은 DB transaction, publisher는 commit 후 발행합니다. Kafka ack 후 outbox 완료 전 장애는 중복 발행될 수 있습니다. 소비 측은 `(consumer, eventId)` unique inbox 수신 저장 후 ACK하고, 별도 처리 transaction에서 업무 변경·inbox 종결·checkpoint를 함께 commit합니다. gap/재처리도 같은 원 이벤트 ID/hash를 보존합니다.

Outbox ID=eventId, event_key는 stream/type/id/sequence의 논리 고유키입니다. aggregateVersion은 stream 발행 sequence이며 임의 entity version과 다릅니다. replay는 eventId를 유지하며 역순/gap은 보류합니다. retry/DLQ/보존/SLO 수치는 [07 문서](requirements/07-events-reliability.md)를 따릅니다.

구매확정은 ShipmentItem 수량별, 배송완료+192시간(주말 포함) 자동확정으로 결정했습니다. 열린 Claim 수량은 제외하며 확정과 Claim hold는 동일 Commerce transaction의 lock으로 경합을 제어합니다. 상세는 [FUL-02](requirements/04-fulfillment-claims.md)입니다.

Settlement는 seller/currency별 불변 ledger를 source event/unit key로 멱등 반영하고 reversal entry로 조정합니다. 지급은 내부 영속 모의 은행 adapter만 사용합니다. 지급 후 환불은 다음 정산 차감/음수 채권 이월로 처리하며 고객 환불을 미루지 않습니다. 상세 수수료·승인·barrier·지급·대사는 [05 문서](requirements/05-settlement-operations.md)를 따릅니다.

## 9. 다음 구현 순서와 완료 조건

| 순서 | 구현 범위 | 완료 판단 |
| --- | --- | --- |
| 1 | Payment snapshot·attempt/payment/transaction/refund·배분의 영속 구현 | DB 재시작 보존, 같은 주문 동시/다른 provider 결제 차단, FK·합계 검증 |
| 2 | PG HTTP adapter와 결과 불명 복구 | 요청 전 commit, timeout 후 동일 키 조회/재처리, UNKNOWN 예약 유지, 부분 응답 검증 |
| 3 | Payment outbox + Commerce inbox | 승인/환불과 outbox 원자성, 중복·역순·재전송 테스트 |
| 4 | Commerce 최소 상품·재고·Checkout·주문 흐름 | oversell 0, 불변 가격, 결제 성공/실패/보상 E2E |
| 5 | 구매자 프론트 | 실제 API 계약으로 주문서·결제 결과·주문 조회, 처리 중·UNKNOWN 표현 |
| 6 | 배송·Claim·구매확정·Settlement | 부분 배송/반품 수량, 원장 중복 0, 정산/지급 UNKNOWN 복구 |
| 7 | Discovery·운영·인증 강화 | projection 재구축, 민감정보 제한, 계약/권한/E2E 검증 |

이 순서는 작업 기준이며 이번 검토에서 미구현 기능을 전부 구축했다는 의미가 아닙니다. 새 기능은 실제 테스트로 확인한 범위만 현재 구현으로 승격합니다.

기존 미정 목록은 [DEC-01~24](requirements/README.md)로 대체됐습니다. 상세 구현 순서와 신규 모델·32개 수용 시나리오는 [08 문서](requirements/08-delivery-acceptance.md)가 위 요약보다 우선합니다. 특히 인증 최소 기반은 첫 단계에 포함하고 PG 확장/영속 복구 전에 고객 API를 공개하지 않습니다.

## 10. 검증과 작업 완료 기준

실행 환경과 명령은 [MSA.md](../MSA.md), 이번 수정 근거와 검증 범위는 [검토 보고서](logic-analysis-2026-09-21.md)에 있습니다.

- 변경 전 관련 use case, migration, 계약과 테스트를 함께 읽습니다. 기존 미커밋 변경을 보존합니다.
- 정상/경계/변경된 멱등 요청/동시 요청/UNKNOWN/잘못된 권한을 해당 구현 범위에서 검증합니다.
- 전체 `clean build`, 서비스 스키마 검증, 문서 링크 검증을 실행합니다. DB/locking 변경에는 격리 PostgreSQL 검증을 추가합니다.
- H2 context 테스트는 PostgreSQL migration·분산 복구 검증을 대체하지 않습니다. PG 동시성 테스트는 DB 경합을 검증하지만 여러 프로세스 E2E는 별도입니다.
- V1 checksum을 보존하고 새 migration만 적용합니다. 실데이터 정리나 운영 배포는 별도 작업입니다.
- 새 계약/환경변수/상태·구현 범위와 실행 결과를 이 문서 및 해당 계약에 함께 갱신합니다.
