# 08. 구현 순서·스키마 차이·수용 테스트

## 현재와 목표의 경계

2026-09-21 현재: 4개 업무 서비스 scaffolding, Payment는 in-memory reference, PG1/PG2에 기존 4개 REST 경로와 DB 처리만 있습니다. 본 묶음은 **요구사항 확정**, 아래 구현과 시험은 앞으로 수행할 작업입니다. 이전 검토의 39개 테스트 통과를 신규 요구사항 전체 통과로 해석하지 않습니다.

## DATA-01 필요한 서비스-local 데이터 확장

기존 V1/V2 checksum 유지. 다음은 새 migration에서 반영할 모델 요구이며 이번 문서 작성으로 DB가 바뀌지는 않습니다. 테이블 이름은 아래 이름을 기본으로 사용하고 변경 시 문서를 함께 바꿉니다.

| owner | 추가/보완 모델 | 반드시 보장할 제약/인덱스 |
| --- | --- | --- |
| Commerce | credential/verification/sessionVersion, invitation, command_idempotency, payment_dispatch_intent | normalized email unique, token hash unique/expiry, principal+operation+key unique, order별 dispatch gate |
| Commerce | order_item_unit, shipment/claim 단위 연결, claim_quote(5분), claim_reason_change version, checkout policy snapshot | `(order_item_id,unit_ordinal)` unique, 원 unit의 중복 활성 claim/outbound 금지, 수량·가격 배분 합계 |
| Commerce | seller financial sequence/outbox, approval execution, payout fence | stream/version unique, 승인hash+1회소비, fence/version/expiry, 주문별 actor 감사 |
| Payment | order_payment_guard, payment_operation, operation lease/result evidence | order PK CLOSED tombstone, provider+merchant unique, payment별 active dispatch 하나, due(status,next_retry_at) |
| Payment | attempt snapshot, refund unit/charge allocation, voidedAmount, PG reconciliation | request hash, 환불 대상 단위 중복금지, 금액잔액 lock, provider+transactionId unique |
| 각 업무 service | consumer_inbox + stream checkpoint + outbox lease/sequence + event_recovery_job | consumer+eventId unique, stream sequence unique, status/nextRetry/lease expiry index |
| 각 PG | receipt 조회 보조 인덱스, webhook_outbox, fault scenarios | merchant unique 유지, `(payment,type,key)` unique, `(occurred_at,transaction_id)` cursor |
| Settlement | recognition unit/charge projection, carry-forward/debt, bank receipt/reconciliation 3표, gross_net_amount, approval snapshot | source identity unique, 원장 초과배분 금지, 부분 역전 일반 index+누적 한도 lock, gross/hold/payout CHECK, seller/currency cycle key, payout key unique |
| Discovery | search_product_projection/generation, event dedup | productId/generation unique, version 조건부 update, 검색/가격/category cursor 인덱스 |

새 논리 상태 `recoveryHold`, `gate`, `operationStatus`, `financialVersion`은 기존 status enum과 다른 필드입니다. 예를 들어 orders에는 UNKNOWN을 넣지 않고 paymentStatus/recoveryStatus로 표현합니다. 승인 EXPIRED는 현재 CHECK에 이미 있으며 DB PENDING을 HTTP APPROVAL_PENDING으로 매핑합니다. 금융 fence 등 새 필드/제약은 [마이그레이션 계획](../implementation/03-migrations.md)에 따라 도입합니다. ORM이 임의 DDL을 생성하거나 CHECK를 제거하지 않습니다.

인덱스는 실제 query와 실행계획으로 검증합니다. 우선순위: payment order guard, inventory reservation active/expiry, inbox/outbox due, claim open unit, shipment/confirmation due+hold, ledger unallocated seller/currency, payout unresolved, receipt date cursor. 수량/금액 여러 행 불변식은 index만으로 충분하지 않으므로 owner transaction/lock 테스트 필수. 웹/배치 임의 full scan을 기본 구현으로 채택하지 않습니다.

## DEV-01 착수 순서와 gate

