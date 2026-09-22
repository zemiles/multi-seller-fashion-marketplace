# v1 구현 상세 문서

작성일: 2026-09-22. [요구사항](../requirements/README.md)의 정책을 구현 단계로 구체화한 문서입니다. PG1=KAKAO, PG2=NAVER, 4개 업무 서비스, 모든 금융 거래 simulated=true를 유지합니다.

| 순서 | 문서 | 구현 시 확인할 내용 |
| --- | --- | --- |
| 1 | [업무 흐름·상태 전이](01-workflows.md) | transaction 경계, lock 순서, 재시도, 경합 승자와 후속 처리 |
| 2 | [이벤트 상세 계약](02-event-contracts.md) | JSON Schema, 예시, producer/consumer, 순서·중복·호환성 |
| 3 | [DB 마이그레이션 계획](03-migrations.md) | 서비스별 배포 단계, backfill, 제약·인덱스, 전환·복구 gate |
| 4 | [요구사항–구현 추적표](04-traceability.md) | 요구사항별 API·테이블·이벤트·AT·추가 시험·구현 상태 |
| 5 | [화면 상세 명세](05-screens.md) | route, 입력, 버튼 조건, API, 상태/오류별 표시 |
| 6 | [장애 대응·운영 절차](06-runbooks.md) | 증거 수집, 쓰기 차단 범위, 재처리·복원, 성공 판정 |

현재/목표 상태는 [BACKEND_DESIGN](../BACKEND_DESIGN.md), 실제 HTTP 필드는 [OpenAPI](../api/README.md), 현재 SQL은 각 서비스 누적 Flyway, 설계 모델은 [목표 ERD](../erd/target/CHANGES.md), 빈 격리 DB용 [현재/목표 DDL](../ddl/README.md)을 함께 봅니다. 생성된 이벤트 계약/추적표는 [문서 도구](../../scripts/docs/README.md)로 재생성합니다.

## 상세화한 결정

- DB transaction은 한 서비스 안에서만 열고, 외부 호출 사이에는 영속 operation과 재처리로 연결합니다. 동일 서비스 transaction 안의 lock 순서는 01 문서에 고정했습니다.
- 무브랜드 상품은 API의 brandId=null과 동일하게 이벤트 brandId=null을 허용합니다. 필드 자체는 필수입니다. 그 밖의 선택/nullable은 JSON Schema가 정합니다.
- financial stream의 sequence는 소비 대상 여부와 관계없이 연속 증가합니다. 이벤트를 해석하지 않고 watermark만 올릴 수 없습니다.
- 현재 상태에서 복구 가능한 행만 backfill합니다. 금액 배분·PG 효과·승인 근거가 없는 과거 행은 격리하고 증거를 확보한 뒤 전환합니다.
- 추가 화면의 보조 API는 [계약 보완 목록](05-screens.md#계약-보완-목록)에 필드와 경로를 확정했습니다. 11개 묶음의 38개 operation을 정식 OpenAPI에 반영했습니다. [계약 연결 manifest](contract-extensions.json)의 SPECIFIED는 명세 완료이며 서버 구현 완료가 아닙니다.

문서 완성/계약 검증과 실제 업무 구현 완료는 별개로 기록합니다. 이 작업은 문서와 검증 가능한 계약 산출물 추가이며, 실행 DB migration이나 서비스 배포를 수행하지 않습니다.

검증 범위와 실제 실행 결과는 [검증 기록](VERIFICATION.md)에 있습니다. 문서 읽기는 위 순서대로, 구현은 [단계별 선행 조건](../requirements/08-delivery-acceptance.md)과 추적표에 따라 진행합니다.
