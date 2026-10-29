// Build-time data generator; production contains only native immutable bytes.
// Source: Qwen Code0.24.5 Apache-2.0 BuiltinAgentRegistry,
// chunk-SYZPPX3O.js64642..65000. No source JavaScript runs in the application.
import fs from 'node:fs';
const agents=JSON.parse(fs.readFileSync(new URL('../data/agents/qwen-0.24.5-builtins.json',import.meta.url),'utf8'));
let out='# Generated from pinned Qwen Code0.24.5 builtin definitions (Apache-2.0).\n.section .rodata\n';
function data(label,value){const bytes=[...Buffer.from(value+'\0')];out+=label+':\n';for(let i=0;i<bytes.length;i+=32)out+=' .byte '+bytes.slice(i,i+32).join(',')+'\n';}
agents.forEach((a,i)=>{data('.Mb_name_'+i,a.name);data('.Mb_desc_'+i,a.description);data('.Mb_value_'+i,'<builtin:'+a.name+'>');data('.Mb_prompt_'+i,a.systemPrompt);data('.Mb_detail_'+i,JSON.stringify(a,null,2));});
for(const field of ['name','desc','value','prompt','detail'])out+='.Mb_'+field+'_table: .quad '+agents.map((_,i)=>'.Mb_'+field+'_'+i).join(',')+'\n';
fs.writeFileSync(new URL('../src/ui_agents_builtin.inc',import.meta.url),out);
