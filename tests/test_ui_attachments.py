"""Explicit user attachments: actual content, image bytes, and safe failures."""
import base64,ctypes as C,json,os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class AttachmentTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();base=pathlib.Path(cls.tmp.name)
  for name in ['ui_attachments','runtime','json']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared',*[str(base/f'{n}.o') for n in ['ui_attachments','runtime','json']],'-o',str(base/'attachments.so')],check=True)
  cls.lib=C.CDLL(str(base/'attachments.so'));cls.lib.ui_attachment_content.argtypes=[C.c_char_p,C.c_size_t,C.c_void_p,C.c_size_t];cls.lib.ui_attachment_content.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):
  self.tmpdir=tempfile.TemporaryDirectory();self.addCleanup(self.tmpdir.cleanup);self.cwd=pathlib.Path(self.tmpdir.name)
 def expand(self,text,cap=1048576):
  raw=text.encode();out=C.create_string_buffer(cap);n=self.lib.ui_attachment_content(raw,len(raw),out,cap)
  return n,json.loads(out.raw[:n]) if n>0 else None
 def test_literal_and_escaped_mentions_do_not_read_files(self):
  path=self.cwd/'ordinary.txt';path.write_text('SECRET')
  for text in ['ordinary prompt',r'escaped \@'+str(path),'unresolved @/does-not-exist',f'@{self.cwd}']:
   self.assertEqual(self.expand(text),(0,None))
 def test_multiple_unicode_and_quoted_paths_send_actual_contents(self):
  a=self.cwd/'lambda λ.txt';a.write_text('actual λ content\n')
  b=self.cwd/'other.txt';b.write_text('second actual content')
  prompt=f'Compare @"{a}" with @{b}'
  n,parts=self.expand(prompt);self.assertGreater(n,0);self.assertEqual(parts[0],{'type':'text','text':prompt})
  self.assertEqual(len(parts),3);self.assertIn('actual λ content\n',parts[1]['text']);self.assertIn(str(a),parts[1]['text']);self.assertIn('second actual content',parts[2]['text'])
  self.assertEqual(self.lib.ui_attachment_count(),2)
 def test_actual_image_payload_is_base64_not_a_filename(self):
  for name,data,mime in [('a.png',b'\x89PNG\r\n\x1a\n'+bytes(range(19)),'image/png'),('b.jpg',b'\xff\xd8\xff'+bytes(range(19)),'image/jpeg'),('c.gif',b'GIF89a'+bytes(range(19)),'image/gif'),('d.webp',b'RIFF1234WEBP'+bytes(range(19)),'image/webp')]:
   with self.subTest(name=name):
    path=self.cwd/name;path.write_bytes(data);n,parts=self.expand('@'+str(path));image=parts[1]['image_url'];header,payload=image['url'].split(',');self.assertEqual(header,'data:'+mime+';base64');self.assertEqual(base64.b64decode(payload),data);self.assertEqual(image['detail'],'auto')
 def test_empty_file_is_valid_but_binary_and_oversize_fail(self):
  path=self.cwd/'empty';path.write_bytes(b'');self.assertGreater(self.expand('@'+str(path))[0],0)
  path.write_bytes(b'binary\x00bytes');self.assertLess(self.expand('@'+str(path))[0],0)
  path.write_bytes(b'x'*262145);self.assertLess(self.expand('@'+str(path))[0],0)
 def test_fifo_never_blocks_and_tiny_buffer_fails(self):
  path=self.cwd/'fifo';os.mkfifo(path);self.assertEqual(self.expand('@'+str(path)),(0,None))
  path=self.cwd/'file';path.write_text('content');self.assertLess(self.expand('@'+str(path),cap=32)[0],0)
 def test_malformed_utf8_never_produces_invalid_json(self):
  path=self.cwd/'invalid';path.write_bytes(b'bad \xff text');self.assertLess(self.expand('@'+str(path))[0],0)
