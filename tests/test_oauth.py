"""Native OAuth against local verified TLS; Python is solely the test oracle.

Endpoints are substituted only in a temporary COPY of assembly source. Production
has no endpoint override and never starts a public device authorization here.
"""
import base64
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
from urllib.parse import parse_qs
from test_tls import make_certificates

ROOT=Path(__file__).resolve().parents[1]
DRIVER='''import ctypes,sys,resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
l=ctypes.CDLL(sys.argv[1]);l.oauth_load.argtypes=[ctypes.c_char_p];l.oauth_login.argtypes=[ctypes.c_char_p];l.http_set_ca.argtypes=[ctypes.c_char_p];l.oauth_error.restype=ctypes.c_char_p
l.http_set_ca(sys.argv[4].encode())
if sys.argv[2]=='rawcancel':l.net_set_interactive(1)
r=l.oauth_login(sys.argv[3].encode()) if sys.argv[2]=='login' else l.oauth_load(sys.argv[3].encode())
if r==0 and sys.argv[2]=='cancel':ctypes.c_long.in_dll(l,'net_cancelled').value=1
if r==0 and sys.argv[2] in ('ensure','cancel','rawcancel'):r=l.oauth_ensure()
if r:print(l.oauth_error().decode(),file=sys.stderr)
l.http_close();sys.exit(0 if r==0 else 1)
'''

class OAuthServer:
 def __init__(self,cert,key):
  self.listener=socket.socket();self.listener.bind(('127.0.0.1',0));self.listener.listen();self.listener.settimeout(.2)
  self.url='https://localhost:'+str(self.listener.getsockname()[1]);self.requests=[];self.responses=[];self.errors=[];self.stop=False
  self.context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);self.context.minimum_version=ssl.TLSVersion.TLSv1_3;self.context.maximum_version=ssl.TLSVersion.TLSv1_3;self.context.load_cert_chain(cert,key)
  self.thread=threading.Thread(target=self.run,daemon=True);self.thread.start()
 def run(self):
  while not self.stop:
   try:raw,_=self.listener.accept()
   except socket.timeout:continue
   except OSError:break
   try:
    with raw,self.context.wrap_socket(raw,server_side=True) as s:
     s.settimeout(4);data=b''
     while b'\r\n\r\n' not in data:data+=s.recv(8192)
     headers,body=data.split(b'\r\n\r\n',1);lines=headers.split(b'\r\n');h={k.lower():v.strip() for k,v in (x.split(b':',1) for x in lines[1:])}
     n=int(h[b'content-length'])
     while len(body)<n:body+=s.recv(8192)
     request=(lines[0],h,parse_qs(body.decode(),keep_blank_values=True));self.requests.append(request)
     status,payload=self.responses.pop(0);payload=payload(request) if callable(payload) else payload
     content=payload if isinstance(payload,bytes) else json.dumps(payload).encode()
     s.sendall(b'HTTP/1.1 '+str(status).encode()+b' Test\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: '+str(len(content)).encode()+b'\r\n\r\n'+content)
     try:s.unwrap()
     except (ssl.SSLError,OSError):pass
   except Exception as e:self.errors.append(repr(e))
 def close(self):self.stop=True;self.listener.close();self.thread.join(5)

