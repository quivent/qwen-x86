"""Native assembly editor tests. Python is a development harness only."""
import ctypes as C, json, pathlib, subprocess, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class EditorTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory(); out=pathlib.Path(cls.tmp.name)
  subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/'src/ui_input.s'),'-o',str(out/'input.o')],check=True)
  subprocess.run(['ld','-shared',str(out/'input.o'),'-o',str(out/'input.so')],check=True)
  cls.lib=C.CDLL(str(out/'input.so'))
  for name,args in {'input_init':[C.c_void_p,C.c_void_p,C.c_size_t],'input_begin':[C.c_void_p,C.c_void_p,C.c_size_t],'input_feed':[C.c_void_p,C.c_void_p,C.c_size_t],'input_osc11_snapshot':[C.c_void_p,C.c_void_p],'input_mouse_snapshot':[C.c_void_p,C.c_void_p],'input_snapshot':[C.c_void_p,C.c_void_p],'input_history_add':[C.c_void_p,C.c_void_p,C.c_size_t],'input_resize':[C.c_void_p,C.c_size_t,C.c_size_t],'input_consumed':[C.c_void_p],'input_timeout':[C.c_void_p],'input_set_external_history':[C.c_void_p,C.c_size_t],'input_set_completion':[C.c_void_p,C.c_size_t],'input_replace':[C.c_void_p,C.c_size_t,C.c_size_t,C.c_void_p,C.c_size_t],'ui_next_grapheme':[C.c_void_p,C.c_size_t,C.c_size_t],'ui_text_width':[C.c_void_p,C.c_size_t]}.items():
   fn=getattr(cls.lib,name);fn.argtypes=args;fn.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):
  self.ctx=C.create_string_buffer(2097152);self.buf=C.create_string_buffer(65536)
  self.assertEqual(self.lib.input_init(self.ctx,self.buf,len(self.buf)),0)
 def begin(self,s=''):
  b=s.encode();self.lib.input_begin(self.ctx,b,len(b))
 def feed(self,b):
  if isinstance(b,str):b=b.encode()
  return self.lib.input_feed(self.ctx,b,len(b))
 def snap(self):
  s=(C.c_uint64*8)();self.lib.input_snapshot(self.ctx,s)
  return C.string_at(s[0],s[1]).decode(),s[2],s[4],s[7]
 def test_edit_cursor_controls(self):
  self.feed('ac');self.feed(b'\x1b[D');self.feed('b');self.assertEqual(self.snap()[:2],('abc',2))
  self.feed(b'\x01X\x05Y');self.assertEqual(self.snap()[:2],('XabcY',5))
  self.feed(b'\x1b[H\x1b[3~');self.assertEqual(self.snap()[0],'abcY')
  self.feed(b'\x05\x7f');self.assertEqual(self.snap()[0],'abc')
 def test_utf8_grapheme_backspace(self):
  for value in ['e\u0301','👩🏽\u200d💻','🇱🇹','क्\u200dष','각']:
   self.begin('a'+value);self.feed(b'\x7f');self.assertEqual(self.snap()[:2],('a',1),value)
  self.begin();raw='λ世'.encode()
  for b in raw:self.feed(bytes([b]))
  self.assertEqual(self.snap()[0],'λ世')
 def test_word_delete_undo_redo(self):
  self.feed('one two');self.feed(b'\x17');self.assertEqual(self.snap()[0],'one ')
  self.feed(b'\x1a');self.assertEqual(self.snap()[0],'one two')
  self.feed(b'\x1b[90;6u');self.assertEqual(self.snap()[0],'one ')
  self.feed(b'\x01\x1bf');self.assertEqual(self.snap()[1],4)
 def test_fragmented_paste_no_submit(self):
  self.feed('head')
  events=0
  raw=b'\x1b[200~a\r\nb\n'+ '👩🏽\u200d💻'.encode()+b'\x1b[201~'
  for b in raw:events|=self.feed(bytes([b]))
  self.assertFalse(events&2);self.assertEqual(self.snap()[0],'heada\nb\n👩🏽\u200d💻')
  self.assertEqual(self.feed(b'\r')&2,2)
  self.feed(b'\x1a');self.assertEqual(self.snap()[0],'head')
 def test_history_draft_multiline(self):
  for s in ('older','newer'):
   b=s.encode();self.lib.input_history_add(self.ctx,b,len(b))
  self.feed('draft');self.feed(b'\x1b[A\x1b[A');self.assertEqual(self.snap()[0],'newer')
  self.feed(b'\x1b[A');self.assertEqual(self.snap()[0],'older')
  self.feed(b'\x1b[B\x1b[B\x1b[B');self.assertEqual(self.snap()[0],'draft')
  self.begin('abc\ndef');self.feed(b'\x1b[A');self.assertEqual(self.snap()[1],3)
 def test_search(self):
  for s in ('alpha test','beta other','alpha last'):
   b=s.encode();self.lib.input_history_add(self.ctx,b,len(b))
  self.feed('draft');self.feed(b'\x12alpha');self.assertEqual(self.snap()[0],'alpha last')
  self.feed(b'\x12');self.assertEqual(self.snap()[0],'alpha test')
  self.feed(b'\x1b');self.lib.input_timeout(self.ctx);self.assertEqual(self.snap()[0],'draft')
 def test_menu_selection_replace(self):
  self.feed('/he');self.lib.input_set_completion(self.ctx,1)
  self.assertEqual(self.feed(b'\x1b[A')&64,64);self.assertEqual(self.feed(b'\r')&256,256)
  self.assertEqual(self.lib.input_replace(self.ctx,0,3,b'/help',5),0);self.assertEqual(self.snap()[0],'/help')
  self.feed(b'\x1b[1;2D');self.assertEqual(self.snap()[3],5)
  self.feed('X');self.assertEqual(self.snap()[0],'/helX')
  self.begin('fresh');self.assertEqual(self.feed(b'\r')&2,2)
  self.assertEqual(self.snap()[2]&4,0)
 def test_timeout_and_events(self):
  self.feed('abc\x1b');self.assertEqual(self.lib.input_timeout(self.ctx)&2097152,2097152);self.assertEqual(self.snap()[0],'abc')
  self.assertEqual(self.feed(b'\t')&16,16);self.assertEqual(self.feed(b'\x11')&65536,65536)
  self.assertEqual(self.feed(b'\x1b[5~')&2048,2048)
  self.begin();self.assertEqual(self.feed(b'\x04')&8,8)
  self.assertEqual(self.feed(b'\x0c')&262144,262144)
  self.assertEqual(self.feed(b'\x0f')&524288,524288)
  self.assertEqual(self.feed(b'\x19')&1048576,1048576)
  self.assertEqual(self.feed(b'\x1b[Z')&131072,131072)
 def test_small_capacity_whole_utf8(self):
  self.lib.input_init(self.ctx,self.buf,5)
  self.feed('a世');self.assertEqual(self.snap()[0],'a世')
  self.assertTrue(self.feed('λ')&32);self.assertEqual(self.snap()[0],'a世')
 def test_burst_stops_at_each_submission(self):
  raw=b'first\rsecond\r'
  self.assertEqual(self.feed(raw)&2,2)
  consumed=self.lib.input_consumed(self.ctx);self.assertEqual(consumed,6)
  self.assertEqual(self.snap()[0],'first')
  self.begin();self.assertEqual(self.feed(raw[consumed:])&2,2)
  self.assertEqual(self.lib.input_consumed(self.ctx),7)
  self.assertEqual(self.snap()[0],'second')
  self.begin();self.assertEqual(self.feed(b'\x03tail')&4,4)
  self.assertEqual(self.lib.input_consumed(self.ctx),1);self.assertEqual(self.snap()[0],'')
  self.assertEqual(self.feed(b'\x04tail')&8,8);self.assertEqual(self.lib.input_consumed(self.ctx),1)
  self.begin();self.assertEqual(self.feed(b'one\x11two\x11')&65536,65536)
  self.assertEqual(self.lib.input_consumed(self.ctx),4);self.assertEqual(self.snap()[0],'one')
  self.begin('/he');self.assertEqual(self.feed(b'\tmore')&16,16)
  self.assertEqual(self.lib.input_consumed(self.ctx),1);self.assertEqual(self.snap()[0],'/he')
 def test_slow_paste_marker_and_rapid_double_escape(self):
  self.feed(b'\x1b[20');self.assertEqual(self.lib.input_timeout(self.ctx),0)
  self.feed(b'0~a\nb\x1b[201~');self.assertEqual(self.snap()[0],'a\nb')
  self.assertEqual(self.feed(b'\x1b\x1b')&2097152,2097152)
  self.assertEqual(self.lib.input_timeout(self.ctx)&2097152,2097152)
  self.assertEqual(self.snap()[0],'a\nb')
 def test_shell_toggle_and_external_history_events(self):
  self.assertEqual(self.feed(b'!command\r')&16777216,16777216)
  self.assertEqual(self.lib.input_consumed(self.ctx),1);self.assertEqual(self.snap()[0],'')
  self.lib.input_set_external_history(self.ctx,1);self.feed('draft')
  self.assertEqual(self.feed(b'\x1b[A')&4194304,4194304);self.assertEqual(self.snap()[0],'draft')
  self.assertEqual(self.feed(b'\x0e')&8388608,8388608);self.assertEqual(self.snap()[0],'draft')
  self.begin();self.feed(b'\x1b[200~!literal\x1b[201~');self.assertEqual(self.snap()[0],'!literal')
 def test_sgr_mouse_fragmented_wheel_metadata_and_discard(self):
  self.feed('draft');events=self.feed(b'\x1b[')
  for byte in b'<64;12;9M':events|=self.feed(bytes([byte]));self.lib.input_timeout(self.ctx)
  self.assertEqual(events&33554432,33554432);self.assertEqual(self.snap()[0],'draft')
  data=(C.c_uint64*4)();self.lib.input_mouse_snapshot(self.ctx,data);self.assertEqual(list(data),[64,12,9,0])
  self.assertEqual(self.feed(b'\x1b[<65;1;2Mtail')&67108864,67108864)
  self.assertEqual(self.lib.input_consumed(self.ctx),10);self.assertEqual(self.snap()[0],'draft')
  self.assertEqual(self.feed(b'\x1b[<64;1;2m'),0)
  self.lib.input_mouse_snapshot(self.ctx,data);self.assertEqual(list(data),[64,1,2,1])
  for packet in [b'\x1b[<0;1;2M',b'\x1b[<32;1;2M',b'\x1b[<64;0;2M',b'\x1b[<64;;2M',b'\x1b[<64;1;9999999999M',b'\x1b[<'+b'1'*150+b';1;2M']:
   self.assertEqual(self.feed(packet),0,packet)
  self.assertEqual(self.snap()[0],'draft')
 def test_osc11_fragmented_colors_and_all_osc_packets_hidden(self):
  self.feed('draft');events=0;self.feed(b'\x1b]')
  for byte in b'11;rgb:ffff/8000/0000\x1b\\':events|=self.feed(bytes([byte]));self.lib.input_timeout(self.ctx)
  self.assertEqual(events&134217728,134217728);self.assertEqual(self.snap()[0],'draft')
  color=(C.c_uint64*4)();self.assertEqual(self.lib.input_osc11_snapshot(self.ctx,color),1);self.assertEqual(list(color),[65535,32768,0,1]);self.assertEqual(self.lib.input_osc11_snapshot(self.ctx,color),0)
  for payload,want in [(b'11;#f80',[65535,34952,0]),(b'11;#ffffff',[65535]*3),(b'11;RGBA:00/80/ff',[0,32896,65535]),(b'11;#000000000000',[0]*3)]:
   self.assertEqual(self.feed(b'\x1b]'+payload+b'\x07')&134217728,134217728)
   self.assertEqual(self.lib.input_osc11_snapshot(self.ctx,color),1);self.assertEqual(list(color)[:3],want)
  for payload in [b'0;window title',b'11;rgb:1/2',b'11;rgb:00000/0/0',b'11;#ffff',b'11;garbage',b'11;'+b'1'*150,b'11;bad\nnewline']:
   self.assertEqual(self.feed(b'\x1b]'+payload+b'\x07'),0,payload)
  self.assertEqual(self.snap()[0],'draft')
  self.assertEqual(self.feed(b'\x1b]11;#fff\x07tail')&134217728,134217728)
  self.assertEqual(self.lib.input_consumed(self.ctx),10);self.assertEqual(self.snap()[0],'draft')
 def test_source_viewport_ctrl_home_end_and_shift_arrows(self):
  self.feed('draft')
  for key,flag in [(b'\x1b[1;5H',8192),(b'\x1b[1;5F',16384),(b'\x1b[7;5~',8192),(b'\x1b[8;5~',16384),(b'\x1b[1;6H',8192),(b'\x1b[1;2A',268435456),(b'\x1b[1;2B',536870912)]:
   self.assertEqual(self.feed(key)&flag,flag,key);self.assertEqual(self.snap()[:2],('draft',5));self.assertEqual(self.snap()[3],2**64-1)
 def test_multiple_wheel_packets_preserve_every_consumed_step(self):
  packet=b'\x1b[<64;5;5M';raw=packet*3;offset=0;ticks=0
  while offset<len(raw):
   event=self.feed(raw[offset:]);self.assertEqual(event&33554432,33554432)
   consumed=self.lib.input_consumed(self.ctx);self.assertEqual(consumed,len(packet));offset+=consumed;ticks+=1
  self.assertEqual(ticks,3);self.assertEqual(self.snap()[0],'')
 def test_sixteen_undo_redo_and_branch(self):
  self.feed('abcdefghijklmnopqrst')
  for n in range(19,3,-1):
   self.feed(b'\x1a');self.assertEqual(self.snap()[0],'abcdefghijklmnopqrst'[:n])
  self.feed(b'\x1a');self.assertEqual(self.snap()[0],'abcd')
  for n in range(5,21):
   self.feed(b'\x1b[90;6u');self.assertEqual(self.snap()[0],'abcdefghijklmnopqrst'[:n])
  self.feed(b'\x1a\x1aX\x1b[90;6u');self.assertEqual(self.snap()[0],'abcdefghijklmnopqrX')
 def test_history_thirty_two_large_entries(self):
  for n in range(35):
   b=(f'{n:02d}:'+('x'*7000)).encode();self.lib.input_history_add(self.ctx,b,len(b))
  self.begin('draft');self.feed(b'\x1b[A')
  for n in range(34,2,-1):
   self.feed(b'\x1b[A');self.assertEqual(self.snap()[0],f'{n:02d}:'+('x'*7000))
  self.feed(b'\x1b[A');self.assertTrue(self.snap()[0].startswith('03:'))
 def test_visual_wrap_movement_and_home_end(self):
  self.lib.input_resize(self.ctx,4,6);self.begin('abcdefghij')
  self.feed(b'\x1b[A');self.assertEqual(self.snap()[1],6)
  self.feed(b'\x1b[A');self.assertEqual(self.snap()[1],2)
  self.feed(b'\x1b[B');self.assertEqual(self.snap()[1],6)
  self.feed(b'\x01');self.assertEqual(self.snap()[1],4)
  self.feed(b'\x05');self.assertEqual(self.snap()[1],8)
  self.begin('a世b世界');self.feed(b'\x1b[A');self.assertEqual(self.snap()[1],5)
 def test_word_scripts_and_punctuation(self):
  self.begin('foo/bar');self.feed(b'\x17');self.assertEqual(self.snap()[0],'foo/')
  self.begin('abcλμ');self.feed(b'\x1bb');self.assertEqual(self.snap()[1],3)
  self.begin('a世界');self.feed(b'\x1bb');self.assertEqual(self.snap()[1],4)
  self.begin('e\u0301');self.feed(b'\x1bb');self.assertEqual(self.snap()[1],0)
 def test_malformed_escape_paste_and_replacement_character(self):
  self.feed('abc\x1b[');self.lib.input_timeout(self.ctx);self.assertEqual(self.snap()[0],'abc')
  self.feed(b'Q') # complete unknown CSI before the next sequence
  self.feed(b'\x1b[200~one\x1b[20Xtwo\x1b[201~')
  self.assertEqual(self.snap()[0],'abcone[20Xtwo')
  self.begin();self.feed('�');self.assertEqual(self.snap()[0],'�')
 def test_ascii_editor_randomized(self):
  import random
  r=random.Random(31);text='';cursor=0
  for _ in range(1500):
   key=r.choice(['letter','left','right','home','end','back','delete'])
   if key=='letter':
    ch=r.choice('abcdef');text=text[:cursor]+ch+text[cursor:];cursor+=1;self.feed(ch)
   elif key=='left':cursor=max(0,cursor-1);self.feed(b'\x1b[D')
   elif key=='right':cursor=min(len(text),cursor+1);self.feed(b'\x1b[C')
   elif key=='home':cursor=0;self.feed(b'\x01')
   elif key=='end':cursor=len(text);self.feed(b'\x05')
   elif key=='back':
    if cursor:text=text[:cursor-1]+text[cursor:];cursor-=1
    self.feed(b'\x7f')
   else:
    text=text[:cursor]+text[cursor+1:];self.feed(b'\x1b[3~')
   self.assertEqual(self.snap()[:2],(text,cursor),key)
 def test_unicode_against_node_segmenter(self):
  vectors=['a\r\nb','e\u0301','👩🏽\u200d💻','🇱🇹🇺🇸🇦','क्\u200dष','각','\u0600A','👨\u200d👩\u200d👧\u200d👦','a\u200db','❤️','☀️']
  script="const v=JSON.parse(process.argv[1]);console.log(JSON.stringify(v.map(s=>Array.from(new Intl.Segmenter('en',{granularity:'grapheme'}).segment(s),x=>x.segment))))"
  expected=json.loads(subprocess.check_output(['node','-e',script,json.dumps(vectors)],text=True))
  for value,want in zip(vectors,expected):
   raw=value.encode();offset=0;got=[]
   while offset<len(raw):
    end=self.lib.ui_next_grapheme(raw,len(raw),offset);self.assertGreater(end,offset);got.append(raw[offset:end].decode());offset=end
   self.assertEqual(got,want,value)
  for s,width in [('abc',3),('e\u0301',1),('世界',4),('👩🏽\u200d💻',2),('🇱🇹',2),('❤️',2),('\n',0)]:
   b=s.encode();self.assertEqual(self.lib.ui_text_width(b,len(b)),width,s)

