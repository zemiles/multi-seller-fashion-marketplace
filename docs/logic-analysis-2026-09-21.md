# 백엔드 전체 검토 및 수정 결과

검토일: 2026-09-21. 개발 진입점은 [BACKEND_DESIGN](BACKEND_DESIGN.md)이며 이 문서는 검토 근거입니다. 이전 분석에서 제기했던 위험 중 이번에 수정한 것과 미구현 기능을 구분합니다.

## 검토 범위와 실제 상태

백엔드의 7개 Gradle 모듈, main Java 129개(실제 클래스/record/enum 49개와 package-info 80개), 테스트, 6개 V1 SQL, 환경 properties, Compose/Dockerfile, migration 생성기, 백엔드 Markdown 전체와 상위 README·대화 기록·DB 설명을 대조했습니다. 신규 회귀 테스트 3개 파일과 V2 3개, 문서·검증 스크립트를 추가했습니다.

기존 작업 트리에는 PG 두 모듈 분리, 프로필 추가, 계약 변경 등 미커밋 변경이 있었습니다. 이를 작업 기준으로 보존했습니다. 변경 내역 전체를 이번 작업이 새로 만든 것으로 간주하지 않습니다.

현재 업무 REST/DB 처리는 두 PG simulator만 구현돼 있습니다. Payment는 메모리 reference implementation이고 Commerce/Settlement/Discovery는 기동·schema·package 기반입니다. 주문→결제→정산 E2E는 아직 없습니다.

## 수정한 문제

| 문제 | 영향 | 수정 |
| --- | --- | --- |
| `require(command != null)` 등 boolean을 Object null 검사에 전달 | false도 검증 통과, 의도한 입력 오류 검사가 동작하지 않음 | 객체 자체 사전 검사 |
| 환불 필수값 검증이 PG 호출 및 잔액 갱신 뒤 실행 | 잘못된 요청으로 외부 환불이 먼저 발생 가능 | Refund/요청자/상태/통화/잔액 검증을 외부 호출 앞으로 이동 |
| 동일 refund key의 다른 금액·claim·사유·요청자 허용 | 다른 요청이 기존 성공으로 보임 | 전체 요청 내용 비교 후 충돌 처리 |
| merchant 중복·동일 주문 다른 provider 시도 허용 | 중복 결제 시도 가능 | provider/merchant 중복 및 주문 기준 미해결/성공 시도 차단 |
| 문자열 결합 key의 구분자 충돌 | 서로 다른 provider/key가 같은 저장 키가 될 수 있음 | record 복합 키 |
| PG 호출 예외·불일치 후 CREATED 유지 / 환불 요청 미보존 | 재시도 시 중복 금융 효과 가능 | 요청 전 상태 저장, UNKNOWN 유지, 같은 키 재호출 차단·환불 금액 예약 |
| refund port에 외부 결제 식별자와 멱등 키 없음 | 외부 PG에서 대상 및 재요청 식별 불가 | provider/providerPaymentKey/idempotencyKey 전달 |
| PG 동시 승인에서 unique 경합을 일반 500으로 반환 | 같은 거래의 동시 요청이 멱등 응답하지 않음 | 별도 transaction에서 승인 commit, 충돌 rollback 후 fresh transaction 재조회 |
| PG 글로벌 synchronized | 다른 결제까지 JVM에서 직렬화하면서 commit 구간은 보호 못함 | 승인 DB unique 및 환불/취소 DB 행 잠금으로 처리 |
| 금액 JSON의 소수·문자열 자동 형변환 | 소수 금액이 잘린 정수로 승인될 수 있음 | 두 PG의 Jackson scalar/float coercion 비활성화, 400 회귀 테스트 |
| FK 생성기가 여러 ADD CONSTRAINT를 통째 필터 | 외부 FK가 섞인 테이블의 내부 FK도 유실 | constraint별 필터, 서비스별 V2로 총 22개 FK 복원 |
| 생성기가 적용된 V1을 재작성 | Flyway checksum 오류·기존 이력 훼손 위험 | build/schema-preview에만 후보 생성, migration 경로 출력 거부 |
| Payment/Settlement/Discovery docker 기본 DB 포트 오류 | 호스트 실행에서 다른 DB 포트에 접속 | 각 5433/5434/5435로 수정 |
| 무인증 로컬 PG·DB의 모든 인터페이스 공개 | 같은 네트워크에서 모의 거래 조작 가능 | Compose host 포트 및 local 앱을 loopback에 바인딩 |
| 단일 앱/10개/4개 서비스 설명 충돌 | 새 작업이 잘못된 구조에서 시작 | 4개 서비스 기준 문서와 실행 가이드로 통일 |
| 구매확정 소유권과 정산 시작 조건 충돌 | 중복 writer·결제 승인 직후 부적절한 정산 | Commerce 구매확정, Settlement 구매확정 기반 원장으로 통일 |
| PG Naver 포트·Actuator·H2 Flyway 설명 오류 | 실행/진단 실패 | 실제 설정과 맞춤, 과거 백업에는 역사적 기록 배너 |
| OpenAPI 승인 UNKNOWN 조회 경로와 202 부재, 3.1 nullable 표기 | 소비자가 결과 불명 시 새 결제 재요청 가능, 타입 불일치 | 202, attempt/refund 조회 초안 및 JSON Schema null·요청자 필수 조건 보완 |

