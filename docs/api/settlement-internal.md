# Settlement 내부 API

[OpenAPI](../../contracts/settlement-internal.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| GET | /internal/v1/sellers/{sellerId}/ledger | queryLedger | commerce-service | SET-01 |
| GET | /internal/v1/settlements | querySettlements | commerce-service | SET-02 |
| GET | /internal/v1/settlements/{settlementId} | querySettlement | commerce-service | SET-02 |
| POST | /internal/v1/settlements/{settlementId}/calculate | runSettlementCalculation | commerce-service | SET-02 |
| POST | /internal/v1/settlements/{settlementId}/payout | dispatchSimulatedPayout | commerce-service | SET-03 |
| GET | /internal/v1/payouts/{payoutId} | queryPayout | commerce-service | SET-03 |
| GET | /internal/v1/reconciliation-discrepancies | queryBankDiscrepancies | commerce-service | SET-04 |
| POST | /internal/v1/reconciliation-discrepancies/{discrepancyId}/resolutions | resolveBankDiscrepancy | commerce-service | SET-04 |
