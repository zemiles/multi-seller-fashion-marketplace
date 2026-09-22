# 06. 장애 대응·운영 절차

v1 모의 거래용. 책임: Commerce=주문/재고/Claim/승인, Payment=PG결제·PG대사, Settlement=원장·모의지급·은행대사, Discovery=검색/분석. 현재 실행 상태는 [BACKEND_DESIGN](../BACKEND_DESIGN.md), 환경·포트는 [MSA](../../MSA.md)를 먼저 확인합니다.

`현재 가능`은 기존 PG 4개 REST/앱 로그/빌드/DB 읽기 진단입니다. `목표` API·worker·metric·운영 UI는 해당 기능 구현 후 사용할 절차입니다. 문서만으로 새 endpoint가 생기지 않습니다. 예시 UUID/자격정보는 실제 대상 값으로 바꾸고 조회 결과를 공개 채널에 복사하지 않습니다.

## 공통 진입·기록·해제 기준

사건 생성 시: incidentId, 최초발견 UTC, owner, 환경, order/payment/operation/refund/payout/event/stream ID, 마지막 확정 version, 영향 resource 수, 마지막정상시각, 증거hash, 담당자와 검토자. 금액은 최소 필요 범위, 세션/비밀번호/계좌/주소 원문은 수집하지 않습니다.

즉시 범위별 write를 hold하고 읽기 조회는 유지합니다. UNKNOWN 결제 하나 때문에 다른 결제의 worker를 전체 중지하지 않습니다. PG DB 유실/공통 publisher 무결성 문제처럼 범위가 넓다는 근거가 있을 때 provider/stream/서비스 단위로 확대합니다. hold 해제는 원인 해결+중복효과0+잔액/수량/sequence 정합+미해결목록 보존을 확인한 뒤 기록합니다.

읽기 진단 예(backend root, 현재 가능):

```powershell
docker compose ps
docker compose logs --since 15m --tail 200 payment-service commerce-service pg-kakao-simulator pg-naver-simulator
# PG1 현재 snapshot 조회: 승인/환불을 생성하지 않음
$pgPaymentId = '00000000-0000-4000-8000-000000000024'
Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:8090/pg/v1/payments/$pgPaymentId"
# PG2는 8091. 반드시 저장된 provider와 providerPaymentKey를 사용.
```

업무 서비스 actuator가 살아 있어도 UNKNOWN이 없다는 의미가 아닙니다. 현재 PG에는 actuator가 없습니다. 로그의 timeout은 최종 no-effect 증거가 아닙니다. 진단 중 approve/cancel/refund를 수동 curl로 재실행하지 말고 owner의 영속 operation 경로를 사용합니다.

## RB-01 결제·환불·취소 UNKNOWN

트리거: 최초1분 metric경고, 15분 incident, 24시간 자동 write replay중지. 담당 FINANCE+Payment, Commerce 협력. AT-08/09/11/12/14/16.

1. **조회:** 목표 `GET /api/v1/admin/payment-operations`와 Payment `GET /internal/v1/payment-operations/{operationId}`로 원 request/key/provider/merchant/paymentId/resultVersion/lease/firstUnknownAt 확인. 내부API는 서비스 credential, 브라우저 쿠키를 전송하지 않습니다.
2. **보호 확인:** Commerce reservation recoveryHold/fulfillment block, Payment 진행refund 예약액/직렬queue, 같은order 다른PG attempt 차단을 확인합니다. 없다면 자동 write를 중지하고 해당order 수동사건으로 격리합니다.
3. **외부 증거:** PG snapshot+목표 immutable transaction receipt 조회, 없는 paymentId는 merchant 조회. current PG는 개별receipt 조회가 없으므로 최신snapshot만으로 귀속을 확정할 수 없는 건은 보류합니다. 404만으로 금액/재고를 해제하지 않습니다.
4. **분류:** receipt 일치 성공→동일 operation의 결과반영, 확정no-effect→실패/예약해제, 금액/통화/key 불일치→quarantine+RB-05, 결과불명→UNKNOWN 유지. PG 영속데이터 유실 의심→RB-06, 승인 replay중지.
5. **복구:** 목표 `POST /api/v1/admin/payment-operations/{operationId}/recover`에 동일 멱등key/reason/expectedVersion. 서비스가 저장된 원 operation만 재처리합니다. 수동 사실확정은 evidenceHash+2인승인, 임의 성공/실패 버튼 금지.
6. **검증:** operation 확정증거/resultVersion, provider효과1회, Payment 거래/금액합계, Commerce결과1회, 예약consume/release1회, 필요보상완료, outbox/inbox backlog 감소. 실패하면 hold 유지.