class ProductionPTYEditorTests(unittest.TestCase):
 """Real static executable: raw terminal bytes through renderer/editor to HTTP."""
 @classmethod
 def setUpClass(cls):
  subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def test_edit_paste_history_and_terminal_restore(self):
  import os,pty,fcntl,struct,termios,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  with tempfile.TemporaryDirectory(prefix='qwen-ui-input-pty-') as d:
   env=dict(os.environ,HOME=d,TERM='xterm-256color',QWEN_API_KEY='fake-ui-editor-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   with ConcurrentServer(lambda req:answer('fixture-final')) as server:
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0))
    original=termios.tcgetattr(slave);output=bytearray()
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--base-url',server.url],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core)
    def drain(seconds=.02):
     ready,_,_=select.select([master],[],[],seconds)
     if ready:
      try:output.extend(os.read(master,262144))
      except OSError:pass
    def until(pred,reason,seconds=4):
     end=time.monotonic()+seconds
     while not pred() and time.monotonic()<end and proc.poll() is None:drain()
     self.assertTrue(pred(),reason+repr(bytes(output[-1500:])))
    def response(count):
     until(lambda:len(server.records)>=count,'missing model request')
     end=time.monotonic()+.2
     while time.monotonic()<end:drain()
    try:
     until(lambda:b'Type your message' in output,'missing composer')
     os.write(master,b'ac\x1b[Db\r');response(1)
     self.assertEqual(server.records[0][1]['messages'][-1]['content'],'abc')
     paste=b'\x1b[200~line one\r\n'+ '👩🏽\u200d💻世'.encode()+b'\x1b[201~'
     for i in range(0,len(paste),2):os.write(master,paste[i:i+2]);drain(.005)
     # Even fragmented embedded newlines must not create model calls.
     end=time.monotonic()+.15
     while time.monotonic()<end:drain()
     self.assertEqual(len(server.records),1)
     os.write(master,b'\r');response(2)
     self.assertEqual(server.records[1][1]['messages'][-1]['content'],'line one\n👩🏽\u200d💻世')
     # Empty draft Up recalls at byte0; End/Backspace edits recalled first row.
     os.write(master,b'\x1b[A\x05\x7f\r');response(3)
     self.assertEqual(server.records[2][1]['messages'][-1]['content'],'line on\n👩🏽\u200d💻世')
     os.write(master,b'/quit\r');proc.wait(timeout=3)
     self.assertEqual(proc.returncode,0)
     self.assertEqual(termios.tcgetattr(slave),original)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)

 def test_production_mouse_wheel_fragments_scroll_without_input(self):
  import os,pty,fcntl,struct,termios,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  from test_ui_renderer import Screen
  with tempfile.TemporaryDirectory(prefix='qwen-ui-mouse-') as d:
   env=dict(os.environ,HOME=d,TERM='xterm-256color',QWEN_API_KEY='fake-mouse-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   content='\n'.join(f'mouse-line {n:02d}' for n in range(45))
   with ConcurrentServer(lambda req:answer(content)) as server:
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));original=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--base-url',server.url],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);output=bytearray()
    def drain(seconds=.02):
     if select.select([master],[],[],seconds)[0]:
      try:output.extend(os.read(master,262144))
      except OSError:pass
    def screen():
     raw=bytes(output);start=raw.rfind(b'\x1b[H');view=Screen(80,24);view.feed(raw[start:] if start>=0 else raw);return '\n'.join(view.lines())
    def until(pred,message,seconds=4):
     end=time.monotonic()+seconds
     while not pred() and time.monotonic()<end and proc.poll() is None:drain()
     self.assertTrue(pred(),message+repr(screen()))
    def settle(seconds=.15):
     end=time.monotonic()+seconds
     while time.monotonic()<end:drain()
    try:
     until(lambda:b'Type your message' in output,'missing composer')
     self.assertIn(b'\x1b[?1002h',output);self.assertIn(b'\x1b[?1006h',output)
     os.write(master,b'large output\r');until(lambda:len(server.records)==1 and 'mouse-line 44' in screen(),'missing transcript tail');settle()
     os.write(master,b'\x1b[<64;');settle(.08);os.write(master,b'5;5M');settle()
     self.assertNotIn('mouse-line 44',screen());self.assertIn('mouse-line 41',screen())
     os.write(master,b'\x1b[<65;5;5M');settle();self.assertIn('mouse-line 44',screen())
     # One OS read can contain multiple packets; every3-line tick must count.
     os.write(master,b'\x1b[<64;5;5M'*3);settle();self.assertNotIn('mouse-line 36',screen());self.assertIn('mouse-line 35',screen())
     os.write(master,b'\x1b[<65;5;5M'*3);settle();self.assertIn('mouse-line 44',screen())
     os.write(master,b'\x1b[1;5H');settle();self.assertIn('>_ Qwen Code',screen())
     os.write(master,b'\x1b[1;5F');settle();self.assertIn('mouse-line 44',screen())
     os.write(master,b'\x1b[<64;5;5m\x1b[<0;5;5Mafter mouse\r')
     until(lambda:len(server.records)==2,'mouse packet leaked or ate prompt');settle()
     self.assertEqual(server.records[1][1]['messages'][-1]['content'],'after mouse')
     os.write(master,b'/quit\r');proc.wait(timeout=3)
     while select.select([master],[],[],0)[0]:
      try:output.extend(os.read(master,262144))
      except OSError:break
     self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
     self.assertIn(b'\x1b[?1002l',output);self.assertIn(b'\x1b[?1006l',output)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)

if __name__=='__main__':unittest.main()
