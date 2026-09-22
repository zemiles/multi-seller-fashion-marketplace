# 05. 판매자 원장·정산·모의 지급·운영

## SET-01 금융 사실과 원장

Settlement가 seller ledger의 유일한 writer. `(sellerId,currency,sourceEventId,sourceUnitOrChargeId,entryType)` unique, signed_amount는 0이 아닌 정수. 원장 수정/삭제 금지, reversal은 원 entry 참조·상반 금액·사유·승인 근거를 가진 새 행. 동일 원장의 누적 reversal은 원 금액을 초과하지 않습니다.

- PurchaseConfirmed에서 **확정한 unit만** SALE_PROCEEDS(+)와 COMMISSION_FEE(-) 생성. 수수료는 주문 때 고정한 10%의 수량 배분. 승인만으로 수익/지급 대상 생성 금지.
- Commerce는 `orderId:sellerId`별 financialVersion을 증가시키며 모든 판매자 재무 사건을 전용 stream으로 발행. PurchaseConfirmed, SellerShippingRevenueRecognized, SellerFinancialAdjusted, SellerSettlementHoldChanged가 같은 aggregate를 사용합니다.
- RefundSucceeded는 Commerce가 수신하여 해당 원 unit/charge의 확정·수익 인식 여부를 조사하고 SellerFinancialAdjusted로 변환. Settlement는 원시 RefundSucceeded를 대사 projection용으로만 보며 **이것과 조정 이벤트를 중복 차감하지 않음**.
- 구매확정 전 반품 unit: 미인식 매출을 제거하는 Commerce 사실만, Settlement의 수익 원장이 없으므로 음수 REFUND를 임의 생성하지 않음. 확정 후 예외 환불: 기존 SALE_PROCEEDS를 -refundPaidAmount, 기존 COMMISSION_FEE를 +originalFeeAllocation으로 역전.
- 유료 배송 수익은 해당 seller 그룹의 모든 unit이 구매확정/취소/반품 종결이고 열린 Claim이 없을 때, 남은 배송 charge 금액을 1회 SHIPPING_REVENUE로 인식. 구매자 귀책 전량 반품으로 배송비가 남는 경우에도 수익 인식. 나중에 환급하면 동일 charge의 조정 원장 생성.
- event의 priorFinancialVersion과 확정 단위/금액 합계를 검사. event 미수신 gap이면 hold; 최신 이벤트만 적용해서 중간 환불을 잃지 않음. 자료의 seller/통화/order 연결이 불일치하면 quarantine.

예: item 실결제 10,000원 확정→매출+10,000/수수료-1,000=지급기여9,000. 지급 후 전량 예외 환불→매출-10,000/수수료+1,000=-9,000. 원 결제 취소나 배송비는 각각 별도 사실이며 환불했다고 이미 지급한 돈이 자동 회수됐다고 표시하지 않습니다.

## SET-02 정산 계산

- 매일 02:00 Asia/Seoul, cutoff=그날00:00 KST. DB UTC로 변환. 포함 대상은 occurredAt<cutoff이며 아직 미배분인 eligible 원장. 늦게 도착한 과거 원장은 다음 정산에 편입, 이미 PAID인 settlement를 다시 열지 않음.
- seller/currency별 worker lock, 고정 계산 run key=`sellerId:KRW:businessDate:policyVersion`. 원장 선택·allocation·CALCULATED 저장 한 transaction. 원장금액을 복수 정산에 초과 배분 금지, 재실행은 같은 settlement/current 결과.
- credit=sum(positive), debit=abs(sum(negative)), net=credit-debit. active hold는 지급 가능 양수액 범위에서 차감, payout=max(0,net-hold). 음수는 0으로 소거하지 않고 미회수 판매자 채무로 다음 계산에 이월.
- payout<1,000원은 송금 attempt를 생성하지 않고 carry-forward. 양수 소액과 음수 잔액은 source allocation을 유지하는 carry-forward entry로 다음 cycle에 전달, 같은 원 entry를 다시 배분하지 않음. 처리 전후 원장 합계=지급+보류+이월 합계 검증.
- 해당 seller의 열린 대사 불일치·account change 검증·금융 version gap·제재 payout hold·구매확정 후 Claim hold가 있으면 지급 보류. 보류는 돈을 소멸시키는 수수료 원장이 아니며 hold_release로 해제.
- DRAFT→CALCULATED→APPROVAL_PENDING→APPROVED→PAYOUT_PENDING→PAID. 계산 변경은 미지급 draft만 새 버전, 승인 hash가 달라지면 승인 무효. FAILED는 no-effect 지급 실패이며 UNKNOWN은 attempt 상태로 노출, settlement는 PAYOUT_PENDING 유지.

## SET-03 지급 승인·모의 은행

실제 은행/PG 지급 연결은 v1 제외. Settlement 내부 `PayoutProviderPort`와 영속 `SimulatedBankAdapter`를 사용하며 별도 업무 서비스·새 PG를 만들지 않습니다. DB namespace/table을 분리하고 adapter 경계를 통해 호출, 실제 송금했다고 보고하지 않습니다.

