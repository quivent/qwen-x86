"""Production assembly provider-error extraction; no provider credentials/network."""
import concurrent.futures
import ctypes as C
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ErrorTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory(prefix='qwen-x86-error-');out=Path(cls.temp.name);objects=[]
  for name in ['ui_error_response','ui_markdown','ui_mermaid','ui_input','runtime','json']:
   obj=out/(name+'.o');objects.append(str(obj));subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(obj),str(ROOT/'src'/(name+'.s'))],check=True)
  shared=out/'error.so';subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(shared),*objects],check=True)
  cls.lib=C.CDLL(str(shared));cls.lib.ui_error_describe.argtypes=[C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t];cls.lib.ui_error_describe.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.temp.cleanup()
 def call(self,status,body,cap=70000):
  if isinstance(body,str):body=body.encode()
  out=C.create_string_buffer(cap+32);C.memset(out,0xa5,len(out))
  n=self.lib.ui_error_describe(status,body,len(body),C.byref(out,16),cap)
  self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[cap+16:],b'\xa5'*16)
  return n,out.raw[16:16+max(n,0)]
 def test_provider_json_shapes_and_status(self):
  cases=[(401,{'error':{'message':'Invalid API key','code':'auth'}},'Invalid API key'),(429,{'message':'Quota exceeded'},'Quota exceeded'),(500,{'error':'Provider unavailable'},'Provider unavailable'),(403,{'error':{'details':4},'message':'Access denied'},'Access denied')]
  for status,body,want in cases:
   n,text=self.call(status,json.dumps(body));self.assertEqual(text.decode(),f'HTTP {status}: {want}');self.assertEqual(n,len(text))
 def test_plain_invalid_empty_and_nested_lookalikes(self):
  for body,want in [(b'upstream overloaded','upstream overloaded'),(b'{invalid','{invalid'),(b'', 'request failed'),(b'   \n','request failed')]:
   self.assertEqual(self.call(503,body)[1].decode(),'HTTP 503: '+want)
  body=b'{"details":{"message":"wrong"},"error":{"details":{"message":"also wrong"}}}'
  self.assertEqual(self.call(400,body)[1],b'HTTP 400: '+body)
 def test_unicode_controls_capacity_and_truncation(self):
  body=json.dumps({'error':{'message':'Bad \x1b]52;c;SECRET\x07世界\x1b[2J\x00 request'}})
  text=self.call(401,body)[1];self.assertEqual(text.decode(),'HTTP 401: Bad 世界 request');self.assertNotIn(b'\x1b',text)
  for cap in [0,1,10,20]:self.assertEqual(self.call(401,body,cap)[0],-28)
  n,text=self.call(500,b'x'*20000);self.assertEqual(text.count(b'x'),16384);self.assertTrue(text.endswith(b' [response truncated]'));self.assertEqual(n,len(text))
  self.assertIn('�',self.call(500,b'\xff')[1].decode())
 def test_reentrant_private_context(self):
  def one(i):return self.call(400+i%100,json.dumps({'error':{'message':f'failure {i}'}}))[1]
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(one,range(100)))
  for i,text in enumerate(results):self.assertEqual(text,f'HTTP {400+i%100}: failure {i}'.encode())
if __name__=='__main__':unittest.main()
