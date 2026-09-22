// Executes snapshots ONLY in newly-created in-memory PGlite databases; accepts no DB URL.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const requireTool=createRequire(path.join(repo,'build/docs-tools/package.json'));
const {PGlite}=requireTool('@electric-sql/pglite');
const read=p=>fs.readFileSync(path.join(repo,p),'utf8'),json=p=>JSON.parse(read(p));
const manifest=json('docs/ddl/manifest.json');
const normalize=t=>t.replace('character varying','varchar').replace('character(','char(').replace('timestamp with time zone','timestamptz').replace('timestamp without time zone','timestamp').replace('time without time zone','time').replace('double precision','float8');
let tables=0,fks=0,indexes=0,negatives=0,engine;
const uuid=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
async function reject(db,sql,params,code){
 let rejected=false;
 try{await db.query(sql,params);}catch(error){assert.equal(error.code,code,sql+' wrong rejection: '+error.message);rejected=true;}
 assert.ok(rejected,'Invalid row accepted: '+sql);negatives++;
}
async function settlementChecks(db){
 const insert='INSERT INTO marketplace.settlement (settlement_id,seller_id,period_start,period_end,currency,credit_amount,debit_amount,hold_amount,net_amount,gross_net_amount,payout_amount,calculation_version) VALUES ($1,$2,\'2026-09-01\',\'2026-09-02\',\'KRW\',10000,1000,2000,7000,$3,$4,\'v1\')';
 await db.query(insert,[uuid(1),uuid(2),9000,7000]);
 await reject(db,insert,[uuid(3),uuid(4),8000,7000],'23514');
 await reject(db,insert,[uuid(3),uuid(4),9000,7001],'23514');
 const ledger='INSERT INTO marketplace.seller_ledger_entry (seller_ledger_entry_id,seller_id,entry_type,signed_amount,currency,source_type,source_key,reversal_of_entry_id,recognized_at,due_date) VALUES ($1,$2,$3,$4,\'KRW\',\'MANUAL_ADJUSTMENT\',$5,$6,now(),\'2026-09-22\')';
 await db.query(ledger,[uuid(10),uuid(2),'SALE_PROCEEDS',10000,'original',null]);
 await db.query(ledger,[uuid(11),uuid(2),'REVERSAL',-3000,'partial-1',uuid(10)]);
 await db.query(ledger,[uuid(12),uuid(2),'REVERSAL',-2000,'partial-2',uuid(10)]);
 await reject(db,ledger,[uuid(13),uuid(2),'REVERSAL',-100,'partial-2',uuid(10)],'23505');
 await reject(db,ledger,[uuid(13),uuid(2),'REVERSAL',-100,'self',uuid(13)],'23514');
 await db.query("INSERT INTO marketplace.bank_reconciliation_run VALUES ($1,'2026-09-22','2026-09-22T00:00:00Z','v1','RUNNING',now(),NULL)",[uuid(20)]);
 const receipt='INSERT INTO marketplace.bank_reconciliation_receipt VALUES ($1,$2,$3,$4,$5,$6,\'SUCCEEDED\',now(),\'{}\'::jsonb,$4)';
 await db.query(receipt,[uuid(21),uuid(20),'bank-key','a'.repeat(64),'KRW',10000]);
 await reject(db,receipt,[uuid(22),uuid(20),'bank-key','a'.repeat(64),'KRW',10000],'23505');
 await reject(db,receipt,[uuid(22),uuid(20),'new-key','a'.repeat(64),'USD',10000],'23514');
 await reject(db,receipt,[uuid(22),uuid(20),'new-key','a'.repeat(64),'KRW',-1],'23514');
 await reject(db,receipt,[uuid(22),uuid(999),'new-key','a'.repeat(64),'KRW',10000],'23503');
 await db.query("INSERT INTO marketplace.bank_reconciliation_discrepancy (discrepancy_id,run_id,identity_key,bank_receipt_id,kind,status,expected_payload,actual_payload,recorded_at,version) VALUES ($1,$2,'identity',$3,'PROVIDER_ONLY','OPEN','{}','{}',now(),0)",[uuid(30),uuid(20),uuid(21)]);
 await reject(db,"UPDATE marketplace.bank_reconciliation_discrepancy SET status='RESOLVED',resolved_at=now(),resolution_event='{}' WHERE discrepancy_id=$1",[uuid(30)],'23514');
 await reject(db,"UPDATE marketplace.bank_reconciliation_discrepancy SET status='RESOLVED',resolved_at=now(),approval_id=$2 WHERE discrepancy_id=$1",[uuid(30),uuid(31)],'23514');
 await db.query("UPDATE marketplace.bank_reconciliation_discrepancy SET status='RESOLVED',resolved_at=now(),approval_id=$2,resolution_event='{}' WHERE discrepancy_id=$1",[uuid(30),uuid(31)]);
}
for(const file of manifest){
 assert.equal(file.applied,false);assert.equal(file.purpose,'EMPTY_ISOLATED_DB_ONLY');
 const sql=read(file.path);assert.equal(createHash('sha256').update(sql).digest('hex'),file.sha256);
 const model=json(`docs/erd/${file.model}/schema.json`),expected=model.tables.filter(t=>t.service===file.service);
 const schemaName=expected[0].schema;
 assert.ok(expected.every(t=>t.schema===schemaName),'Snapshot contains multiple schemas');
 const db=await PGlite.create();
 try{
  engine ||= (await db.query('SELECT version() AS version')).rows[0].version;
  await db.exec(sql);
  const actual=(await db.query("SELECT c.relname AS name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=$1 AND c.relkind='r'",[schemaName])).rows;
  assert.deepEqual(actual.map(t=>t.name).sort(),expected.map(t=>t.name).sort(),file.path+' tables');
  const columns=(await db.query("SELECT c.relname AS table_name,a.attname AS name,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull AS not_null FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=$1 AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped",[schemaName])).rows;
  const constraints=(await db.query("SELECT c.relname AS table_name,k.conname AS name,k.contype AS type,pg_get_constraintdef(k.oid) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=$1",[schemaName])).rows;
  const ix=(await db.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname=$1",[schemaName])).rows;
  for(const t of expected){
   const cols=columns.filter(c=>c.table_name===t.name);assert.equal(cols.length,t.columns.length,t.id+' column count');
   for(const c of t.columns){const col=cols.find(a=>a.name===c.name);assert.ok(col,t.id+'.'+c.name);assert.equal(normalize(col.type),normalize(c.type),t.id+'.'+c.name+' type');assert.equal(col.not_null,!c.nullable,t.id+'.'+c.name+' nullability');}
   const cs=constraints.filter(c=>c.table_name===t.name);
   assert.ok(cs.some(c=>c.type==='p'&&c.definition===`PRIMARY KEY (${t.pk.join(', ')})`),t.id+' PK');
   for(const key of t.unique)assert.ok(cs.some(c=>c.type==='u'&&c.definition.replaceAll('"','')===`UNIQUE (${key.join(', ')})`)||ix.some(i=>i.tablename===t.name&&i.indexdef.includes('UNIQUE INDEX')&&i.indexdef.replaceAll('"','').includes(`(${key.join(', ')})`)&&!i.indexdef.includes(' WHERE ')),t.id+' unique '+key);
   for(const c of t.constraints.filter(c=>/\bCHECK\s*\(/i.test(c))){const name=c.match(/^CONSTRAINT (\w+)/)?.[1];if(name)assert.ok(cs.some(x=>x.type==='c'&&x.name===name.slice(0,63)),t.id+' CHECK '+name);}
   for(const index of t.indexes){assert.ok(ix.some(i=>i.tablename===t.name&&i.indexname===index.name.slice(0,63)&&i.indexdef.includes('UNIQUE INDEX')===index.unique&&i.indexdef.includes(' WHERE ')===index.partial),t.id+' index '+index.name);indexes++;}
  }
  const expectedFks=model.fks.filter(f=>expected.some(t=>t.id===f.from));
  assert.equal(constraints.filter(c=>c.type==='f').length,expectedFks.length,file.path+' FK count');
  for(const fk of expectedFks){const from=expected.find(t=>t.id===fk.from),to=expected.find(t=>t.id===fk.to);assert.ok(to,'Cross-service FK');const prefix=`FOREIGN KEY (${fk.columns.join(', ')}) REFERENCES ${to.schema}.${to.name}(${fk.targetColumns.join(', ')})`;assert.ok(constraints.some(c=>c.table_name===from.name&&c.type==='f'&&c.definition.startsWith(prefix)),fk.name+' definition');}
  if(file.model==='target'&&file.service==='settlement-service'){
   assert.ok(!ix.some(i=>i.tablename==='seller_ledger_entry'&&i.indexdef.includes('UNIQUE INDEX')&&i.indexdef.includes('(reversal_of_entry_id)')));
   await settlementChecks(db);
  }
  tables+=expected.length;fks+=expectedFks.length;console.log('PASS '+file.path);
 }finally{await db.close();}
}
console.log(`PASS: ${manifest.length} empty in-memory SQL snapshots; ${tables} tables, ${fks} FKs, ${indexes} explicit indexes, ${negatives} expected constraint rejections. Engine: ${engine}`);
console.log('Not a native server upgrade/backfill, multi-connection concurrency or runtime integration test. Cumulative reversal limits require owner transaction tests.');