자동 recovery 일정은 +5초/+30초/+2분/+5분/+15분 후15분 간격, jitter<=10%. 24h후 read-only조회1h, 자동 financial write replay는 수동검토 전 재활성화하지 않습니다. webhook과 poll은 같은 결과반영 함수를 사용합니다.

## RB-02 Outbox 지연·DLQ·sequence gap

트리거: oldest60초 경고/5분 사건, gap15분 또는 retry10회소진. 담당 source owner+consumer owner. 금융재처리 FINANCE 2인승인. AT-15/27/30.

1. 정식 X-07 계약 `listEventQueues`(서버 미구현)의 queue 조회에서 source topic/group/aggregateType/id/lastSequence/현재sequence/hash 확인. current에는 queue관리 API가 없으므로 owner DB read-only 진단만 가능합니다.
2. 원 producer outbox에 누락 sequence가 있는지 확인하고 broker 발행ACK/consumer inbox 저장/업무commit을 구분합니다. lease가 살아 있는 worker와 중복 수동처리하지 않습니다.
3. 스키마오류는 호환 consumer 배포 후, 전송실패는 동일 outbox재전송, 업무실패는 원 inbox retry. replay는 eventId/body/key/sequence 불변. 새 ID의 대체 이벤트 생성·offset 임의advance 금지.
4. 2인승인 후 `POST /api/v1/admin/event-queues/{entryId}/replays`(목표)에 expectedHash/evidenceIds/version 전달, job ID를 조회합니다. broker offset만 되감는 작업은 inbox dedup/보존 여부를 먼저 검증해야 합니다.
5. 원본이 유실되었으면 archive/backup에서 같은 ID/hash를 복구합니다. 금융stream을 최신snapshot으로 덮어쓰지 않습니다. catalog/analysis만 검증된 snapshot+watermark 재구축을 사용합니다.
6. job의 OUTBOX SUCCEEDED는 broker ACK+PUBLISHED commit, INBOX SUCCEEDED는 업무/no-op+checkpoint commit을 뜻합니다. OUTBOX job 성공만으로 전체 복구가 끝나지 않습니다. 최종 완료: source와consumer sequence연속, backlog 감소, 같은unit 재고/원장추가0, unknown type0, quarantine 원인별해결 기록. gap 뒤 사건이 먼저 적용되지 않았는지 검사합니다.

읽기 SQL 예시(각 서비스 자신의 DB에서만, `marketplace` schema):

```sql
BEGIN TRANSACTION READ ONLY;
SELECT status, count(*) AS rows, min(occurred_at) AS oldest
FROM marketplace.outbox_event GROUP BY status;
SELECT outbox_event_id, aggregate_type, aggregate_id, aggregate_version,
       status, attempt_count, available_at, locked_at
FROM marketplace.outbox_event
WHERE status <> 'PUBLISHED'
ORDER BY available_at, outbox_event_id LIMIT 100;
COMMIT;
```

`consumer_inbox/checkpoint` 조회는 M1 적용 후 가능합니다. 원 payload 전체를 관리자 목록/일반로그에 출력하지 않고 event ID/hash/검증실패 필드명만 표시합니다.

## RB-03 재고·출고·구매확정 불일치

트리거: available음수, 예약중복, 승인후예약소비불가, 확정+hold수량충돌. 담당 Commerce, 금융효과 연관 시 FINANCE. AT-04/16~21.

1. 해당 SKU/주문 신규checkout·인계를 hold합니다. 기존 금융 UNKNOWN예약은 유지합니다.
2. inventory 현재값과 inventory_ledger, ACTIVE reservation item 합계, consumed order unit, shipment generation, claim guard, confirmation unit을 owner read-only query로 대조합니다.
3. 결제승인 뒤 reservation파손이면 order recovery=COMPENSATING/출고차단, RB-01의VOID/환불완료 후 종결. 재고만 더해서 승인된주문을 성공시켜서는 안 됩니다.
4. 물류재고실사 등 근거가 있으면 기존 `adjustInventory` command에 delta/reason/expectedVersion, 동일 key로 ledger append. reserved 직접update 금지. 반품은 실제검수·재판매가능 증거 후 입고, refund receipt만으로 입고하지 않습니다.
5. 확정/Claim 경합은 unit별sourceEvent를 확인하고 수익이 이미 인식됐다면 financial adjustment. 오래된 event를 삭제해 합계를 맞추지 않습니다.
6. 완료: onHand-reserved-safety>=0, reserved=활성예약합계, outbound generation 중복0, 확정+환불종결unit 중복효과0, 외부금융합계/주문일치. 타 SKU/주문까지 hold해제 범위를 임의확장하지 않습니다.

