"""Native user shell mode and source-format history, no model delegation."""
import ctypes as C,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ShellModeTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  for name in ['ui_shell','tools','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared',*[str(base/f'{x}.o') for x in ['ui_shell','tools','json']],'-o',str(base/'shell.so')],check=True)
  cls.lib=C.CDLL(str(base/'shell.so'))
  for name,args in {'ui_shell_parse_history':[C.c_void_p,C.c_size_t,C.c_void_p],'ui_shell_execute':[C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t],'ui_shell_history_message':[C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t],'ui_shell_history_add':[C.c_void_p,C.c_size_t],'tools_set_workspace':[C.c_char_p],'tools_set_approval':[C.c_void_p,C.c_size_t],'ui_shell_history_config':[C.c_char_p,C.c_char_p,C.c_size_t]}.items():
   fn=getattr(cls.lib,name);fn.argtypes=args;fn.restype=C.c_int64
  for name in ['ui_shell_history_prev','ui_shell_history_next']:getattr(cls.lib,name).restype=C.c_void_p
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.cwd=pathlib.Path(self.tmp.name);self.lib.tools_set_workspace(str(self.cwd).encode());self.lib.tools_set_approval(None,1);self.lib.ui_shell_history_clear();self.lib.ui_shell_history_config(None,None,0)
 def execute(self,cmd):
  b=cmd.encode();out=C.create_string_buffer(65537);n=self.lib.ui_shell_execute(b,len(b),out,len(out));self.assertGreaterEqual(n,0);return out.raw[:n].decode()
 def message(self,cmd,result):
  if isinstance(cmd,str):cmd=cmd.encode()
  if isinstance(result,str):result=result.encode()
  out=C.create_string_buffer(131072);n=self.lib.ui_shell_history_message(cmd,len(cmd),result,len(result),out,len(out));self.assertGreaterEqual(n,0);return out.raw[:n].decode()
 def test_real_execution_output_errors_and_stateless_cwd(self):
  self.assertIn('real output',self.execute("printf 'real output'; printf changed > marker"));self.assertEqual((self.cwd/'marker').read_text(),'changed')
  self.assertIn('Error',self.execute('exit 7'))
  self.execute('cd /tmp');self.assertEqual(self.execute('pwd').strip(),str(self.cwd))
 def test_no_permission_bypass_in_module(self):
  self.lib.tools_set_approval(None,0);self.assertIn('denied',self.execute('touch must-not-exist').lower());self.assertFalse((self.cwd/'must-not-exist').exists())
 def test_exact_source_history_and_unicode_truncation(self):
  self.assertEqual(self.message('printf hi','  hi\n'),'I ran the following shell command:\n```sh\nprintf hi\n```\n\nThis produced the following result:\n```\nhi\n```')
  result='👩'*5001;msg=self.message('test',result);self.assertIn('👩'*5000+'\n... (truncated)',msg);self.assertNotIn('👩'*5001,msg)
  self.assertIn('(Command produced no output)',self.message('true',' \n\t'))
  for result in [b'a\0b',b'\xff']:self.assertIn('binary output',self.message('test',result))
 def test_separate_mru_history_dedup_and_bound(self):
  self.assertIsNone(self.lib.ui_shell_history_next())
  self.lib.ui_shell_history_add(b' \n\t',3);self.assertIsNone(self.lib.ui_shell_history_prev())
  for i in range(105):
   b=f'command {i}'.encode();self.lib.ui_shell_history_add(b,len(b))
  for i in range(104,4,-1):self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),f'command {i}'.encode())
  self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),b'command 5')
  self.lib.ui_shell_history_add(b'command 50',10);self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),b'command 50')
  self.assertEqual(C.string_at(self.lib.ui_shell_history_next()),b'')
  self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),b'command 50')
  self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),b'command 104')

 def test_parse_source_wrapper_roundtrip_and_ordinary_fallback(self):
  results=['simple','output with ``` fences\nand more','first\n```\n\nThis produced the following result:\n```\nsecond','λ👩\n```']
  for result in results:
   raw=self.message('printf hi',result).encode();spans=(C.c_uint64*4)()
   self.assertEqual(self.lib.ui_shell_parse_history(raw,len(raw),spans),1)
   self.assertEqual(C.string_at(spans[0],spans[1]),b'printf hi')
   self.assertEqual(C.string_at(spans[2],spans[3]).decode(),result)
  valid=self.message('test','result').encode()
  for raw in [b'ordinary user text',valid[:-1],valid+b'extra',valid.replace(b'following result',b'following output'),valid.replace(b'command:',b'command?',1),valid.replace(b'result',b'\xff',1),b'I ran the following shell command:\n```sh\nnot a full wrapper']:
   spans=(C.c_uint64*4)(1,2,3,4);self.assertEqual(self.lib.ui_shell_parse_history(raw,len(raw),spans),0,raw);self.assertEqual(list(spans),[1,2,3,4])
 def test_private_per_project_persistence_and_no_save(self):
  import os,json,stat
  home=self.cwd/'home';home.mkdir();workspace=self.cwd/'workspace';workspace.mkdir()
  self.assertEqual(self.lib.ui_shell_history_config(os.fsencode(home),os.fsencode(workspace),1),0)
  self.lib.ui_shell_history_add(b'printf first',12);self.lib.ui_shell_history_add(b'printf second',13);self.lib.ui_shell_history_add(b'printf first',12)
  files=list(home.rglob('shell-history-*.json'));self.assertEqual(len(files),1)
  self.assertEqual(json.loads(files[0].read_text()),['printf second','printf first']);self.assertEqual(stat.S_IMODE(files[0].stat().st_mode),0o600)
  self.assertEqual(list(files[0].parent.glob('*.tmp-*')),[])
  self.lib.ui_shell_history_clear();self.assertEqual(self.lib.ui_shell_history_config(os.fsencode(home),os.fsencode(workspace),0),2)
  self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),b'printf first')
  before=files[0].read_bytes();self.lib.ui_shell_history_add(b'not saved',9);self.assertEqual(files[0].read_bytes(),before)
  other=self.cwd/'other';other.mkdir();self.assertEqual(self.lib.ui_shell_history_config(os.fsencode(home),os.fsencode(other),1),0)
  self.lib.ui_shell_history_add(b'other project',13);self.assertEqual(len(list(home.rglob('shell-history-*.json'))),2)
  self.lib.ui_shell_history_config(None,None,0)
 def test_persistence_corruption_symlink_and_descriptor_cleanup(self):
  import os
  home=self.cwd/'home';home.mkdir();workspace=self.cwd/'workspace';workspace.mkdir()
  self.lib.ui_shell_history_config(os.fsencode(home),os.fsencode(workspace),1);self.lib.ui_shell_history_add(b'good command',12)
  path=next(home.rglob('shell-history-*.json'));path.write_text('["new", 123]')
  self.assertLess(self.lib.ui_shell_history_load(),0);self.assertEqual(C.string_at(self.lib.ui_shell_history_prev()),b'good command')
  target=self.cwd/'target';target.write_text('["outside"]');path.unlink();path.symlink_to(target)
  self.assertLess(self.lib.ui_shell_history_load(),0);self.assertEqual(target.read_text(),'["outside"]')
  path.unlink();self.lib.ui_shell_history_save()
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(5):self.lib.ui_shell_history_load();self.lib.ui_shell_history_save()
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)
  self.assertFalse(list(path.parent.glob('*.tmp-*')));self.lib.ui_shell_history_config(None,None,0)

class ShellModePTYTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def setUp(self):
  import os,pty,fcntl,struct,termios
  from test_cli import ConcurrentServer,answer,disable_core
  self.temp=tempfile.TemporaryDirectory(prefix='qwen-shell-pty-');self.addCleanup(self.temp.cleanup)
  base=pathlib.Path(self.temp.name);self.home=base/'home';self.home.mkdir();self.cwd=base/'work';self.cwd.mkdir()
  env=dict(os.environ,HOME=str(self.home),TERM='xterm-256color',QWEN_API_KEY='fake-shell-pty-key')
  for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
  self.env=env
  self.server=ConcurrentServer(lambda req:answer('normal model response'));self.server.__enter__();self.addCleanup(lambda:self.server.__exit__(None,None,None))
  self.master,self.slave=pty.openpty();fcntl.ioctl(self.slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));self.original=termios.tcgetattr(self.slave)
  self.addCleanup(lambda:(os.close(self.master),os.close(self.slave)))
  self.proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--cwd',str(self.cwd),'--base-url',self.server.url],stdin=self.slave,stdout=self.slave,stderr=self.slave,env=env,preexec_fn=disable_core)
  def stop():
   if self.proc.poll() is None:self.proc.kill();self.proc.wait(timeout=2)
  self.addCleanup(stop);self.output=bytearray();self.until(lambda:b'Type your message' in self.output,'missing composer')
 def drain(self):
  import select,os
  if select.select([self.master],[],[],.02)[0]:
   try:self.output.extend(os.read(self.master,262144))
   except OSError:pass
 def until(self,predicate,message,seconds=4):
  import time
  end=time.monotonic()+seconds
  while not predicate() and time.monotonic()<end and self.proc.poll() is None:self.drain()
  self.assertTrue(predicate(),message+repr(bytes(self.output[-2000:])))
 def settle(self):
  import time
  end=time.monotonic()+.2
  while time.monotonic()<end:self.drain()
 def send(self,data):
  import os
  os.write(self.master,data)
 def quit(self):
  import termios
  self.send(b'/quit\r');self.proc.wait(timeout=3);self.assertEqual(self.proc.returncode,0);self.assertEqual(termios.tcgetattr(self.slave),self.original)
 def test_direct_shell_no_model_call_and_separate_history(self):
  command=b'printf x >> executions; printf shell-result'
  self.send(b'!'+command+b'\r');self.until(lambda:(self.cwd/'executions').exists(),'direct shell command did not run');self.settle()
  self.assertEqual(len(self.server.records),0,'shell mode delegated execution to model')
  self.assertEqual((self.cwd/'executions').read_text(),'x');self.assertIn(b'shell-result',self.output)
  self.assertEqual(list(self.home.rglob('shell-history-*.json')),[],'--no-save wrote shell MRU')
  self.send(b'\x1b');self.settle();self.send(b'normal question\r')
  self.until(lambda:len(self.server.records)==1,'normal prompt after shell mode');self.settle()
  history=[x for x in self.server.records[0][1]['messages'] if x['role']!='system']
  self.assertEqual(history[-1]['content'],'normal question');self.assertEqual(len(history),2)
  self.assertTrue(all(x['role']=='user' for x in history),'shell invented assistant/tool protocol messages')
  self.assertEqual(history[0]['content'],'I ran the following shell command:\n```sh\n'+command.decode()+'\n```\n\nThis produced the following result:\n```\nshell-result\n```')
  self.send(b'!\x1b[A\r');self.until(lambda:(self.cwd/'executions').read_text()=='xx','shell command history was polluted');self.settle()
  self.assertEqual(len(self.server.records),1)
  self.send(b'\x1b');self.settle();self.send(b'\x1b[A\r')
  self.until(lambda:len(self.server.records)==2,'normal input history polluted by shell');self.settle()
  self.assertEqual(self.server.records[1][1]['messages'][-1]['content'],'normal question');self.quit()
 def test_shell_mru_survives_process_restart_and_no_save_is_read_only(self):
  import json,stat
  from test_cli import disable_core
  self.quit()
  def restart(no_save=False):
   args=[str(ROOT/'qwen-x86'),'--cwd',str(self.cwd),'--base-url',self.server.url]
   if no_save:args.append('--no-save')
   # A reused PTY master can still contain the exited process's ready screen.
   while __import__('select').select([self.master],[],[],.02)[0]:__import__('os').read(self.master,262144)
   self.output.clear();self.proc=subprocess.Popen(args,stdin=self.slave,stdout=self.slave,stderr=self.slave,env=self.env,preexec_fn=disable_core)
   self.until(lambda:b'Type your message' in self.output,'restart composer missing')
  restart();command=b'printf x >> persistent-marker'
  self.send(b'!'+command+b'\r');self.until(lambda:(self.cwd/'persistent-marker').exists(),'persistent shell command not run');self.settle()
  paths=list(self.home.rglob('shell-history-*.json'));self.assertEqual(len(paths),1)
  self.assertEqual(json.loads(paths[0].read_text()),[command.decode()]);self.assertEqual(stat.S_IMODE(paths[0].stat().st_mode),0o600)
  self.send(b'\x1b');self.settle();self.quit()
  before=(paths[0].read_bytes(),paths[0].stat().st_mtime_ns)
  restart(no_save=True);self.send(b'!\x1b[A\r')
  self.until(lambda:(self.cwd/'persistent-marker').read_text()=='xx','shell MRU did not survive real process restart');self.settle()
  self.assertEqual((paths[0].read_bytes(),paths[0].stat().st_mtime_ns),before,'--no-save rewrote persisted MRU')
  self.assertEqual(len(self.server.records),0)
  self.send(b'\x1b');self.settle();self.quit()
 def test_shell_cancellation_returns_live_prompt_without_model(self):
  import os,time
  self.send(b'!printf ready > ready; echo $$ > shell.pid; sleep 30\r')
  self.until(lambda:(self.cwd/'ready').exists() and (self.cwd/'shell.pid').exists(),'long command not running')
  shell=int((self.cwd/'shell.pid').read_text());start=time.monotonic();tail=len(self.output);self.send(b'\x03')
  self.until(lambda:b'cancel' in bytes(self.output[tail:]).lower(),'direct shell was not cancelled',3)
  self.assertLess(time.monotonic()-start,3);self.assertIsNone(self.proc.poll())
  self.send(b'printf recovered > recovered\r');self.until(lambda:(self.cwd/'recovered').exists(),'prompt not usable after shell cancellation')
  self.assertEqual(len(self.server.records),0)
  with self.assertRaises(ProcessLookupError):os.kill(shell,0)
  self.send(b'\x1b');self.settle();self.quit()

if __name__=='__main__':unittest.main()
