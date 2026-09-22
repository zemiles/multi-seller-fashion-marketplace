# 현재 / v1 목표 SQL 설계

같은 모델로 [ERD](../erd/README.md)와 PostgreSQL 17+ SQL을 생성합니다. 아래 파일은 **빈 격리 DB 전용 스키마 스냅샷**이며 기존 DB 업그레이드용 Flyway migration이 아닙니다. 운영/Compose DB에 적용하지 않습니다. 6개 서비스는 별도 DB입니다. 업무 서비스의 schema는 marketplace, PG1은 pgkakao, PG2는 pgnaver이며 파일에 실제 schema를 보존합니다.

| 서비스 | 현재 파일 정의 | 목표 설계 SQL |
| --- | --- | --- |
| commerce-service | [SQL](current/commerce-service.sql) | [SQL](target/commerce-service.sql) |
| payment-service | [SQL](current/payment-service.sql) | [SQL](target/payment-service.sql) |
| settlement-service | [SQL](current/settlement-service.sql) | [SQL](target/settlement-service.sql) |
| discovery-data-service | [SQL](current/discovery-data-service.sql) | [SQL](target/discovery-data-service.sql) |
| pg-kakao-simulator | [SQL](current/pg-kakao-simulator.sql) | [SQL](target/pg-kakao-simulator.sql) |
| pg-naver-simulator | [SQL](current/pg-naver-simulator.sql) | [SQL](target/pg-naver-simulator.sql) |

목표 SQL은 미적용입니다. [migration wave/backfill/전환 gate](../implementation/03-migrations.md)에 따라 새 버전 migration으로 옮겨야 합니다. 기존 V1/V2와 거래 이력을 수정하지 않습니다. [manifest](manifest.json)는 파일 hash와 표/FK 수를 제공합니다.

M4 정산 gross_net_amount, 부분 역전 UNIQUE 제거/조회 인덱스, 은행 대사 3개 테이블 및 운영 복구/quote 모델을 포함합니다. 승인 상태는 DB PENDING↔API APPROVAL_PENDING 매핑이며 EXPIRED는 기존 상태입니다.

행간 합계·누적 역전 한도·인가·원 event hash·금융 효과의 1회성은 SQL CHECK만으로 보장하지 않습니다. [workflow 잠금/transaction](../implementation/01-workflows.md)과 [시험 기준](../implementation/04-traceability.md)을 함께 구현합니다. 생성기 round-trip 검증은 실행 DB 검증의 대체가 아닙니다. 실제 검증 범위는 [검증 기록](../implementation/VERIFICATION.md)을 확인합니다.
