"""Native workspace completion: real metadata, confined traversal, bounded rows."""
import ctypes as C,os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class PathCatalogTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();base=pathlib.Path(cls.tmp.name)
  for name in ['ui_paths','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared',str(base/'ui_paths.o'),str(base/'json.o'),'-o',str(base/'paths.so')],check=True)
  cls.lib=C.CDLL(str(base/'paths.so'));cls.lib.ui_path_catalog.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t];cls.lib.ui_path_catalog.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):
  self.tmpdir=tempfile.TemporaryDirectory();self.addCleanup(self.tmpdir.cleanup);self.cwd=pathlib.Path(self.tmpdir.name)
 def file(self,path):
  p=self.cwd/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('never read file contents');return p
 def catalog(self,query='',cap=128):
  if isinstance(query,str):query=query.encode()
  items=(C.c_void_p*(128*3))();n=self.lib.ui_path_catalog(os.fsencode(self.cwd),query,len(query),items,cap)
  return n,[tuple(C.string_at(items[i*3+j]).decode() for j in range(3)) for i in range(max(0,n))]
 def test_real_recursive_prefix_fuzzy_and_stable_sort(self):
  for path in ['z.txt','src/main.s','src/model.s','README.md','src/nested/data.txt']:self.file(path)
  n,rows=self.catalog();values=[r[2] for r in rows]
  self.assertEqual(values,sorted(['z.txt','src/','src/main.s','src/model.s','README.md','src/nested/','src/nested/data.txt']))
  self.assertEqual(self.catalog('SRC/MA')[1][0][2],'src/main.s')
  self.assertEqual(self.catalog('smds')[1][0][2],'src/model.s')
  self.assertEqual(self.catalog('main')[1][0][1],'file')
  self.assertEqual(self.catalog('src/')[1][0][1],'directory')
 def test_skip_dependencies_and_symlinks(self):
  self.file('source/keep.txt')
  for folder in ['.git','node_modules','.venv','cache','build','dist','target','.next']:
   self.file(folder+'/secret.txt')
  outside=self.cwd.parent/('outside-'+self.cwd.name);outside.mkdir();self.addCleanup(lambda:__import__('shutil').rmtree(outside));(outside/'private.txt').write_text('private')
  (self.cwd/'linked').symlink_to(outside,target_is_directory=True);(self.cwd/'linked-file').symlink_to(outside/'private.txt')
  self.assertEqual([r[2] for r in self.catalog()[1]],['source/','source/keep.txt'])
 def test_spaces_unicode_no_content_reads_and_fifo(self):
  self.file('music lab/λ song.txt');os.mkfifo(self.cwd/'fifo')
  p=self.file('unreadable.txt');p.chmod(0)
  rows=self.catalog('song')[1];self.assertEqual(rows[0][2],'music lab/λ song.txt')
  self.assertIn('unreadable.txt',[r[2] for r in self.catalog()[1]])
  self.assertNotIn('fifo',[r[2] for r in self.catalog()[1]])
  self.file('γû.txt');self.assertEqual(self.catalog('λ')[0],1) # only actual lambda path, not cross-scalar bytes
  self.file('control\x1bname');self.file('control\u0085name');self.assertFalse(any('control' in r[2] for r in self.catalog()[1]))
 def test_escape_and_malformed_query_rejected(self):
  for query in ['/etc','../etc','src/../etc','..',b'a\0b',b'\xff',b'x'*513]:
   with self.subTest(query=query):self.assertLess(self.catalog(query)[0],0)
  self.assertEqual(self.lib.ui_path_catalog(None,None,0,None,0),0)
 def test_bounded_top_results_and_fd_cleanup(self):
  for n in reversed(range(160)):self.file(f'f{n:03d}.txt')
  n,rows=self.catalog();self.assertEqual(n,128);self.assertEqual([r[2] for r in rows],[f'f{i:03d}.txt' for i in range(128)])
  self.assertEqual([r[2] for r in self.catalog(cap=3)[1]],['f000.txt','f001.txt','f002.txt'])
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(6):self.catalog(cap=2)
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)
 def test_depth_bound_and_prefix_rank(self):
  self.file('/'.join(['deep']*14)+'/file.txt');self.file('main.txt');self.file('a/main.txt')
  rows=self.catalog('main')[1];self.assertEqual(rows[0][2],'main.txt')
  self.assertFalse(any(r[2].count('/')>12 for r in self.catalog()[1]))

class PathCompletionPTYTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def test_real_at_path_tab_spaces_unicode_no_duplicate_at(self):
  import pty,fcntl,struct,termios,time,select
  from test_cli import ConcurrentServer,answer,disable_core
  with tempfile.TemporaryDirectory(prefix='qwen-path-pty-') as d:
   base=pathlib.Path(d);home=base/'home';home.mkdir();cwd=base/'work';cwd.mkdir()
   (cwd/'src').mkdir();(cwd/'src/main.s').write_text('not read by completion')
   (cwd/'music lab').mkdir();(cwd/'music lab/λ song.txt').write_text('not read by completion')
   env=dict(os.environ,HOME=str(home),TERM='xterm-256color',QWEN_API_KEY='fake-path-pty-key')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   with ConcurrentServer(lambda req:answer('path fixture complete')) as server:
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));original=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--no-save','--cwd',str(cwd),'--base-url',server.url],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core)
    output=bytearray()
    def drain():
     if select.select([master],[],[],.02)[0]:
      try:output.extend(os.read(master,262144))
      except OSError:pass
    def until(pred,message,seconds=4):
     end=time.monotonic()+seconds
     while not pred() and time.monotonic()<end and proc.poll() is None:drain()
     self.assertTrue(pred(),message+repr(bytes(output[-2000:])))
    def settle():
     end=time.monotonic()+.15
     while time.monotonic()<end:drain()
    try:
     until(lambda:b'Type your message' in output,'missing composer')
     os.write(master,b'Inspect @src/ma\t');settle();os.write(master,b'\r')
     until(lambda:len(server.records)==1,'plain path completion did not submit');settle()
     self.assertEqual(server.records[0][1]['messages'][-1]['content'][0]['text'],'Inspect @src/main.s ');self.assertIn('not read by completion',server.records[0][1]['messages'][-1]['content'][1]['text'])
     os.write(master,b'Inspect @mus\t');settle()
     os.write(master,'λ'.encode()+b'\t');settle();os.write(master,b'\r')
     until(lambda:len(server.records)==2,'quoted directory/file completion did not submit');settle()
     self.assertEqual(server.records[1][1]['messages'][-1]['content'][0]['text'],'Inspect @"music lab/λ song.txt" ');self.assertIn('not read by completion',server.records[1][1]['messages'][-1]['content'][1]['text'])
     os.write(master,b'/quit\r');proc.wait(timeout=3);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),original)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)

if __name__=='__main__':unittest.main()
