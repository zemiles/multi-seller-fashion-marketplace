# Commerce 고객 · 판매자 · 관리자 API

[OpenAPI](../../contracts/commerce-public.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| POST | /api/v1/members | 회원 가입 | ANONYMOUS | SEC-01 |
| POST | /api/v1/sessions | 고객/판매자 로그인 | ANONYMOUS | SEC-01 |
| GET | /api/v1/session | 익명 포함 세션·CSRF 조회 | ANONYMOUS | SEC-01 |
| DELETE | /api/v1/session | 고객 세션 폐기 | MEMBER | SEC-01 |
| POST | /api/v1/auth/verifications | verifyEmail | ANONYMOUS | SEC-01 |
| POST | /api/v1/auth/password-resets | resetPassword | ANONYMOUS | SEC-01 |
| POST | /api/v1/auth/verification-requests | requestVerification | ANONYMOUS | SEC-01 |
| POST | /api/v1/auth/password-reset-requests | requestPasswordReset | ANONYMOUS | SEC-01 |
| GET | /api/v1/me | 내 회원 정보 | MEMBER | COM-01 |
| PATCH | /api/v1/me | 닉네임 수정 | MEMBER | COM-01 |
| DELETE | /api/v1/me | 열린 거래 없는 회원 탈퇴 | MEMBER | COM-01 |
| GET | /api/v1/me/addresses | 내 배송지 | MEMBER | COM-01 |
| POST | /api/v1/me/addresses | 배송지 추가 | MEMBER | COM-01 |
| PATCH | /api/v1/me/addresses/{addressId} | 배송지·기본주소 수정 | MEMBER | COM-01 |
| DELETE | /api/v1/me/addresses/{addressId} | 배송지 삭제 | MEMBER | COM-01 |
| GET | /api/v1/categories | 활성 카테고리 | ANONYMOUS | CAT-01 |
| GET | /api/v1/brands | 브랜드 조회 | ANONYMOUS | CAT-01 |
| GET | /api/v1/products | 상품 검색·목록 | ANONYMOUS | CAT-01, DIS-01 |
| GET | /api/v1/products/{productId} | 현재 판매 상품 상세 | ANONYMOUS | CAT-01 |
| GET | /api/v1/search | 검색·랭킹 결과 | ANONYMOUS | DIS-01 |
| GET | /api/v1/me/wishlist | 내 찜 목록 | MEMBER | EXP-01 |
| PUT | /api/v1/me/wishlist/{productId} | 찜 추가 | MEMBER | EXP-01 |
| DELETE | /api/v1/me/wishlist/{productId} | 찜 삭제 | MEMBER | EXP-01 |
| GET | /api/v1/cart | 장바구니 | MEMBER | ORD-01 |
| PUT | /api/v1/cart/items/{skuId} | 장바구니 수량·선택 변경 | MEMBER | ORD-01 |
| DELETE | /api/v1/cart/items/{skuId} | 장바구니 항목 삭제 | MEMBER | ORD-01 |
| POST | /api/v1/checkouts | 가격 확정·15분 재고 예약 | MEMBER | ORD-02, INV-01 |
| GET | /api/v1/checkouts/{checkoutId} | 불변 주문서 조회 | MEMBER | ORD-02 |
| POST | /api/v1/orders | PG 호출 전 주문 생성 | MEMBER | ORD-03 |
| GET | /api/v1/orders | 내 주문 목록 | MEMBER | ORD-04 |
| POST | /api/v1/orders/{orderId}/payment | PG1 또는 PG2 모의 결제 | MEMBER | PAY-01, ORD-03 |
| GET | /api/v1/orders/{orderId} | 주문·배송·클레임 상태 | MEMBER | ORD-04 |
| GET | /api/v1/orders/{orderId}/payment-status | 새 승인 없는 결제 조회 | MEMBER | ORD-04, PAY-05 |
| POST | /api/v1/orders/{orderId}/claims | 취소·반품·교환 접수 | MEMBER | CLM-01 |
| GET | /api/v1/claims/{claimId} | 내 클레임 조회 | MEMBER | CLM-01 |
| POST | /api/v1/claims/{claimId}/withdraw | 효과 시작 전 클레임 철회 | MEMBER | CLM-01 |
| POST | /api/v1/shipment-items/{shipmentItemId}/confirmations | 수량별 구매확정 | MEMBER | FUL-02 |
| GET | /api/v1/me/review-eligibilities | 작성 가능 구매 항목 | MEMBER | EXP-02 |
| POST | /api/v1/reviews | 구매 리뷰 작성 | MEMBER | EXP-02 |
| PATCH | /api/v1/reviews/{reviewId} | 리뷰 revision 작성 | MEMBER | EXP-02 |
| DELETE | /api/v1/reviews/{reviewId} | 리뷰 비공개 삭제 | MEMBER | EXP-02 |
| GET | /api/v1/products/{productId}/reviews | 공개 리뷰 | ANONYMOUS | EXP-02 |
| GET | /api/v1/notifications | 앱 내 알림 | MEMBER | EXP-03 |
| POST | /api/v1/notifications/{notificationId}/read | 읽음 처리 | MEMBER | EXP-03 |
| GET | /api/v1/notification-preferences | 알림·분석 동의 | MEMBER | EXP-03, DIS-03 |
| PATCH | /api/v1/notification-preferences | 알림·분석 동의 변경 | MEMBER | EXP-03, DIS-03 |
| POST | /api/v1/uploads | 업로드 슬롯 발급 | MEMBER | SEC-04 |
| PUT | /api/v1/uploads/{uploadId}/content | 검역 전 파일 바이트 업로드 | MEMBER | SEC-04 |
| POST | /api/v1/uploads/{uploadId}/complete | 해시 검증·검역 요청 | MEMBER | SEC-04 |
| GET | /api/v1/uploads/{uploadId}/download | 권한 검증된 5분 다운로드 주소 | MEMBER, SELLER_OWNER, ADMIN_SUPPORT, ADMIN_CATALOG, ADMIN_FINANCE, ADMIN_RISK | SEC-04 |
| POST | /api/v1/behavior-events | 동의된 행동 이벤트 기록 | MEMBER | DIS-03 |
| POST | /api/v1/behavior-events/batch | 행동 이벤트 최대50개 기록 | MEMBER | DIS-03 |
| POST | /api/v1/sellers | 입점 신청 | MEMBER | COM-02 |
| GET | /api/v1/sellers/{sellerId} | 내 판매자 조회 | SELLER_OWNER, SELLER_CATALOG, SELLER_FULFILLMENT, SELLER_FINANCE | COM-02 |
| PATCH | /api/v1/sellers/{sellerId} | 판매자 표시정보 수정 | SELLER_OWNER | COM-02 |
| POST | /api/v1/sellers/{sellerId}/documents | documents | SELLER_OWNER | COM-02 |
| POST | /api/v1/sellers/{sellerId}/verifications | verifications | SELLER_OWNER | COM-02 |
| POST | /api/v1/sellers/{sellerId}/settlement-account-change-requests | settlement-account-change-requests | SELLER_OWNER | COM-02 |
| POST | /api/v1/sellers/{sellerId}/team-invitations | team-invitations | SELLER_OWNER | COM-02 |
| POST | /api/v1/seller-invitations/accept | 회원이 팀 초대 수락 | MEMBER | COM-02 |
| GET | /api/v1/sellers/{sellerId}/members | 팀원 조회 | SELLER_OWNER | COM-02 |
| PATCH | /api/v1/sellers/{sellerId}/members/{memberId} | 팀 권한 변경 | SELLER_OWNER | COM-02 |
| DELETE | /api/v1/sellers/{sellerId}/members/{memberId} | 마지막 OWNER 제외 팀원 제거 | SELLER_OWNER | COM-02 |
| GET | /api/v1/sellers/{sellerId}/products | 자기 판매자 상품·초안 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| POST | /api/v1/sellers/{sellerId}/products | 상품 초안 생성 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| GET | /api/v1/sellers/{sellerId}/products/{productId} | 판매자 상품 상세 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| PATCH | /api/v1/sellers/{sellerId}/products/{productId} | 게시본을 보존하는 새 revision 편집 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| POST | /api/v1/sellers/{sellerId}/products/{productId}/revisions | 상품 revision 작성 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| POST | /api/v1/sellers/{sellerId}/products/{productId}/submit-review | submit-review | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| POST | /api/v1/sellers/{sellerId}/products/{productId}/publish | publish | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| POST | /api/v1/sellers/{sellerId}/products/{productId}/pause | pause | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| GET | /api/v1/sellers/{sellerId}/products/{productId}/skus | SKU 목록 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| PUT | /api/v1/sellers/{sellerId}/products/{productId}/skus | SKU 전체 검증 갱신 | SELLER_OWNER, SELLER_CATALOG | CAT-01 |
| GET | /api/v1/sellers/{sellerId}/inventory | 재고 수량 조회 | SELLER_OWNER, SELLER_CATALOG | INV-01 |
| POST | /api/v1/sellers/{sellerId}/inventory/{skuId}/adjustments | 재고 원장 조정 | SELLER_OWNER, SELLER_CATALOG | INV-01 |
| GET | /api/v1/sellers/{sellerId}/orders | 자기 판매자 항목만 주문 조회 | SELLER_OWNER, SELLER_FULFILLMENT | FUL-01 |
| GET | /api/v1/sellers/{sellerId}/shipments | 배송 목록 | SELLER_OWNER, SELLER_FULFILLMENT | FUL-01 |
| POST | /api/v1/sellers/{sellerId}/shipments | 수량별 분할 출고 준비 | SELLER_OWNER, SELLER_FULFILLMENT | FUL-01 |
| POST | /api/v1/sellers/{sellerId}/shipments/{shipmentId}/handover | 택배 인계 | SELLER_OWNER, SELLER_FULFILLMENT | FUL-01 |
| GET | /api/v1/sellers/{sellerId}/claims | 판매자별 클레임 | SELLER_OWNER, SELLER_FULFILLMENT | CLM-01 |
| POST | /api/v1/sellers/{sellerId}/claims/{claimId}/decisions | 클레임 검수 결정 | SELLER_OWNER, SELLER_FULFILLMENT | CLM-01 |
| POST | /api/v1/sellers/{sellerId}/claims/{claimId}/inspections | 반품 unit별 검수·재입고 판단 | SELLER_OWNER, SELLER_FULFILLMENT | CLM-02 |
| POST | /api/v1/sellers/{sellerId}/reviews/{reviewId}/reply | 판매자 답글 | SELLER_OWNER, SELLER_FULFILLMENT | EXP-02 |
| PATCH | /api/v1/sellers/{sellerId}/reviews/{reviewId}/reply | 판매자 답글 수정 | SELLER_OWNER, SELLER_FULFILLMENT | EXP-02 |
| GET | /api/v1/sellers/{sellerId}/ledger | 판매자 원장 | SELLER_OWNER, SELLER_FINANCE | SET-01 |
| GET | /api/v1/sellers/{sellerId}/settlements | 판매자 정산 목록 | SELLER_OWNER, SELLER_FINANCE | SET-02 |
| GET | /api/v1/sellers/{sellerId}/settlements/{settlementId} | 정산·이월·보류 조회 | SELLER_OWNER, SELLER_FINANCE | SET-02 |
| POST | /api/v1/sellers/{sellerId}/appeals | 제재 이의신청 | SELLER_OWNER | OPS-01 |
| GET | /api/v1/sellers/{sellerId}/appeals | listSellerAppeals | SELLER_OWNER | OPS-01 |
| POST | /api/v1/sellers/{sellerId}/products/{productId}/analysis-runs | 모의 concept 분석 요청 | SELLER_OWNER, SELLER_CATALOG | DIS-02 |
| GET | /api/v1/sellers/{sellerId}/products/{productId}/analysis-runs/{runId} | 분석 결과·근거 | SELLER_OWNER, SELLER_CATALOG | DIS-02 |
| POST | /api/v1/sellers/{sellerId}/products/{productId}/concept-reviews | 분석 concept 검토 | SELLER_OWNER, SELLER_CATALOG | DIS-02 |
| POST | /api/v1/admin/sessions | 관리자 TOTP 로그인 | ANONYMOUS | SEC-02 |
| GET | /api/v1/admin/session | 관리자 세션 조회 | ADMIN_IAM, ADMIN_SUPPORT, ADMIN_CATALOG, ADMIN_RISK, ADMIN_FINANCE | SEC-02 |
| DELETE | /api/v1/admin/session | 관리자 세션 폐기 | ADMIN_IAM, ADMIN_SUPPORT, ADMIN_CATALOG, ADMIN_RISK, ADMIN_FINANCE | SEC-02 |
| POST | /api/v1/admin/sellers/{sellerId}/verifications/{verificationId}/decisions | decideSellerVerification | ADMIN_SUPPORT | COM-02 |
| POST | /api/v1/admin/sellers/{sellerId}/settlement-account-change-requests/{requestId}/decisions | decideAccountChange | ADMIN_FINANCE | COM-02 |
| POST | /api/v1/admin/products/{productId}/review-decisions | decideProductReview | ADMIN_CATALOG | CAT-01 |
| POST | /api/v1/admin/shipments/{shipmentId}/tracking-events | recordTrackingEvent | ADMIN_SUPPORT | FUL-01 |
| POST | /api/v1/admin/reviews/{reviewId}/moderation | moderateReview | ADMIN_CATALOG | EXP-02 |
| POST | /api/v1/admin/settlements/{settlementId}/calculate | calculateSettlement | ADMIN_FINANCE | SET-02 |
| POST | /api/v1/admin/settlements/{settlementId}/approval-requests | requestSettlementApproval | ADMIN_FINANCE | SET-03 |
| POST | /api/v1/admin/settlements/{settlementId}/payout | requestPayout | ADMIN_FINANCE | SET-03 |
| POST | /api/v1/admin/payment-operations/{operationId}/recover | recoverPaymentOperation | ADMIN_FINANCE | PAY-05 |
| POST | /api/v1/admin/reconciliation-discrepancies/{discrepancyId}/resolutions | resolveDiscrepancy | ADMIN_FINANCE | PAY-06, SET-04 |
| POST | /api/v1/admin/approval-requests | createApproval | ADMIN_FINANCE, ADMIN_RISK, ADMIN_IAM, ADMIN_SUPPORT | OPS-01 |
| GET | /api/v1/admin/approval-requests | listApprovals | ADMIN_FINANCE, ADMIN_RISK, ADMIN_IAM, ADMIN_SUPPORT | OPS-01 |
| POST | /api/v1/admin/approval-requests/{approvalId}/decisions | decideApproval | ADMIN_FINANCE, ADMIN_RISK, ADMIN_IAM, ADMIN_SUPPORT | OPS-01 |
| POST | /api/v1/admin/incidents | createIncident | ADMIN_RISK | OPS-01 |
| GET | /api/v1/admin/incidents | listIncidents | ADMIN_RISK | OPS-01 |
| POST | /api/v1/admin/seller-penalties | createPenalty | ADMIN_RISK | OPS-01 |
| GET | /api/v1/admin/seller-penalties | listPenalties | ADMIN_RISK | OPS-01 |
| POST | /api/v1/admin/compliance-rules | createComplianceRule | ADMIN_CATALOG | OPS-01 |
| GET | /api/v1/admin/compliance-rules | listComplianceRules | ADMIN_CATALOG | OPS-01 |
| POST | /api/v1/admin/appeals/{appealId}/decisions | decideAppeal | ADMIN_RISK | OPS-01 |
| POST | /api/v1/admin/concept-taxonomies | createTaxonomy | ADMIN_CATALOG | DIS-02 |
| GET | /api/v1/admin/concept-taxonomies | listConceptTaxonomies | ADMIN_CATALOG | DIS-02 |
| POST | /api/v1/admin/concept-taxonomies/{taxonomyId}/publish | publishTaxonomy | ADMIN_CATALOG | DIS-02 |
| GET | /api/v1/admin/settlements | listAdminSettlements | ADMIN_FINANCE | SET-02 |
| GET | /api/v1/admin/payment-operations | listPaymentOperations | ADMIN_FINANCE | PAY-05 |
| GET | /api/v1/admin/reconciliation-discrepancies | listDiscrepancies | ADMIN_FINANCE | PAY-06, SET-04 |
| GET | /api/v1/admin/audit-logs | listAuditLogs | ADMIN_IAM | OPS-01 |
| GET | /api/v1/admin/settlements/{settlementId} | 정산 계산 근거 | ADMIN_FINANCE | SET-02 |
| PATCH | /api/v1/admin/incidents/{incidentId} | 사건 상태 변경 | ADMIN_RISK | OPS-01 |
| POST | /api/v1/orders/{orderId}/claim-quotes | quoteClaim | MEMBER | CLM-01, CLM-02 |
| POST | /api/v1/claims/{claimId}/reason-change-requests | requestClaimReasonChange | MEMBER | CLM-01 |
| GET | /api/v1/claims/{claimId}/reason-change-requests | listMyClaimReasonChanges | MEMBER | CLM-01 |
| GET | /api/v1/sellers/{sellerId}/claims/{claimId} | getSellerClaim | SELLER_OWNER, SELLER_FULFILLMENT | CLM-01 |
| GET | /api/v1/sellers/{sellerId}/claims/{claimId}/reason-change-requests | listSellerClaimReasonChanges | SELLER_OWNER, SELLER_FULFILLMENT | CLM-01 |
| POST | /api/v1/sellers/{sellerId}/claims/{claimId}/reason-change-requests/{requestId}/decisions | decideClaimReasonChange | SELLER_OWNER, SELLER_FULFILLMENT | CLM-01 |
| POST | /api/v1/admin/claims/{claimId}/return-tracking-events | recordReturnTracking | ADMIN_SUPPORT | CLM-01, FUL-01 |
| POST | /api/v1/admin/shipments/{shipmentId}/corrections | correctShipment | ADMIN_SUPPORT | FUL-01, OPS-01 |
| GET | /api/v1/admin/seller-verifications | listSellerVerificationReviews | ADMIN_SUPPORT | COM-02 |
| GET | /api/v1/admin/product-review-requests | listProductReviewRequests | ADMIN_CATALOG | CAT-01 |
| GET | /api/v1/admin/review-moderation-requests | listReviewModerationRequests | ADMIN_CATALOG | EXP-02 |
| GET | /api/v1/admin/settlement-account-change-requests | listAccountChangeReviews | ADMIN_FINANCE | COM-02 |
| GET | /api/v1/sellers/{sellerId}/settlement-account | getSellerSettlementAccount | SELLER_OWNER, SELLER_FINANCE | COM-02, SEC-04 |
| GET | /api/v1/sellers/{sellerId}/appeals/{appealId} | getSellerAppeal | SELLER_OWNER | OPS-01 |
| GET | /api/v1/uploads/{uploadId} | getUploadStatus | MEMBER | SEC-04 |
| GET | /api/v1/admin/administrators | listAdministrators | ADMIN_IAM | SEC-02 |
| GET | /api/v1/admin/administrators/{adminId} | getAdministrator | ADMIN_IAM | SEC-02 |
| POST | /api/v1/admin/administrators/{adminId}/role-change-requests | requestAdminRoleChange | ADMIN_IAM | SEC-02, OPS-01 |
| POST | /api/v1/admin/administrators/{adminId}/role-change-requests/{requestId}/execute | executeAdminRoleChange | ADMIN_IAM | SEC-02, OPS-01 |
| POST | /api/v1/admin/administrators/{adminId}/mfa-recovery-requests | requestAdminMfaRecovery | ADMIN_IAM | SEC-02, OPS-01 |
| POST | /api/v1/admin/administrators/{adminId}/mfa-recovery-requests/{requestId}/execute | executeAdminMfaRecovery | ADMIN_IAM | SEC-02, OPS-01 |
| GET | /api/v1/admin/approval-requests/{approvalId} | getApproval | ADMIN_FINANCE, ADMIN_RISK, ADMIN_IAM, ADMIN_SUPPORT | OPS-01, SEC-02 |
| GET | /api/v1/admin/event-queues | listEventQueues | ADMIN_FINANCE, ADMIN_CATALOG | EVT-03, OPS-02 |
| POST | /api/v1/admin/event-queues/{entryId}/replays | replayEventQueue | ADMIN_FINANCE, ADMIN_CATALOG | EVT-03, OPS-01 |
| GET | /api/v1/admin/recovery-jobs/{jobId} | getRecoveryJob | ADMIN_FINANCE, ADMIN_CATALOG | EVT-03, OPS-02 |
| POST | /api/v1/claims/{claimId}/exchange-conversions | convertExchange | MEMBER | CLM-03 |
| GET | /api/v1/admin/orders/{orderId} | getOrderForSupport | ADMIN_SUPPORT | CLM-01, ORD-04 |
| GET | /api/v1/admin/claims/{claimId} | getClaimForSupport | ADMIN_SUPPORT | CLM-01 |
| POST | /api/v1/admin/orders/{orderId}/claim-exceptions | createClaimException | ADMIN_SUPPORT | CLM-01, OPS-01 |
| POST | /api/v1/admin/search-rebuilds | createSearchRebuild | ADMIN_CATALOG | DIS-01 |
| GET | /api/v1/admin/search-rebuilds/{generationId} | getSearchRebuild | ADMIN_CATALOG | DIS-01 |
