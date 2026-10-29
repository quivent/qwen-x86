"""Read-only native real-session catalog: filesystem and JSON, no UI mock rows."""
import ctypes as C,json,os,pathlib,subprocess,tempfile,time,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class SessionCatalogTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();base=pathlib.Path(cls.tmp.name)
  for name in ['ui_sessions','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared',str(base/'ui_sessions.o'),str(base/'json.o'),'-o',str(base/'sessions.so')],check=True)
  cls.lib=C.CDLL(str(base/'sessions.so'));cls.lib.ui_session_catalog.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t];cls.lib.ui_session_catalog.restype=C.c_int64
  cls.lib.ui_session_preview.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t];cls.lib.ui_session_preview.restype=C.c_int64
  cls.lib.ui_session_mutations_config.argtypes=[C.c_char_p,C.c_int];cls.lib.ui_session_mutations_config.restype=C.c_int64
  cls.lib.ui_session_rename.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t];cls.lib.ui_session_rename.restype=C.c_int64
  cls.lib.ui_session_delete.argtypes=[C.c_char_p];cls.lib.ui_session_delete.restype=C.c_int64
  cls.lib.ui_session_delete_many.argtypes=[C.c_void_p,C.c_size_t,C.c_void_p];cls.lib.ui_session_delete_many.restype=C.c_int64
  cls.lib.ui_relative_time.argtypes=[C.c_int64,C.c_int64,C.c_void_p,C.c_size_t];cls.lib.ui_relative_time.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):
  self.tmpdir=tempfile.TemporaryDirectory();self.addCleanup(self.tmpdir.cleanup);self.home=pathlib.Path(self.tmpdir.name);self.directory=self.home/'.local/state/qwen-x86';self.directory.mkdir(parents=True)
 def file(self,name,text='test prompt',mtime=1000):
  p=self.directory/('session-'+name+'.json');p.write_text(json.dumps([{'role':'assistant','content':'skip'},{'role':'user','content':text}],ensure_ascii=False));os.utime(p,ns=(mtime,mtime));return p
 def catalog(self,cap=64,home=None):
  items=(C.c_void_p*(64*3))();n=self.lib.ui_session_catalog(os.fsencode(home or self.home),items,cap)
  if n<0:return n,[]
  return n,[tuple(C.string_at(items[i*3+j]).decode() for j in range(3)) for i in range(n)]
 def test_real_sorted_labels_and_paths_read_only(self):
  old=self.file('old','old first',1000);new=self.file('new','new\nfirst\tline',3000);middle=self.file('middle','middle',2000)
  before={p:p.read_bytes() for p in self.directory.iterdir()}
  n,rows=self.catalog();self.assertEqual(n,3);self.assertEqual([x[2] for x in rows],[str(new),str(middle),str(old)])
  self.assertEqual(rows[0][0],'new first line');self.assertEqual(rows[0][1],f'{int(time.time())//2592000} months ago');self.assertNotIn(str(new),rows[0][1])
  self.assertEqual({p:p.read_bytes() for p in self.directory.iterdir()},before)
 def test_relative_time_source_boundaries_and_capacity(self):
  now=2000000000
  cases=[(-1,'just now'),(0,'just now'),(59,'just now'),(60,'1 minute ago'),(119,'1 minute ago'),(120,'2 minutes ago'),(3599,'59 minutes ago'),(3600,'1 hour ago'),(7199,'1 hour ago'),(7200,'2 hours ago'),(86399,'23 hours ago'),(86400,'1 day ago'),(172800,'2 days ago'),(604799,'6 days ago'),(604800,'1 week ago'),(1209600,'2 weeks ago'),(2591999,'4 weeks ago'),(2592000,'1 month ago'),(5184000,'2 months ago')]
  for age,expected in cases:
   with self.subTest(age=age):
    out=C.create_string_buffer(128);n=self.lib.ui_relative_time(now,now-age,out,len(out));self.assertEqual(n,len(expected));self.assertEqual(out.value.decode(),expected)
    exact=C.create_string_buffer(len(expected)+1);self.assertEqual(self.lib.ui_relative_time(now,now-age,exact,len(exact)),len(expected))
    short=C.create_string_buffer(b'unchanged',128);self.assertEqual(self.lib.ui_relative_time(now,now-age,short,len(expected)),-28);self.assertEqual(short.value,b'unchanged')
 def test_catalog_fresh_and_future_timestamps_use_just_now(self):
  fresh=self.file('fresh','fresh',time.time_ns());future=self.file('future','future',time.time_ns()+86400*1000000000)
  n,rows=self.catalog();self.assertEqual(n,2);self.assertEqual([row[2] for row in rows],[str(future),str(fresh)]);self.assertEqual([row[1] for row in rows],['just now','just now'])
 def test_invalid_symlink_fifo_oversize_and_nonarray_skipped(self):
  valid=self.file('valid');(self.directory/'session-malformed.json').write_text('[broken')
  (self.directory/'session-object.json').write_text('{}');(self.directory/'session-oversize.json').write_bytes(b' '*(1048576+1))
  (self.directory/'session-link.json').symlink_to(valid);os.mkfifo(self.directory/'session-fifo.json')
  (self.directory/'not-session.json').write_text('[]')
  n,rows=self.catalog();self.assertEqual(n,1);self.assertEqual(rows[0][2],str(valid))
 def test_newest_bounded_set_and_repeat_no_fd_leak(self):
  for i in range(75):self.file(str(i),f'prompt {i}',1000000000+i)
  n,rows=self.catalog();self.assertEqual(n,64);self.assertEqual([x[0] for x in rows],[f'prompt {i}' for i in range(74,10,-1)])
  n,rows=self.catalog(3);self.assertEqual(n,3);self.assertEqual([x[0] for x in rows],['prompt 74','prompt 73','prompt 72'])
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(8):self.assertEqual(self.catalog(2)[0],2)
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)
 def test_utf8_100_codepoint_bound_and_empty_fallback(self):
  self.file('unicode','👩'*105+'tail',300);p=self.directory/'session-empty.json';p.write_text('[]');os.utime(p,ns=(100,100))
  n,rows=self.catalog();self.assertEqual(n,2);self.assertEqual(rows[0][0],'👩'*100);self.assertEqual(rows[1][0],'Untitled session')
 def test_missing_directory_and_component_symlink(self):
  missing=self.home/'new-home';missing.mkdir();self.assertEqual(self.catalog(home=missing)[0],0)
  alternate=self.home/'linked-home';alternate.mkdir();(alternate/'.local').symlink_to(self.home/'.local',target_is_directory=True)
  self.assertLess(self.catalog(home=alternate)[0],0)
  self.assertEqual(self.lib.ui_session_catalog(b'relative',None,64),-22)
  self.assertEqual(self.lib.ui_session_catalog(None,None,0),0)

 def test_read_only_preview_transcript_order_unicode_and_catalog_lifetime(self):
  p=self.directory/'session-preview.json';payload=[{'role':'system','content':'do not show system'},{'role':'user','content':'first λ'},{'role':'assistant','content':'answer 👩'},{'role':'assistant','content':None,'tool_calls':[{'id':'preview-must-not-execute','type':'function','function':{'name':'run_shell','arguments':json.dumps({'command':'touch '+str(self.home/'must-not-run')})}}]},{'role':'tool','content':'real result'},{'role':'user','content':'last'}];p.write_text(json.dumps(payload,ensure_ascii=False));before=(p.read_bytes(),p.stat().st_mtime_ns)
  items=(C.c_void_p*(64*3))();self.assertEqual(self.lib.ui_session_catalog(os.fsencode(self.home),items,64),1);label=C.string_at(items[0]);path=C.string_at(items[2])
  out=C.create_string_buffer(1048577);n=self.lib.ui_session_preview(os.fsencode(p),out,len(out));self.assertGreater(n,0)
  self.assertEqual(out.raw[:n].decode(),'> User\nfirst λ\n\n◆ Qwen\nanswer 👩\n\nTool\nreal result\n\n> User\nlast\n\n')
  self.assertEqual((p.read_bytes(),p.stat().st_mtime_ns),before);self.assertFalse((self.home/'must-not-run').exists())
  self.assertEqual(C.string_at(items[0]),label);self.assertEqual(C.string_at(items[2]),path)
 def test_preview_bounds_malformed_symlinks_fifo_and_fd_cleanup(self):
  valid=self.file('valid','preview text');out=C.create_string_buffer(b'unchanged',1048577)
  self.assertLess(self.lib.ui_session_preview(os.fsencode(valid),out,4),0);self.assertEqual(out.value,b'unchanged')
  for name,source in [('malformed','[broken'),('object','{}'),('oversize','x'*1048577)]:
   p=self.directory/f'session-{name}.json';p.write_text(source);self.assertLess(self.lib.ui_session_preview(os.fsencode(p),out,len(out)),0)
  link=self.directory/'session-symlink.json';link.symlink_to(valid);self.assertLess(self.lib.ui_session_preview(os.fsencode(link),out,len(out)),0)
  fifo=self.directory/'session-fifo.json';os.mkfifo(fifo);self.assertLess(self.lib.ui_session_preview(os.fsencode(fifo),out,len(out)),0)
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(8):self.assertGreater(self.lib.ui_session_preview(os.fsencode(valid),out,len(out)),0)
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)
  empty=self.directory/'session-empty.json';empty.write_text('[]');n=self.lib.ui_session_preview(os.fsencode(empty),out,len(out));self.assertIn(b'No text messages',out.raw[:n])

 def test_attachment_array_catalog_and_preview_show_only_prompt_text(self):
  p=self.directory/'session-attachments.json';p.write_text(json.dumps([{'role':'user','content':[{'type':'text','text':'real @image.png question λ'},{'type':'image_url','image_url':{'url':'data:image/png;base64,SECRETBASE64'}},{'type':'text','text':'ATTACHMENT BODY MUST NOT LABEL'}]},{'role':'assistant','content':'answer'}]))
  self.assertEqual(self.catalog()[1][0][0],'real @image.png question λ')
  out=C.create_string_buffer(1048577);n=self.lib.ui_session_preview(os.fsencode(p),out,len(out));self.assertGreater(n,0);self.assertIn('real @image.png question λ',out.value.decode());self.assertNotIn(b'SECRETBASE64',out.value);self.assertNotIn(b'ATTACHMENT BODY',out.value)

 def test_rename_persists_title_without_touching_transcript(self):
  p=self.file('rename','original prompt');before=(p.read_bytes(),p.stat().st_mtime_ns)
  self.assertEqual(self.lib.ui_session_mutations_config(os.fsencode(self.home),1),0)
  title='Renamed λ 👩 with "quotes"'.encode()
  self.assertEqual(self.lib.ui_session_rename(os.fsencode(p),title,len(title)),0)
  sidecar=pathlib.Path(str(p)+'.title');self.assertEqual(json.loads(sidecar.read_text()),title.decode());self.assertEqual(sidecar.stat().st_mode&0o777,0o600)
  self.assertEqual(self.catalog()[1][0][0],title.decode());self.assertEqual((p.read_bytes(),p.stat().st_mtime_ns),before)
  # A later real transcript save preserves the independent title.
  p.write_text('[{"role":"user","content":"later save"}]');self.assertEqual(self.catalog()[1][0][0],title.decode())
  self.assertFalse(list(self.directory.glob('.title-*')))
 def test_session_mutations_confinement_denial_invalid_titles_and_links(self):
  p=self.file('safe');self.lib.ui_session_mutations_config(os.fsencode(self.home),0)
  self.assertEqual(self.lib.ui_session_delete(os.fsencode(p)),-13);self.assertEqual(self.lib.ui_session_rename(os.fsencode(p),b'new',3),-13)
  self.lib.ui_session_mutations_config(os.fsencode(self.home),1)
  outside=self.home/'session-outside.json';outside.write_text('[]')
  for path in [outside,self.directory/'../session-safe.json',self.directory/'other.json']:
   self.assertLess(self.lib.ui_session_delete(os.fsencode(path)),0)
  link=self.directory/'session-link.json';link.symlink_to(p)
  fifo=self.directory/'session-fifo.json';os.mkfifo(fifo)
  for path in [link,fifo]:self.assertLess(self.lib.ui_session_delete(os.fsencode(path)),0)
  for title in [b'',b'new\nname',b'bad\x00name',b'\xff',b'a'*401]:self.assertLess(self.lib.ui_session_rename(os.fsencode(p),title,len(title)),0)
  self.assertTrue(p.exists());self.assertTrue(outside.exists());self.assertFalse(pathlib.Path(str(p)+'.title').exists())
  # A sidecar symlink is replaced atomically; its target is never opened/written.
  titlepath=pathlib.Path(str(p)+'.title');titlepath.symlink_to(outside)
  self.assertEqual(self.lib.ui_session_rename(os.fsencode(p),b'safe title',10),0);self.assertEqual(outside.read_text(),'[]');self.assertFalse(titlepath.is_symlink())
 def test_multiselect_delete_reports_individual_results_and_removes_title(self):
  p=self.file('first');q=self.file('second');agentstate=pathlib.Path(str(p)+'.agent.json');agentstate.write_text('{"kind":"acp","sessionId":"private"}');outside=self.home/'session-outside.json';outside.write_text('[]')
  self.lib.ui_session_mutations_config(os.fsencode(self.home),1);self.assertEqual(self.lib.ui_session_rename(os.fsencode(p),b'title',5),0)
  paths=(C.c_char_p*3)(os.fsencode(p),os.fsencode(outside),os.fsencode(q));statuses=(C.c_int64*3)()
  self.assertEqual(self.lib.ui_session_delete_many(paths,3,statuses),2);self.assertEqual([statuses[0],statuses[2]],[0,0]);self.assertLess(statuses[1],0)
  self.assertFalse(p.exists());self.assertFalse(q.exists());self.assertFalse(pathlib.Path(str(p)+'.title').exists());self.assertFalse(agentstate.exists());self.assertTrue(outside.exists())
  self.assertEqual(self.lib.ui_session_delete_many(paths,65,statuses),-22)
 def test_sidecar_validation_and_repeated_mutations_do_not_leak_fds(self):
  p=self.file('title','fallback');sidecar=pathlib.Path(str(p)+'.title')
  for content in ['{}','"bad\\nname"','"'+('x'*401)+'"','[broken']:
   sidecar.write_text(content);self.assertEqual(self.catalog()[1][0][0],'fallback')
  sidecar.unlink();os.mkfifo(sidecar);self.assertEqual(self.catalog()[1][0][0],'fallback');sidecar.unlink()
  self.lib.ui_session_mutations_config(os.fsencode(self.home),1);before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for i in range(12):
   self.assertEqual(self.lib.ui_session_rename(os.fsencode(p),b'repeated',8),0);self.assertEqual(self.catalog()[1][0][0],'repeated')
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)

class SessionPickerPTYTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def test_resume_picker_replaces_current_conversation(self):
  import pty,fcntl,termios,struct,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  with tempfile.TemporaryDirectory(prefix='qwen-session-picker-') as d:
   home=pathlib.Path(d);directory=home/'.local/state/qwen-x86';directory.mkdir(parents=True)
   saved=directory/'session-real.json';saved.write_text(json.dumps([{'role':'user','content':'saved user prompt'},{'role':'assistant','content':'saved assistant answer'}]));before=saved.read_bytes()
   env=dict(os.environ,HOME=d,TERM='xterm-256color',QWEN_API_KEY='fake-picker-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   with ConcurrentServer(lambda req:answer('fixture complete')) as server:
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));original=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--base-url',server.url],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core)
    output=bytearray()
    def drain():
     if select.select([master],[],[],.02)[0]:
      try:output.extend(os.read(master,262144))
      except OSError:pass
    def until(pred,message,seconds=4):
     end=time.monotonic()+seconds
     while not pred() and time.monotonic()<end and proc.poll() is None:drain()
     self.assertTrue(pred(),message+repr(bytes(output[-1800:])))
    def settle():
     end=time.monotonic()+.2
     while time.monotonic()<end:drain()
    try:
     until(lambda:b'Type your message' in output,'missing composer')
     os.write(master,b'before-switch\r');until(lambda:len(server.records)==1,'initial request');settle()
     marker=len(output);os.write(master,b'/resume\r')
     until(lambda:b'saved user prompt' in output[marker:],'real session catalog row missing')
     os.write(master,b'\r');settle();os.write(master,b'after-switch\r')
     until(lambda:len(server.records)==2,'request after selecting session');settle()
     messages=server.records[1][1]['messages'];contents=[x['content'] for x in messages if x['role']!='system']
     self.assertEqual(contents,['saved user prompt','saved assistant answer','after-switch'])
     self.assertEqual(saved.read_bytes(),before,'--no-save resume modified original session')
     os.write(master,b'/quit\r');proc.wait(timeout=3);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)

 def test_space_preview_scroll_back_is_read_only_until_enter_resume(self):
  import pty,fcntl,termios,struct,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  from test_ui_renderer import Screen
  with tempfile.TemporaryDirectory(prefix='qwen-session-preview-pty-') as d:
   home=pathlib.Path(d);directory=home/'.local/state/qwen-x86';directory.mkdir(parents=True)
   saved=directory/'session-preview.json';assistant='saved assistant answer\n'+'\n'.join(f'preview line {n:02d}' for n in range(30))
   saved.write_text(json.dumps([{'role':'user','content':'saved user prompt'},{'role':'assistant','content':assistant}]));before=(saved.read_bytes(),saved.stat().st_mtime_ns)
   other=directory/'session-unrelated.json';other.write_text(json.dumps([{'role':'user','content':'unrelated session label'},{'role':'assistant','content':'other answer'}]));os.utime(other,ns=(0,0))
   env=dict(os.environ,HOME=d,TERM='xterm-256color',QWEN_API_KEY='fake-preview-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   with ConcurrentServer(lambda req:answer('fixture response')) as server:
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));original=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--base-url',server.url],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);output=bytearray()
    def drain():
     if select.select([master],[],[],.02)[0]:
      try:output.extend(os.read(master,262144))
      except OSError:pass
    def view():
     raw=bytes(output);start=raw.rfind(b'\x1b[H');screen=Screen(80,24);screen.feed(raw[start:] if start>=0 else raw);return '\n'.join(screen.lines())
    def until(pred,message,seconds=4):
     end=time.monotonic()+seconds
     while not pred() and time.monotonic()<end and proc.poll() is None:drain()
     self.assertTrue(pred(),message+repr(view()))
    def settle():
     end=time.monotonic()+.2
     while time.monotonic()<end:drain()
    def request(text,count):
     os.write(master,text.encode()+b'\r');until(lambda:len(server.records)==count,'model request missing');settle()
    try:
     until(lambda:b'Type your message' in output,'missing composer');request('before preview',1)
     os.write(master,b'/resume\r');until(lambda:'saved user prompt' in view(),'session picker row missing')
     os.write(master,b' ');until(lambda:'saved assistant answer' in view(),'Space did not read real session preview')
     self.assertEqual(len(server.records),1);self.assertEqual((saved.read_bytes(),saved.stat().st_mtime_ns),before)
     os.write(master,b'\x1b[6~'*8);until(lambda:'preview line 29' in view(),'preview did not scroll to real transcript tail')
     os.write(master,b'\x1b');settle();self.assertIn('saved user prompt',view());self.assertNotIn('preview line 29',view())
     os.write(master,b'\x1b');settle();request('before accept',2)
     active=[x['content'] for x in server.records[1][1]['messages'] if x['role']!='system']
     self.assertEqual(active,['before preview','fixture response','before accept'],'preview changed active history before acceptance')
     os.write(master,b'/resume\r');until(lambda:'saved user prompt' in view(),'picker reopen failed')
     os.write(master,b'/SAVED');until(lambda:'Search: SAVED' in view(),'slash did not enter real case-insensitive search')
     self.assertNotIn('unrelated session label',view());self.assertEqual(len(server.records),2)
     os.write(master,b'\r');until(lambda:'Filter: SAVED' in view(),'Enter resumed instead of committing search to filtered list')
     self.assertIn('saved user prompt',view());self.assertEqual(len(server.records),2)
     os.write(master,b' ');until(lambda:'saved assistant answer' in view(),'Space did not preview committed filtered selection')
     self.assertEqual(len(server.records),2);self.assertEqual((saved.read_bytes(),saved.stat().st_mtime_ns),before)
     os.write(master,b'\x1b');until(lambda:'Filter: SAVED' in view(),'Escape did not retain committed filter in picker')
     self.assertIn('saved user prompt',view());self.assertEqual(len(server.records),2)
     os.write(master,b'\r');settle();request('after accept',3)
     selected=[x['content'] for x in server.records[2][1]['messages'] if x['role']!='system']
     self.assertEqual(selected,['saved user prompt',assistant,'after accept'])
     self.assertEqual((saved.read_bytes(),saved.stat().st_mtime_ns),before)
     os.write(master,b'/quit\r');proc.wait(timeout=3);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)

if __name__=='__main__':unittest.main()
