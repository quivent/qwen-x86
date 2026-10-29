"""Native formatter security/layout fixtures; Python only inspects assembly output.
No Node, third-party Markdown engine, terminal renderer or library at runtime."""
import concurrent.futures
import ctypes
import os
import mmap
import json
from pathlib import Path
import random
import re
import subprocess
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
SGR=re.compile(rb'\x1b\[[0-9;]*m')

class MarkdownTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory(prefix='qwen-x86-markdown-');cls.root=Path(cls.tmp.name)
  objects=[]
  for name in ['ui_markdown','ui_mermaid','ui_input','runtime','json']:
   obj=cls.root/(name+'.o');objects.append(str(obj))
   subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(obj),str(ROOT/'src'/(name+'.s'))],check=True)
  cls.shared=cls.root/'markdown.so'
  subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(cls.shared),*objects],check=True)
  cls.lib=ctypes.CDLL(str(cls.shared))
  cls.lib.ui_sanitize.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.ui_format_markdown.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_size_t]
  cls.lib.ui_format_markdown_ex.argtypes=cls.lib.ui_format_markdown.argtypes+[ctypes.c_size_t]
  cls.lib.ui_format_markdown_ex.restype=ctypes.c_int64
  cls.lib.ui_format_numbered_preview.argtypes=cls.lib.ui_format_markdown_ex.argtypes+[ctypes.c_char_p]
  cls.lib.ui_format_numbered_preview.restype=ctypes.c_int64
  cls.lib.ui_format_markdown_source.argtypes=cls.lib.ui_format_markdown_ex.argtypes+[ctypes.c_size_t]
  cls.lib.ui_format_markdown_source.restype=ctypes.c_int64
  cls.lib.ui_format_markdown_full.argtypes=cls.lib.ui_format_markdown_source.argtypes+[ctypes.c_size_t]
  cls.lib.ui_format_markdown_full.restype=ctypes.c_int64
  cls.lib.ui_mermaid_count.argtypes=[ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.ui_mermaid_count.restype=ctypes.c_int64
  cls.lib.ui_extract_mermaid.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.ui_extract_mermaid.restype=ctypes.c_int64
  cls.lib.ui_math_count.argtypes=[ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.ui_math_count.restype=ctypes.c_int64
  cls.lib.ui_extract_math.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.ui_extract_math.restype=ctypes.c_int64
  cls.lib.ui_text_width.argtypes=[ctypes.c_void_p,ctypes.c_size_t]
  for name in ['ui_sanitize','ui_format_markdown','ui_text_width']:getattr(cls.lib,name).restype=ctypes.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def call(self,raw,cap=262144,width=80,sanitize=False,theme=None):
  if isinstance(raw,str):raw=raw.encode()
  out=ctypes.create_string_buffer(cap+32);ctypes.memset(out,0xa5,len(out))
  args=[raw,len(raw),ctypes.byref(out,16),cap]
  if not sanitize:args.append(width)
  if theme is not None and not sanitize:args.append(theme)
  n=getattr(self.lib,'ui_sanitize' if sanitize else 'ui_format_markdown_ex' if theme is not None else 'ui_format_markdown')(*args)
  self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[16+cap:],b'\xa5'*16)
  return n,out.raw[16:16+max(n,0)]
 def render(self,raw,width=80):
  n,out=self.call(raw,width=width);self.assertGreaterEqual(n,0)
  self.assertEqual(n,len(out));self.assertNotIn(b'\x1b',SGR.sub(b'',out))
  out.decode('utf-8');return out
 def plain(self,raw,width=80):return SGR.sub(b'',self.render(raw,width)).decode()
 def test_mermaid_rendering_source_indices_and_pending(self):
  raw=b'Before\n```mermaid\nflowchart LR\nA[Start] --> B[End]\n```\nAfter\n$$\nx^2\n$$\n'
  out=ctypes.create_string_buffer(65536)
  n=self.lib.ui_format_markdown_full(raw,len(raw),out,len(out),60,4,7,11)
  self.assertGreater(n,0);plain=SGR.sub(b'',out.raw[:n]).decode()
  self.assertIn('Mermaid flowchart (LR) · source: /copy mermaid 12',plain)
  self.assertIn('LaTeX block · source: /copy latex 8',plain)
  self.assertIn('Start',plain);self.assertIn('▶',plain);self.assertIn('After',plain)
  self.assertNotIn('A[Start]',plain)
  mixed=b'```python\n```mermaid\nignored\n```\n```mermaid\nsequenceDiagram\nA->>B: hi\n```\n~~~mermaid\nflowchart TD\nA-->B'
  self.assertEqual(self.lib.ui_mermaid_count(mixed,len(mixed)),2)
  for idx,want in [(1,b'sequenceDiagram\nA->>B: hi\n'),(2,b'flowchart TD\nA-->B')]:
   n=self.lib.ui_extract_mermaid(mixed,len(mixed),idx,out,len(out));self.assertEqual(out.raw[:n],want)
  self.assertEqual(self.lib.ui_extract_mermaid(mixed,len(mixed),3,out,len(out)),-1)
  self.assertEqual(self.lib.ui_extract_mermaid(mixed,len(mixed),1,out,1),-28)
  pending=self.plain('```mermaid\nflowchart TD\nA[Last character]')
  self.assertIn('Mermaid diagram is being written...',pending);self.assertIn('A[Last character]',pending)
 def test_rich_capture_mermaid_inner_width_and_table_margin(self):
  raw='Flow\n\n```mermaid\nflowchart LR\nA[Read] --> B[Write] --> C[Done]\n```\n\nUI_RICH_DONE'
  plain=self.plain(raw,width=96)
  top=next(line for line in plain.splitlines() if '┌──────┐' in line)
  reference=(ROOT/'docs/ui-captures/reference/rich-mermaid.txt').read_text()
  reference_top=next(line for line in reference.splitlines() if '┌──────┐' in line)
  # Renderer supplies the four-cell assistant prefix; formatter supplies diagram1.
  self.assertEqual('    '+top,reference_top)
  raw='Files\n\n| File | Result |\n| --- | --- |\n| main.s | Built |\n| λ-song.txt | Unicode 世界 |\n\nUI_RICH_DONE'
  plain=self.plain(raw,width=96)
  bottom=next(line for line in plain.splitlines() if line.startswith('└'))
  self.assertIn(bottom+'\n\nUI_RICH_DONE',plain)
  self.assertNotIn(bottom+'\n\n\nUI_RICH_DONE',plain)
 def test_complete_theme_catalogue_uses_private_palettes(self):
  values=[self.call('`code` **bold**',theme=i)[1] for i in range(16)]
  self.assertGreater(len(set(values)),8)
  self.assertEqual(values[15],values[0])
  no_color=self.call('`code` **bold**\n```python\nreturn \"hi\"\n```',theme=16)[1]
  self.assertNotIn(b'38;2;',no_color);self.assertIn(b'\x1b[1m',no_color)
  self.assertEqual(self.call('`code` **bold**',theme=999)[1],values[0])
  self.assertEqual(self.call('`code` **bold**',theme=1<<32)[1],values[0])
 def test_plain_headings_inline_and_unclosed_constructs(self):
  self.assertEqual(self.plain('# Heading\n**bold** *italic* ~~gone~~ `code`\n'),'Heading\nbold italic gone code\n')
  out=self.render('**bold** *italic* ~~gone~~ `code`')
  for code in [b'\x1b[1m',b'\x1b[3m',b'\x1b[9m',b'\x1b[38;2;173;216;230m']:self.assertIn(code,out)
  for raw in ['**partial','*partial','`partial','~~partial','[partial](url','```python\nprint("partial']:
   out=self.render(raw);self.assertTrue(out.endswith(b'\x1b[0m') or out.endswith(b'\n'))
 def test_lists_quotes_rules_and_links(self):
  self.assertEqual(self.plain('- first\n  + nested\n1. ordered\n> quoted\n'),' - first\n   + nested\n 1. ordered\n │ quoted\n')
  self.assertEqual(self.plain('[Qwen](https://example.test)'),'Qwen (https://example.test)')
  self.assertEqual(self.plain('---\n',width=12),'---\n')
 def test_fenced_code_highlighting_and_line_gutter(self):
  source='```python\ndef example(x):\n    return "hi" # comment\nvalue = 42\n```\n'
  out=self.render(source);plain=SGR.sub(b'',out).decode()
  self.assertEqual(plain,' 1 def example(x):\n 2     return "hi" # comment\n 3 value = 42\n')
  for code in [b'\x1b[38;2;255;215;0m',b'\x1b[38;2;170;217;76m',b'\x1b[38;2;191;189;182m']:self.assertIn(code,out)
  self.assertNotIn('```',plain)
 def test_unicode_grapheme_wrapping(self):
  for raw in ['世界世界世界','e\u0301'*12,'👩🏽\u200d💻'*6,'🇱🇹'*6,'a\u0301世界👩🏽\u200d💻🇱🇹'*3]:
   plain=self.plain(raw,width=6)
   self.assertEqual(plain.replace('\n',''),raw)
   for line in plain.split('\n'):
    value=line.encode();self.assertLessEqual(self.lib.ui_text_width(value,len(value)),6)
   for line in plain.split('\n')[1:]:self.assertFalse(line.startswith('\u0301'))
 def test_table_aligns_cells_and_preserves_narrow_content(self):
  raw='| Name | Value |\n| :--- | ---: |\n| 世界 | 2 |\n| long value here | 99 |\n'
  plain=self.plain(raw,width=40)
  lines=[line for line in plain.splitlines() if line];self.assertEqual(len(lines),7)
  self.assertTrue(lines[0].startswith('┌'));self.assertTrue(lines[-1].endswith('┘'))
  widths=[]
  for line in lines:
   b=line.encode();widths.append(self.lib.ui_text_width(b,len(b)))
  self.assertEqual(len(set(widths)),1);self.assertLessEqual(widths[0],40)
  self.assertIn('世界',plain);self.assertIn('long value here',plain);self.assertNotIn(':---',plain)
  narrow=self.plain(raw,width=24)
  self.assertIn('│ long     │       │',narrow)
  self.assertIn('│ value    │    99 │',narrow)
  self.assertIn('│ here     │       │',narrow)
 def test_source_table_width_distribution_wrapping_and_vertical_threshold(self):
  raw='| Name | Value |\n| :--- | ---: |\n| 世界 | 2 |\n| long value here | 99 |\n'
  plain=self.plain(raw,width=24)
  self.assertIn('┌──────────┬───────┐',plain)
  for line in plain.splitlines():
   if line:self.assertEqual(self.lib.ui_text_width(line.encode(),len(line.encode())),20)
  # Source vertical-centers short cells and retains styling across word wraps.
  raw='| Name | Value |\n|---|---|\n| **alpha beta gamma delta** | x |\n'
  out=self.render(raw,width=26);plain=SGR.sub(b'',out).decode()
  self.assertNotIn('**',plain);self.assertIn('│ alpha beta │       │',plain);self.assertIn('│ gamma      │ x     │',plain);self.assertIn('│ delta      │       │',plain)
  raw='| Name | Value |\n|---|---|\n| one two three four five six seven eight nine ten eleven twelve | x |\n'
  plain=self.plain(raw,width=24);self.assertIn('Name: one two',plain);self.assertNotIn('┌',plain)
 def test_controls_csi_osc_dcs_and_invalid_utf8_are_sanitized(self):
  raw=b'hello\x1b[2J\x1b[31mred\x1b[0m\x00\x03\r\n\x1b]52;c;SECRET\x07end\x1bPPRIVATE\x1b\\!\xc0\xaf\xed\xa0\x80'
  n,out=self.call(raw,sanitize=True);self.assertGreater(n,0)
  self.assertNotIn(b'\x1b',out);self.assertNotIn(b'SECRET',out);self.assertNotIn(b'PRIVATE',out)
  self.assertTrue(out.startswith(b'hellored\nend!'));out.decode()
  n,out=self.call('abc\u202eSECRET\u2066xyz\u009b\tZ',sanitize=True)
  self.assertEqual(out.decode(),'abcSECRETxyz    Z')
 def test_partial_escape_protocols_never_leak(self):
  for escape in [b'\x1b',b'\x1b[',b'\x1b[31',b'\x1b]52;c;never',b'\x1bPnever\x1b']:
   self.assertEqual(self.call(b'safe'+escape,sanitize=True)[1],b'safe')
   self.assertEqual(self.plain(b'safe'+escape),'safe')
 def test_caps_empty_input_and_invalid_width(self):
  for cap in range(0,60):
   n,out=self.call('**bold** 世界',cap=cap)
   if n>=0:self.assertLessEqual(n,cap)
  self.assertEqual(self.call(b'',cap=0),(0,b''))
  self.assertLess(self.call('text',width=3)[0],0)
  self.assertLess(self.call('text',width=4097)[0],0)
  self.assertLess(self.call(b'x'*(1048576+1))[0],0)
  self.assertEqual(self.call('世界',cap=6,sanitize=True),(6,'世界'.encode()))
  self.assertLess(self.call('世界',cap=5,sanitize=True)[0],0)
 def test_one_megabyte_body_and_reentrant_calls(self):
  source=b'x'*1048576
  n,out=self.call(source,cap=1500000,width=80)
  self.assertGreater(n,1048576);self.assertEqual(SGR.sub(b'',out).replace(b'\n',b''),source)
  values=['# title\n**bold** 世界\n','```js\nconst x = 42;\n```','| a | b |\n|---|---|\n|1|2|']*10
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
   rendered=list(pool.map(self.render,values))
  self.assertEqual(rendered[0],rendered[3])
 def test_bounded_mutated_input_never_emits_untrusted_controls(self):
  rng=random.Random(7)
  for _ in range(250):
   raw=bytes(rng.randrange(256) for _ in range(rng.randrange(200)))
   n,out=self.call(raw,cap=65536,width=20)
   self.assertGreaterEqual(n,0);out.decode()
   plain=SGR.sub(b'',out)
   self.assertNotIn(b'\x1b',plain)
   self.assertTrue(all(x>=32 or x==10 for x in plain))
 def test_paths_escaped_markers_and_underscore_emphasis(self):
  self.assertEqual(self.plain(r'C:\path\file_name **bold**'),r'C:\path\file_name bold')
  self.assertEqual(self.plain(r'\*literal\* _italic_'),'*literal* italic')
  self.assertEqual(self.plain('_ not a bullet'),'_ not a bullet')
  self.assertEqual(self.plain('2 * 3 ** ~~ _'),'2 * 3 ** ~~ _')
 def test_table_right_center_alignment_and_invalid_separator(self):
  raw='| left | right | center |\n|---|---:|:---:|\n| a | b | c |\n'
  text=self.plain(raw)
  self.assertIn('│ a    │     b │   c    │',text)
  self.assertIn('--:-',self.plain('| a | b |\n|--:-|---|\n'))
  self.assertIn('│',self.plain('| a | b |\n|--:|---|\n'))
 def test_adversarial_link_search_is_bounded(self):
  source='['*20000+']x'
  started=time.monotonic();text=self.plain(source)
  self.assertLess(time.monotonic()-started,2)
  self.assertEqual(text.replace('\n',''),source)
 def test_each_streaming_prefix_has_only_trusted_sgr(self):
  source='# Head\n**bold** [label](https://example.test)\n```python\nreturn "text"\n```\n'
  for end in range(len(source)+1):self.render(source[:end])
 def test_unterminated_input_at_guard_page_boundary(self):
  libc=ctypes.CDLL(None)
  libc.mprotect.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_int]
  page=mmap.PAGESIZE
  mapping=mmap.mmap(-1,page*2,prot=mmap.PROT_READ|mmap.PROT_WRITE)
  address=ctypes.addressof(ctypes.c_char.from_buffer(mapping))
  self.assertEqual(libc.mprotect(address+page,page,0),0)
  try:
   for raw in [b'**bold**',b'[incomplete',b'```py\nreturn 42',b'\xf0\x9f',b'\x1b]incomplete']:
    ctypes.memmove(address+page-len(raw),raw,len(raw))
    out=ctypes.create_string_buffer(4096)
    n=self.lib.ui_sanitize(address+page-len(raw),len(raw),out,len(out))
    self.assertGreaterEqual(n,0)
    n=self.lib.ui_format_markdown(address+page-len(raw),len(raw),out,len(out),20)
    self.assertGreaterEqual(n,0)
   self.assertEqual(self.lib.ui_format_markdown(None,0,address+page,0,80),0)
   self.assertLess(self.lib.ui_format_markdown(b'text',4,address+page,0,80),0)
  finally:
   libc.mprotect(address+page,page,mmap.PROT_READ|mmap.PROT_WRITE)
   mapping.close()
 def test_themes_are_private_and_source_exact(self):
  raw='`inline`\n```python\ndef f(): return "string"\n```\n'
  expected=[(b'173;216;230',b'170;217;76'),(b'139;233;253',b'255;247;131'),(b'121;184;255',b'158;203;255'),(b'0;134;179',b'221;17;68')]
  rendered=[]
  for theme,(inline,string) in enumerate(expected):
   n,out=self.call(raw,theme=theme);self.assertGreater(n,0)
   self.assertIn(inline,out);self.assertIn(string,out);rendered.append(out)
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
   results=list(pool.map(lambda theme:self.call(raw,theme=theme)[1],list(range(4))*8))
  for index,out in enumerate(results):self.assertEqual(out,rendered[index%4])
  self.assertEqual(self.call(raw)[1],rendered[0])
 def test_upstream_default_markdown_snapshot(self):
  # Actual upstream0.24.5 Ink capture, not a palette invented for this port.
  raw='## Result\n\nUI_CASE_MARKDOWN_DONE\n\nThis is **bold**, *italic*, and `inline code`.\n\n```python\nprint("Hello, world")\n```\n\n- First item\n- Second item\n\n> A quoted line\n'
  out=self.render(raw)
  expected='Result\n\nUI_CASE_MARKDOWN_DONE\n\nThis is bold, italic, and inline code.\n\n 1 print("Hello, world")\n\n - First item\n - Second item\n\n │ A quoted line\n'
  self.assertEqual(SGR.sub(b'',out).decode(),expected)
  self.assertIn(b'\x1b[38;2;173;216;230minline code',out)
  self.assertIn(b'\x1b[38;2;191;189;182mprint',out)
  self.assertIn(b'\x1b[38;2;170;217;76m"Hello, world"',out)
  fixture=ROOT/'docs/ui-captures/reference/markdown.json'
  if fixture.exists():
   rows=json.loads(fixture.read_text())['cells']
   found={}
   for row in rows:
    text=''.join(cell['text'] for cell in row)
    for word in ['Result','inline code','Hello, world']:
     at=text.find(word)
     if at>=0:found[word]=row[at]
   self.assertTrue(found['Result']['bold'])
   self.assertEqual(found['inline code']['fg'],'add8e6')
   self.assertEqual(found['Hello, world']['fg'],'aad94c')
 def test_word_wrapping_hanging_indent_and_tasks(self):
  wrapped=self.plain('alpha beta gamma delta',width=12)
  self.assertEqual([line.strip() for line in wrapped.splitlines()],['alpha beta','gamma delta'])
  self.assertEqual(self.plain('- [x] done\n- [ ] todo\n'),' ✓ done\n ○ todo\n')
  wrapped=self.plain('- alpha beta gamma delta',width=14)
  self.assertEqual([line.strip() for line in wrapped.splitlines()],['- alpha beta','gamma delta'])
  self.assertTrue(wrapped.splitlines()[1].startswith('   '))
 def test_inline_tables_stream_rows_and_twenty_columns(self):
  raw='| **name** | `value` |\n|---|---|\n|*foo*|**bar**|\n'
  out=self.render(raw);plain=SGR.sub(b'',out).decode()
  self.assertIn('│ name │ value │',plain);self.assertIn('│ foo  │ bar   │',plain)
  self.assertNotIn('**',plain);self.assertNotIn('`',plain)
  headers=[f'h{i}' for i in range(20)]
  row=lambda cells:'| '+' | '.join(cells)+' |\n'
  raw=row(headers)+row(['---']*20)+''.join(row([f'r{r}c{c}' for c in range(20)]) for r in range(128))
  n,out=self.call(raw,cap=2000000,width=240);self.assertGreater(n,0)
  plain=SGR.sub(b'',out).decode();self.assertEqual(sum(line.startswith('│') for line in plain.splitlines()),129)
  self.assertIn('r127c19',plain);self.assertNotIn('| ---',plain)
  escaped=self.plain('| a | b |\n|---|---|\n| a\\|b | `x|y` |\n')
  self.assertIn('a|b',escaped);self.assertIn('x|y',escaped)
 def test_source_backed_math_and_image_alt(self):
  self.assertEqual(self.plain(r'Inline $x^2 + \alpha_1 \leq \sqrt{x}$ done'),'Inline x² + α₁ ≤ √(x) done')
  raw='$$\n\\frac{a}{b} + \\sqrt{x^2} \\times \\pi\n$$\n'
  self.assertEqual(self.plain(raw),' LaTeX block · source: /copy latex 1\n a/b + √(x²) × π\n')
  self.assertEqual(self.plain('Cost $5 and $ 6'),'Cost $5 and $ 6')
  self.assertEqual(self.plain('![chart](https://example.test/image.png)'),'[Image: chart] (https://example.test/image.png)')
  self.assertEqual(self.plain('![incomplete'),'![incomplete')
 def test_math_recursive_groups_and_malformed_budget(self):
  self.assertEqual(self.plain(r'$\frac{\sqrt{x}}{\frac{a}{b}} + \alpha_{i+1}$'),'√(x)/a/b + αᵢ₊₁')
  source='$$\n'+r'\frac{'*2000+'x\n$$\n'
  started=time.monotonic();out=self.render(source)
  self.assertLess(time.monotonic()-started,2)
  self.assertIn(b'frac{',out)
  for prefix in ['$$\n'+r'\sqrt{x', '$$\n'+r'\frac{a}{',r'$x^{2$']:
   self.render(prefix)
 def test_cumulative_math_labels_and_raw_extraction(self):
  raw=b"```text\n$$\nnot math\n$$\n```\n$$\n\\frac{a}{b}\n$$\ntext\n$$\npartial x^2"
  self.assertEqual(self.lib.ui_math_count(raw,len(raw)),2)
  out=ctypes.create_string_buffer(4096)
  n=self.lib.ui_format_markdown_source(raw,len(raw),out,len(out),80,0,7)
  self.assertGreater(n,0)
  plain=SGR.sub(b'',out.raw[:n])
  self.assertIn(b'/copy latex 8',plain);self.assertIn(b'/copy latex 9',plain)
  n=self.lib.ui_extract_math(raw,len(raw),1,out,len(out))
  self.assertEqual(out.raw[:n],b'\\frac{a}{b}\n')
  n=self.lib.ui_extract_math(raw,len(raw),2,out,len(out))
  self.assertEqual(out.raw[:n],b'partial x^2')
  self.assertEqual(self.lib.ui_extract_math(raw,len(raw),3,out,len(out)),-1)
  self.assertEqual(self.lib.ui_extract_math(raw,len(raw),0,out,len(out)),-22)
  self.assertEqual(self.lib.ui_extract_math(raw,len(raw),1,out,2),-28)
  self.assertEqual(self.lib.ui_math_count(b'',0),0)
  self.assertEqual(self.lib.ui_math_count(None,10),-22)
 def test_numbered_tool_preview_reuses_language_and_source_gutter_colors(self):
  raw=b' 8 def f(x):\n 9     return "hello"\n10 # actual physical line\n'
  out=ctypes.create_string_buffer(65536)
  n=self.lib.ui_format_numbered_preview(raw,len(raw),out,len(out),80,0,b'python')
  self.assertGreater(n,0);data=out.raw[:n];self.assertEqual(SGR.sub(b'',data),raw)
  self.assertIn(b'\x1b[38;2;61;65;73m 8 ',data);self.assertIn(b'\x1b[38;2;255;215;0mdef',data);self.assertIn(b'\x1b[38;2;170;217;76m"hello"',data)
  n=self.lib.ui_format_numbered_preview(raw,len(raw),out,len(out),80,16,b'python');self.assertNotIn(b'38;2;',out.raw[:n])
 def test_source_numeric_bases_exponents_and_json_key_color(self):
  out=self.render('```python\nx = 0xCAFE + 0b101 + 0o77 + 1.5e-3 + 2j\n```')
  for token in [b'0xCAFE',b'0b101',b'0o77',b'1.5e-3',b'2j']:self.assertIn(b'\x1b[38;2;191;189;182m'+token,out)
  # Qwen Dark has no hljs-number or hljs-attr style; those inherit code text.
  out=self.render('```json\n{"key": "value", "n": 42}\n```')
  self.assertIn(b'\x1b[38;2;191;189;182m"key"',out);self.assertIn(b'\x1b[38;2;170;217;76m"value"',out)
 def test_source_language_keyword_profiles_and_comment_boundaries(self):
  python=self.render('```python\nstring = len([1]) # comment\n```');self.assertNotIn(b'\x1b[38;2;255;215;0mstring',python);self.assertIn(b'\x1b[38;2;100;106;113m# comment',python)
  c=self.render('```c\nint x = 1; /* comment */ int y = 2;\n```');self.assertIn(b'\x1b[38;2;100;106;113m/* comment */',c);self.assertEqual(SGR.sub(b'',c),b' 1 int x = 1; /* comment */ int y = 2;\n')
  sql=self.render('```sql\nSELECT x FROM users -- note\n```');self.assertIn(b'\x1b[38;2;255;215;0mSELECT',sql);self.assertIn(b'\x1b[38;2;100;106;113m-- note',sql)
  go=self.render('```go\nfunc main() { println("hi") }\n```');self.assertIn(b'\x1b[38;2;255;215;0mmain',go)
 def test_no_external_runtime_imports(self):
  self.assertEqual(subprocess.check_output(['nm','-u',str(self.shared)],text=True).strip(),'')

if __name__=='__main__':unittest.main()
