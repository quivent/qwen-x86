#!/usr/bin/env python3
"""Development-only: pin ICU CJK dictionary from the exact reference Node ELF.
No generated executable code or runtime Node/ICU dependency. Unicode License v3.
"""
import argparse,hashlib,json,pathlib,struct,subprocess,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--node',default='/home/oscillihue/.local/lib/qwen-code/node/bin/node');args=p.parse_args();node=pathlib.Path(args.node)
versions=json.loads(subprocess.check_output([str(node),'-p','JSON.stringify(process.versions)']))
b=node.read_bytes();assert b[:6]==b'\x7fELF\x02\x01'
syms=subprocess.check_output(['nm','-D',str(node)],text=True).splitlines();sym=next(x for x in syms if x.endswith(' icudt78_dat'));addr=int(sym.split()[0],16)
phoff=struct.unpack_from('<Q',b,32)[0];ents,n=struct.unpack_from('<HH',b,54)
for i in range(n):
 q=phoff+i*ents;typ=struct.unpack_from('<I',b,q)[0];off,va=struct.unpack_from('<QQ',b,q+8);size=struct.unpack_from('<Q',b,q+32)[0]
 if typ==1 and va<=addr<va+size:start=off+addr-va;break
else:raise ValueError('data symbol outside load segments')
h=struct.unpack_from('<H',b,start)[0];assert b[start+12:start+16]==b'CmnD';base=start+h;count=struct.unpack_from('<I',b,base)[0]
entries={}
for i in range(count):
 no,do=struct.unpack_from('<II',b,base+4+i*8);name=b[base+no:b.index(0,base+no)].decode()
 if '/brkitr/' in name and name.endswith('dict.dict'):
  end=struct.unpack_from('<II',b,base+4+(i+1)*8)[1];entries[name.rsplit('/',1)[1]]=(name,b[base+do:base+end])
if 'cjdict.dict' not in entries:raise ValueError('missing CJK dictionary')
name,data=entries['cjdict.dict']
complex_manifest=[]
for label in ['thai','lao','burmese','khmer']:
 en,ed=entries[label+'dict.dict'];eh=struct.unpack_from('<H',ed)[0];ix=struct.unpack_from('<8I',ed,eh);assert ix[4]&7==0
 et=ed[eh+ix[0]:eh+ix[1]];(ROOT/('src/ui_'+label+'_icu78.bin')).write_bytes(et)
 complex_manifest.append({'script':label,'entry':en,'bytes':len(et),'transform':ix[5],'sha256':hashlib.sha256(et).hexdigest()})
h=struct.unpack_from('<H',data)[0];indexes=struct.unpack_from('<8I',data,h);assert data[12:16]==b'Dict' and indexes[4]&7==1
trie=data[h+indexes[0]:h+indexes[1]];(ROOT/'src/ui_cjk_icu78.bin').write_bytes(trie)
# Exact reference ICU78/Unicode17 NFKC data for characters handled by CjkBreakEngine.
js=r'''const out=[];const cj=/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u;for(let cp=0;cp<0x110000;cp++){let s=String.fromCodePoint(cp);if(cj.test(s)||cp===0x30fc||(cp>=0xff66&&cp<=0xff9f)){let n=s.normalize('NFKC');if(n!==s)out.push([cp,Array.from(n,x=>x.codePointAt(0))]);}}const pairs=[];for(let a=0x3040;a<=0x30ff;a++){for(let m of [0x3099,0x309a]){let n=String.fromCodePoint(a,m).normalize('NFC');if(Array.from(n).length===1)pairs.push([a,m,n.codePointAt(0)]);}}console.log(JSON.stringify({out,pairs}));'''
norm=json.loads(subprocess.check_output([str(node),'-e',js]));lines=['# Generated ICU78.2/Unicode17 CJK NFKC data; Unicode License v3.','.section .rodata','.balign 4','.Ldict_nfkc:'];pool=[]
for cp,seq in norm['out']:lines.append(f' .long {cp},{len(pool)},{len(seq)}');pool.extend(seq)
lines+= [f'.equ DICT_NFKC_COUNT,{len(norm["out"])}','.Ldict_nfkc_pool:']+[' .long '+','.join(map(str,pool[i:i+16])) for i in range(0,len(pool),16)]
lines+= ['.Ldict_kana_compose:']+[' .long '+','.join(map(str,row)) for row in norm['pairs']]+[f'.equ DICT_KANA_COMPOSE_COUNT,{len(norm["pairs"])}']
(ROOT/'src/ui_dictionary.inc').write_text('\n'.join(lines)+'\n')
d=ROOT/'docs/third-party';d.mkdir(parents=True,exist_ok=True)
manifest={'reference_node':versions,'complex_dictionaries':complex_manifest,'source_symbol':'icudt78_dat','dictionary_entry':name,'trie_bytes':len(trie),'trie_sha256':hashlib.sha256(trie).hexdigest(),'normalization_entries':len(norm['out']),'kana_compositions':len(norm['pairs']),'source':'https://github.com/unicode-org/icu/tree/release-78.2/icu4c/source/common','license':'https://www.unicode.org/license.txt'}
(d/'ui-dictionary-provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
license_path=d/'unicode-license.txt'
if not license_path.exists():license_path.write_bytes(urllib.request.urlopen('https://www.unicode.org/license.txt').read())
print(json.dumps(manifest,indent=2))