## RB-04 지급 UNKNOWN·hold·음수 이월

트리거: 지급 UNKNOWN, barrier 미달, fence/permit 모순, 은행 receipt 응답 유실. 담당은 Settlement와 Commerce FINANCE입니다. AT-22~25/32.

1. 해당 판매자의 지급만 hold하고 원장 이벤트 소비는 정상 처리합니다. attempt/key/amount/accountSnapshotHash/approval/fenceVersion/permit/결과 version을 조회합니다.
2. Commerce barrier watermark와 Settlement checkpoint, 신규 Claim/제재 hold, 계좌 version을 비교합니다. 모의 은행의 영속 key로 receipt를 조회하며 변경된 계좌로 재송금하지 않습니다.
3. permit이 미소비 상태로 만료됐다면 같은 attempt에 새 barrier/fence version을 발급합니다. consume 응답만 유실됐다면 같은 consume을 replay합니다. 이미 소비된 permit은 동일 operation 복구에만 사용합니다.
4. 은행 receipt 일치 → 동일 attempt SUCCEEDED/PAID, 확정 no-effect → FAILED 후 새 승인으로 다음 revision, 불명/차이 → hold와 RB-05. 별도 은행 HTTP 서버가 있다고 가정하지 않고 Settlement adapter command를 사용합니다.
5. 지급 후 환불은 recognition 역전과 다음 정산 carry-forward로 처리합니다. 고객 환불 지연·다른 판매자와의 상계·자동 계좌 출금은 금지합니다. 30일간 음수가 지속되면 사건 생성과 신규 지급 hold를 적용하며 채무를 0으로 소거하지 않습니다.
6. 완료 기준: bank key당 receipt 1개, 지급/보류/이월 합계 보존, 요청자·승인자 분리, payload hash 일치, 원시 RefundSucceeded와 SellerFinancialAdjusted의 이중 차감 0건.

## RB-05 PG·은행 대사 불일치

PG 담당은 Payment, 은행 담당은 Settlement입니다. 목표 관리자 API는 `listDiscrepancies/resolveDiscrepancy`이며 AT-26으로 검증합니다.

1. run의 businessDate/sourceAsOf/algorithmVersion과 UTC 조회 범위를 고정합니다. PG는 provider+transactionId, 은행은 bankReceiptId/key 기준으로 원문 hash를 확인하고 양쪽 건수와 cursor 순회 완료 여부를 비교합니다.
2. PROVIDER_ONLY는 owner 결과 반영 누락, INTERNAL_ONLY는 조회 범위/receipt 유실, AMOUNT_MISMATCH는 snapshot/배분, STATUS_MISMATCH는 지연/모순, DUPLICATE는 동일 업무 효과의 중복 여부를 조사합니다. 분류 결과만으로 금액을 고치지 않습니다.
3. 확정 영수증으로 미반영 operation을 복구하거나 오탐 근거를 붙여 해당 discrepancy를 해결합니다. resolutionType/evidenceIds/approvalId/expectedVersion을 기록하고 다른 FINANCE 관리자의 승인을 받습니다.
4. 완료 기준: 신규 승인/환불/지급 없이 기존 operation 사실만 1회 반영, 같은 identity의 불일치 재발 없음, 전일 및 최근 3일 재비교 합계 일치. 차이가 남으면 사건을 재오픈하고 해당 금융 쓰기를 hold합니다.

PG 대사 01:00 / 정산 02:00 / 은행 대사 03:00 KST는 목표 스케줄입니다. 일정 변경은 버전 있는 설정과 리허설을 거쳐 반영하며 브라우저 시간에 의존하지 않습니다.

## RB-06 DB 복원과 재개

트리거: DB 유실·서로 불일치하는 시점으로 복원·PG 기록 소실 의심. 각 DB owner와 운영 책임자가 담당하고 FINANCE가 검토합니다. RPO<=5분/RTO<=60분은 목표이며 실제 달성 여부는 리허설로 측정합니다. AT-30.

