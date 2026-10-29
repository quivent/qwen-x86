"""Native Mermaid previews against original0.24.5 pure renderer goldens.
The golden function was executed only during development; application uses ASM.
"""
import ctypes as C
import json
import concurrent.futures
import random
import time
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SGR=re.compile(rb'\x1b\[[0-9;]*m')
GOLDENS=json.loads('[{"source": "flowchart LR\\nA[Start] --> B[End]", "width": 60, "result": {"title": "Mermaid flowchart (LR)", "lines": ["           ┌───────┐                    ┌──────┐", "           │ Start │───────────────────▶│ End  │", "           └───────┘                    └──────┘", ""]}}, {"source": "flowchart TD\\nA[Start] --> B[Middle] --> C[End]", "width": 40, "result": {"title": "Mermaid flowchart (TD)", "lines": ["               ┌───────┐", "               │ Start │", "               └───────┘", "                   │", "                   │", "                   │", "                   ▼", "               ┌────────┐", "               │ Middle │", "               └────────┘", "                    │", "                    │", "                    │", "                    ▼", "                ┌──────┐", "                │ End  │", "                └──────┘", ""]}}, {"source": "flowchart TD\\nA[Start] --> B{Valid?}\\nB -->|yes| C[Done]\\nB -->|no| D[Retry]", "width": 60, "result": {"title": "Mermaid flowchart (TD)", "lines": ["                         ┌───────┐", "                         │ Start │", "                         └───────┘", "                             │", "                             │", "                             │", "                             ▼", "                         ╱────────╲", "                         ◇ Valid? ◇", "                         ╲────────╱", "                              │", "                       ┌──────┴─────┐", "                     [no]         [yes]", "                       ▼            ▼", "                   ┌───────┐    ┌──────┐", "                   │ Retry │    │ Done │", "                   └───────┘    └──────┘", ""]}}, {"source": "sequenceDiagram\\nparticipant A as Alice\\nparticipant B as Bob\\nA->>B: Hello\\nB-->>A: Done", "width": 60, "result": {"title": "Mermaid sequence diagram", "lines": ["Participants: Alice | Bob", "", "Alice → Bob: Hello", "Bob ⇢ Alice: Done"]}}, {"source": "classDiagram\\nclass Animal {\\n+int age\\n+speak()\\n}\\nAnimal <|-- Dog\\nDog: +bark()", "width": 60, "result": {"title": "Mermaid class diagram", "lines": ["Classes: Animal | Dog", "", "Relationships:", "Animal <|-- Dog", "", "Members:", "Animal: +int age", "Animal: +speak()", "Dog: +bark()"]}}, {"source": "unsupportedDiagram\\nA magic B", "width": 50, "result": {"title": "Mermaid source (unsupportedDiagram)", "lines": ["```mermaid", "unsupportedDiagram", "A magic B", "```"], "warning": "Visual preview is not available; showing source so it remains readable and copyable."}}]')
class MermaidTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory(prefix='qwen-x86-mermaid-');out=Path(cls.temp.name);objects=[]
  for name in ['ui_mermaid','ui_markdown','ui_input','runtime','json']:
   obj=out/(name+'.o');objects.append(str(obj))
   subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(obj),str(ROOT/'src'/(name+'.s'))],check=True)
  cls.shared=out/'mermaid.so';subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(cls.shared),*objects],check=True)
  cls.lib=C.CDLL(str(cls.shared));cls.lib.ui_render_mermaid.argtypes=[C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_size_t,C.c_size_t,C.c_size_t];cls.lib.ui_render_mermaid.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.temp.cleanup()
 def render(self,source,width=60,theme=0,index=0,cap=262144):
  raw=source.encode() if isinstance(source,str) else source
  out=C.create_string_buffer(cap+32);C.memset(out,0xa5,len(out))
  n=self.lib.ui_render_mermaid(raw,len(raw),C.byref(out,16),cap,width+1,theme,index)
  self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[cap+16:],b'\xa5'*16)
  self.assertGreaterEqual(n,0)
  data=out.raw[16:16+n];plain=SGR.sub(b'',data);self.assertNotIn(b'\x1b',plain)
  return data.decode(),plain.decode()
 def test_capacity_invalid_input_and_control_sanitization(self):
  source=b'flowchart LR\nA[Hello\x1b]52;c;SECRET\x07 world]-->B[Done]'
  _,plain=self.render(source);self.assertIn('Hello world',plain);self.assertNotIn('SECRET',plain)
  for cap in [0,1,8,32,128]:
   out=C.create_string_buffer(cap+32);C.memset(out,0xa5,len(out))
   n=self.lib.ui_render_mermaid(source,len(source),C.byref(out,16),cap,61,0,1)
   self.assertEqual(n,-28);self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[16+cap:],b'\xa5'*16)
  out=C.create_string_buffer(100)
  self.assertEqual(self.lib.ui_render_mermaid(source,131073,out,100,61,0,1),-22)
 def test_unicode_concurrency_themes_and_bounded_malformed(self):
  source='flowchart LR\nA[世界 👩🏽\u200d💻] --> B[Done]'
  expected=[self.render(source,60,i,3)[0] for i in range(16)]
  self.assertGreater(len(set(expected)),8)
  self.assertEqual(self.render(source,60,1<<32,3)[0],expected[0])
  self.assertNotIn('38;2;',self.render(source,60,16,3)[0])
  self.assertIn('世界',SGR.sub(b'',expected[0].encode()).decode())
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
   results=list(pool.map(lambda i:self.render(source,60,i%16,3)[0],range(64)))
  for i,value in enumerate(results):self.assertEqual(value,expected[i%16])
  rng=random.Random(145);start=time.monotonic()
  for _ in range(150):
   raw='flowchart TD\n'+''.join(rng.choice('AB[]{}()|<>-=;: \n世界') for _ in range(rng.randrange(0,600)))
   self.render(raw,width=rng.randrange(24,90))
  self.assertLess(time.monotonic()-start,5)
 def test_explicit_unsupported_source_remains_copyable(self):
  _,plain=self.render('unsupportedDiagram\n A magic B',index=7)
  self.assertIn('/copy mermaid 7',plain);self.assertIn('Visual preview is not available',plain)
  self.assertIn('A magic B',plain)
 def test_all_new_families_no_runtime_and_source_budget(self):
  fixtures=json.loads((ROOT/'tests/fixtures/ui_mermaid_extended.json').read_text())
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
   result=list(pool.map(lambda f:self.render(f['source'],80,2,4)[1],fixtures*4))
  for text in result:self.assertNotIn('Visual preview is not available',text);self.assertIn('/copy mermaid 4',text)
  _,plain=self.render('journey\n'+'Step: 5: User\n'*100,width=80)
  self.assertEqual(plain.count('• Step:'),80);self.assertIn('Preview limited to 80 source lines.',plain)
  for source,warning in [('pie','Pie preview found no previewable slices'),('stateDiagram-v2','State preview found no previewable states'),('erDiagram','ER preview found no previewable entities')]:
   _,plain=self.render(source);self.assertIn(warning,plain)
  _,plain=self.render('pie\n"A": 1\ntitle Late title\n"B": 2',80)
  self.assertLess(plain.index('title Late title'),plain.index('A: 1'))
  _,plain=self.render('mindmap\n  '+'世界'*1000,width=100);plain.encode().decode('utf8')
 def test_original_supported_and_fallback_goldens(self):
  for golden in GOLDENS + json.loads((ROOT/'tests/fixtures/ui_mermaid_extended.json').read_text()):
   with self.subTest(source=golden['source']):
    ansi,plain=self.render(golden['source'],golden['width'])
    lines=[line[1:] if line.startswith(' ') else line for line in plain.splitlines()]
    expected=golden['result'];want=[expected['title'],*expected['lines']]
    if expected.get('warning'):want.append(expected['warning'])
    self.assertEqual(lines,want)
if __name__=='__main__':unittest.main()
