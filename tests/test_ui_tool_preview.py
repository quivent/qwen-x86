"""Typed native previews: no tool execution/filesystem reads, no JS helpers.
Reference shape: original0.24.5 ToolInfo/WriteFileInvocation/DiffRenderer."""
import ctypes as C
import json
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
class PreviewTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory(prefix='qwen-x86-preview-');out=Path(cls.tmp.name)
  objects=[]
  for name in ['ui_tool_preview','ui_markdown','ui_mermaid','ui_input','json','runtime']:
   obj=out/(name+'.o');objects.append(str(obj))
   subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(obj),str(ROOT/'src'/(name+'.s'))],check=True)
  cls.shared=out/'preview.so';subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(cls.shared),*objects],check=True)
  cls.lib=C.CDLL(str(cls.shared))
  cls.lib.ui_tool_set_file_context.argtypes=[C.c_void_p,C.c_size_t]
  cls.lib.ui_tool_set_file_context.restype=C.c_int64
  for name in ['ui_tool_preview','ui_tool_describe']:
   fn=getattr(cls.lib,name);fn.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t];fn.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):self.lib.ui_tool_set_file_context(None,0)
 def call(self,name,args,describe=False,cap=1048576):
  raw=json.dumps(args,ensure_ascii=False).encode() if isinstance(args,dict) else args
  out=C.create_string_buffer(cap+32);C.memset(out,0xa5,len(out))
  n=getattr(self.lib,'ui_tool_describe' if describe else 'ui_tool_preview')(name.encode(),raw,len(raw),C.byref(out,16),cap)
  self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[16+cap:],b'\xa5'*16)
  text=out.raw[16:16+max(n,0)].decode()
  self.assertNotIn('\x1b',text)
  return n,text
 def context(self,text):
  raw=text.encode();self.assertEqual(self.lib.ui_tool_set_file_context(raw,len(raw)),0)
 def preview(self,name,args):
  n,text=self.call(name,args);self.assertGreaterEqual(n,0);return text
 def describe(self,name,args):
  n,text=self.call(name,args,describe=True);self.assertGreaterEqual(n,0);return text
 def test_reference_new_write_heading_and_numbered_body(self):
  args={'path':'capture.txt','content':'A visible edit preview\n'}
  self.assertEqual(self.describe('write_file',args),'WriteFile Writing to capture.txt ←')
  self.assertEqual(self.preview('write_file',args),'\n 1 A visible edit preview\n\nApply this change?')
  source=ROOT/'docs/ui-captures/reference/approval.txt'
  if source.exists():
   original=source.read_text()
   self.assertIn('? WriteFile Writing to capture.txt ←',original)
   self.assertIn('1 A visible edit preview',original)
 def test_paths_source_aliases_and_read_title(self):
  self.assertEqual(self.describe('read_file',{'file_path':'folder/file.txt'}),'ReadFile folder/file.txt ←')
  self.assertEqual(self.call('read_file',{'path':'folder/file'})[0],-1)
  self.assertEqual(self.describe('edit_file',{'path':'a.txt','old_string':'a','new_string':'b'}),'Edit a.txt ←')
  self.assertEqual(self.describe('edit_file',{'path':'a.txt','old_string':'','new_string':'b'}),'Edit Create a.txt ←')
  self.assertEqual(self.describe('edit_file',{'path':'a.txt','old_string':'a','new_string':'a'}),'Edit No file changes to a.txt ←')
 def test_shell_actual_command_and_question(self):
  args={'command':'printf "héllo"\nprintf done'}
  self.assertEqual(self.describe('run_shell',args),'Shell printf "héllo" printf done ←')
  self.assertEqual(self.preview('run_shell',args),'\n  printf "héllo"\nprintf done\n\nAllow execution of: \'printf\'?')
 def test_edit_diff_real_line_numbers_and_partial_line(self):
  self.context('one\ntwo\nthree old tail\nfour\nfive\n')
  text=self.preview('edit_file',{'path':'a','old_string':'old','new_string':'NEW'})
  self.assertIn(' 3 - three old tail\n',text)
  self.assertIn(' 3 + three NEW tail\n',text)
  self.assertIn(' 1   one\n',text);self.assertIn(' 4   four\n',text)
  self.assertNotIn(' 1 - old',text)
 def test_multiline_replacement_with_later_physical_context(self):
  self.context(''.join(f'line {i}\n' for i in range(1,31)))
  text=self.preview('edit_file',{'path':'a','old_string':'line 20\nline 21\n','new_string':'replacement\n'})
  self.assertIn(' 20 - line 20\n',text);self.assertIn(' 21 - line 21\n',text)
  self.assertIn(' 20 + replacement\n',text);self.assertIn(' 21   line 22\n',text)
  self.assertNotIn('line 1\n',text)
 def test_overwrite_and_existing_empty_file(self):
  self.context('old content\n')
  text=self.preview('write_file',{'path':'a','content':'new content\n'})
  self.assertIn(' 1 - old content\n',text);self.assertIn(' 1 + new content\n',text)
  self.context('')
  text=self.preview('write_file',{'path':'a','content':'new\n'})
  self.assertIn(' 1 + new\n',text)
  self.lib.ui_tool_set_file_context(None,0)
  self.assertNotIn('+ new',self.preview('write_file',{'path':'a','content':'new\n'}))
 def test_ambiguous_missing_and_missing_context_refuse_fake_diff(self):
  self.context('old old\n')
  self.assertLess(self.call('edit_file',{'path':'a','old_string':'old','new_string':'new'})[0],0)
  self.assertLess(self.call('edit_file',{'path':'a','old_string':'missing','new_string':'new'})[0],0)
  self.lib.ui_tool_set_file_context(None,0)
  self.assertEqual(self.call('edit_file',{'path':'a','old_string':'old','new_string':'new'})[0],-1)
 def test_sanitized_control_free_previews_and_flat_titles(self):
  args={'path':'safe\n\x1b[2Jname','content':'hello\x1b]52;c;SECRET\x07\t世界\n'}
  self.assertEqual(self.describe('write_file',args),'WriteFile Writing to safe name ←')
  text=self.preview('write_file',args);self.assertNotIn('SECRET',text);self.assertIn('hello    世界',text)
 def test_line_gutter_padding_and_empty_new_file(self):
  text=self.preview('write_file',{'path':'a','content':''.join(f'line {i}\n' for i in range(1,13))})
  self.assertIn('  1 line 1\n',text);self.assertIn(' 12 line 12\n',text)
  self.assertEqual(self.preview('write_file',{'path':'a','content':''}),'\n 1 \n\nApply this change?')
 def test_context_is_copied_and_unchanged_file(self):
  context=C.create_string_buffer(b'old\n')
  self.lib.ui_tool_set_file_context(context,4);context[0]=b'X'
  text=self.preview('edit_file',{'path':'a','old_string':'old','new_string':'new'})
  self.assertIn('- old',text)
  self.context('same\n')
  self.assertIn('No changes detected.',self.preview('write_file',{'path':'a','content':'same\n'}))
 def test_large_repeated_prefix_linear_match(self):
  raw='a'*65535+'b\n';self.context(raw)
  started=time.monotonic()
  text=self.preview('edit_file',{'path':'a','old_string':'a'*32000+'b','new_string':'changed'})
  self.assertLess(time.monotonic()-started,2);self.assertIn('changed',text)
 def test_invalid_arguments_caps_and_unsupported_tools(self):
  for raw in [b'{',b'[]',b'{"path":1,"content":"x"}',b'{"path":"a\\u0000hidden","content":"x"}']:
   self.assertLess(self.call('write_file',raw)[0],0)
  self.assertEqual(self.call('unknown',{})[0],-1)
  for cap in range(30):self.assertLess(self.call('write_file',{'path':'a','content':'a'*100},cap=cap)[0],0)
  self.assertLess(self.lib.ui_tool_set_file_context(b'x',1048577),0)
 def test_no_runtime_libraries(self):
  self.assertEqual(subprocess.check_output(['nm','-u',str(self.shared)],text=True).strip(),'')

if __name__=='__main__':unittest.main()
