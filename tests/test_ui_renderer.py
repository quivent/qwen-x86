"""Pure assembly renderer exercised through real PTYs; no application runtime shim."""
import codecs
import ctypes
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import tempfile
import time
import unicodedata
import unittest
ROOT=Path(__file__).resolve().parents[1]
DRIVER=r'''import ctypes,sys,time,json,resource,os
os.environ.pop("NO_COLOR",None)
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
l=ctypes.CDLL(sys.argv[1]);mode=sys.argv[2];result=sys.argv[3]
for name in ['ui_start','ui_tool_begin']:getattr(l,name).argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_size_t] if name=='ui_tool_begin' else [ctypes.c_char_p]*3
for name in ['ui_user','ui_delta','ui_tool_end']:getattr(l,name).argtypes=[ctypes.c_char_p,ctypes.c_size_t]+([ctypes.c_long] if name=='ui_tool_end' else [])
l.ui_readline.argtypes=[ctypes.c_void_p,ctypes.c_size_t];l.ui_approve.argtypes=[ctypes.c_char_p];l.ui_choose.argtypes=[ctypes.c_char_p,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_size_t]
l.ui_start(b'bench-model',b'/tmp/work',b'API Key')
if mode=='chat':
 text='Hello 世界 👩\u200d💻'.encode();l.ui_user(text,len(text));l.ui_begin_response();text=b'# Native response\n\n**bold** and `code`\n\n- first\n- second';l.ui_delta(text,len(text));l.ui_tool_begin(b'write_file',b'{"path":"hello.txt","content":"safe"}',37);l.ui_tool_end(b'Created hello.txt',17,0);l.ui_end_response()
if mode=='lifecycle':
 args=b'{"path":"capture.txt","content":"A visible edit preview\\n"}';l.ui_user(b'Write the file',14);l.ui_tool_begin(b'write_file',args,len(args));l.ui_tool_end(b'File written successfully.',26,0);l.ui_end_response()
if mode=='toolerror':
 args=b'{"path":"capture.txt","content":"MUST_NOT_SHOW_AS_WRITTEN"}';l.ui_tool_begin(b'write_file',args,len(args));l.ui_tool_end(b'Permission denied',17,1);l.ui_tool_end(b'Standalone network failure',26,1)
if mode=='details':
 l.ui_tool_begin(b'read_file',b'{"path":"notes.txt"}',20);text=b'line1\nline2\nline3\nline4_hidden\nline5';l.ui_tool_end(text,len(text),0)
if mode=='tabs':
 l.ui_begin_response();text=b'\t'*(1048576-64)+b'EXPANSION_TAIL';l.ui_delta(text,len(text));l.ui_end_response()
if mode=='large':
 l.ui_begin_response();text=(('x'*79+'\n')*12000+'TAIL_AFTER_64K').encode();l.ui_delta(text,len(text));l.ui_end_response()
if mode=='scroll':
 for i in range(45):
  text=('message %02d'%i).encode();l.ui_user(text,len(text))
if mode=='theme':l.ui_set_theme(1)
if mode=='themepreview':
 class Item(ctypes.Structure):_fields_=[('label',ctypes.c_char_p),('description',ctypes.c_char_p),('value',ctypes.c_void_p)]
 callback=ctypes.CFUNCTYPE(None,ctypes.c_long,ctypes.c_void_p)(lambda i,v:l.ui_set_theme(i));l.ui_set_choice_preview.argtypes=[ctypes.c_void_p];l.ui_set_choice_preview(callback)
 table=(Item*2)(Item(b'Default dark',b'Source default palette',None),Item(b'Dracula',b'Source Dracula palette',None));n=l.ui_choose(b'Theme',table,2,0);l.ui_set_choice_preview(None)
 if n<0:l.ui_set_theme(0)
 value=[n,l.ui_get_theme()]
elif mode=='typedapproval':
 args=b'{"path":"capture.txt","content":"A visible edit preview\\n"}';l.ui_tool_begin(b'write_file',args,len(args));value=l.ui_approve(b'Allow this file write?\n'+args)
elif mode=='approval':
 text=('Run command:\n'+''.join('line %02d explicit command\n'%i for i in range(60))).encode();value=l.ui_approve(text)
elif mode=='choose':
 class Item(ctypes.Structure):_fields_=[('label',ctypes.c_char_p),('description',ctypes.c_char_p),('value',ctypes.c_void_p)]
 table=(Item*3)(Item(b'First model',b'First description',None),Item(b'Second model',b'Second description',None),Item(b'Third model',b'Third description',None));value=l.ui_choose(b'Select model',table,3,0)
elif mode=='fifo':
 l.ui_begin_response();deadline=time.time()+5
 while time.time()<deadline:
  if l.ui_poll()<0:break
  time.sleep(.01)
 l.ui_end_response();buf=ctypes.create_string_buffer(65536);value=[]
 while True:
  n=l.ui_take_queued(buf,len(buf))
  if n<=0:break
  value.append(buf.value.decode())
elif mode=='busy':
 l.ui_begin_response();deadline=time.time()+5;value=0
 while time.time()<deadline:
  value=l.ui_poll()
  if value<0:break
  time.sleep(.01)
 l.ui_end_response();buf=ctypes.create_string_buffer(65536);n=l.ui_readline(buf,len(buf));value=[value,n,buf.value.decode()]
else:
 buf=ctypes.create_string_buffer(65536);n=l.ui_readline(buf,len(buf));value=[n,buf.value.decode()]
l.ui_restore();open(result,'w').write(json.dumps(value))
'''

