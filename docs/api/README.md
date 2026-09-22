# API 명세서

[오프라인 API 뷰어](index.html)에서 서비스·경로를 검색하고 인증/헤더/요청·응답·예시·오류를 확인합니다. 요청 실행 기능은 없습니다. OpenAPI 3.1 JSON은 Swagger Editor/Postman 등 호환 도구에 import할 수 있습니다.

**현재 구현은 pg-current의 4경로×2개 PG뿐입니다. 나머지는 v1 구현 목표입니다.** Payment YAML은 기존 정본을 유지하며 JSON은 뷰어/검증용 생성본입니다.

| 계약 | OpenAPI | operation 수 | 상태 |
| --- | --- | ---: | --- |
| Commerce 고객 · 판매자 · 관리자 API | [JSON](../../contracts/commerce-public.openapi.json) | 155 | 미구현 목표 |
| Commerce 내부 협력 API | [JSON](../../contracts/commerce-internal.openapi.json) | 6 | 미구현 목표 |
| Settlement 내부 API | [JSON](../../contracts/settlement-internal.openapi.json) | 8 | 미구현 목표 |
| Discovery 내부 API | [JSON](../../contracts/discovery-internal.openapi.json) | 11 | 미구현 목표 |
| 업무 서비스 공통 운영 내부 API | [JSON](../../contracts/operations-internal.openapi.json) | 3 | 미구현 목표 |
| PG1 · PG2 현재 구현 API | [JSON](../../contracts/pg-current.openapi.json) | 4 | 구현됨 |
| PG1 · PG2 목표 v1 확장 API | [JSON](../../contracts/pg-target.openapi.json) | 8 | 미구현 목표 |
| Payment Service API | [JSON](../../contracts/payment-service.openapi.json) | 10 | 미구현 목표 |

총 205개 operation 정의입니다. pg-current와 pg-target은 같은 PG의 현재/목표 버전이므로 배포 API 개수로 합산하지 않습니다.

## 계약 해석

- 공개 고객 경로는 Commerce facade의 /api/v1, 서비스 내부는 /internal/v1, PG는 /pg/v1입니다. target 내부 경로를 브라우저에 노출하지 않습니다.
- x-implementation, x-requirements, x-authorized-roles, x-service-scope로 구현 여부와 요구사항을 추적합니다. 표의 shorthand를 실제 경로/DTO로 정규화했습니다.
- nullable은 JSON Schema anyOf 또는 type 배열. 금액은 v1 KRW 정수·정해진 상한. 현재 PG의 임의 3자리 통화/long 허용은 current에만 보존했습니다.
- 금융/주문 command는 Idempotency-Key, 일반 수정은 expectedVersion, 브라우저 쓰기는 쿠키+CSRF+Origin 검증. JWT는 서비스 호출 전용입니다.
- 금액 합계·unit 소유권·멱등성·승인자 분리·상태 전이는 JSON Schema로만 검증할 수 없습니다. [요구사항](../requirements/README.md)과 [수용 테스트](../requirements/08-delivery-acceptance.md)를 함께 구현합니다.
- 예시는 합성 데이터이며 실제 사용자/계좌/자격증명이 아닙니다. 오류 응답 문구가 아니라 code로 분기합니다. DELETE 본문에 expectedVersion이 있는 계약은 proxy/클라이언트 보존을 테스트합니다.
- 업로드, 관리자 로그인, 팀 초대 수락, 내부 approval 소비와 catalog snapshot 등 기존 요구사항에 필요했던 보조 경로도 명세했습니다.

## 탐색용 목록

- [Commerce 고객 · 판매자 · 관리자 API](commerce-public.md)
- [Commerce 내부 협력 API](commerce-internal.md)
- [Settlement 내부 API](settlement-internal.md)
- [Discovery 내부 API](discovery-internal.md)
- [업무 서비스 공통 운영 내부 API](operations-internal.md)
- [PG1 · PG2 현재 구현 API](pg-current.md)
- [PG1 · PG2 목표 v1 확장 API](pg-target.md)
- [Payment Service API](payment-service.md)

기존 [Payment YAML](../../contracts/payment-service.openapi.yaml) / [Checkout 계약](../../contracts/commerce-payment-checkout-contract-v0.1.md). 생성과 검증은 [도구 안내](../../scripts/docs/README.md)를 따릅니다.
