import {parseSql,validateModel} from './schema-model.mjs';

const same=(a,b)=>a.length===b.length&&a.every(x=>b.includes(x));
const keyOf=constraint=>constraint.match(/\b(?:PRIMARY\s+KEY|UNIQUE)\s*\(([^)]+)\)/i)?.[1].split(',').map(x=>x.trim());
export function ddlSnapshot(model,service){
 const tables=model.tables.filter(t=>t.service===service),ids=new Set(tables.map(t=>t.id));
 const lines=[`-- ${service}: empty isolated database schema snapshot.`,
  '-- NOT an upgrade migration. NEVER apply to an existing/production database.',
  '-- Generated from the same model as ERD; cross-row money/authority rules remain owner transactions.',
  '-- PostgreSQL 17+; gen_random_uuid() is a built-in function. No external extension required.',
  'BEGIN;',...new Set(tables.map(t=>`CREATE SCHEMA IF NOT EXISTS ${t.schema};`)),''];
 for(const t of tables){
  if(t.note)lines.push('-- '+t.note.replace(/[\r\n]+/g,' '));
  const definitions=t.columns.map(c=>c.definition.replace(/^PLANNED\s+/,'').replace(/\s+REFERENCES\s+\w+\.\w+\s*\([^)]+\)(?:\s+ON\s+(?:DELETE|UPDATE)\s+(?:CASCADE|RESTRICT|NO ACTION|SET NULL|SET DEFAULT))*/gi,''));
  const constraints=t.constraints.filter(c=>!/^\s*(?:CONSTRAINT\s+\w+\s+)?FOREIGN\s+KEY/i.test(c));
  if(!definitions.some(c=>/\bPRIMARY KEY\b/i.test(c))&&!constraints.some(c=>/\bPRIMARY KEY\b/i.test(c)))constraints.push(`PRIMARY KEY (${t.pk.join(', ')})`);
  const represented=[...constraints.map(keyOf).filter(Boolean),...t.columns.filter(c=>/\bUNIQUE\b/i.test(c.definition)).map(c=>[c.name])];
  for(const index of t.indexes.filter(i=>i.unique&&!i.partial)){
   const match=index.sql.match(/\bON\s+\w+\.\w+\s*\(([^)]+)\)/i);if(match)represented.push(match[1].split(',').map(x=>x.trim()));
  }
  for(const unique of t.unique)if(!represented.some(k=>same(k,unique))){constraints.push(`UNIQUE (${unique.join(', ')})`);represented.push(unique);}
  lines.push(`CREATE TABLE ${t.schema}.${t.name} (`,[...definitions,...constraints].map(x=>'    '+x).join(',\n'),');','');
 }
 for(const fk of model.fks.filter(f=>ids.has(f.from))){
  if(!ids.has(fk.to))throw Error('Cross-service FK in DDL '+fk.name);
  const from=tables.find(t=>t.id===fk.from),to=tables.find(t=>t.id===fk.to);
  const tail=fk.sql.match(/REFERENCES\s+\w+\.\w+\s*\([^)]+\)([\s\S]*)$/i)?.[1].replace(/[;,]\s*$/,'').trim()||'';
  lines.push(`ALTER TABLE ${from.schema}.${from.name} ADD CONSTRAINT ${fk.name} FOREIGN KEY (${fk.columns.join(', ')}) REFERENCES ${to.schema}.${to.name} (${fk.targetColumns.join(', ')})${tail?' '+tail:''};`);
 }
 for(const t of tables)for(const index of t.indexes)lines.push(index.sql);
 lines.push('COMMIT;','');
 const sql=lines.join('\n');
 // Round-trip our supported DDL subset; engine validation is a separate check.
 const roundTrip=parseSql(sql,service);validateModel(roundTrip);
 for(const expected of tables){
  const actual=roundTrip.tables.find(t=>t.id===expected.id);
  if(!actual||actual.columns.length!==expected.columns.length||!same(actual.pk,expected.pk))throw Error('DDL table mismatch '+expected.id);
  for(const c of expected.columns){const found=actual.columns.find(x=>x.name===c.name);if(!found||found.type!==c.type||found.nullable!==c.nullable)throw Error('DDL column mismatch '+expected.id+'.'+c.name);}
  for(const key of expected.unique)if(!actual.unique.some(k=>same(k,key)))throw Error('DDL unique missing '+expected.id+':'+key);
  const checks=t=>t.constraints.filter(c=>/\bCHECK\s*\(/i.test(c)).map(c=>c.replace(/\s+/g,' ').trim()).sort();
  if(JSON.stringify(checks(actual))!==JSON.stringify(checks(expected)))throw Error('DDL CHECK mismatch '+expected.id);
  if(actual.indexes.length!==expected.indexes.length)throw Error('DDL index missing '+expected.id);
 }
 if(roundTrip.fks.length!==model.fks.filter(f=>ids.has(f.from)).length)throw Error('DDL FK count mismatch '+service);
 return sql;
}
