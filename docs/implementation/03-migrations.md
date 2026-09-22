# 03. 현재 → v1 목표 DB 마이그레이션 계획

기준: [현재 ERD](../erd/current/all-services.dbml), [목표 변경 목록](../erd/target/CHANGES.md), [DATA-01](../requirements/08-delivery-acceptance.md). 현재 파일113테이블/173FK → 목표163테이블/209FK입니다. 실행 DB를 조사한 수치가 아닙니다. [변경별 실행 단계](migration-manifest.json)는 목표 overlay의 모든 변경을 migration wave와 연결합니다.

이 문서는 기존 DB의 적용 계획입니다. [현재/목표 SQL 스냅샷](../ddl/README.md)은 빈 격리 DB 전용이며 기존 데이터 업그레이드 migration이 아닙니다. 적용된 V1/V2를 수정하지 않고 서비스별 다음 번호에 expand migration을 작성합니다. 서비스-local version 번호는 서로 동기화할 필요가 없습니다.

## MIG-01 단계와 버전 예약

| wave | 서비스 / 새 migration 이름(계획) | 주요 내용 | 선행 조건 |
| --- | --- | --- | --- |
| M0 | 전체 preflight | checksum/row count/orphan/중복/금액/진행거래 inventory, 백업·복원 가능 확인 | 현재 서비스별 누적 migration 적용 검증 |
| M1 | Commerce V2, Payment/Settlement/Discovery V3 `event_identity_expand` | inbox/checkpoint/sequence/recovery job, outbox envelope·text aggregateId, Commerce credential/token/sessionVersion/idempotency | 기존 outbox writer·publisher 일시 중지 또는 호환 writer |
| M2 | Payment V4 `payment_recovery_expand`, 각 PG V2 `receipt_webhook_expand` | 주문 guard/operation/result/환불unit/PG대사, PG webhook/fault·receipt cursor | M1, 기존 PG 데이터 보존 |
| M3 | Commerce V3 `order_unit_fulfillment_expand` | item unit, shipment/claim/confirmation unit, claim quote/사유변경 version, dispatch intent, recoveryHold, snapshot | M1, close-order와 P2 영속화 준비 |
| M4 | Commerce V4 `financial_fence_expand`, Settlement V4 `payout_financial_expand` | financial state/fence/approval, recognition/carry-forward/bank receipt, 정산 의미 정합화 | M2/M3, financial event schema |
| M5 | Discovery V4 `projection_generation_expand` | search generation/projection, 분석 retry/simulated | M1, catalog snapshot API 준비 |
| M6 | 각 서비스 다음 version `validate_v1_contracts` | backfill 증거 검증, NOT NULL/CHECK/unique 검증, 신 reader 전환 | 해당 wave 동작과 회귀 통과 |
| M7 | 별도 후속 version `retire_legacy_reads` | 구 reader 제거 및 불필요 인덱스 정리 | 관측기간+복원 리허설+기존금융조회 검증 |

위 번호는 현재 파일 기준 예약입니다. 작업 시 새 migration이 선행됐다면 충돌 없는 다음 번호로 조정하고 manifest에 실제 파일을 기록합니다. 이미 적용한 checksum 변경·repair로 번호 충돌을 우회하지 않습니다.

## MIG-02 기존 SQL과 요구사항의 차이

| 대상 | 실제 차이 | 결정된 전환 방법 |
| --- | --- | --- |
| settlement.net_amount | 현재 CHECK는 credit-debit-hold, API 요구 netAmount는 credit-debit | M4에서 `gross_net_amount bigint`를 nullable로 추가, credit-debit로 backfill. API netAmount는 이 컬럼 사용. 기존 net_amount는 legacy post-hold 값으로 유지. 새 payout CHECK는 payout<=greatest(gross_net_amount-hold_amount,0). net를 이중 차감하지 않음 |
| seller_ledger_entry.reversal_of_entry_id | 현재 UNIQUE는 원행당 역전1건만 허용 | 누적 부분 역전이 필요한 legacy 행은 M4에서 unique를 일반 index로 교체. owner가 원ledger/recognition을 lock하여 누적역전<=원액 검사. 이벤트source unique는 유지 |
| admin_approval_request.status | DB PENDING, HTTP APPROVAL_PENDING; EXPIRED는 이미 CHECK에 있음 | DB PENDING↔API APPROVAL_PENDING 명시 mapping. EXECUTED/FAILED는 approval_execution 결과로 조회. EXPIRED를 새 상태로 중복 추가하지 않음 |
| outbox.aggregate_id/version/payload | 현재 UUID, nullable/nonnegative version, payload object/array | text aggregateId, version>=1, object envelope. 과거 미확인 payload를 임의 v1로 변환해 발행하지 않음 |
| payment guard | 현재 active attempt unique가 order+provider 범위 | order PK guard로 provider 전체를 직렬화. 성공/VOID/REFUND 이력도 영구 성공 금지 guard 유지 |
| payment voided_amount | 현재 독립 필드 없음 | VOID 영수증/거래 근거로만 backfill, refunded+voided<=total. VOIDED는 refunded=0, voided=total |
| aggregate 가격·수량 | 현재 item/shipment/claim 중심, unit lineage 없음 | 원 snapshot과 이력에서 검증 가능한 unit만 생성. 이미 출고/환불된 여러수량의 임의 ordinal 할당 금지 |
| Settlement reconciliation_* | legacy PG형 필드 포함 | v1 신규 은행 대사에서는 사용하지 않음. 신규 `bank_reconciliation_run/receipt/discrepancy`에 bank key/account hash 중심 모델을 추가하고 기존 행은 legacy 읽기 유지 |

