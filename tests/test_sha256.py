import ctypes,hashlib,hmac,os,pathlib,random,subprocess,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class SHA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  subprocess.run(['as','-I','src','-o','build/sha256.o','src/sha256.s'],cwd=ROOT,check=True)
  subprocess.run(['ld','-shared','-Bsymbolic','-o','build/test-sha256.so','build/sha256.o'],cwd=ROOT,check=True)
  cls.lib=ctypes.CDLL(str(ROOT/'build/test-sha256.so'))
  signatures={'sha256_hash':3,'sha256_init':1,'sha256_update':3,'sha256_final':2,'hmac_sha256':5,'hkdf_expand':5,'tls_hkdf_label':6}
  for name,count in signatures.items():
   f=getattr(cls.lib,name);f.argtypes=[ctypes.c_void_p]*count;f.restype=ctypes.c_int64
 def test_hash_vectors_and_boundaries(self):
  for n in [0,1,3,55,56,63,64,65,127,128,1000,65536]:
   data=os.urandom(n);out=ctypes.create_string_buffer(32);self.lib.sha256_hash(data,n,out)
   self.assertEqual(out.raw,hashlib.sha256(data).digest(),n)
 def test_incremental(self):
  rng=random.Random(42)
  for n in [0,100,10000]:
   data=os.urandom(n);ctx=ctypes.create_string_buffer(112);out=ctypes.create_string_buffer(32);self.lib.sha256_init(ctx)
   offset=0
   while offset<n:
    part=data[offset:offset+rng.randrange(1,100)];self.lib.sha256_update(ctx,part,len(part));offset+=len(part)
   self.lib.sha256_final(ctx,out);self.assertEqual(out.raw,hashlib.sha256(data).digest())
 def test_hmac(self):
  for k in [0,1,32,63,64,65,200]:
   key=os.urandom(k);data=os.urandom(333);out=ctypes.create_string_buffer(32);self.lib.hmac_sha256(key,k,data,len(data),out)
   self.assertEqual(out.raw,hmac.digest(key,data,'sha256'))
 def test_hkdf_rfc5869(self):
  ikm=bytes([11])*22;salt=bytes(range(13));info=bytes(range(240,250));prk=hmac.digest(salt,ikm,'sha256')
  self.assertEqual(prk.hex(),'077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5')
  out=ctypes.create_string_buffer(42);self.assertEqual(self.lib.hkdf_expand(prk,info,len(info),out,42),0)
  self.assertEqual(out.raw.hex(),'3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865')
 def test_hkdf_label_and_limits(self):
  secret=bytes(range(32));context=hashlib.sha256(b'hello').digest();label=b'c hs traffic'
  info=(32).to_bytes(2,'big')+bytes([6+len(label)])+b'tls13 '+label+bytes([len(context)])+context
  expected=hmac.digest(secret,info+b'\x01','sha256')
  out=ctypes.create_string_buffer(32);self.assertEqual(self.lib.tls_hkdf_label(secret,label,context,len(context),out,32),0);self.assertEqual(out.raw,expected)
  self.assertLess(self.lib.hkdf_expand(secret,b'x'*257,257,out,32),0)
  self.assertLess(self.lib.hkdf_expand(secret,b'',0,out,8161),0)
if __name__=='__main__':unittest.main()
