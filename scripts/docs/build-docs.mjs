import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {readCurrent,services,dbml,mermaid,groups} from './schema-model.mjs';
import {targetModel} from './target-model.mjs';
import {buildApiSpecs,pgSpecs} from './api-model.mjs';
import {ddlSnapshot} from './ddl-model.mjs';
import crypto from 'node:crypto';

const here=path.dirname(fileURLToPath(import.meta.url)),repo=path.resolve(here,'../..'),check=process.argv.includes('--check');
let changed=0;const outputs=new Map();
const emit=(relative,body)=>outputs.set(relative,body.endsWith('\n')?body:body+'\n');
const json=value=>JSON.stringify(value,null,2)+'\n';
const safeJson=value=>JSON.stringify(value).replaceAll('<','\\u003c');
const md=value=>String(value).replaceAll('|','\\|').replaceAll('\n',' ');
const current=readCurrent(repo),target=targetModel(current);
for(const model of [current,target])model.groups=groups(model);
const ddlManifest=[];
for(const [label,model]of [['current',current],['target',target]])for(const service of services){
 const sql=ddlSnapshot(model,service),relative=`docs/ddl/${label}/${service}.sql`;
 emit(relative,sql);ddlManifest.push({path:relative,model:label,service,tables:model.tables.filter(t=>t.service===service).length,foreignKeys:model.fks.filter(f=>model.tables.find(t=>t.id===f.from).service===service).length,sha256:crypto.createHash('sha256').update(sql).digest('hex'),purpose:'EMPTY_ISOLATED_DB_ONLY',applied:false});
}
emit('docs/ddl/manifest.json',json(ddlManifest));
emit('docs/ddl/README.md','# 현재 / v1 목표 SQL 설계\n\n같은 모델로 [ERD](../erd/README.md)와 PostgreSQL 17+ SQL을 생성합니다. 아래 파일은 **빈 격리 DB 전용 스키마 스냅샷**이며 기존 DB 업그레이드용 Flyway migration이 아닙니다. 운영/Compose DB에 적용하지 않습니다. 6개 서비스는 별도 DB입니다. 업무 서비스의 schema는 marketplace, PG1은 pgkakao, PG2는 pgnaver이며 파일에 실제 schema를 보존합니다.\n\n| 서비스 | 현재 파일 정의 | 목표 설계 SQL |\n| --- | --- | --- |\n'+services.map(s=>`| ${s} | [SQL](current/${s}.sql) | [SQL](target/${s}.sql) |`).join('\n')+'\n\n목표 SQL은 미적용입니다. [migration wave/backfill/전환 gate](../implementation/03-migrations.md)에 따라 새 버전 migration으로 옮겨야 합니다. 기존 V1/V2와 거래 이력을 수정하지 않습니다. [manifest](manifest.json)는 파일 hash와 표/FK 수를 제공합니다.\n\nM4 정산 gross_net_amount, 부분 역전 UNIQUE 제거/조회 인덱스, 은행 대사 3개 테이블 및 운영 복구/quote 모델을 포함합니다. 승인 상태는 DB PENDING↔API APPROVAL_PENDING 매핑이며 EXPIRED는 기존 상태입니다.\n\n행간 합계·누적 역전 한도·인가·원 event hash·금융 효과의 1회성은 SQL CHECK만으로 보장하지 않습니다. [workflow 잠금/transaction](../implementation/01-workflows.md)과 [시험 기준](../implementation/04-traceability.md)을 함께 구현합니다. 생성기 round-trip 검증은 실행 DB 검증의 대체가 아닙니다. 실제 검증 범위는 [검증 기록](../implementation/VERIFICATION.md)을 확인합니다.\n');
emit('docs/erd/current/schema.json',json(current));emit('docs/erd/target/schema.json',json(target));
for(const [label,model]of [['current',current],['target',target]]){
 emit(`docs/erd/${label}/all-services.dbml`,dbml(model));
 for(const service of services){
  emit(`docs/erd/${label}/${service}.dbml`,dbml(model,service));
  const tables=model.tables.filter(t=>t.service===service);let text=`# ${service} — ${label==='current'?'현재 물리':'v1 목표 / 미적용'} 데이터 사전\n\n문서용 접두사는 서비스 DB 경계를 나타냅니다. 목표 파일은 실행 DDL이 아닙니다. 원본 출처는 [ERD 안내](../README.md)를 따릅니다.\n\n`;
  for(const t of tables){const fk=model.fks.filter(f=>f.from===t.id),fkCols=new Set(fk.flatMap(f=>f.columns));text+=`## ${t.name}\n\n상태: ${t.status.toUpperCase()} · 실제 schema: ${t.schema} · ${t.note||'현재 누적 마이그레이션 정의'}\n\n| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |\n| --- | --- | --- | --- | --- |\n`;for(const c of t.columns)text+=`| ${c.name} | ${c.type} | ${c.nullable?'허용':'불가'} | ${[t.pk.includes(c.name)?'PK':'',fkCols.has(c.name)?'FK':'',t.unique.some(k=>k.length===1&&k[0]===c.name)?'UK':''].filter(Boolean).join(', ')} | ${md(c.definition)} |\n`;text+=`\nPK: (${t.pk.join(', ')})\n\nUNIQUE: ${t.unique.map(k=>'('+k.join(', ')+')').join('; ')||'없음'}\n\n`;
   for(const f of fk)text+=`- FK ${f.name}: (${f.columns.join(', ')}) → ${f.to}(${f.targetColumns.join(', ')})\n`;
   if(t.constraints.length||t.indexes.length)text+='\n```sql\n'+[...t.constraints,...t.indexes.map(i=>i.sql)].join('\n')+'\n```\n\n';
  }emit(`docs/erd/${label}/${service}.md`,text);
 }
 for(const g of model.groups){const source=mermaid(model,g.tableIds);emit(`docs/erd/${label}/${g.id}.mmd`,source);emit(`docs/erd/${label}/${g.id}.md`,`# ${g.label} — ${label}\n\n주요 키/컬럼 최대10개 표시. 전체 컬럼/제약은 [서비스 데이터 사전](${g.service}.md), 영역 밖 FK는 서비스 DBML을 확인합니다.\n\n\`\`\`mermaid\n${source}\`\`\`\n`);}
}
let erdReadme='# 테이블 ERD · 데이터 사전\n\n기준: 2026-09-21. [브라우저 ERD](index.html)는 인터넷 없이 열 수 있습니다. 업무 영역 선택, 테이블 검색, 직접 관계, 전체 컬럼/제약 조회를 제공합니다.\n\n현재 모델은 누적 Flyway **파일 정의**에서 생성했으며 실행 DB를 introspection한 결과는 아닙니다. PG1=KAKAO, PG2=NAVER, 타 서비스 ID는 물리 FK로 연결하지 않습니다.\n\n';
erdReadme+=`| 모델 | 테이블 | FK | 의미 |\n| --- | ---: | ---: | --- |\n| [현재 통합 DBML](current/all-services.dbml) | ${current.tables.length} | ${current.fks.length} | 서비스별 DB를 문서 namespace로 모은 실제 정의 |\n| [목표 통합 DBML](target/all-services.dbml) | ${target.tables.length} | ${target.fks.length} | 신규 ${target.tables.length-current.tables.length}개+변경 컬럼·CHECK·인덱스를 반영한 설계, migration 미적용 |\n\n현재 컬럼 ${current.tables.reduce((n,t)=>n+t.columns.length,0)}개, 명시적 CREATE INDEX ${current.tables.reduce((n,t)=>n+t.indexes.length,0)}개. PK/UNIQUE 자동 생성 인덱스는 별도입니다.\n\n## 서비스별 현재 / 목표\n\n| 서비스 | 현재 ERD | 목표 ERD | 현재 데이터 사전 | 목표 데이터 사전 |\n| --- | --- | --- | --- | --- |\n`;
for(const service of services)erdReadme+=`| ${service} | [DBML](current/${service}.dbml) | [DBML](target/${service}.dbml) | [컬럼·제약](current/${service}.md) | [컬럼·제약](target/${service}.md) |\n`;
erdReadme+='\n## 읽는 법\n\n- DBML의 commerce/payment/settlement/discovery/pg1/pg2는 **독립 DB의 문서 별칭**입니다. 모든 테이블을 한 DB에 생성하라는 뜻이 아닙니다. 실제 schema는 서비스별 데이터 사전에 보존했습니다.\n- CURRENT=현재 파일, PLANNED=새 테이블, MODIFIED=기존 테이블의 변경 계획. 목표 DBML을 그대로 기존 DB에 적용하지 않습니다.\n- PK/UK는 단일 또는 명시적 복합 key입니다. 복합 unique의 각 컬럼을 단독 unique로 표시하지 않습니다. nullable FK의 부모는 0..1, unique FK의 자식은 0..1, 그 외 자식은 0..N입니다. DB는 자식 최소1개를 보장하지 않으므로 임의로 1..N을 그리지 않습니다.\n- Mermaid는 FK가 child PK를 구성하면 실선, 그 외 비식별 관계는 점선입니다. HTML의 주황 점선은 **목표에 추가할 FK**를 구분하는 별도 범례입니다.\n- DBML은 컬럼/PK/UNIQUE/관계 중심 교환 형식입니다. CHECK·partial/expression index·기본값/트리거의 정확한 SQL은 데이터 사전/원본 migration이 기준입니다. DBML import가 이 SQL 의미까지 재현한다는 뜻은 아닙니다.\n- 외부 ERD 도구에는 서비스별 DBML 또는 통합 DBML을 import합니다. 외부 계정 게시 작업은 수행하지 않았습니다.\n\n## 요구사항과 target 차이\n\n[목표 변경 목록](target/CHANGES.md), [현재/목표 SQL](../ddl/README.md), [DATA-01](../requirements/08-delivery-acceptance.md), [전체 요구사항](../requirements/README.md)을 확인합니다. 인증 credential은 기존 member_auth_identity를 재사용하고 세션 데이터는 Redis에 둡니다. 중복 credential/session SQL 테이블을 새로 만들지 않습니다.\n\n';
erdReadme+='## 업무 영역별 Mermaid\n\n';for(const g of current.groups)erdReadme+=`- [${g.label}](current/${g.id}.md) / [목표](target/${g.id}.md)\n`;
// Target groups may gain another page, so add links that only exist in target.
for(const g of target.groups.filter(g=>!current.groups.some(c=>c.id===g.id)))erdReadme+=`- [목표 ${g.label}](target/${g.id}.md)\n`;
erdReadme+='\n## 원본 및 재생성\n\n원본 SHA-256은 [current/schema.json](current/schema.json)의 sources에 기록합니다. 이 목록 이외 파일이나 실행 DB를 변경하지 않습니다. `scripts/docs/build-docs.mjs`는 문서만 생성하며 `--check`는 재생성 차이를 검사합니다. 실행 환경은 [문서 생성 도구](../../scripts/docs/README.md)를 참고합니다.\n';emit('docs/erd/README.md',erdReadme);
emit('docs/erd/target/CHANGES.md','# v1 목표 모델 변경 목록\n\n실행 SQL 아님. 다음 Flyway 버전에서 backfill/제약/lock 테스트와 함께 구현합니다. 모든 기존 테이블을 포함한 목표 DBML에서 추가와 변경을 구분합니다. 상태 CHECK, partial unique, 합계 불변식은 해당 요구사항과 이 목록의 note를 함께 구현해야 합니다.\n\n| 대상 | 변경 | 필드/이유 |\n| --- | --- | --- |\n'+target.changes.map(c=>`| ${c.table} | ${c.kind} | ${md((c.columns||'')+' '+c.note)} |`).join('\n')+'\n\nSettlement 기존 reconciliation_*는 아직 PG형 legacy 필드를 포함합니다. 새 목표 Payment pg_reconciliation_*와 혼용하거나 Settlement에서 PG를 대사하지 않습니다. v1은 별도 bank_reconciliation_*를 추가하고 기존 행은 legacy 조회용으로 보존합니다. 정산 금액 매핑·부분 역전·은행 대사의 추가 명세는 [MIG-02](../../implementation/03-migrations.md)를 함께 적용합니다. 이 보완은 target overlay와 [빈 DB용 목표 SQL](../../ddl/README.md)에 반영됐습니다. 기존 DB에는 MIG-02의 expand/backfill/검증 절차를 따르는 새 migration으로 적용합니다.\n');
emit('docs/erd/index.html',fs.readFileSync(path.join(here,'erd-viewer.html'),'utf8').replace('__MODEL_DATA__',()=>safeJson({current,target})));

