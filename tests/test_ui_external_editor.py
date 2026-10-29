"""Native external-editor ABI. Fake editor programs are test fixtures only."""
import ctypes as C,glob,json,os,pathlib,shlex,signal,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ExternalEditorTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  for name in ['ui_external_editor','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared',str(base/'ui_external_editor.o'),str(base/'json.o'),'-o',str(base/'editor.so')],check=True)
  cls.lib=C.CDLL(str(base/'editor.so'));cls.lib.ui_external_edit.argtypes=[C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p];cls.lib.ui_external_edit.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(prefix='native editor with spaces ');self.addCleanup(self.tmp.cleanup);self.base=pathlib.Path(self.tmp.name)
  self.log=self.base/'log.json'
  self.before=set(glob.glob('/tmp/qwen-edit-*.txt'))
 def editor(self,body,arguments=''):
  script=self.base/'fake editor.py'
  script.write_text('import os,sys,pathlib,json,signal,stat\np=pathlib.Path(sys.argv[-1])\n'+body+'\n')
  return shlex.quote(os.sys.executable)+' '+shlex.quote(str(script))+' '+arguments
 def call(self,editor,text=b'original',cap=65536,visual=None,extra=None):
  env=dict(os.environ,EDITOR=editor,NATIVE_EDITOR_LOG=str(self.log),NATIVE_EDITOR_PARENT=str(os.getpid()),NATIVE_EDITOR_TOKEN='preserved')
  env.pop('VISUAL',None)
  if visual is not None:env['VISUAL']=visual
  env.update(extra or {})
  rawenv=[os.fsencode(k+'='+v) for k,v in env.items()];envp=(C.c_char_p*(len(rawenv)+1))(*rawenv,None)
  output=C.create_string_buffer(b'unchanged',65536)
  n=self.lib.ui_external_edit(text,len(text),output,cap,envp)
  self.assertEqual(set(glob.glob('/tmp/qwen-edit-*.txt')),self.before,'temporary draft leaked')
  return n,output.raw[:n] if n>=0 else output.value
 def test_quoted_editor_arguments_environment_private_file_and_newlines(self):
  editor=self.editor("pathlib.Path(os.environ['NATIVE_EDITOR_LOG']).write_text(json.dumps({'argv':sys.argv[1:-1],'mode':stat.S_IMODE(p.stat().st_mode),'old':p.read_text(),'token':os.environ['NATIVE_EDITOR_TOKEN']}))\np.write_bytes('edited λ\\r\\nline\\rtail\\n\\n'.encode())", "'argument with spaces' --flag")
  n,output=self.call(editor,b'original\n')
  self.assertEqual(output,'edited λ\nline\ntail\n\n'.encode());self.assertEqual(n,len(output))
  info=json.loads(self.log.read_text());self.assertEqual(info['argv'],['argument with spaces','--flag']);self.assertEqual(info['mode'],0o600);self.assertEqual(info['old'],'original\n');self.assertEqual(info['token'],'preserved')
 def test_visual_precedence_atomic_replacement_and_umask(self):
  visual=self.editor("q=p.with_suffix('.new');assert stat.S_IMODE(p.stat().st_mode)==0o600;q.write_text('visual replacement');q.chmod(0o600);q.replace(p)")
  previous=os.umask(0o777)
  try:n,output=self.call('exit 9',visual=visual)
  finally:os.umask(previous)
  self.assertEqual(output,b'visual replacement')
 def test_nonzero_signal_and_missing_editor_preserve_output(self):
  for editor in ['exit 7','kill -INT $$','nonexistent-native-editor-command']:
   with self.subTest(editor=editor):
    n,output=self.call(editor);self.assertLess(n,0);self.assertEqual(output,b'unchanged')
 def test_invalid_nul_utf8_capacity_and_oversize_rejected(self):
  for payload in ["b'a\\x00b'","b'\\xff'","b'x'*65536"]:
   with self.subTest(payload=payload):
    n,output=self.call(self.editor('p.write_bytes('+payload+')'));self.assertLess(n,0);self.assertEqual(output,b'unchanged')
  n,output=self.call(self.editor("p.write_text('too much')"),cap=3);self.assertEqual(n,-28);self.assertEqual(output,b'unchanged')
 def test_replaced_symlink_or_fifo_rejected_without_block(self):
  target=self.base/'target';target.write_text('private original')
  for body in ["p.unlink();p.symlink_to("+repr(str(target))+")","p.unlink();os.mkfifo(p)"]:
   n,output=self.call(self.editor(body));self.assertLess(n,0);self.assertEqual(output,b'unchanged');self.assertEqual(target.read_text(),'private original')
 def test_signal_handlers_restored_and_parent_ignores_editor_interrupt(self):
  seen=[]
  def handler(signum,frame):seen.append(signum)
  oldint=signal.signal(signal.SIGINT,handler);oldquit=signal.signal(signal.SIGQUIT,handler)
  try:
   n,output=self.call(self.editor("assert signal.getsignal(signal.SIGINT)!=signal.SIG_IGN;assert signal.getsignal(signal.SIGQUIT)==signal.SIG_DFL\nos.kill(int(os.environ['NATIVE_EDITOR_PARENT']),signal.SIGINT)\nos.kill(int(os.environ['NATIVE_EDITOR_PARENT']),signal.SIGQUIT)\np.write_text('still here')"))
   self.assertEqual(output,b'still here');self.assertEqual(seen,[])
   self.assertIs(signal.getsignal(signal.SIGINT),handler);self.assertIs(signal.getsignal(signal.SIGQUIT),handler)
   os.kill(os.getpid(),signal.SIGINT);os.kill(os.getpid(),signal.SIGQUIT);self.assertEqual(seen,[signal.SIGINT,signal.SIGQUIT])
  finally:signal.signal(signal.SIGINT,oldint);signal.signal(signal.SIGQUIT,oldquit)
 def test_repeated_calls_release_descriptors_and_empty_editor_uses_fallback(self):
  editor=self.editor("p.write_text('ok')")
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(8):self.assertEqual(self.call(editor,visual='')[1],b'ok')
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)

class ExternalEditorPTYTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def test_real_ctrl_x_restores_tty_edits_draft_and_undo(self):
  import pty,fcntl,struct,termios,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  with tempfile.TemporaryDirectory(prefix='qwen-real-editor-') as d:
   home=pathlib.Path(d);log=home/'editor-log.json';script=home/'fake editor.py'
   script.write_text("import sys,pathlib,json,termios,os\np=pathlib.Path(sys.argv[-1]);tty=termios.tcgetattr(0)\npathlib.Path(os.environ['EDITOR_LOG']).write_text(json.dumps({'old':p.read_text(),'path':str(p),'lflag':tty[3]}))\np.write_text('edited λ\\n')\n")
   env=dict(os.environ,HOME=d,TERM='xterm-256color',QWEN_API_KEY='fake-editor-pty-key',EDITOR=shlex.quote(os.sys.executable)+' '+shlex.quote(str(script)),EDITOR_LOG=str(log))
   for key in ['VISUAL','OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   with ConcurrentServer(lambda req:answer('editor fixture complete')) as server:
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
     self.assertTrue(pred(),message+repr(bytes(output[-1500:])))
    def settle():
     end=time.monotonic()+.15
     while time.monotonic()<end:drain()
    try:
     until(lambda:b'Type your message' in output,'missing composer')
     os.write(master,b'original draft\x18');until(log.exists,'CtrlX did not launch real editor');settle()
     first=json.loads(log.read_text());self.assertEqual(first['old'],'original draft')
     self.assertTrue(first['lflag']&termios.ICANON);self.assertTrue(first['lflag']&termios.ISIG)
     self.assertFalse(pathlib.Path(first['path']).exists());self.assertEqual(len(server.records),0)
     self.assertFalse(termios.tcgetattr(slave)[3]&termios.ICANON)
     log.unlink();os.write(master,b'\x1a\x18');until(log.exists,'second editor launch');settle()
     self.assertEqual(json.loads(log.read_text())['old'],'original draft','external edit was not undoable')
     os.write(master,b'\r');until(lambda:len(server.records)==1,'edited draft not submitted');settle()
     self.assertEqual(server.records[0][1]['messages'][-1]['content'],'edited λ\n')
     os.write(master,b'/quit\r');proc.wait(timeout=3);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)

if __name__=='__main__':unittest.main()