`gross_net_amount`, bank_reconciliation_* 및 위 constraint/index 변경은 **목표 ERD와 Settlement 목표 SQL에 반영 완료**입니다. 기존 DB용 migration은 M4/M6의 nullable expand→backfill→최종 NOT NULL/CHECK 순서로 작성합니다. bank_reconciliation_run: run_id PK, business_date, source_as_of, algorithm_version unique; receipt: bank_receipt_id PK, run_id FK, receipt/hash; discrepancy: discrepancy_id PK, run_id FK, identity_key unique, kind/status, expected/actual JSON, approval_id 외부참조. 기존 PG 대사 행을 은행 영수증으로 재해석하지 않습니다.

## MIG-03 backfill 절차

공통: writer를 호환 버전으로 배포→새 nullable 필드/테이블→PK cursor 500행 이하 배치→batch별 commit/checkpoint→전수 불변식 비교→제약 검증→reader 전환. 신규 쓰기는 새 필드를 채우고, backfill은 값이 비어 있는 기존 행만 갱신합니다. 외부 HTTP를 backfill DB transaction에 넣지 않습니다.

| 모델 | 채울 값과 증거 | 자동 전환하지 않는 경우 |
| --- | --- | --- |
| credential/session | 기존 member_auth_identity PASSWORD hash 재사용. member.password_hash만 있으면 검증된 hash 형식 그대로 이전, sessionVersion0 시작 후 세션 폐기 | 서로 다른 두 credential, 미지원 hash: 계정 잠금/재설정 경로. 평문 추정 금지 |
| verification/invitation/upload/idempotency | 새 테이블은 빈 상태 시작. 기존 미종결 작업은 원 요청/리소스와 연결 가능한 경우만 이관 | 과거 요청키를 새 key로 조작하여 재승인 금지 |
| order_item_unit | ordered_quantity 1..99, 원 product/discount/paid와 고정fee를 MONEY-01 배분. sum(unit)=item 검사 | snapshot/정책버전 불명, 부분배송/Claim/환불 단위 연결을 증명하지 못함 |
| shipment/claim/confirmation unit | 원 shipment_item/claim_source_allocation/confirmation_event를 시간·source ID로 대조, 같은원unit 중복효과0 | 기록이 aggregate 수량만 있어 복수 해석 가능: 주문별 격리, 수동 근거 확보 |
| order guard | 과거 성공 payment 존재→successful_payment_id 보존. 미해결attempt→active 유지. 확정취소/만료→CLOSED | 다중provider 승인/미해결 중복이면 자동하나선택 금지, incident |
| operation/result | provider 요청키/raw request와 확정거래 증거 연결, resultVersion1부터 해당이력용 baseline | 원 receipt나 no-effect 근거 없음→UNKNOWN. 성공으로 추정하지 않음 |
| outbox sequence | 신 v1 stream은 1부터 시작. 이미 v1을 발행했다면 원 event sequence 그대로 이관 | 구 non-v1 outbox는 LEGACY 격리/archive, 같은 ID에 새 v1 payload를 덮어쓰지 않음 |
| financial recognition | 기존 ledger source와 원 Commerce 확정event/unit이 1:1이면 동일 recognition 식별로 연결 | 이미 지급된 aggregate 원장을 unit별 신규매출로 재생성 금지 |
| carry-forward | source settlement/배분·잔액을 연결, 차변·대변 부호 유지, 완료+미이월 합계 대조 | 양수 소액을 중복 지급하거나 음수 debt를0으로 변경 금지 |
| bank receipt | 원 adapter receipt/key/hash 있는 행만 이관, 없으면 legacy payout 증거로 보존 | 과거 PAID만으로 새 은행 receipt를 만들어 성공 위장 금지 |
| search projection | 새 generation에 catalog snapshot asOf/watermarks→증분events catch-up→검증→ACTIVE교체 | 임의 updatedAt 최신값만으로 금융/상품 stream gap 무시 금지 |

운영자가 격리 해제할 때 원본 ID, 적용전/후 합계, 증거hash, 작업자/검토자, batch ID를 기록합니다. 재실행은 같은 batch/source ID로 no-op 또는 동일 결과여야 합니다. 격리 목록은 숫자가0이어야 자동 전환하며, 일부 제외 전환은 제외된 resource의 쓰기 차단을 유지합니다.

## MIG-04 신규 제약·인덱스 우선순위