| 단계 | 구현 내용 | 다음 단계 전에 확인 |
| --- | --- | --- |
| A | 계약 DTO/schema fixtures, auth/인가 최소기반, command key/guard migration | 401/403/소유권, DTO 합계·정수·KRW 검증, schema link 일치 |
| B | Payment 영속화+PG1/PG2 adapter+operation queue+close-order | 다중 instance 중복0, restart복구, UNKNOWN 보존, 실패/성공 배분 |
| C | PG receipt/merchant 조회·webhook·fault·대사 확장 | 응답유실/중복·역순 webhook, 같은receipt 1회효과, 대사 정확성 |
| D | Commerce 상품·재고·checkout·order, outbox/inbox 구매 연결 | oversell0, expiry race, PG2 별도 성공, 보상·고객 상태조회 |
| E | storefront 실제 API 연결 | 결제중 새로고침/뒤로가기/재조회, 금액위조거부, mock 제거 |
| F | 배송·Claim·교환·확정·리뷰·알림 | 부분 수량/배송비/claim hold/단위 배분 정합 |
| G | seller financial stream·원장·정산·모의은행·운영 승인 | 지급후환불·carry-forward·중복지급0·복원대사 |
| H | Discovery·분석·판매자/관리자 UI·독립 SPA 추출 | projection 재구축, 권한분리, 세 앱별 독립 배포 시험 |

각 단계는 독립 검증 가능한 vertical slice로 나눕니다. 인증을 마지막에 덧붙이지 않으며, 실제 PG adapter를 붙이기 전에 영속 요청과 멱등 guard가 먼저 있어야 합니다. 계획상 앞 단계여도 기능 없는 화면을 production 완료로 보고하지 않습니다.

## TEST-01 필수 수용 시나리오

동시성/영속화 시험은 격리 PostgreSQL, DB unique/lock을 사용하는 실제 repository와 HTTP 두 인스턴스로 수행합니다. H2나 단일 JVM synchronized만 통과하면 부족합니다. 테스트마다 요구사항 ID, arrange/action/assert, failure injection point를 남깁니다.