1. FINANCE 담당자가 계산 결과·보류·계좌 snapshot hash를 확인하고 승인 요청. 다른 FINANCE 관리자가 승인. 동일 계정 두 역할·세션 두 개로 자기 승인 불가.
2. 지급 직전 seller 계좌/제재 및 source stream barrier를 다시 검증. Commerce에서 seller financial barrier+holdVersion을 조회하여 Settlement가 해당 버전까지 적용했는지 확인. 미달/접속 불가이면 hold, stale cache로 지급 금지.
3. 지급 dispatch와 신규 Claim의 경합은 짧은 Commerce seller financial fence로 직렬화. fence를 얻기 전 신규 hold가 있으면 지급 중단; fence 승리 후 접수된 Claim은 지급후 조정으로 처리. fence는 30초, 영속 fence ID/version; 만료 이후 늦은 dispatch는 거부, dispatch 허가 소비는 1회. 외부 호출 동안 DB lock 유지 금지.
4. unique payout key=`payout:{settlementId}:{payoutRevision}`, amount/account snapshot immutable. REQUESTED commit 후 모의 bank 호출, bank는 key+payload hash unique와 receipt를 독립 transaction(REQUIRES_NEW)에 영속화. settlement 성공 기록 전 crash로 UNKNOWN 재현 가능.
5. receipt 확인 후 SUCCEEDED/PAID/SettlementPaid outbox 원자적 저장. simulated=true, bankReceiptId. 동일 key 조회는 동일 receipt, 변경 내용409. 실패/timeout은 PAYMENT와 동일한 UNKNOWN 보존 원칙.
6. UNKNOWN 동안 새 key 지급·계좌 변경 retry 금지. GET receipt(key)로 복구. no-effect FAILED 확정 후에만 새 payoutRevision(다시 2인 승인). 기존 key는 폐기하지 않음.

모의 은행 초기 mode=SUCCESS, 시험 mode=DECLINE_NO_EFFECT/COMMIT_THEN_TIMEOUT/DELAY. 표시는 “모의 지급 완료”, 원장/모의 은행 잔액과 음수 이월을 재시작 후도 보존합니다. 금액·계좌 불일치 receipt는 UNKNOWN+대사 사건이며 성공으로 보정하지 않습니다.

Commerce 내부 계약은 다음과 같습니다. 호출자는 Settlement principal이며 같은 seller state lock 아래 barrier/fence/새 hold를 직렬화합니다. barrier에 열거하지 않은 새로운 stream이 사이에 생기면 sellerStateVersion이 바뀌므로 fence 취득은 실패합니다.

| 경로 | 필수 입력 → 결과 |
| --- | --- |
| GET /internal/v1/sellers/{sellerId}/financial-barrier | → sellerStateVersion, streams[{aggregateType,aggregateId,requiredVersion}], activeHoldIds, accountVersion, accountSnapshotHash |
| POST /internal/v1/sellers/{sellerId}/payout-fences | settlementId,payoutAttemptId,expectedSellerStateVersion,accountSnapshotHash,consumedStreamVersions → fenceId,fenceVersion,expiresAt; 미달/변경/hold는409 |
| POST /internal/v1/payout-fences/{fenceId}/consume | payoutAttemptId,fenceVersion,operationHash → dispatchPermitId,consumedAt; 1회소비, 동일요청 replay는 같은 허가 |
| GET /internal/v1/admin-approval-requests/{id} | → actionType,targetId,payloadHash,requesterId,approverId,status,expiresAt; 용도·hash·만료 확인 |

fence 발급 후 접수된 Claim은 거부하지 않고 `postFenceAdjustment`로 기록합니다. consume이 성공한 지급은 이후 환불/hold를 지급후 조정 경로로 처리하고, consume 전에 fence가 만료되면 새 barrier를 얻어야 합니다. 모의 bank는 durable dispatchPermitId+operationHash를 검증하고 같은 payout key에 1회만 receipt를 생성합니다. consume 응답 유실도 같은 fence 조회/동일 요청 재실행으로 확인하며 새 지급 key를 만들지 않습니다. 지급이 최종 no-effect 실패라면 해당 후속 조정은 아직 미지급 원장과 상계합니다.

## SET-04 지급 후 환불·대사

지급 후 환불은 판매자 다음 정산에서 원금·수수료 역전액 차감. 지급 가능액보다 크면 채권/음수 carry-forward로 보존, 다음 수익부터 상계. 자동 은행 출금·고객 환불 지연·다른 판매자 수익 상계 금지. 30일 음수 잔액 유지 시 incident와 신규 지급 hold, 강제 징수는 v1 제외.

모의 은행 대사는 매일03:00 KST 전일+최근3일 receipt와 payout attempt 비교. key,account hash,KRW,amount,status 확인; 한쪽만 있음/차액/중복을 discrepancy로 저장. 동일 receipt 재조회/재처리는 중복 지급을 만들지 않음. Payment의 PG 대사와 실행 owner/테이블/시각이 다릅니다.