1. 영향 서비스의 금융 쓰기·배치·queue publisher를 동결하고 조회는 유지합니다. DB/backup/WAL/복원 시점·서비스 버전·topic offset/watermark·미해결 목록을 보존합니다. PG 기록이 유실되면 같은 merchant replay도 새 효과를 만들 수 있으므로 자동 쓰기를 중지합니다.
2. 검증된 backup+WAL을 **별도 격리 DB**에 복원합니다. 대상 DB와 복원 시각을 확인하지 않고 기존 DB를 덮어쓰지 않습니다. provider별 DB와 서비스 경계를 유지합니다.
3. schema checksum·행 수·PK/FK·원금/환불/VOID/지급·재고 합계를 검증하고 금융 최종 사실은 PG/모의 은행 receipt와 대조합니다. 한 서비스의 복원 시점이 맞아도 다른 DB와 일치한다고 가정하지 않습니다.
4. aggregate별 checkpoint와 archive/outbox를 대조하고 같은 ID/body/sequence로 replay합니다. 복원된 inbox의 중복 방지 기록이 과거 broker 재전송까지 처리할 수 있는지 보존 기간을 검사합니다. 금융 sequence가 누락된 범위는 쓰기를 재개하지 않습니다.
5. Commerce→Payment→PG의 승인/환불 연결과 Commerce 확정→Settlement 원장/지급 연결을 검증합니다. 새로운 돈 이동 없이 미반영 사실만 복구하며 UNKNOWN은 삭제하거나 초기화하지 않습니다.
6. 2인 검토 후 제한된 조회→쓰기→worker 순서로 재개합니다. PG별 모의 거래·환불 1건과 재고/원장 중복 0건을 확인한 뒤 범위를 확대합니다. 전환 시각·DB endpoint·앱 버전·되돌림 조건을 기록합니다.

확정 backup 저장소/운영 DB credential은 배포 환경의 비밀 설정에서 관리합니다. 이 문서에는 값이나 추측한 복원 CLI를 넣지 않습니다. 실행 전 실제 배포환경의 backup/restore job ID를 운영 사건에 첨부해야 합니다.

## RB-07 검색·분석·인증·웹훅 장애

| 대상 | 확인/조치 | 완료 기준 |
| --- | --- | --- |
| 검색 stale/실패 | 판매중지 event/generation/sourceVersion 확인, X-11 rebuild로 snapshot+watermark 검증 후 ACTIVE 교체, 목록 fallback | 판매중지 상품 주문 불가, 건수/version 일치, 이전 generation 복귀 가능 |
| 분석 지연 | revision/taxonomy/model/prompt/run 확인, 같은 run 복구, 이전 revision 결과를 현재에 적용 금지 | 근거/점수 완료, concept 중복 0건 |
| Redis 세션 장애 | 인증 의존 요청 503, Redis 연결·세션 version 확인, 복구 후 bootstrap 재시도 | 만료/폐기 token 재사용 0건, 익명 공개 조회 가능 |
| JWT/MFA 키 교체 | kid allowlist/발급 서비스/audience/60초 만료 확인, 허용 키 overlap 후 구 키 퇴역 | 위조/다른 audience 거부, 정상 호출, 비밀정보 로그 0건 |
| webhook 401 | provider/kid/timestamp/raw body 보존과 서명 입력 검증, 재전송에 새 timestamp/signature | 유효 요청 202, 동일 body 중복 효과 0건, 다른 body 409 |

새 key를 공개 로그에 붙이거나 서명 검증을 꺼서 복구하지 않습니다. 키 교체는 보안 운영 절차이며 단순 문서 작성 작업에서 실행하지 않습니다.

## 운영 리허설·종결 기록

매월 RB-06 복원 리허설, 릴리스 전 RB-01~05 장애 주입 시험을 수행합니다. 실패 주입은 목표 PG fault-scenarios의 local/stage principal에만 허용하고 prod에서는 비활성화합니다. 처리 시간/UNKNOWN 경과 시간/queue 지연/gap/discrepancy/중복 수/금액·수량 차이를 측정합니다. 사건 종결에는 최초 증거, 조치 command/job ID, 승인자, 검증 query와 결과, 미해결 제외 범위, 재발 방지 작업을 남깁니다. 단순 200 응답이나 오류 로그가 없다는 이유만으로 종결하지 않습니다.