const apis={...buildApiSpecs(),...pgSpecs()};
const java=process.env.DOCS_JAVA||'java';const jar=process.env.DOCS_SNAKEYAML_JAR;
if(!jar)throw Error('Set DOCS_SNAKEYAML_JAR to the installed SnakeYAML jar; see scripts/docs/README.md');
const payment=JSON.parse(execFileSync(java,['-cp',jar,path.join(here,'YamlToJson.java'),path.join(repo,'contracts/payment-service.openapi.yaml')],{encoding:'utf8',maxBuffer:5*1024*1024}));
for(const [p,methods]of Object.entries(payment.paths))for(const op of Object.values(methods)){op['x-implementation']='planned';op['x-requirements']=[p.includes('webhook')?'PG-03':p.includes('guards')?'PAY-03':p.includes('refund')?'PAY-04':p.includes('approve')?'PAY-02':'PAY-01'];op['x-authorized-roles']=[p.includes('webhook')?'PG1/PG2_SIGNED_WEBHOOK':'commerce-service'];}
apis['payment-service']=payment;
function resolve(doc,s){return s?.$ref?doc.components.schemas[s.$ref.split('/').at(-1)]:s;}
const sampleId='11111111-1111-4111-8111-111111111111';
function shape(doc,input){
 const s=structuredClone(resolve(doc,input)||{}),parts=[...(s.allOf||[]).filter(p=>!p.if)];delete s.allOf;
 if(s.anyOf&&(s.type==='object'||s.properties)){parts.push(s.anyOf[0]);delete s.anyOf;}
 for(const part of parts){const p=shape(doc,part);s.properties={...(s.properties||{}),...(p.properties||{})};s.required=[...new Set([...(s.required||[]),...(p.required||[])])];for(const [k,v]of Object.entries(p))if(!['properties','required'].includes(k)&&s[k]===undefined)s[k]=v;}
 return s;
}
function example(doc,s,name='',depth=0){
 if(depth>15)return null;const schemaName=s.$ref?.split('/').at(-1);s=shape(doc,s);if(s.example!==undefined)return s.example;if(s.const!==undefined)return s.const;if(s.enum)return s.enum[0];
 if(s.anyOf)return example(doc,s.anyOf.find(x=>x.type!=='null')||s.anyOf[0],name,depth+1);
 let value;const type=Array.isArray(s.type)?s.type.find(t=>t!=='null'):s.type;
 if(type==='object'||s.properties){value={};for(const key of s.required||Object.keys(s.properties||{})){if(s.properties?.[key])value[key]=example(doc,s.properties[key],key,depth+1);}}
 else if(type==='array'){value=Array.from({length:s.minItems||0},(_,idx)=>example(doc,s.items,name,depth+1));if(name==='availableProviders')value=['KAKAO','NAVER'];}
 else if(type==='boolean')value=true;
 else if(type==='integer'||type==='number')value=s.minimum>0?s.minimum:0;
 else if(type==='null')value=null;
 else if(s.format==='uuid')value=sampleId;
 else if(s.format==='date-time')value='2026-09-21T00:00:00Z';
 else if(s.format==='date')value='2026-09-21';
 else if(s.format==='email')value='demo@example.test';
 else if(s.format==='uri')value='https://example.test/image.jpg';
 else if(s.pattern?.includes('mp-'))value='mp-'+sampleId+'-'+sampleId;
 else if(s.pattern?.includes('[0-9a-f]'))value='a'.repeat(s.pattern.includes('32')?32:64);
 else if(s.pattern?.includes('[0-9]{5}'))value='12345';
 else if(s.pattern?.includes('[0-9]{6}'))value='123456';
 else if(s.pattern?.includes('[A-Z]'))value='KRW';
 else value=(name==='password'||name==='newPassword'?'Synthetic-only-password':name==='paymentMethod'?'SIMULATED':name==='merchantTxId'?'mp-'+sampleId+'-'+sampleId:'sample').padEnd(s.minLength||1,'x').slice(0,s.maxLength||10000);
 if(value&&typeof value==='object'&&!Array.isArray(value)){
  const unitNames=['PaymentUnit','OrderUnit'];if(unitNames.includes(schemaName))Object.assign(value,{productAmount:10000,discountAmount:0,paidAmount:10000,commissionAmount:1000});
  if(['CheckoutPaymentItem','OrderItem','CheckoutItem'].includes(schemaName))Object.assign(value,{productAmount:10000,discountAmount:0,taxAmount:0,paidAmount:10000});
  if(['Money','NonNegativeMoney','SettlementMoney'].includes(schemaName))value.amount=schemaName==='NonNegativeMoney'?0:10000;
  if(schemaName==='CheckoutPaymentCharge')value.amount=3000;
  if(['Order','Checkout'].includes(schemaName))value.amount={currency:'KRW',amount:13000};
  if(schemaName==='ShippingGroup')value.shippingAmount=3000;
  if(schemaName==='Sku')Object.assign(value,{unitPrice:10000,discountPerUnit:0,paidUnitPrice:10000});
  if(['PgApprove','PgPayment','PgReceipt','PgTransactionReceipt','PgPaymentSnapshot'].includes(schemaName))value.amount=10000;
  if(schemaName==='PgRefund')value.amount=1000;
  if(schemaName==='RefundItemAllocation')Object.assign(value,{productRefundAmount:10000,discountReversalAmount:0,taxRefundAmount:0,refundAmount:10000});
  if(['RefundRequest','Refund'].includes(schemaName)){value.claimId=sampleId;value.items=[example(doc,{$ref:'#/components/schemas/RefundItemAllocation'},'',depth+1)];if(value.requestedByType!=='SYSTEM')value.requestedById=sampleId;}
  if(value.actorType&&value.actorType!=='SYSTEM')value.actorId=sampleId;
  if(schemaName==='CancellationRequest')value.claimId=sampleId;
  if(schemaName==='ClaimQuote')Object.assign(value,{expiresAt:'2026-09-21T00:05:00Z',eligibleUnitIds:[sampleId+':1'],items:[{orderItemId:sampleId,unitOrdinals:[1],productRefundAmount:10000,discountReversalAmount:0,taxRefundAmount:0,refundAmount:10000}],charges:[],totalRefund:{currency:'KRW',amount:10000},allowedActions:['CANCEL'],reasons:[]});
  if(schemaName==='RecoveryJob'){value.completedAt=null;value.failureCode=null;value.statusUrl='/api/v1/admin/recovery-jobs/'+sampleId;}
  if(schemaName==='EventQueueEntry'&&value.queueType==='OUTBOX')value.consumer=null;
  if(schemaName==='ClaimReasonChange')value.decisionReason=null;
  if(schemaName==='ExchangeConversionResult')value.claim.type='RETURN';
  if(['PreparePaymentRequest','PaymentAttempt'].includes(schemaName))value.charges=[];
  if(schemaName==='Payment')value.refundedAmount={currency:'KRW',amount:0};
 }
 return value;
}
let apiIndex='# API 명세서\n\n[오프라인 API 뷰어](index.html)에서 서비스·경로를 검색하고 인증/헤더/요청·응답·예시·오류를 확인합니다. 요청 실행 기능은 없습니다. OpenAPI 3.1 JSON은 Swagger Editor/Postman 등 호환 도구에 import할 수 있습니다.\n\n**현재 구현은 pg-current의 4경로×2개 PG뿐입니다. 나머지는 v1 구현 목표입니다.** Payment YAML은 기존 정본을 유지하며 JSON은 뷰어/검증용 생성본입니다.\n\n| 계약 | OpenAPI | operation 수 | 상태 |\n| --- | --- | ---: | --- |\n';
let operations=0;
for(const [name,doc]of Object.entries(apis)){
 let n=0;for(const methods of Object.values(doc.paths))for(const op of Object.values(methods)){n++;for(const content of [op.requestBody?.content,...Object.values(op.responses).map(r=>r.content)].filter(Boolean))if(content['application/json']){const media=content['application/json'];media.example=example(doc,media.schema);}}
 operations+=n;emit(`contracts/${name}.openapi.json`,json(doc));apiIndex+=`| ${doc.info.title} | [JSON](../../contracts/${name}.openapi.json) | ${n} | ${name==='pg-current'?'구현됨':'미구현 목표'} |\n`;
 let text=`# ${doc.info.title}\n\n[OpenAPI](../../contracts/${name}.openapi.json) · [전체 API 뷰어](index.html)\n\n| Method | Path | 설명 | 권한 | 요구사항 |\n| --- | --- | --- | --- | --- |\n`;
 for(const [p,methods]of Object.entries(doc.paths))for(const [method,op]of Object.entries(methods))text+=`| ${method.toUpperCase()} | ${p} | ${md(op.summary)} | ${md((op['x-authorized-roles']||[op['x-service-scope']||'provider']).join(', '))} | ${(op['x-requirements']||[]).join(', ')} |\n`;
 emit(`docs/api/${name}.md`,text);
}
apiIndex+=`\n총 ${operations}개 operation 정의입니다. pg-current와 pg-target은 같은 PG의 현재/목표 버전이므로 배포 API 개수로 합산하지 않습니다.\n\n## 계약 해석\n\n- 공개 고객 경로는 Commerce facade의 /api/v1, 서비스 내부는 /internal/v1, PG는 /pg/v1입니다. target 내부 경로를 브라우저에 노출하지 않습니다.\n- x-implementation, x-requirements, x-authorized-roles, x-service-scope로 구현 여부와 요구사항을 추적합니다. 표의 shorthand를 실제 경로/DTO로 정규화했습니다.\n- nullable은 JSON Schema anyOf 또는 type 배열. 금액은 v1 KRW 정수·정해진 상한. 현재 PG의 임의 3자리 통화/long 허용은 current에만 보존했습니다.\n- 금융/주문 command는 Idempotency-Key, 일반 수정은 expectedVersion, 브라우저 쓰기는 쿠키+CSRF+Origin 검증. JWT는 서비스 호출 전용입니다.\n- 금액 합계·unit 소유권·멱등성·승인자 분리·상태 전이는 JSON Schema로만 검증할 수 없습니다. [요구사항](../requirements/README.md)과 [수용 테스트](../requirements/08-delivery-acceptance.md)를 함께 구현합니다.\n- 예시는 합성 데이터이며 실제 사용자/계좌/자격증명이 아닙니다. 오류 응답 문구가 아니라 code로 분기합니다. DELETE 본문에 expectedVersion이 있는 계약은 proxy/클라이언트 보존을 테스트합니다.\n- 업로드, 관리자 로그인, 팀 초대 수락, 내부 approval 소비와 catalog snapshot 등 기존 요구사항에 필요했던 보조 경로도 명세했습니다.\n\n## 탐색용 목록\n\n`;
for(const [name,doc]of Object.entries(apis))apiIndex+=`- [${doc.info.title}](${name}.md)\n`;
apiIndex+='\n기존 [Payment YAML](../../contracts/payment-service.openapi.yaml) / [Checkout 계약](../../contracts/commerce-payment-checkout-contract-v0.1.md). 생성과 검증은 [도구 안내](../../scripts/docs/README.md)를 따릅니다.\n';emit('docs/api/README.md',apiIndex);
emit('docs/api/index.html',fs.readFileSync(path.join(here,'api-viewer.html'),'utf8').replace('__API_DATA__',()=>safeJson(apis)));
for(const [relative,body]of outputs){const file=path.join(repo,relative),existing=fs.existsSync(file)?fs.readFileSync(file,'utf8'):null;if(existing!==body){changed++;if(check)console.error('STALE '+relative);else{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,body,'utf8');}}}
if(check&&changed)process.exitCode=1;console.log(`${check?'Checked':'Generated'} ${outputs.size} artifacts; ${changed} ${check?'stale':'changed'}; current ${current.tables.length} tables/${current.fks.length} FKs, target ${target.tables.length}/${target.fks.length}; ${operations} API operations.`);
