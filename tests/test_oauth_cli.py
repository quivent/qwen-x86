"""Production assembly cache->OAuth endpoint/model selection->verified HTTPS."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from test_cli import answer, disable_core
from test_https_cli import HTTPSModelServer
from test_tls import make_certificates
ROOT=Path(__file__).resolve().parents[1]

class OAuthProductionCLI(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
  cls.certificates=tempfile.TemporaryDirectory(prefix='qwen-oauth-cli-certs-')
  cls.ca,cls.cert,cls.key=make_certificates(cls.certificates.name)
 @classmethod
 def tearDownClass(cls):cls.certificates.cleanup()
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(prefix='qwen-oauth-cli-');self.base=Path(self.temp.name)
  self.home=self.base/'home';self.home.mkdir(mode=0o700)
  self.workspace=self.base/'work';self.workspace.mkdir()
  self.env=dict(os.environ,HOME=str(self.home))
  for name in ['QWEN_API_KEY','OPENAI_API_KEY','QWEN_BASE_URL','OPENAI_BASE_URL','QWEN_MODEL','OPENAI_MODEL']:self.env.pop(name,None)
 def tearDown(self):self.temp.cleanup()
 def cache(self,resource,external=False):
  directory=self.home/'.config'/('qwen-go' if external else 'qwen-x86')
  directory.mkdir(mode=0o700,parents=True)
  path=directory/'oauth.json'
  path.write_text(json.dumps({'access_token':'fake-cached-access-only','refresh_token':'fake-refresh-must-remain-private','token_type':'Bearer','expiry_date':int((time.time()+3600)*1000),'resource_url':resource}))
  path.chmod(0o600)
  return path
 def run_cli(self,*flags):
  return subprocess.run([str(ROOT/'qwen-x86'),'--cwd',str(self.workspace),'--ca-file',str(self.ca),'-p','Say ready',*flags],env=self.env,capture_output=True,timeout=12,preexec_fn=disable_core)
 def test_native_cache_selects_resource_and_coder_model_without_leaking_tokens(self):
  with HTTPSModelServer(self.cert,self.key,[lambda _:answer('OAuth ready')]) as server:
   self.cache(server.url.removeprefix('https://').removesuffix('/v1'))
   result=self.run_cli()
  self.assertEqual(result.returncode,0,result.stderr)
  self.assertEqual(server.requests[0]['model'],'coder-model')
  self.assertEqual(server.targets,[b'POST /v1/chat/completions HTTP/1.1'])
  self.assertEqual(server.headers[0][b'authorization'],b'Bearer fake-cached-access-only')
  self.assertIn(b'OAuth ready',result.stdout)
  for path in self.home.rglob('session-*.json'):
   self.assertNotIn('fake-cached-access',path.read_text());self.assertNotIn('fake-refresh',path.read_text())
  self.assertNotIn(b'fake-cached-access',result.stdout+result.stderr)
 def test_external_unexpired_cache_is_reused_without_changing_file(self):
  with HTTPSModelServer(self.cert,self.key,[lambda _:answer('external ready')]) as server:
   path=self.cache(server.url,external=True);before=path.read_bytes();stamp=path.stat().st_mtime_ns
   result=self.run_cli('--no-save')
  self.assertEqual(result.returncode,0,result.stderr)
  self.assertEqual(path.read_bytes(),before);self.assertEqual(path.stat().st_mtime_ns,stamp)
  self.assertFalse((self.home/'.config/qwen-x86/oauth.json').exists())
  self.assertEqual(server.headers[0][b'authorization'],b'Bearer fake-cached-access-only')
 def test_explicit_endpoint_and_model_survive_oauth_configuration(self):
  self.cache('https://resource-must-not-be-used.invalid')
  with HTTPSModelServer(self.cert,self.key,[lambda _:answer('overrides ready')]) as server:
   result=self.run_cli('--base-url',server.url,'--model','explicit-coder','--no-save')
  self.assertEqual(result.returncode,0,result.stderr)
  self.assertEqual(server.requests[0]['model'],'explicit-coder')
  self.assertEqual(server.headers[0][b'authorization'],b'Bearer fake-cached-access-only')
 def test_api_key_takes_precedence_over_oauth_cache(self):
  self.cache('https://resource-must-not-be-used.invalid');self.env['QWEN_API_KEY']='fake-explicit-key'
  with HTTPSModelServer(self.cert,self.key,[lambda _:answer('key ready')]) as server:
   result=self.run_cli('--base-url',server.url,'--no-save')
  self.assertEqual(result.returncode,0,result.stderr)
  self.assertEqual(server.requests[0]['model'],'qwen3-coder-plus')
  self.assertEqual(server.headers[0][b'authorization'],b'Bearer fake-explicit-key')

 def test_empty_qwen_environment_allows_openai_fallbacks(self):
  self.env.update(QWEN_API_KEY='',OPENAI_API_KEY='fake-openai-fallback',QWEN_MODEL='',OPENAI_MODEL='fallback-model',QWEN_BASE_URL='')
  with HTTPSModelServer(self.cert,self.key,[lambda _:answer('fallback ready')]) as server:
   self.env['OPENAI_BASE_URL']=server.url
   result=self.run_cli('--no-save')
  self.assertEqual(result.returncode,0,result.stderr)
  self.assertEqual(server.requests[0]['model'],'fallback-model')
  self.assertEqual(server.headers[0][b'authorization'],b'Bearer fake-openai-fallback')

if __name__=='__main__':unittest.main()