목표 모델에는 명시적 CREATE INDEX 252개(현재 202개)가 정의됐습니다. PK/UNIQUE가 자동 생성하는 인덱스는 별도입니다. 아래 우선순위의 단일 행 CHECK·partial unique·조회 인덱스는 [목표 SQL](../ddl/README.md)에 포함했고, 여러 행의 합계/활성 상태는 owner lock으로 보장합니다. 실제 데이터 분포·QPS에 대한 EXPLAIN/부하 측정은 아직 실행하지 않았으므로 성능 최적화 완료를 뜻하지 않습니다.

| 우선 | 대상 | 목표 키/인덱스 또는 불변식 | 확인 query |
| --- | --- | --- | --- |
| P0 | order_payment_guard | order_id PK, active/successful Payment-local FK | order 기준 prepare/close 동시 요청 |
| P0 | payment_operation | provider/kind/merchant/key unique; payment당 dispatch중 한 개 | `kind`, status, next_retry_at, lease_expires_at로 회수 |
| P0 | refund_unit_allocation | refund/item/ordinal PK, payment lock에서 활성·성공 중복 합산 | 동일unit 이중환불/병렬7천원2건 |
| P0 | active_unit_claim_guard | order_item_id/unit_ordinal PK, claim_item_unit FK | 인계/Claim/확정 경합 |
| P0 | shipment_item_unit | order item/unit/generation의 active outbound 중복 금지 | 자식에 active flag를 두는 경우 상태와 같은transaction에서 갱신; 다른표 status에 의존하는 partial index 불가 |
| P0 | financial/fence | seller PK, payout_attempt/fence_version unique, active/consumed fence partial unique | 만료 fence 교체·consume replay |
| P0 | inbox/checkpoint/outbox | consumer/event PK; stream/sequence unique; due(status,next_retry_at) 또는 outbox available_at | due처리, lease회수, 금융 gap |
| P0 | payout/bank | payout key unique, bank key unique, payload/account hash 일치 | timeout 후 동일key receipt |
| P1 | reservation/confirmation | expiry/eligibleAt + ID cursor, active/no-hold 대상 | 1분 worker와 recoveryHold 제외 |
| P1 | ledger/allocation | source_key unique, seller/currency/recognized_at/ID, allocation 원금 상한 | cutoff 정산·역전·이월 |
| P1 | PG transaction | `(created_at,transaction_id)`, `(payment_id,transaction_type,idempotency_key)` | API occurredAt=현재 DB created_at, 고정asOf cursor |
| P1 | projection | generation/category/price/product_id, generation/published_at/product_id | 필터·price/newest cursor EXPLAIN |

partial unique payment dispatch predicate는 `status IN ('PROCESSING','PENDING','UNKNOWN') AND payment_id IS NOT NULL`로 설계합니다. 대기 REQUESTED는 여러 개 접수 가능하고 승인 전 operation은 order guard로 보호합니다. PG dispatch 직전 같은 lock 아래 REQUESTED→PROCESSING으로 전환합니다. lease 만료만으로 UNKNOWN을 predicate 밖으로 빼지 않습니다.

CHECK/FK 추가는 가능한 경우 NOT VALID→backfill→VALIDATE 순서, NOT NULL은 null0 검증 후. unique index는 중복을 먼저 검사합니다. 대용량 기존 table의 concurrent index 생성은 transaction 밖 별도 migration/config로 분리하고 실패한 invalid index 여부를 확인한 뒤 명시적으로 복구합니다. Flyway version과 PostgreSQL에서 해당 절차를 격리 DB로 검증합니다. DBML import가 이 SQL 전체를 대신하지 않습니다.

## MIG-05 적용 gate와 복구

각 wave 기록: 서비스/DB 식별, migration checksum, 시작/종료, 전후 row count, 금액/수량 합계, null/orphan/중복 건수, query 실행계획, backfill checkpoint, app reader/writer 버전, 테스트 결과. 고객/계좌/토큰 원문은 기록하지 않습니다.

- G0: 현재 checksum 불변, 서비스 간 FK0, 백업 복원 가능, 정확한 대상 DB 확인.
- G1: 빈 격리 PostgreSQL에 전체 migration 적용, 기존 버전 sample DB 업그레이드 모두 성공.
- G2: insert/update/재실행/중단후재개에서 원금·reserved·recognized·payout·carry-forward 보존. PG receipt 포함 교차 서비스 비교는 API/증거 export로 수행.
- G3: 새 worker 읽기-only 검증→canary write→target reader. 새 필드로 쓰기 시작한 뒤 그 필드를 모르는 구 worker 동시 실행 금지.
- G4: AT-04~27/30/32 해당 범위 통과, orphan/중복0, 진행 UNKNOWN/hold 누락0. 목표 QPS로 실행계획 확인.

실패 시 해당 writer/worker를 멈추고 expand schema를 남긴 채 호환 app으로 되돌립니다. 신규 상태를 구버전이 해석할 수 없으면 쓰기 동결 후 forward fix가 기본입니다. 적용된 DDL을 drop/down migration으로 되감거나 backfill 전 backup으로 PG 효과까지 사라진 것으로 취급하지 않습니다. cross-service 복원은 [RB-06](06-runbooks.md#rb-06-db-복원과-재개)를 따릅니다.
