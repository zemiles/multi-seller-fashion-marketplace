# ERD · API · 구현 상세 계약 생성과 검증

애플리케이션·기존 DB를 실행하거나 변경하지 않는 문서 도구입니다. SQL 검증만 매번 새 메모리 DB를 만들고 폐기합니다. 생성 HTML은 네트워크 의존성 없이 열 수 있으며 API 요청 실행 기능이 없습니다.

## 원본과 산출물

| 원본 | 역할 | 생성 결과 |
| --- | --- | --- |
| 각 서비스의 누적 Flyway migration | 현재 물리 테이블의 정본 | [현재 ERD](../../docs/erd/README.md), DBML, 데이터 사전, schema.json |
| [target-model.mjs](target-model.mjs) + [target-rules.mjs](target-rules.mjs) + v1 요구사항 | 추가·변경 모델, CHECK·인덱스 | 목표 ERD와 변경 목록 |
| [ddl-model.mjs](ddl-model.mjs) + 현재/목표 모델 | 서비스별 빈 격리 DB용 스냅샷 | [SQL 12개·hash manifest](../../docs/ddl/README.md). 기존 DB upgrade용 아님 |
| [api-model.mjs](api-model.mjs) + [contract-extensions.mjs](contract-extensions.mjs) + v1 요구사항 | 고객/판매자/관리자/내부/PG 및 X-01~11 필드 계약 | OpenAPI JSON 8개 |
| [Payment YAML](../../contracts/payment-service.openapi.yaml) | Payment 계약 정본 | Payment OpenAPI JSON. YAML은 생성기가 수정하지 않음 |
| [erd-viewer.html](erd-viewer.html), [api-viewer.html](api-viewer.html) | 오프라인 뷰어 템플릿 | [ERD 뷰어](../../docs/erd/index.html), [API 뷰어](../../docs/api/index.html) |
| [event-model.mjs](event-model.mjs) + Payment JSON | 이벤트별 타입·필수 필드·공통 DTO·예시 | [JSON Schema·필드 사전·정상/오류 fixture](../../contracts/events/v1/README.md) |
| [trace-model.mjs](trace-model.mjs) + 요구사항·OpenAPI·target schema | 요구사항 연결·추가 시험·migration wave | [추적표](../../docs/implementation/04-traceability.md), traceability.json, migration-manifest.json |

`docs/erd`, `docs/api`, `docs/ddl`, `contracts/*.openapi.json`은 생성본입니다. 직접 고치지 말고 원본 수정 → 재생성 → 검증합니다. API 정책을 바꾸면 요구사항/수용 테스트도 함께 변경합니다. 목표 CHECK·partial index는 목표 모델/SQL에 포함돼 있으며 기존 데이터에는 migration 계획의 expand/backfill/검증 후 도입합니다. 누적 금액·인가 등 행간 불변식은 owner transaction에서 구현합니다.

`contracts/events/v1` 전체, `docs/implementation/04-traceability.md`, `traceability.json`, `migration-manifest.json`, `contract-extensions.json`도 생성본입니다. 나머지 구현 상세 Markdown은 직접 작성한 정본입니다. Payment DTO를 이벤트로 복제할 때 필드 구조를 재사용하되 이벤트 object에는 `additionalProperties:false`를 적용합니다. OpenAPI와 이벤트 생성은 아래 순서대로 실행합니다.

## 재생성

Node.js 20+, JDK 17+, SnakeYAML 2.6이 필요합니다. SnakeYAML은 Gradle 의존성 캐시에 이미 있으면 재사용합니다. `DOCS_JAVA`를 생략하면 PATH의 java를 사용합니다.