Settlement의 기존 reconciliation_*는 PG형 필드를 일부 포함합니다. v1은 별도 bank_reconciliation_run/receipt/discrepancy를 추가하고 기존 테이블은 legacy 읽기용으로 보존합니다. PG 대사용 외부 Payment FK를 만들지 않습니다. 기존 데이터 유무 확인→backfill/검증→애플리케이션 전환 순서이며, 문서만 보고 기존 테이블을 삭제하지 않습니다. [MIG-02](../implementation/03-migrations.md)의 정산 netAmount/부분 역전/은행 대사 전환을 함께 적용합니다.

## OPS-01 운영·승인·감사

Commerce가 admin identity, approval, seller incident/penalty/appeal, compliance 원본을 소유. Settlement는 승인 ID+내용 hash를 Commerce 내부 조회로 검증하고 자기 지급/원장 transaction에 적용 기록. 관리자 브라우저가 `approved=true`를 보내는 것으로 승인하지 않습니다.

- 승인 요청: actionType,targetId,payloadHash,reason,evidenceIds,requester,expiresAt=24시간. APPROVAL_PENDING→APPROVED/REJECTED/CANCELLED/EXPIRED(목표 상태). 승인 후 payload/version이 달라지면 무효, 자원 owner가 동일 actionId를 1회 소비.
- 2인 승인 필수: 계좌 변경, 수동 금융 조정, UNKNOWN 수동 해결, 지급, 금전 제재, 제재 해제, 관리자 권한 변경. 요청자 자신의 승인 금지, final 승인 직전 최신 권한 재검증. 실행 실패는 승인 소비 상태와 operation ID로 재시도하며 새 효과를 만들지 않음.
- incident: OPEN→INVESTIGATING→RESOLVED/DISMISSED→CLOSED, 원인·증빙·영향 주문 연결. UNKNOWN·배송지연·정산불일치는 자동 사건 생성 가능하나 자동 금전벌칙 부과 불가.
- penalty: WARNING/LISTING_RESTRICTION/PAYOUT_HOLD/SUSPENSION/FEE/TERMINATION. 금전 FEE는 1~100,000,000원·사유·2인 승인; seller financial stream으로 음수 원장. 해제/취소는 대응 reversal/hold release, 원 기록 삭제 금지.
- appeal: 접수 후7일 이내 검토 목표, 기한 초과는 경보이며 자동 승인 아님. 인용 시 제재 해제 및 이미 반영된 금액 역전, 기각은 사유 공개. 판매자 건강지표는 최근30일 출고지연율/취소율/분쟁율과 분모를 기록, 표본0은 N/A.
- compliance rule은 version immutable, 조건·심각도·적용범위·시작시각. v1 금칙어·필수 소재/사이즈 정보·이미지 누락의 결정적 검사. finding→판매자 수정 task→재검사→해소. AI나 문자열 한 번 일치로 판매자 계좌 지급을 영구 차단하지 않음.

## OPS-02 API 작업 목록

모든 관리자 경로는 관리자 세션/MFA/권한/감사, 판매자 경로는 seller ownership을 전제로 합니다. 목록 공통 cursor 규약 적용.

| 경로 | command/query 내용 |
| --- | --- |
| GET /api/v1/sellers/{sellerId}/ledger · /settlements · /settlements/{id} | 기간·상태·금액·배분·hold·모의 지급 결과, 계좌 마스킹 |
| GET /api/v1/admin/settlements · /settlements/{id} | 계산 근거·원장·barrier·승인 이력 |
| POST /api/v1/admin/settlements/{id}/calculate · /approval-requests · /payout | cutoff/policyVersion 또는 승인 ID; 각 command key 필수 |
| GET /api/v1/admin/payment-operations · /reconciliation-discrepancies | UNKNOWN·age·근거·읽기 전용 provider 상태 |
| POST /api/v1/admin/payment-operations/{id}/recover | 동일 operation 복구 요청, 임의 amount/key 교체 불가 |
| POST /api/v1/admin/reconciliation-discrepancies/{id}/resolutions | resolutionType,evidenceIds,approvalId; 차액 덮어쓰기 금지 |
| POST /api/v1/admin/approval-requests · /approval-requests/{id}/decisions | action payload/hash 또는 APPROVE/REJECT+reason |
| GET/POST /api/v1/admin/incidents · /seller-penalties · /compliance-rules | 위 state/정책대로 생성·조회, PATCH는 expectedVersion |
| POST /api/v1/sellers/{sellerId}/appeals | penaltyId,reason,evidenceIds → appeal |
| POST /api/v1/admin/appeals/{id}/decisions | ACCEPT/REJECT,reason,approvalId |
| GET /api/v1/admin/audit-logs | actor/target/time 필터, 읽기 권한 감사 |

조회·대사 화면에서 사용자가 직접 DB를 수정하게 하지 않습니다. 운영 작업도 정상 command/멱등성/승인 경로를 재사용합니다.