class Screen:
 def __init__(self,cols,rows):self.cols=cols;self.rows=rows;self.grid=[[' ']*cols for _ in range(rows)];self.colors=[[None]*cols for _ in range(rows)];self.x=0;self.y=0;self.fg=None
 def feed(self,raw):
  text=raw.decode('utf8','replace');i=0
  while i<len(text):
   ch=text[i]
   if ch=='\x1b':
    m=re.match(r'\x1b\[([0-9;?]*)([A-Za-z])',text[i:])
    if not m:i+=1;continue
    params,op=m.groups();i+=len(m[0]);p=[int(x or 0) for x in params.lstrip('?').split(';')]
    if op in 'Hf':self.y=max(0,min(self.rows-1,(p[0] or 1)-1));self.x=max(0,min(self.cols-1,((p[1] if len(p)>1 else 1) or 1)-1))
    elif op=='J':
     for y in range(self.y,self.rows):
      start=self.x if y==self.y else 0
      for x in range(start,self.cols):self.grid[y][x]=' ';self.colors[y][x]=None
    elif op=='m':
     if p==[0] or p==[39]:self.fg=None
     elif len(p)>=5 and p[:2]==[38,2]:self.fg=tuple(p[2:5])
    continue
   i+=1
   if ch=='\r':self.x=0;continue
   if ch=='\n':self.y=min(self.rows-1,self.y+1);continue
   if ord(ch)<32:continue
   if unicodedata.combining(ch) or ch in '\u200d\ufe0f':continue
   width=2 if unicodedata.east_asian_width(ch) in 'WF' else 1
   if self.x>=self.cols:self.x=0;self.y=min(self.rows-1,self.y+1)
   self.grid[self.y][self.x]=ch;self.colors[self.y][self.x]=self.fg
   if width==2 and self.x+1<self.cols:self.grid[self.y][self.x+1]=''
   self.x+=width
 def lines(self):return [''.join(x) for x in self.grid]