```powershell
$env:DOCS_JAVA = 'C:\Program Files\Java\jdk-17\bin\java.exe'
$env:DOCS_SNAKEYAML_JAR = (Get-ChildItem "$env:USERPROFILE\.gradle\caches\modules-2\files-2.1\org.yaml\snakeyaml\2.6" -Recurse -Filter 'snakeyaml-2.6.jar' | Select-Object -First 1).FullName
node scripts/docs/build-docs.mjs
node scripts/docs/build-implementation-docs.mjs
node scripts/docs/build-docs.mjs --check
node scripts/docs/build-implementation-docs.mjs --check
python scripts/docs/verify-docs.py
python scripts/docs/verify-implementation.py
python scripts/docs/verify-contract-closure.py
.\scripts\verify-doc-links.ps1
```

Python 검증에는 `jsonschema>=4.18`이 필요합니다. schema/example, `$ref`, path parameter, 구현 상태, 요구사항 ID, 원본 hash, ERD 페이지 누락을 검사합니다. 생성기는 서비스 간 물리 FK, 없는 컬럼 참조, 비고유 부모 키, 중복 테이블/키도 거부합니다. SQL 추출기는 **현재 저장소 DDL의 부분집합**만 처리하므로 새 ALTER/타입/문법이 생기면 parser와 회귀 테스트도 갱신해야 합니다. 일반 PostgreSQL parser 또는 실행 DB 검증의 대체가 아닙니다.

`verify-implementation.py`는 이벤트 schema/registry 19종, 정상 19개·의도적 오류 51개 fixture, payload 내부 금액/수량·stream 산술, 요구사항 55개·API·AT·화면·migration 연결을 검사합니다. 원 주문 snapshot·실제 승인·PG receipt·원장 한도는 DB 통합시험이 필요합니다. 문서 fixture 통과를 AT/DT 통과로 기록하지 않습니다. 새 기능 구현 시 trace 모델과 실제 증거도 함께 갱신합니다.

## 추가 형식 검증

검증용 Node 패키지는 앱 package/build 설정과 분리된, Git 제외 경로에 설치합니다. 설치 스크립트는 실행하지 않습니다.

Gradle `clean`은 `build/docs-tools`도 지웁니다. 전체 Java 빌드 후 형식 검증을 다시 할 때 아래 의존성을 재설치해야 합니다.

```powershell
npm install --prefix build/docs-tools --ignore-scripts --no-audit --no-fund @apidevtools/swagger-parser @dbml/core ajv ajv-formats mermaid @electric-sql/pglite
node scripts/docs/verify-formats.mjs
node scripts/docs/verify-ddl.mjs
```

형식 검증기는 OpenAPI 3.1 구조, DBML 및 Mermaid parser 입력을 검사합니다. 별도의 브라우저 시각 QA와 동일하지 않습니다. 형식 통과는 금액 합계·인가·DB lock·동시성·재시도 구현이 완료됐다는 의미가 아닙니다. 목표 API를 실제 서버로 호출하는 테스트는 각 기능 구현 후 추가합니다.

`verify-contract-closure.py`는 X-01~11 operation manifest, 요청 필수/금지/조건부 필드·version 오류 104개, 인증 방식·역할/scope 명세, 화면 operationId, M4 목표 모델, DDL hash 연결을 검사합니다. 실제 인증 서버나 승인 로직을 실행하지 않습니다.

`verify-ddl.mjs`는 [PGlite 메모리 DB](https://pglite.dev/docs/api) 12개에 각각 SQL을 실행하고 컬럼/타입/NULL/PK/UK/FK/CHECK/인덱스를 모델과 대조합니다. 정산 gross/hold/payout, 부분 역전 source 중복, 은행 receipt와 대사 종결 제약의 성공·오류 사례를 실행합니다. DB URL/기존 데이터 경로는 받지 않습니다. 검증 엔진 버전은 출력과 검증 기록에 남깁니다. 단일 연결 임베디드 엔진이므로 **native PostgreSQL 기존-data upgrade/backfill·다중 연결 lock 경합 테스트는 별도**입니다. owner lock의 누적 역전 상한을 SQL만으로 보장했다고 보고하지 않습니다.

참고 형식: [OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0.html), [DBML 문법](https://dbml.dbdiagram.io/docs/).
