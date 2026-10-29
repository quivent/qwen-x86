"""Explicit native persisted exact-command grants, user+workspace isolation."""
import ctypes as C,json,os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ShellPermissionTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  for name in ['ui_shell_permissions','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared','-Bsymbolic',str(base/'ui_shell_permissions.o'),str(base/'json.o'),'-o',str(base/'permissions.so')],check=True);cls.lib=C.CDLL(str(base/'permissions.so'))
  for name,args in {'ui_shell_permission_config':[C.c_char_p,C.c_char_p,C.c_int],'ui_shell_permission_add':[C.c_void_p,C.c_size_t,C.c_int],'ui_shell_permission_match':[C.c_void_p,C.c_size_t],'ui_shell_permission_remove':[C.c_void_p,C.c_size_t,C.c_int],'ui_shell_permission_catalog':[C.c_void_p,C.c_size_t]}.items():fn=getattr(cls.lib,name);fn.argtypes=args;fn.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.home=pathlib.Path(self.tmp.name);self.cwd=self.home/'workspace';self.cwd.mkdir();self.config()
 def config(self,save=1,cwd=None):self.lib.ui_shell_permission_config(os.fsencode(self.home),os.fsencode(cwd or self.cwd),save)
 def add(self,s,scope=1):b=s.encode();return self.lib.ui_shell_permission_add(b,len(b),scope)
 def match(self,s):b=s.encode();return self.lib.ui_shell_permission_match(b,len(b))
 def rows(self):
  out=(C.c_void_p*600)();n=self.lib.ui_shell_permission_catalog(out,200);return [tuple(C.string_at(out[i*3+j]).decode() for j in range(3)) for i in range(n)]
 def test_explicit_add_persists_exact_bytes_and_scope_isolation(self):
  self.assertEqual(self.match('git status'),0);self.assertEqual(self.add('git status'),0);self.assertEqual(self.match('git status'),1)
  for other in ['git status --short','git status; touch unrelated',' git status','git status\n','git status$(evil)']:self.assertEqual(self.match(other),0)
  self.assertEqual(self.add('printf λ',0),0);self.assertEqual(self.rows()[0],('git status','Project · exact command','git status'))
  files=list((self.home/'.local/state/qwen-x86').glob('shell-allow---*.json'));self.assertEqual(len(files),2);self.assertTrue(all(p.stat().st_mode&0o777==0o600 for p in files));self.assertTrue(any(json.loads(p.read_text())==['git status'] for p in files))
  self.config();self.assertEqual(self.match('git status'),1);self.assertEqual(self.match('printf λ'),1)
  other=self.home/'other';other.mkdir();self.config(cwd=other);self.assertEqual(self.match('git status'),0);self.assertEqual(self.match('printf λ'),1)
 def test_no_save_loads_but_cannot_add_remove_or_touch_files(self):
  self.assertEqual(self.add('explicit'),0);before={p:(p.read_bytes(),p.stat().st_mtime_ns) for p in (self.home/'.local/state/qwen-x86').iterdir()};self.config(0)
  self.assertEqual(self.match('explicit'),1);self.assertEqual(self.add('new'),-13);self.assertEqual(self.lib.ui_shell_permission_remove(b'explicit',8,1),-13)
  self.assertEqual({p:(p.read_bytes(),p.stat().st_mtime_ns) for p in before},before)
 def test_remove_readd_does_not_overwrite_surviving_rules(self):
  for s in ['first','second','third']:self.assertEqual(self.add(s),0)
  self.assertEqual(self.lib.ui_shell_permission_remove(b'second',6,1),0);self.assertEqual(self.match('second'),0);self.assertEqual(self.add('fourth'),0)
  for s in ['first','third','fourth']:self.assertEqual(self.match(s),1)
  self.config()
  for s in ['first','third','fourth']:self.assertEqual(self.match(s),1)
  self.assertEqual(self.match('second'),0)
 def test_malformed_or_linked_permission_files_fail_closed_and_no_fd_leak(self):
  self.assertEqual(self.add('approved'),0);files=list((self.home/'.local/state/qwen-x86').glob('shell-allow---*.json'));self.assertEqual(len(files),1);file=files[0]
  for raw in ['[broken','[123]','{}','["approved",false]']:
   file.write_text(raw);self.config();self.assertEqual(self.match('approved'),0)
  file.unlink();outside=self.home/'outside';outside.write_text('["approved"]');file.symlink_to(outside);self.config();self.assertEqual(self.match('approved'),0);self.assertEqual(outside.read_text(),'["approved"]')
  file.unlink();os.mkfifo(file);self.config();self.assertEqual(self.match('approved'),0)
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(10):self.config(0)
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)
 def test_invalid_utf8_nul_and_scope_are_rejected(self):
  for b in [b'',b'bad\x00bytes',b'\xff',b'x'*65536]:self.assertLess(self.lib.ui_shell_permission_add(b,len(b),1),0)
  self.assertEqual(self.lib.ui_shell_permission_add(b'valid',5,2),-22);self.assertEqual(self.rows(),[])
