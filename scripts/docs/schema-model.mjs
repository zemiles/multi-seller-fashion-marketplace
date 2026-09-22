import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const services = ['commerce-service','payment-service','settlement-service','discovery-data-service','pg-kakao-simulator','pg-naver-simulator'];
export const namespace = s => ({'commerce-service':'commerce','payment-service':'payment','settlement-service':'settlement','discovery-data-service':'discovery','pg-kakao-simulator':'pg1','pg-naver-simulator':'pg2'}[s]);
export function splitTop(text, separator=',') {
  const parts=[]; let start=0,depth=0,quote=null;
  for(let i=0;i<text.length;i++) {
    const c=text[i];
    if(quote){if(c===quote){if(text[i+1]===quote)i++;else quote=null;}continue;}
    if(c==="'"||c==='"')quote=c;
    else if(c==='(')depth++;
    else if(c===')')depth--;
    else if(c===separator&&depth===0){parts.push(text.slice(start,i).trim());start=i+1;}
  }
  parts.push(text.slice(start).trim()); return parts.filter(Boolean);
}
function closeParen(text,open){let depth=0,quote=null;for(let i=open;i<text.length;i++){const c=text[i];if(quote){if(c===quote){if(text[i+1]===quote)i++;else quote=null;}continue;}if(c==="'"||c==='"')quote=c;else if(c==='(')depth++;else if(c===')'&&!--depth)return i;}throw Error('Unbalanced SQL');}
const cols = raw => splitTop(raw).map(x=>x.trim().replaceAll('"',''));
export function parseSql(sql,service){
  const normalized=sql.replace(/\/\*[\s\S]*?\*\//g,' ').replace(/--[^\r\n]*/g,' ');
  const tables=[],fks=[];
  const pattern=/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\.(\w+)\s*\(/gi;
  for(let m;(m=pattern.exec(normalized));){
    const open=normalized.indexOf('(',m.index),close=closeParen(normalized,open);
    const table={service,schema:m[1],name:m[2],id:`${namespace(service)}.${m[2]}`,columns:[],pk:[],unique:[],constraints:[],indexes:[],status:'current'};
    for(const item of splitTop(normalized.slice(open+1,close))){
      if(/^(CONSTRAINT|PRIMARY|UNIQUE|CHECK|FOREIGN|EXCLUDE)\b/i.test(item)){
        table.constraints.push(item);
        const key=item.match(/(?:CONSTRAINT\s+\w+\s+)?(PRIMARY\s+KEY|UNIQUE(?:\s+NULLS\s+NOT\s+DISTINCT)?)\s*\(([^)]+)\)/i);
        if(key){if(/^PRIMARY/i.test(key[1]))table.pk=cols(key[2]);else table.unique.push(cols(key[2]));}
        const fk=item.match(/(?:CONSTRAINT\s+(\w+)\s+)?FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+(\w+)\.(\w+)\s*\(([^)]+)\)/i);
        if(fk)fks.push({name:fk[1]||`${table.name}_fk_${fks.length}`,from:table.id,columns:cols(fk[2]),to:`${namespace(service)}.${fk[4]}`,targetColumns:cols(fk[5]),sql:item});
        continue;
      }
      const c=item.match(/^(\w+)\s+([\s\S]+)$/);if(!c)throw Error(`Unknown column: ${item}`);
      const type=c[2].split(/\s+(?:NOT\s+NULL|NULL|DEFAULT|PRIMARY\s+KEY|UNIQUE|REFERENCES|CHECK|GENERATED|CONSTRAINT)\b/i)[0].trim();
      const column={name:c[1],type,nullable:!(/\bNOT\s+NULL\b|\bPRIMARY\s+KEY\b/i.test(c[2])),definition:item};
      table.columns.push(column);
      if(/\bPRIMARY\s+KEY\b/i.test(c[2]))table.pk.push(c[1]);
      if(/\bUNIQUE\b/i.test(c[2]))table.unique.push([c[1]]);
      const fk=c[2].match(/REFERENCES\s+(\w+)\.(\w+)\s*\(([^)]+)\)/i);
      if(fk)fks.push({name:`${table.name}_${c[1]}_fkey`,from:table.id,columns:[c[1]],to:`${namespace(service)}.${fk[2]}`,targetColumns:cols(fk[3]),sql:item});
    }
    for(const col of table.columns)if(table.pk.includes(col.name))col.nullable=false;
    tables.push(table);pattern.lastIndex=close+1;
  }
  const alter=/ALTER\s+TABLE\s+\w+\.(\w+)\s+([\s\S]*?);/gi;
  for(let a;(a=alter.exec(normalized));){
    const add=/ADD\s+CONSTRAINT\s+(\w+)\s+FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+\w+\.(\w+)\s*\(([^)]+)\)[^,;]*/gi;
    let n=0;for(let f;(f=add.exec(a[2]));){n++;fks.push({name:f[1],from:`${namespace(service)}.${a[1]}`,columns:cols(f[2]),to:`${namespace(service)}.${f[3]}`,targetColumns:cols(f[4]),sql:f[0]});}
    if(!n)throw Error(`Unsupported ALTER requires parser update: ${a[0]}`);
  }
  const index=/CREATE\s+(UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\s+ON\s+\w+\.(\w+)([\s\S]*?);/gi;
  for(let m;(m=index.exec(normalized));){const t=tables.find(x=>x.name===m[3]);if(!t)throw Error(`Index table ${m[3]}`);t.indexes.push({name:m[2],unique:!!m[1],partial:/\bWHERE\b/i.test(m[4]),sql:m[0]});const raw=m[4].trim();if(m[1]&&!/\bWHERE\b/i.test(raw)){const open=raw.indexOf('('),end=closeParen(raw,open);const key=cols(raw.slice(open+1,end));if(key.every(k=>t.columns.some(c=>c.name===k)))t.unique.push(key);}}
  return {tables,fks};
}
export function readCurrent(repo){
  const model={tables:[],fks:[],sources:[]};
  for(const service of services){
    const dir=path.join(repo,service,'src/main/resources/db/migration');
    const files=fs.readdirSync(dir).filter(f=>/^V\d+.*\.sql$/.test(f)).sort((a,b)=>Number(a.match(/^V(\d+)/)[1])-Number(b.match(/^V(\d+)/)[1]));
    let sql='';for(const name of files){const relative=`${service}/src/main/resources/db/migration/${name}`,text=fs.readFileSync(path.join(dir,name),'utf8');sql+=text+'\n';model.sources.push({path:relative,sha256:crypto.createHash('sha256').update(text).digest('hex')});}
    const parsed=parseSql(sql,service);model.tables.push(...parsed.tables);model.fks.push(...parsed.fks);
  }
  validateModel(model);return model;
}
export function validateModel(model){
  const ids=new Set();for(const t of model.tables){if(ids.has(t.id))throw Error(`Duplicate table ${t.id}`);ids.add(t.id);if(!t.pk.length)throw Error(`Missing PK ${t.id}`);const c=new Set(t.columns.map(c=>c.name));if(c.size!==t.columns.length)throw Error(`Duplicate columns ${t.id}`);for(const key of [t.pk,...t.unique])for(const name of key)if(!c.has(name))throw Error(`Missing key column ${t.id}.${name}`);}
  const names=new Set();for(const fk of model.fks){const key=`${fk.from}:${fk.name}`;if(names.has(key))throw Error(`Duplicate FK ${key}`);names.add(key);const a=model.tables.find(x=>x.id===fk.from),b=model.tables.find(x=>x.id===fk.to);if(!a||!b)throw Error(`Missing FK table ${key}`);if(a.service!==b.service)throw Error(`Cross-service physical FK ${key}`);if(fk.columns.length!==fk.targetColumns.length)throw Error(`FK arity ${key}`);for(const [t,c] of [[a,fk.columns],[b,fk.targetColumns]])if(!c.every(k=>t.columns.some(x=>x.name===k)))throw Error(`Missing FK column ${key}`);if(![b.pk,...b.unique].some(k=>sameSet(k,fk.targetColumns)))throw Error(`FK target not unique ${key}`);}
}
const sameSet=(a,b)=>a.length===b.length&&a.every(v=>b.includes(v));
export function cardinality(model,fk){const t=model.tables.find(x=>x.id===fk.from);return {parentOptional:fk.columns.some(k=>t.columns.find(c=>c.name===k).nullable),childOne:[t.pk,...t.unique].some(k=>k.every(c=>fk.columns.includes(c))),identifying:fk.columns.every(c=>t.pk.includes(c))};}
const quote=s=>String(s).replaceAll('\\','\\\\').replaceAll("'","\\'").replaceAll('\n',' ');
export function dbml(model,service=null){
  const tables=model.tables.filter(t=>!service||t.service===service),ids=new Set(tables.map(t=>t.id));
  const lines=["Project marketplace {", "  database_type: 'PostgreSQL'", "  Note: 'Documentation namespaces stand for separate service databases. No cross-service physical FK. CURRENT is migration-derived; PLANNED requires future migrations.'",'}',''];
  for(const t of tables){lines.push(`Table ${t.id} {`);for(const c of t.columns){const attrs=[c.nullable?'null':'not null'];if(t.pk.length===1&&t.pk[0]===c.name)attrs.push('pk');if(t.unique.some(k=>k.length===1&&k[0]===c.name))attrs.push('unique');attrs.push(`note: '${quote(c.definition)}'`);lines.push(`  ${c.name} "${c.type}" [${attrs.join(', ')}]`);}const composite=[...(t.pk.length>1?[{cols:t.pk,flag:'pk'}]:[]),...t.unique.filter(k=>k.length>1).map(cols=>({cols,flag:'unique'}))];if(composite.length){lines.push('  indexes {');for(const k of composite)lines.push(`    (${k.cols.join(', ')}) [${k.flag}]`);lines.push('  }');}lines.push('}','');}
  for(const fk of model.fks.filter(f=>ids.has(f.from)&&ids.has(f.to))){const c=cardinality(model,fk);const side=(id,list)=>`${id}.${list.length===1?list[0]:`(${list.join(', ')})`}`;lines.push(`Ref ${namespace(tables.find(t=>t.id===fk.from).service)}_${fk.name}: ${side(fk.from,fk.columns)} ${c.childOne?'-':'>'} ${side(fk.to,fk.targetColumns)}`);}
  return lines.join('\n')+'\n';
}
const camel=id=>id.replace(/[^a-zA-Z0-9]+([a-zA-Z0-9])/g,(_,c)=>c.toUpperCase());
export function mermaid(model,tableIds){
  const tables=model.tables.filter(t=>tableIds.includes(t.id)),ids=new Set(tableIds),lines=['erDiagram','    direction LR'];
  for(const t of tables){lines.push(`    ${camel(t.id)}["${t.id}"] {`);const fkCols=new Set(model.fks.filter(f=>f.from===t.id).flatMap(f=>f.columns));const important=t.columns.filter(c=>t.pk.includes(c.name)||fkCols.has(c.name));const selected=[...important,...t.columns.filter(c=>!important.includes(c))].slice(0,10);for(const c of selected){const keys=[...(t.pk.includes(c.name)?['PK']:[]),...(fkCols.has(c.name)?['FK']:[]),...(t.unique.some(k=>k.length===1&&k[0]===c.name)?['UK']:[])];lines.push(`        ${c.type.replace(/[^a-zA-Z0-9]/g,'_')} ${c.name}${keys.length?' '+keys.join(', '):''} "${c.nullable?'nullable':'required'}"`);}lines.push('    }');}
  for(const f of model.fks.filter(f=>ids.has(f.from)&&ids.has(f.to))){const c=cardinality(model,f);lines.push(`    ${camel(f.to)} ${c.parentOptional?'|o':'||'}${c.identifying?'--':'..'}${c.childOne?'o|':'o{'} ${camel(f.from)} : "${f.columns.join('+')}"`);}
  return lines.join('\n')+'\n';
}
export function groups(model){
  const result=[];
  const commerce=[['identity','회원·판매자',/^(member|shipping_address|seller$|seller_member|seller_document|seller_verification|seller_settlement|seller_invitation|credential|verification_token)/],['catalog','상품·재고',/^(brand|category|product|option_|sku|inventory$|inventory_ledger)/],['order','장바구니·주문',/^(cart|checkout|inventory_reservation|orders$|order_|payment_dispatch)/],['fulfillment','배송·클레임',/^(shipment|purchase_confirmation|claim|exchange)/],['experience','리뷰·알림',/^(review|seller_review_reply|wishlist|notification|upload)/],['operations','운영·금융협력',/.*/]];
  for(const s of services){let remaining=model.tables.filter(t=>t.service===s);for(const [key,label,re] of s==='commerce-service'?commerce:[['core',namespace(s),/.*/]]){const subset=remaining.filter(t=>re.test(t.name));remaining=remaining.filter(t=>!subset.includes(t));for(let i=0;i<subset.length;i+=16)result.push({id:`${namespace(s)}-${key}-${i/16+1}`,service:s,label:`${namespace(s)} / ${label}${subset.length>16?' '+(i/16+1):''}`,tableIds:subset.slice(i,i+16).map(t=>t.id)});}}
  return result;
}