| ID | 관련 요구 | 시나리오와 합격 결과 |
| --- | --- | --- |
| AT-01 | SEC-01/02 | 타회원 orderId/타seller SKU/비관리자 지급 요청 → 404/403, DB/PG 효과0 |
| AT-02 | SEC-01/03 | CSRF 없음, 위조JWT/다른aud/만료/알고리즘변경 → 거부; token 로그0 |
| AT-03 | MONEY-01 | KRW외통화, 소수/문자열/overflow/합계 mismatch → PG요청0 |
| AT-04 | ORD-02/INV-01 | available10에 100 동시 구매예약 → 합계예약<=10, 부분실패 rollback |
| AT-05 | ORD-03/PAY-01 | 동일 order PG1/PG2 각각 20 동시시도 → 유효 approval 최대1 |
| AT-06 | API-02 | 같은key·같은payload → 같은ID, 다른금액/배분/actor →409 |
| AT-07 | ORD-05 | close-order가 prepare보다 먼저 도착 → CLOSED tombstone, 늦은승인0, 예약1회해제 |
| AT-08 | ORD-05/PAY-05 | dispatch와15분expiry 경합·timeout → UNKNOWN예약유지, 다른PG재결제0 |
| AT-09 | PAY-02/05 | PG승인commit후 응답유실+Payment재시작 → 원 key복구, SALE/PaymentApproved1회 |
| AT-10 | PG-01 | 각각 PG1/PG2 정상 결제·조회·전액취소·부분환불 → 독립DB, provider혼선0 |
| AT-11 | PAY-04 | 10,000원에 병렬7,000원 환불2개 → 예약/성공 총액<=10,000 |
| AT-12 | PAY-04/05 | 첫환불UNKNOWN+둘째환불 접수 → 둘째 dispatch대기, 새key재환불0 |
| AT-13 | PAY-04 | VOID된결제 refundedAmount=0, voidedAmount=원금, refund불가; 금융순액0 |
| AT-14 | PG-03 | 서명오류/만료/같은event다른body →401/409; 유효중복·역순 → 1회effect |
| AT-15 | EVT-03 | Kafka ACK후outbox완료 전 crash, inbox업무commit후offset실패 → 재고/원장중복0 |
| AT-16 | ORD-04 | PG승인후예약손상 fault → 출고차단·보상완료 후CANCELLED, 결제유실0 |
| AT-17 | FUL-01/CLM-01 | 인계와취소 동일unit 경합 → 둘 중 하나, 과출고/과환불0 |
| AT-18 | FUL-02 | delivered+191:59:59 미확정, +192h대상; Claim hold수량만제외 |
| AT-19 | FUL-02 | 자동확정과Claim 동시 → 한쪽winner, 동일unit 매출/환불중복0 |
| AT-20 | CLM-02 | seller2개·부분/전량취소·분할반품 → seller배송비1회, 재청구0, charge초과환급0 |
| AT-21 | CLM-03 | 교환예약만료/재고부족/대체배송 → 환불전환 또는1회교환, 두번째승인/매출0 |
| AT-22 | SET-01 | 승인만/확정전환불 → 지급원장0; 확정수량만매출, 원시환불+조정 중복차감0 |
| AT-23 | SET-02 | 10,001원 배분/일괄vs부분 확정/환불 → 원금·fee합계 및 잔여원단위 동일 |
| AT-24 | SET-02/03 | 두정산worker/동일관리자승인/새Claim fence → 배분1회, 자기승인거부, hold또는지급후조정 |
| AT-25 | SET-03/04 | 모의은행commit후timeout → 같은receipt복구·중복지급0; 지급후환불 음수이월보존 |
| AT-26 | PAY-06/SET-04 | PG/은행 한쪽기록누락·금액차이 → discrepancy, 근거없는자동수정0 |
| AT-27 | EVT-02/03 | sellerfinancial seq2먼저/seq1지연 → 보류후순차적용, 원장최종동일 |
| AT-28 | EXP-02/DIS-02 | 반품후리뷰·오래된분석결과 → 부정후기자동삭제0, 최신revision오염0 |
| AT-29 | FE-02 | 더블클릭/새로고침/네트워크끊김 →같은logicalkey, UNKNOWN을실패표시안함 |
| AT-30 | OPS-04 | 서비스DB복원+이벤트replay+대사 → 미해결목록보존·원장/재고합계일치 |
| AT-31 | DIS-01/FE-01 | searchgeneration전환/판매중지event/area독립rollback → 상품권위보존·타앱배포불필요 |
| AT-32 | COM-02/OPS-01 | 계좌변경·권한회수·승인후payload변경 → 기존지급snapshot불변·실행차단 |

## TEST-02 완료 산출물

기능별로 최소 정상, 입력 경계, 소유권, 동일/변경 key, 경합, 재시작, 외부 장애(해당 시)를 테스트합니다. 완료 보고에는 테스트 명령/환경/개수·실행 안 된 항목·남은 단계가 들어갑니다. 문서 링크 검사만으로 로직 검증이라고 보고하지 않습니다.

- 코드: service별 controller/application/domain/infrastructure 경계, 외부 호출 port, UTC clock, 실행 상태/metric.
- 데이터: forward migration, orphan/backfill 검증, query 실행계획, unique/lock 실DB 시험.
- 계약: 해당 기능 OpenAPI/이벤트 JSON Schema, 예제, 생성 client 호환 시험. 이 문서에 확정된 필드를 생략하면 완료 불가.
- 사용자 동작: 실제 UI→Commerce→Payment→PG1 및 PG2→주문반영→Claim→정산 E2E, 모든 금융 화면 simulated 표시.
- 운영: UNKNOWN/DEAD/gap/discrepancy 조회·재처리·감사, backup/restore 시험. DB수동수정 없이 복구 가능해야 함.

구현 결과를 [BACKEND_DESIGN](../BACKEND_DESIGN.md)의 현재 상태에 반영하고, 정책을 변경했다면 [결정 목록](README.md)의 변경 이유·version과 영향을 받은 AT ID를 기록합니다. “나중에 정함”으로 기존 결정이나 안전 gate를 삭제하지 않습니다.