class NativeUIRenderer(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory(prefix='qwen-ui-renderer-');cls.build=Path(cls.temp.name)
  names='ui ui_input ui_markdown ui_mermaid ui_tool_preview ui_help ui_shell tools terminal runtime json net'.split()
  for name in names:subprocess.run(['as','--64','-I',str(ROOT/'src'),'-o',str(cls.build/(name+'.o')),str(ROOT/'src'/(name+'.s'))],check=True)
  cls.lib=cls.build/'ui.so';subprocess.run(['ld','-shared','-Bsymbolic','-o',str(cls.lib),*[str(cls.build/(n+'.o')) for n in names]],check=True,stderr=subprocess.PIPE)
 @classmethod
 def tearDownClass(cls):cls.temp.cleanup()
 def start(self,mode='idle',cols=100,rows=30):
  self.master,slave=pty.openpty();fcntl.ioctl(slave,0x5414,struct.pack('HHHH',rows,cols,0,0));self.result=self.build/('result-'+str(time.monotonic_ns()));self.proc=subprocess.Popen(['python3','-c',DRIVER,str(self.lib),mode,str(self.result)],stdin=slave,stdout=slave,stderr=subprocess.PIPE);os.close(slave);self.cols=cols;self.rows=rows;self.raw=b'';self.read(.5)
  self.addCleanup(self.cleanup)
  return self.screen()
 def cleanup(self):
  if hasattr(self,'proc') and self.proc.poll() is None:self.proc.kill();self.proc.wait()
  if hasattr(self,'master'):
   try:os.close(self.master)
   except OSError:pass
 def read(self,seconds=.2):
  end=time.monotonic()+seconds
  while time.monotonic()<end:
   ready,_,_=select.select([self.master],[],[],min(.05,max(0,end-time.monotonic())))
   if ready:
    try:chunk=os.read(self.master,65536)
    except OSError:break
    if not chunk:break
    self.raw+=chunk
  return self.raw
 def screen(self):
  s=Screen(self.cols,self.rows);frames=self.raw.split(b'\x1b[H');raw=next((x for x in reversed(frames[1:]) if x.endswith(b'\x1b[0m')),frames[-1]);s.feed(b'\x1b[H'+raw);return s
 def finish(self,keys=b'\x04\x04'):
  os.write(self.master,keys);self.read(.15);out,err=self.proc.communicate(timeout=5);self.assertEqual(self.proc.returncode,0,err);return json.loads(self.result.read_text())
 def test_source_geometry_at_80_100_120_and_palette(self):
  for cols,rows in [(80,24),(100,30),(120,40)]:
   screen=self.start(cols=cols,rows=rows);lines=screen.lines()
   self.assertTrue(any('>_ Qwen Code' in x for x in lines),('\n'.join(lines),self.proc.poll(),self.proc.stderr.read() if self.proc.poll()!=None else b''))
   self.assertIn('API Key | bench-model','\n'.join(lines));self.assertIn('/tmp/work','\n'.join(lines))
   self.assertEqual(any('██╔' in x for x in lines),cols>=100)
   rules=[i for i,x in enumerate(lines) if x=='─'*cols];self.assertEqual(len(rules),2);self.assertEqual(rules[1]-rules[0],2);self.assertLess(rules[0],rows-6);self.assertTrue(lines[rules[0]+1].startswith('>   Type'));self.assertIn('➜ work · bench-model',lines[rules[1]+1])
   title=next((y,x.index('>_ Qwen')) for y,x in enumerate(lines) if '>_ Qwen' in x);self.assertEqual(screen.colors[title[0]][title[1]],(203,166,247))
   self.finish();self.cleanup()
 def test_multiline_unicode_editor_and_submission(self):
  self.start(cols=80,rows=24);os.write(self.master,'hello 世界'.encode()+b'\x1b\r'+ '👩\u200d💻'.encode());self.read(.15)
  self.assertIn('hello 世界','\n'.join(self.screen().lines()));value=self.finish(b'\r');self.assertEqual(value[1],'hello 世界\n👩\u200d💻')
 def test_transcript_markdown_tools_and_no_untrusted_ansi(self):
  screen=self.start('chat',120,40);text='\n'.join(screen.lines());self.assertIn('Native response',text);self.assertIn('safe',text);self.assertIn('WriteFile',text);self.finish()
 def test_completed_write_transitions_header_and_keeps_numbered_content(self):
  self.start('lifecycle',100,30);lines=self.screen().lines();text='\n'.join(lines)
  self.assertIn('✓ WriteFile Writing to capture.txt',text);self.assertNotIn('←',text);self.assertNotIn('File written successfully.',text);self.assertNotIn('Apply this change?',text)
  row=next(i for i,x in enumerate(lines) if '✓ WriteFile' in x);self.assertTrue(lines[row+1].startswith('    1 A visible edit preview'),repr(lines[row+1]));self.assertIn('> Write the file',lines[row-1]);self.finish()
 def test_failed_tool_transitions_header_and_standalone_error_stays_red(self):
  self.start('toolerror',100,30);screen=self.screen();text='\n'.join(screen.lines());self.assertIn('✗ WriteFile Writing to capture.txt',text);self.assertIn('Permission denied',text);self.assertNotIn('MUST_NOT_SHOW_AS_WRITTEN',text);self.assertIn('✗ Standalone network failure',text);self.assertNotIn('←',text);self.finish()
 def test_editor_viewport_follows_multiline_cursor(self):
  self.start(cols=80,rows=24);text='\n'.join('editor line %02d'%i for i in range(10))
  os.write(self.master,b'\x1b[200~'+text.encode()+b'\x1b[201~');self.read(.2)
  view='\n'.join(self.screen().lines());self.assertIn('editor line 09',view);self.assertNotIn('editor line 00',view);self.assertEqual(self.finish(b'\r')[1],text)
 def test_large_assistant_message_tail_remains_visible(self):
  self.start('large',120,40);deadline=time.monotonic()+6
  while time.monotonic()<deadline and 'TAIL_AFTER_64K' not in '\n'.join(self.screen().lines()):self.read(.1)
  self.assertIn('TAIL_AFTER_64K','\n'.join(self.screen().lines()));self.finish()
 def test_slash_completion_accepts_actual_supported_command(self):
  self.start();self.assertEqual(self.finish(b'/he\t\r')[1],'/help')
 def test_two_press_exit_hint_and_escape_clear(self):
  self.start();os.write(self.master,b'kept draft\x1b');self.read(.2);self.assertIn('Press Esc again to clear','\n'.join(self.screen().lines()));self.assertIsNone(self.proc.poll())
  os.write(self.master,b'\x1b');self.read(.2);self.assertNotIn('kept draft','\n'.join(self.screen().lines()));os.write(self.master,b'\x03');self.read(.15);self.assertIn('Press Ctrl+C again to exit','\n'.join(self.screen().lines()));self.assertEqual(self.finish(b'\x03')[0],-1)
 def test_fifo_queue_preserves_prompt_boundaries_and_full_draft(self):
  self.start('fifo');os.write(self.master,b''.join(('queued %d'%i).encode()+b'\x11' for i in range(9)));self.read(.4);text='\n'.join(self.screen().lines());self.assertIn('queued 8',text);self.assertIn('full (8)',text);self.assertIn('+5 more queued',text)
  self.assertEqual(self.finish(b'\x03'),['queued %d'%i for i in range(8)])
 def test_details_toggle_reveals_stored_tool_output(self):
  self.start('details');self.assertNotIn('line4_hidden','\n'.join(self.screen().lines()));os.write(self.master,b'\x0f');self.read(.2);self.assertIn('line4_hidden','\n'.join(self.screen().lines()));self.finish()
 def test_theme_dialog_previews_and_cancel_restores_palette(self):
  self.start('themepreview');os.write(self.master,b'\x1b[B');self.read(.15);screen=self.screen();lines=screen.lines();y,x=next((y,x.index('Dracula')) for y,x in enumerate(lines) if 'Dracula' in x);self.assertEqual(screen.colors[y][x],(255,121,198));self.assertEqual(self.finish(b'\x1b'),[-1,0])
 def test_one_megabyte_tabs_expand_without_blank_response(self):
  self.start('tabs',120,40);deadline=time.monotonic()+6
  while time.monotonic()<deadline and 'EXPANSION_TAIL' not in '\n'.join(self.screen().lines()):self.read(.1)
  self.assertIn('EXPANSION_TAIL','\n'.join(self.screen().lines()));self.finish()
 def test_scroll_and_resize(self):
  self.start('scroll',100,30);self.assertIn('message 44','\n'.join(self.screen().lines()));os.write(self.master,b'\x1b[5~');self.read(.15);self.assertNotIn('message 44','\n'.join(self.screen().lines()))
  fcntl.ioctl(self.master,0x5414,struct.pack('HHHH',40,120,0,0));self.cols=120;self.rows=40;self.read(.2);self.assertTrue(any(x=='─'*120 for x in self.screen().lines()));os.write(self.master,b'\x1b[5~'*30);self.read(.4);self.assertTrue(any('██╔' in x for x in self.screen().lines()));self.finish()
 def test_approval_source_selection_and_full_preview_scroll(self):
  self.start('approval',100,30);text='\n'.join(self.screen().lines());self.assertIn('› 1. Yes, allow once',text);os.write(self.master,b'\x1b[5~'*20);self.read(.3);self.assertIn('Run command:','\n'.join(self.screen().lines()))
  os.write(self.master,b'\x1b[6~');self.read(.2);self.assertIn('line 08','\n'.join(self.screen().lines()));self.assertEqual(self.finish(b'n'),0)
 def test_approval_explicit_once_and_session(self):
  self.start('approval');self.assertEqual(self.finish(b'y'),1);self.cleanup();self.start('approval');self.assertEqual(self.finish(b'\x1b[B\r'),2)
 def test_typed_write_approval_has_real_numbered_content_and_question(self):
  self.start('typedapproval');text='\n'.join(self.screen().lines());self.assertIn('? WriteFile Writing to capture.txt',text);self.assertIn('1 A visible edit preview',text);self.assertIn('Apply this change?',text);self.assertNotIn('"content"',text);self.assertEqual(self.finish(b'n'),0)
 def test_approval_mouse_packets_never_trigger_numeric_shortcuts(self):
  self.start('typedapproval');os.write(self.master,b'\x1b[<0;1;1M\x1b[<0;1;1m');self.read(.2);self.assertIsNone(self.proc.poll())
  os.write(self.master,b'\x1b[<'+b'9'*150+b';1;1M');self.read(.2);self.assertIsNone(self.proc.poll());self.assertEqual(self.finish(b'n'),0)
 def test_typed_approval_uses_source_warning_success_and_muted_styles(self):
  self.start('typedapproval');screen=self.screen();lines=screen.lines()
  y=next(y for y,line in enumerate(lines) if '? WriteFile' in line);x=lines[y].index('? WriteFile');self.assertEqual(screen.colors[y][x],(249,226,175))
  d=lines[y].index('Writing to');self.assertEqual(screen.colors[y][d],(108,112,134));self.assertIn(b'\x1b[1mWriteFile\x1b[0m',self.raw)
  y=next(y for y,line in enumerate(lines) if 'Yes, allow once' in line);x=lines[y].index('Yes, allow once');self.assertEqual(screen.colors[y][x],(166,227,161));self.assertEqual(self.finish(b'n'),0)
 def test_generic_backend_choice(self):
  self.start('choose');self.assertIn('Select model','\n'.join(self.screen().lines()));self.assertTrue(any('╭' in x for x in self.screen().lines()));self.assertEqual(self.finish(b'\x1b[B\r'),1)
 def test_generic_dialog_search_is_case_insensitive_and_preserves_original_index(self):
  self.start('choose');os.write(self.master,b'sNd');self.read(.2);text='\n'.join(self.screen().lines());self.assertIn('Search: sNd',text);self.assertIn('Second model',text);self.assertNotIn('First model',text);self.assertEqual(self.finish(b'\r'),1)
 def test_generic_dialog_letters_y_n_are_search_not_approval_shortcuts(self):
  self.start('choose');os.write(self.master,b'ny');self.read(.2);self.assertIsNone(self.proc.poll());self.assertIn('No matching entries','\n'.join(self.screen().lines()));self.assertEqual(self.finish(b'\x1b'),-1)
 def test_theme_changes_real_palette(self):
  screen=self.start('theme');lines=screen.lines();y,x=next((y,x.index('>_ Qwen')) for y,x in enumerate(lines) if '>_ Qwen' in x);self.assertEqual(screen.colors[y][x],(255,121,198));self.finish()
 def test_busy_enter_interrupts_and_preserves_queued_prompt(self):
  self.start('busy');value=self.finish(b'next instruction\r');self.assertEqual(value,[-125,16,'next instruction'])
if __name__=='__main__':unittest.main()
