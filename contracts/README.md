# 서비스 계약

구현할 로직은 [v1 전체 요구사항](../docs/requirements/README.md), 현재 상태는 [BACKEND_DESIGN](../docs/BACKEND_DESIGN.md)을 기준으로 합니다.

전체 경로·DTO는 [API 명세서](../docs/api/README.md)와 [오프라인 탐색 뷰어](../docs/api/index.html), 테이블 대응은 [현재/목표 ERD](../docs/erd/README.md)를 확인합니다. OpenAPI JSON은 생성본이며 수정·재생성 방법은 [문서 도구](../scripts/docs/README.md)를 따릅니다.

| 계약 | 상태 |
| --- | --- |
| PG1/PG2 기존 REST 4종 | 구현됨. [PG1/Kakao](../pg-kakao-simulator/README.md), [PG2/Naver](../pg-naver-simulator/README.md) 및 pg-simulator-common DTO |
| [Payment OpenAPI](payment-service.openapi.yaml) | 1.0.0 목표 계약. 내부 HTTP Controller/영속화는 미구현 |
| [Commerce–Payment Checkout](commerce-payment-checkout-contract-v0.1.md) | v1 정책·필드·산술·호출/복구 계약 확정. 기존 파일명은 링크 호환 유지 |
| [PG 확장·webhook](../docs/requirements/03-payment-pg.md) | 현재 두 PG에 구현할 인증·조회·receipt·웹훅·대사 요구 확정 |
| [Kafka 이벤트 19종](events/v1/README.md) | typed JSON Schema·정상/오류 fixture·필드 사전 작성. [순서·처리 규칙](../docs/implementation/02-event-contracts.md). producer/consumer는 미구현 |
| [고객·서비스 인증/외부 API](../docs/requirements/01-security-api.md) | 서버 session/CSRF, 서비스 RS256 JWT, Commerce facade. 미구현 |

Payment 내부 command record는 최종 HTTP 계약이 아닙니다. snapshot의 단위 수량/판매자/수수료·전체 배분, operation/resultVersion, close-order guard와 DB 복구를 갖춘 뒤 공개 facade와 연결합니다.

v1 Money는 KRW JSON 정수(주문1~100,000,000원)이며 문자열·소수는 거부합니다. PG1=KAKAO, PG2=NAVER, 결제수단=SIMULATED. 화면과 업무 API는 simulated=true를 표시해야 합니다. 현재 PG의 4종 응답에는 이 필드가 없으므로 adapter가 명시적으로 모의 거래로 태깅하고 PG 확장 시에도 추가합니다.

Payment target 경로는 `/internal/v1`입니다. 과거 초안의 `/api/v1/payment-*`를 고객 공개 경로로 구현하지 않습니다. 고객은 Commerce `/api/v1/orders/{id}/payment`를 통해 결제하고 GET으로 결과를 조회합니다.

UNKNOWN은 안전한 결과 조회/복구 상태입니다. 502/timeout을 받은 브라우저가 새 거래를 시작하지 않도록 resourceId/statusUrl을 보존합니다. 결제 승인과 정산 수익 인식은 다르며, Settlement는 Commerce의 판매자 재무 stream으로 매출·환불 조정을 반영합니다.

계약 변경 시 정상·권한·금액·동일/변경 멱등 요청·timeout·중복/역순·restart 테스트와 구현 여부 표를 갱신합니다. 기존 draft를 수정했다고 실제 API가 배포된 것은 아닙니다.

화면/운영 상세화로 확인한 [X-01~11 보완 계약](../docs/implementation/05-screens.md#계약-보완-목록)은 경로·입력·권한·동작을 결정한 설계입니다. 38개 operation의 schema·예시·권한·오류 규칙을 정식 OpenAPI에 반영했습니다. 계약은 총 8개이며 [공통 운영 내부 계약](operations-internal.openapi.json)은 4개 업무 서비스 각각의 owner-local port이지 새 배포 서비스가 아닙니다. 서버 구현은 별도입니다. 전체 관련 요구사항은 [추적표](../docs/implementation/04-traceability.md)를 따릅니다.
