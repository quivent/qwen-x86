"""Native theme preferences: scoped real files, preservation, private atomic I/O."""
import ctypes as C,json,os,pathlib,stat,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class UIPreferencesTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  for name in ['ui_preferences','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared',str(base/'ui_preferences.o'),str(base/'json.o'),'-o',str(base/'preferences.so')],check=True)
  cls.lib=C.CDLL(str(base/'preferences.so'))
  cls.lib.ui_preferences_config.argtypes=[C.c_char_p,C.c_char_p,C.c_size_t];cls.lib.ui_preferences_config.restype=C.c_int64
  cls.lib.ui_preferences_get_theme.restype=C.c_void_p
  cls.lib.ui_preferences_set_theme.argtypes=[C.c_char_p,C.c_size_t];cls.lib.ui_preferences_set_theme.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);base=pathlib.Path(self.temp.name)
  self.home=base/'home with spaces';self.cwd=base/'work';self.home.mkdir();self.cwd.mkdir();self.configure()
 def configure(self,allowed=1):self.assertEqual(self.lib.ui_preferences_config(os.fsencode(self.home),os.fsencode(self.cwd),allowed),0)
 def get(self):
  value=self.lib.ui_preferences_get_theme();return C.string_at(value).decode() if value else None
 def put(self,value,scope=0):return self.lib.ui_preferences_set_theme(value.encode(),scope)
 def path(self,scope=0):return self.cwd/'.qwen-x86/ui.json' if scope else self.home/'.config/qwen-x86/ui.json'
 def write(self,value,scope=0):
  p=self.path(scope);p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value);return p
 def test_scopes_user_default_project_override_and_private_atomic_files(self):
  self.assertIsNone(self.get());self.assertEqual(self.put('Dracula'),0);self.assertEqual(self.get(),'Dracula')
  self.assertEqual(self.put('Light',1),0);self.assertEqual(self.get(),'Light')
  self.assertEqual(self.put('Dark',0),0);self.assertEqual(self.get(),'Light')
  for scope,theme in [(0,'Dark'),(1,'Light')]:
   p=self.path(scope);self.assertEqual(json.loads(p.read_text()),{'schemaVersion':1,'themeName':theme});self.assertEqual(stat.S_IMODE(p.stat().st_mode),0o600)
   self.assertEqual(list(p.parent.glob('*.tmp-*')),[])
  self.path(1).unlink();self.assertEqual(self.get(),'Dark')
 def test_replace_preserves_unknown_keys_nested_values_and_raw_text(self):
  original=' \n{ "model" : "custom", "unknown":{"array":[1,true,"}\\\"λ"]}, "themeName" : "old" }\t'
  p=self.write(original);self.assertEqual(self.put('New "λ"'),0)
  self.assertEqual(p.read_text(),original.replace('"old"',json.dumps('New "λ"',ensure_ascii=False)))
  self.assertEqual(self.get(),'New "λ"')
  p.write_text('{"themeName":{"old":true},"keep":[1,2]}');self.assertEqual(self.put('Flat'),0);self.assertEqual(json.loads(p.read_text()),{'themeName':'Flat','keep':[1,2]})
 def test_insert_theme_into_empty_or_existing_object_preserves_fields(self):
  for source in ['{}',' { \n}\t','{"model":"my-model","schemaVersion":9}\n']:
   p=self.write(source);self.assertEqual(self.put('Chosen'),0);value=json.loads(p.read_text());self.assertEqual(value['themeName'],'Chosen')
   if 'model' in source:self.assertEqual(value['model'],'my-model');self.assertEqual(value['schemaVersion'],9)
 def test_no_save_never_creates_or_changes_files(self):
  self.configure(0);self.assertEqual(self.put('Temporary',1),0);self.assertFalse((self.cwd/'.qwen-x86').exists());self.assertFalse((self.home/'.config').exists())
  self.configure();self.assertEqual(self.put('Saved'),0);before=(self.path().read_bytes(),self.path().stat().st_mtime_ns)
  self.configure(0);self.assertEqual(self.get(),'Saved');self.assertEqual(self.put('Temporary'),0);self.assertEqual((self.path().read_bytes(),self.path().stat().st_mtime_ns),before)
 def test_malformed_oversize_nonobject_and_symlink_refused(self):
  for source in ['{broken','[]','x'*65537]:
   p=self.write(source);before=p.read_bytes();self.assertLess(self.put('New'),0);self.assertEqual(p.read_bytes(),before)
  p=self.path();p.unlink();target=self.cwd/'target';target.write_text('{"themeName":"Outside"}');p.symlink_to(target)
  self.assertIsNone(self.get());self.assertLess(self.put('New'),0);self.assertEqual(target.read_text(),'{"themeName":"Outside"}')
  p.unlink();os.mkfifo(p);self.assertLess(self.put('New'),0)
 def test_bad_project_falls_back_user_and_directory_symlink_denied(self):
  self.assertEqual(self.put('User'),0);self.write('{broken',1);self.assertEqual(self.get(),'User')
  import shutil
  shutil.rmtree(self.cwd/'.qwen-x86');(self.cwd/'.qwen-x86').symlink_to(self.home/'.config/qwen-x86',target_is_directory=True)
  self.assertLess(self.put('Escaped',1),0);self.assertEqual(self.get(),'User')
 def test_descriptor_cleanup_capacity_and_argument_validation(self):
  self.assertEqual(self.put('Base'),0);before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for i in range(8):self.assertEqual(self.put('Choice'+str(i)),0);self.assertEqual(self.get(),'Choice'+str(i))
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)
  p=self.write('{"padding":"'+'x'*65500+'"}');old=p.read_bytes();self.assertLess(self.put('x'*100),0);self.assertEqual(p.read_bytes(),old)
  for value,scope in [(b'',0),(b'bad\nname',0),(b'\xff',0),(b'Fine',2)]:self.assertLess(self.lib.ui_preferences_set_theme(value,scope),0)

class UIPreferencePTYTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def test_startup_scope_precedence_and_real_workspace_theme_commit(self):
  import pty,fcntl,struct,termios,time,select
  from test_cli import disable_core
  from test_ui_renderer import Screen
  with tempfile.TemporaryDirectory(prefix='qwen-theme-scope-') as d:
   base=pathlib.Path(d);home=base/'home';cwd=base/'workspace';home.mkdir();cwd.mkdir()
   user=home/'.config/qwen-x86/ui.json';user.parent.mkdir(parents=True);user.write_text(json.dumps({'themeName':'Dracula','model':'preserve-user-model'}))
   project=cwd/'.qwen-x86/ui.json';project.parent.mkdir();project.write_text(json.dumps({'themeName':'GitHub Light','unknown':{'preserve':True}}))
   env=dict(os.environ,HOME=str(home),TERM='xterm-256color',QWEN_API_KEY='fake-theme-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL','NO_COLOR']:env.pop(key,None)
   master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,0,0));original=termios.tcgetattr(slave)
   proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--cwd',str(cwd)],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);output=bytearray()
   def drain():
    if select.select([master],[],[],.02)[0]:
     try:output.extend(os.read(master,262144))
     except OSError:pass
   def view():
    raw=bytes(output);start=raw.rfind(b'\x1b[H');screen=Screen(100,30);screen.feed(raw[start:] if start>=0 else raw);return screen
   def text():return '\n'.join(view().lines())
   def until(pred,message,seconds=4):
    end=time.monotonic()+seconds
    while not pred() and time.monotonic()<end and proc.poll() is None:drain()
    self.assertTrue(pred(),message+' returncode='+str(proc.poll())+repr(text()))
   def settle():
    end=time.monotonic()+.2
    while time.monotonic()<end:drain()
   try:
    until(lambda:'Type your message' in text(),'missing composer');settle()
    screen=view();y,x=next((y,line.index('>_ Qwen')) for y,line in enumerate(screen.lines()) if '>_ Qwen' in line)
    self.assertEqual(screen.colors[y][x],(153,0,0),'Workspace theme did not override User at startup')
    beforeuser=user.read_bytes();os.write(master,b'/theme\r');until(lambda:'Select Theme' in text(),'real theme dialog missing')
    os.write(master,b'\x1b[A'*6);settle();os.write(master,b'\t');until(lambda:'Apply To' in text(),'Tab did not focus theme scope');os.write(master,b'\x1b[B\r')
    until(lambda:json.loads(project.read_text()).get('themeName')=='Dracula','Workspace scope was not persisted')
    self.assertEqual(user.read_bytes(),beforeuser);self.assertEqual(json.loads(project.read_text())['unknown'],{'preserve':True});settle()
    screen=view();y,x=next((y,line.index('>_ Qwen')) for y,line in enumerate(screen.lines()) if '>_ Qwen' in line);self.assertEqual(screen.colors[y][x],(255,121,198))
    os.write(master,b'/quit\r');proc.wait(timeout=3);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
   finally:
    if proc.poll() is None:proc.kill();proc.wait(timeout=2)
    os.close(master);os.close(slave)


class AutoThemePTYTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def run_auto(self,variables,color,reply=None,typed=None,no_color=False):
  import pty,fcntl,struct,termios,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  from test_ui_renderer import Screen
  with tempfile.TemporaryDirectory(prefix='qwen-auto-theme-') as d:
   env=dict(os.environ,HOME=d,TERM='xterm-256color',QWEN_API_KEY='fake-auto-theme-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL','NO_COLOR','COLORFGBG']:env.pop(key,None)
   env.update(variables)
   with ConcurrentServer(lambda req:answer('auto fixture done')) as server:
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));original=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--base-url',server.url],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);output=bytearray()
    def drain():
     if select.select([master],[],[],.01)[0]:
      try:output.extend(os.read(master,262144))
      except OSError:pass
    def view():
     raw=bytes(output);start=raw.rfind(b'\x1b[H');screen=Screen(80,24);screen.feed(raw[start:] if start>=0 else raw);return screen
    def until(pred,message,seconds=4):
     end=time.monotonic()+seconds
     while not pred() and time.monotonic()<end and proc.poll() is None:drain()
     self.assertTrue(pred(),message+repr('\n'.join(view().lines())))
    def settle():
     end=time.monotonic()+.2
     while time.monotonic()<end:drain()
    try:
     if reply is not None:
      until(lambda:b'\x1b]11;?\x07' in output,'OSC11 query missing')
      os.write(master,reply)
     until(lambda:b'Type your message' in output,'composer missing');settle()
     if color is not None:
      screen=view();y,x=next((y,line.index('>_ Qwen')) for y,line in enumerate(screen.lines()) if '>_ Qwen' in line)
      self.assertEqual(screen.colors[y][x],color)
     if variables.get('COLORFGBG'):self.assertNotIn(b'\x1b]11;?\x07',output,'known environment triggered unnecessary OSC query')
     if no_color:
      self.assertNotIn(b'\x1b[38;2;',output);self.assertNotIn(b'\x1b[48;2;',output)
     self.assertEqual(len(server.records),0,'theme probe submitted user text')
     if typed is not None:
      self.assertIn(typed,'\n'.join(view().lines()));os.write(master,b'\r');until(lambda:len(server.records)==1,'typed bytes lost during OSC probe');settle()
      self.assertEqual(server.records[0][1]['messages'][-1]['content'],typed)
     os.write(master,b'/quit\r');proc.wait(timeout=3);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)
 def test_colorfgbg_light_dark_precedes_probe(self):
  self.run_auto({'COLORFGBG':'0;15'},(139,92,246));self.run_auto({'COLORFGBG':'15;0'},(203,166,247))
 def test_osc11_light_dark_preserves_pending_typed_bytes(self):
  self.run_auto({},(139,92,246),b'before \x1b]11;rgb:ffff/ffff/ffff\x1b\\after',typed='before after')
  self.run_auto({},(203,166,247),b'\x1b]11;#000000\x07')
 def test_no_color_avoids_rgb_from_first_frame(self):
  self.run_auto({'NO_COLOR':'1','COLORFGBG':'0;15'},None,no_color=True)

if __name__=='__main__':unittest.main()
