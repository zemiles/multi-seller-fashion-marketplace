import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const requireTool=createRequire(path.join(repo,'build/docs-tools/package.json'));
const SwaggerParser=requireTool('@apidevtools/swagger-parser');
const {Parser}=requireTool('@dbml/core');
const {default:mermaid}=await import(pathToFileURL(path.join(repo,'build/docs-tools/node_modules/mermaid/dist/mermaid.core.mjs')).href);
let specs=0,diagrams=0;
for(const file of fs.readdirSync(path.join(repo,'contracts')).filter(n=>n.endsWith('.openapi.json'))){
 await SwaggerParser.validate(path.join(repo,'contracts',file),{resolve:{external:false}});specs++;
}
for(const mode of ['current','target'])for(const file of fs.readdirSync(path.join(repo,'docs/erd',mode)).filter(n=>n.endsWith('.dbml'))){
 const source=fs.readFileSync(path.join(repo,'docs/erd',mode,file),'utf8');
 const database=new Parser().parse(source,'dbml');
 if(!database.schemas.length)throw Error(`Empty DBML ${file}`);diagrams++;
}
let mermaids=0;
for(const mode of ['current','target'])for(const file of fs.readdirSync(path.join(repo,'docs/erd',mode)).filter(n=>n.endsWith('.mmd'))){
 await mermaid.parse(fs.readFileSync(path.join(repo,'docs/erd',mode,file),'utf8'));mermaids++;
}
console.log(`PASS: ${specs} OpenAPI 3.1 documents (Swagger Parser), ${diagrams} DBML documents (@dbml/core), ${mermaids} Mermaid ERD pages.`);