Payment 수정은 여전히 메모리 구현 내부의 개선입니다. DB 내구성과 다중 인스턴스 안전성을 구현한 것은 아닙니다.

## SQL 검증

| 서비스 | V1 내부 FK | V2 추가 | 적용 후 |
| --- | ---: | ---: | ---: |
| Commerce | 136 | 0 | 136 |
| Payment | 3 | 11 | 14 |
| Settlement | 4 | 10 | 14 |
| Discovery | 6 | 1 | 7 |

기존 V1은 변경하지 않았습니다. 격리 PostgreSQL 17.11에서 각 DB에 V1 다음 V2를 적용했고 모든 FK가 생성됨을 확인했습니다. 복원한 Payment → PaymentAttempt FK가 orphan 결제 삽입을 거부하는 음성 테스트도 통과했습니다. 운영/기존 Compose 데이터에는 적용하지 않았습니다.

## 실행한 검증

- `clean build --no-daemon` 및 후속 `build --no-daemon` 성공. 최종 39개 테스트, 실패 0.
- Payment 18개: domain 7, 기존 lifecycle 3, 새 safety 7, context 1.
- PG simulator 각 9개: API 6 + 동시성 3. H2와 격리 PostgreSQL에서 검증.
- 나머지 업무 서비스 context 3개 성공.
- PG 동시성: 8개 동시 승인 → 결제·승인 거래 각 1건, 8개 동일 환불 → 효과 1번, 서로 다른 초과 환불 경쟁 → 하나만 성공.
- 서비스 schema 비교: 모든 내부 FK 일치, cross-service FK 없음.
- V1+V2 실제 PostgreSQL SQL 적용 및 FK 거부 확인.
- Compose 설정, 문서 상대 링크/코드 블록, `git diff --check` 검증.
- OpenAPI YAML 구문, 내부 참조 49개, 3.1 null 표기 검증. 전체 OpenAPI 의미 검증 도구나 실제 Controller 계약 테스트를 수행한 것은 아님.
- 생성기 migration 경로 출력 거부 및 실행 전후 V1 hash 불변 확인.

PG 동시성 테스트는 하나의 Spring 프로세스에서 여러 DB transaction을 경쟁시키며, 실제 여러 서버 프로세스를 띄운 테스트는 아닙니다. H2만으로 PostgreSQL 동작을 추정하지 않고 같은 PG 테스트를 PostgreSQL에서도 반복했습니다.

## 남은 구현과 실사용 전 조건

1. Payment 영속화, 전체 Checkout snapshot·금액/수량 배분, 주문 기준 DB 중복 결제 가드.
2. PG adapter·timeout 조회·UNKNOWN 복구·재시작 보존. 현재 UNKNOWN은 보류할 수 있으나 자동 확정/해제가 없음.
3. Kafka outbox 발행·consumer inbox·webhook 원문/서명/중복·역순 처리.
4. Commerce 상품/재고/주문과 배송·Claim·구매확정.
5. Settlement 원장·지급·은행 대사, Discovery projection.
6. 서비스 간/고객 인증·권한, simulator 공유 환경 접근 제어, simulated 식별 계약.
7. PG 대사 모델은 Payment에 추가 설계. 현재 Settlement의 과거 reconciliation schema와 역할이 다름.
8. 공개 금액 직렬화, 지원 통화, 할인·세금·자동확정·예약 보류 기한 등 정책 확정.

전체 Compose 앱 E2E, 실제 PG/송금, 운영 배포, 기존 실데이터 migration·성능 검증은 수행하지 않았습니다. 현재 검증 결과를 운영 준비 완료로 해석하지 않습니다.