class NativeOAuth(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory(prefix='qwen-native-oauth-');cls.build=Path(cls.temp.name)
  cls.ca,cert,key=make_certificates(cls.build);cls.server=OAuthServer(cert,key)
  source=(ROOT/'src/oauth.s').read_text().replace('https://chat.qwen.ai/api/v1/oauth2/device/code',cls.server.url+'/device').replace('https://chat.qwen.ai/api/v1/oauth2/token',cls.server.url+'/token')
  path=cls.build/'oauth.s';path.write_text(source)
  subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
  subprocess.run(['as','--64','-I',str(ROOT/'src'),'-o',str(cls.build/'oauth.o'),str(path)],check=True)
  modules='runtime json net http sha256 x25519 aesgcm rsa x509 tls'.split()
  cls.library=cls.build/'oauth.so'
  subprocess.run(['ld','-shared','-Bsymbolic','-o',str(cls.library),str(cls.build/'oauth.o'),*[str(ROOT/'build'/f'{x}.o') for x in modules]],check=True)
 @classmethod
 def tearDownClass(cls):cls.server.close();cls.temp.cleanup()
 def setUp(self):
  self.home=Path(tempfile.mkdtemp(dir=self.build));self.server.responses.clear();self.server.requests.clear();self.server.errors.clear()
 def invoke(self,mode='ensure',timeout=16):
  return subprocess.run(['python3','-c',DRIVER,str(self.library),mode,str(self.home),str(self.ca)],capture_output=True,timeout=timeout)
 def cache(self,external=False,**overrides):
  d=self.home/'.config'/('qwen-go' if external else 'qwen-x86');d.mkdir(parents=True,mode=0o700,exist_ok=True)
  obj=dict(access_token='old-access-private',refresh_token='refresh+/&=%private',resource_url=self.server.url,expiry_date=int((time.time()-60)*1000),token_type='Bearer');obj.update(overrides)
  p=d/'oauth.json';p.write_text(json.dumps(obj));p.chmod(0o600);return p
 def device(self,**overrides):
  obj=dict(device_code='device-private+&',user_code='ABCD-EFGH',verification_uri='https://example.invalid/verify',interval=1,expires_in=30);obj.update(overrides);return obj
 def token(self,**overrides):
  obj=dict(access_token='fresh-access-private',refresh_token='fresh-refresh-private',resource_url=self.server.url,token_type='Bearer',expires_in=3600);obj.update(overrides);return obj
 def assert_private(self,result):
  for secret in [b'fresh-access-private',b'fresh-refresh-private',b'old-access-private',b'refresh+/&=%private',b'device-private']:
   self.assertNotIn(secret,result.stdout+result.stderr)
 def test_device_login_pkce_pending_atomic_cache_and_form_headers(self):
  self.server.responses.extend([(200,self.device()),(400,{'error':'authorization_pending'}),(200,self.token())])
  result=self.invoke('login');self.assertEqual(result.returncode,0,result.stderr);self.assert_private(result)
  self.assertIn(b'ABCD-EFGH',result.stdout);self.assertIn(b'https://example.invalid/verify',result.stdout)
  a,b,c=self.server.requests;challenge=a[2]['code_challenge'][0];verifier=c[2]['code_verifier'][0]
  self.assertEqual(len(verifier),43);self.assertEqual(challenge,base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode())
  self.assertEqual(a[2]['code_challenge_method'],['S256']);self.assertEqual(c[2]['device_code'],['device-private+&'])
  self.assertEqual(b[2]['code_verifier'],c[2]['code_verifier'])
  for _,h,_ in self.server.requests:self.assertEqual(h[b'content-type'],b'application/x-www-form-urlencoded');self.assertNotIn(b'authorization',h)
  directory=self.home/'.config/qwen-x86';path=directory/'oauth.json';saved=json.loads(path.read_text())
  self.assertEqual(saved['access_token'],'fresh-access-private');self.assertGreater(saved['expiry_date'],time.time()*1000)
  self.assertEqual(path.stat().st_mode&0o777,0o600);self.assertEqual(directory.stat().st_mode&0o777,0o700);self.assertFalse(list(directory.glob('.oauth-tmp-*')))
  self.assertEqual(self.invoke().returncode,0);self.assertEqual(len(self.server.requests),3)
 def test_refresh_urlencoding_and_rotation_preserves_missing_refresh(self):
  p=self.cache();response=self.token();response.pop('refresh_token');self.server.responses.append((200,response))
  result=self.invoke();self.assertEqual(result.returncode,0,result.stderr);self.assert_private(result)
  self.assertEqual(self.server.requests[0][2]['refresh_token'],['refresh+/&=%private'])
  saved=json.loads(p.read_text());self.assertEqual(saved['refresh_token'],'refresh+/&=%private');self.assertEqual(saved['access_token'],'fresh-access-private')
 def test_two_workers_refresh_once_with_lock_and_reread(self):
  p=self.cache();self.server.responses.append((200,self.token()))
  args=['python3','-c',DRIVER,str(self.library),'ensure',str(self.home),str(self.ca)]
  children=[subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE) for _ in range(2)]
  for child in children:
   out,err=child.communicate(timeout=10);self.assertEqual(child.returncode,0,err)
  self.assertEqual(len(self.server.requests),1);self.assertEqual(json.loads(p.read_text())['access_token'],'fresh-access-private')
 def test_external_expired_never_refreshes_or_writes(self):
  p=self.cache(external=True);before=p.read_bytes();result=self.invoke()
  self.assertNotEqual(result.returncode,0);self.assertEqual(p.read_bytes(),before);self.assertEqual(self.server.requests,[]);self.assertFalse((self.home/'.config/qwen-x86/oauth.json').exists())
 def test_external_writable_cache_rejected(self):
  p=self.cache(external=True,expiry_date=int((time.time()+3600)*1000));p.chmod(0o666)
  self.assertNotEqual(self.invoke().returncode,0);self.assertEqual(p.stat().st_mode&0o777,0o666)
 def test_lock_symlink_and_native_unsafe_permissions_fail_closed(self):
  p=self.cache();outside=self.home/'outside';outside.write_text('untouched');(p.parent/'oauth.lock').symlink_to(outside)
  self.assertNotEqual(self.invoke().returncode,0);self.assertEqual(outside.read_text(),'untouched');self.assertEqual(self.server.requests,[])
  (p.parent/'oauth.lock').unlink();p.chmod(0o644);self.assertNotEqual(self.invoke().returncode,0)
 def test_external_unknown_expiry_rejected(self):
  path=self.cache(external=True,expiry_date=0)
  self.assertNotEqual(self.invoke().returncode,0)
  obj=json.loads(path.read_text());obj.pop('expiry_date');path.write_text(json.dumps(obj))
  self.assertNotEqual(self.invoke().returncode,0);self.assertEqual(self.server.requests,[])
 def test_canceled_lock_wait_returns_without_network(self):
  path=self.cache();lock=path.parent/'oauth.lock'
  with lock.open('w') as held:
   lock.chmod(0o600);fcntl.flock(held,fcntl.LOCK_EX);start=time.monotonic()
   result=self.invoke('cancel',timeout=3)
   self.assertNotEqual(result.returncode,0);self.assertLess(time.monotonic()-start,2);self.assertEqual(self.server.requests,[])
 def test_raw_ctrl_c_byte_cancels_contended_lock(self):
  path=self.cache();lock=path.parent/'oauth.lock'
  with lock.open('w') as held:
   lock.chmod(0o600);fcntl.flock(held,fcntl.LOCK_EX)
   args=['python3','-c',DRIVER,str(self.library),'rawcancel',str(self.home),str(self.ca)]
   child=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
   time.sleep(.2);start=time.monotonic();out,err=child.communicate(b'\x03',timeout=3)
   self.assertNotEqual(child.returncode,0);self.assertLess(time.monotonic()-start,1);self.assertEqual(self.server.requests,[])
 def test_failed_refresh_keeps_previous_cache_and_secrets_private(self):
  path=self.cache();before=path.read_bytes();self.server.responses.append((400,{'error':'invalid_grant','error_description':'fresh-refresh-private'}))
  result=self.invoke();self.assertNotEqual(result.returncode,0);self.assertEqual(path.read_bytes(),before);self.assert_private(result)
 def test_denied_no_cache_and_no_secret_output(self):
  self.server.responses.extend([(200,self.device()),(400,{'error':'access_denied','error_description':'fresh-access-private'})])
  result=self.invoke('login');self.assertNotEqual(result.returncode,0);self.assertIn(b'denied',result.stderr);self.assert_private(result);self.assertFalse((self.home/'.config/qwen-x86/oauth.json').exists())
 def test_invalid_display_uri_controls_rejected_before_printing(self):
  self.server.responses.append((200,self.device(verification_uri='https://example.invalid/\x1b]52;clipboard')))
  result=self.invoke('login');self.assertNotEqual(result.returncode,0);self.assertNotIn(b'\x1b',result.stdout);self.assertEqual(len(self.server.requests),1)
 def test_invalid_json_and_oversized_response_fail_closed(self):
  for payload in [b'{broken',b' '*65536]:
   self.server.responses.append((200,payload));result=self.invoke('login');self.assertNotEqual(result.returncode,0);self.assert_private(result)
 def test_slowdown_respects_increased_interval_then_expiry(self):
  self.server.responses.extend([(200,self.device(expires_in=3)),(400,{'error':'slow_down'})]);start=time.monotonic()
  result=self.invoke('login',timeout=8);elapsed=time.monotonic()-start
  self.assertNotEqual(result.returncode,0);self.assertIn(b'expired',result.stderr);self.assertGreaterEqual(elapsed,2.8);self.assertEqual(len(self.server.requests),2)

if __name__=='__main__':unittest.main()
