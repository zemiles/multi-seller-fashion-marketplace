# 테이블 ERD · 데이터 사전

기준: 2026-09-21. [브라우저 ERD](index.html)는 인터넷 없이 열 수 있습니다. 업무 영역 선택, 테이블 검색, 직접 관계, 전체 컬럼/제약 조회를 제공합니다.

현재 모델은 누적 Flyway **파일 정의**에서 생성했으며 실행 DB를 introspection한 결과는 아닙니다. PG1=KAKAO, PG2=NAVER, 타 서비스 ID는 물리 FK로 연결하지 않습니다.

| 모델 | 테이블 | FK | 의미 |
| --- | ---: | ---: | --- |
| [현재 통합 DBML](current/all-services.dbml) | 113 | 173 | 서비스별 DB를 문서 namespace로 모은 실제 정의 |
| [목표 통합 DBML](target/all-services.dbml) | 163 | 209 | 신규 50개+변경 컬럼·CHECK·인덱스를 반영한 설계, migration 미적용 |

현재 컬럼 1243개, 명시적 CREATE INDEX 202개. PK/UNIQUE 자동 생성 인덱스는 별도입니다.

## 서비스별 현재 / 목표

| 서비스 | 현재 ERD | 목표 ERD | 현재 데이터 사전 | 목표 데이터 사전 |
| --- | --- | --- | --- | --- |
| commerce-service | [DBML](current/commerce-service.dbml) | [DBML](target/commerce-service.dbml) | [컬럼·제약](current/commerce-service.md) | [컬럼·제약](target/commerce-service.md) |
| payment-service | [DBML](current/payment-service.dbml) | [DBML](target/payment-service.dbml) | [컬럼·제약](current/payment-service.md) | [컬럼·제약](target/payment-service.md) |
| settlement-service | [DBML](current/settlement-service.dbml) | [DBML](target/settlement-service.dbml) | [컬럼·제약](current/settlement-service.md) | [컬럼·제약](target/settlement-service.md) |
| discovery-data-service | [DBML](current/discovery-data-service.dbml) | [DBML](target/discovery-data-service.dbml) | [컬럼·제약](current/discovery-data-service.md) | [컬럼·제약](target/discovery-data-service.md) |
| pg-kakao-simulator | [DBML](current/pg-kakao-simulator.dbml) | [DBML](target/pg-kakao-simulator.dbml) | [컬럼·제약](current/pg-kakao-simulator.md) | [컬럼·제약](target/pg-kakao-simulator.md) |
| pg-naver-simulator | [DBML](current/pg-naver-simulator.dbml) | [DBML](target/pg-naver-simulator.dbml) | [컬럼·제약](current/pg-naver-simulator.md) | [컬럼·제약](target/pg-naver-simulator.md) |

## 읽는 법

- DBML의 commerce/payment/settlement/discovery/pg1/pg2는 **독립 DB의 문서 별칭**입니다. 모든 테이블을 한 DB에 생성하라는 뜻이 아닙니다. 실제 schema는 서비스별 데이터 사전에 보존했습니다.
- CURRENT=현재 파일, PLANNED=새 테이블, MODIFIED=기존 테이블의 변경 계획. 목표 DBML을 그대로 기존 DB에 적용하지 않습니다.
- PK/UK는 단일 또는 명시적 복합 key입니다. 복합 unique의 각 컬럼을 단독 unique로 표시하지 않습니다. nullable FK의 부모는 0..1, unique FK의 자식은 0..1, 그 외 자식은 0..N입니다. DB는 자식 최소1개를 보장하지 않으므로 임의로 1..N을 그리지 않습니다.
- Mermaid는 FK가 child PK를 구성하면 실선, 그 외 비식별 관계는 점선입니다. HTML의 주황 점선은 **목표에 추가할 FK**를 구분하는 별도 범례입니다.
- DBML은 컬럼/PK/UNIQUE/관계 중심 교환 형식입니다. CHECK·partial/expression index·기본값/트리거의 정확한 SQL은 데이터 사전/원본 migration이 기준입니다. DBML import가 이 SQL 의미까지 재현한다는 뜻은 아닙니다.
- 외부 ERD 도구에는 서비스별 DBML 또는 통합 DBML을 import합니다. 외부 계정 게시 작업은 수행하지 않았습니다.

## 요구사항과 target 차이

[목표 변경 목록](target/CHANGES.md), [현재/목표 SQL](../ddl/README.md), [DATA-01](../requirements/08-delivery-acceptance.md), [전체 요구사항](../requirements/README.md)을 확인합니다. 인증 credential은 기존 member_auth_identity를 재사용하고 세션 데이터는 Redis에 둡니다. 중복 credential/session SQL 테이블을 새로 만들지 않습니다.

## 업무 영역별 Mermaid

- [commerce / 회원·판매자](current/commerce-identity-1.md) / [목표](target/commerce-identity-1.md)
- [commerce / 상품·재고](current/commerce-catalog-1.md) / [목표](target/commerce-catalog-1.md)
- [commerce / 장바구니·주문](current/commerce-order-1.md) / [목표](target/commerce-order-1.md)
- [commerce / 배송·클레임](current/commerce-fulfillment-1.md) / [목표](target/commerce-fulfillment-1.md)
- [commerce / 리뷰·알림](current/commerce-experience-1.md) / [목표](target/commerce-experience-1.md)
- [commerce / 운영·금융협력 1](current/commerce-operations-1.md) / [목표](target/commerce-operations-1.md)
- [commerce / 운영·금융협력 2](current/commerce-operations-2.md) / [목표](target/commerce-operations-2.md)
- [payment / payment](current/payment-core-1.md) / [목표](target/payment-core-1.md)
- [settlement / settlement](current/settlement-core-1.md) / [목표](target/settlement-core-1.md)
- [discovery / discovery](current/discovery-core-1.md) / [목표](target/discovery-core-1.md)
- [pg1 / pg1](current/pg1-core-1.md) / [목표](target/pg1-core-1.md)
- [pg2 / pg2](current/pg2-core-1.md) / [목표](target/pg2-core-1.md)
- [목표 commerce / 배송·클레임 2](target/commerce-fulfillment-2.md)
- [목표 payment / payment 2](target/payment-core-2.md)
- [목표 settlement / settlement 2](target/settlement-core-2.md)

## 원본 및 재생성

원본 SHA-256은 [current/schema.json](current/schema.json)의 sources에 기록합니다. 이 목록 이외 파일이나 실행 DB를 변경하지 않습니다. `scripts/docs/build-docs.mjs`는 문서만 생성하며 `--check`는 재생성 차이를 검사합니다. 실행 환경은 [문서 생성 도구](../../scripts/docs/README.md)를 참고합니다.
