# Commerce 내부 협력 API

[OpenAPI](../../contracts/commerce-internal.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| GET | /internal/v1/sellers/{sellerId}/financial-barrier | getFinancialBarrier | settlement-service | SET-03 |
| POST | /internal/v1/sellers/{sellerId}/payout-fences | createPayoutFence | settlement-service | SET-03 |
| POST | /internal/v1/payout-fences/{fenceId}/consume | consumePayoutFence | settlement-service | SET-03 |
| GET | /internal/v1/admin-approval-requests/{approvalId} | getApprovalForExecution | settlement-service, payment-service, discovery-data-service | OPS-01 |
| POST | /internal/v1/admin-approval-requests/{approvalId}/consume | consumeApproval | settlement-service | OPS-01 |
| GET | /internal/v1/catalog/snapshot | getCatalogSnapshot | discovery-data-service | DIS-01 |
