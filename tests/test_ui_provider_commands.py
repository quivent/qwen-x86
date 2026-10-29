"""Actual production auth/settings/account controllers with masked credentials."""
import fcntl,json,os,pathlib,pty,select,struct,subprocess,tempfile,termios,time,unittest
from test_cli import answer,disable_core
from test_provider_cli import ProviderServer
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ProviderControllerTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def test_first_run_masked_auth_cancel_isolation_settings_key_and_restart(self):
  with tempfile.TemporaryDirectory(prefix='qwen-auth-controllers-') as d:
   base=pathlib.Path(d);home=base/'home';home.mkdir();work=base/'work';work.mkdir()
   with ProviderServer(lambda r:answer('AUTH_CONTROLLER_REQUEST_DONE_'+str(len(server.records)))) as server:
    env={k:v for k,v in os.environ.items() if k not in ['QWEN_API_KEY','OPENAI_API_KEY','QWEN_BASE_URL','OPENAI_BASE_URL','QWEN_MODEL','OPENAI_MODEL']};env.update(HOME=str(home),TERM='xterm-256color')
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',35,110,0,0));before=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--cwd',str(work)],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);raw=bytearray()
    def until(needle,start=0,timeout=5):
     end=time.monotonic()+timeout
     while needle not in raw[start:] and time.monotonic()<end and proc.poll() is None:
      if select.select([master],[],[],.03)[0]:
       try:raw.extend(os.read(master,262144))
       except OSError:break
     self.assertIn(needle,raw[start:],repr(bytes(raw[-2500:])))
    def send(data,needle):
     start=len(raw);os.write(master,data);until(needle,start)
    def custom_setup(key,model,base_url,anthropic=False):
     send(b'\x1b[B\x1b[B\r',b'Protocol')
     send(b'\x1b[B\r' if anthropic else b'\r',b'Base URL' if anthropic else b'Chat Completions')
     if not anthropic:send(b'\r',b'Base URL')
     send(base_url.encode()+b'\r',b'Use environment variable');send(b'\r',b'API Key');send(key.encode()+b'\r',b'Model IDs');send(model.encode()+b'\r',b'Review')
    try:
     until(b'Custom Provider');self.assertIn(b'Alibaba ModelStudio',raw);self.assertIn(b'Third-party Providers',raw)
     custom_setup('secret-first-native-key','actual-controller-model',server.url);send(b'\r',b'Provider connected.')
     path=home/'.config/qwen-x86/ui.json';initial=path.read_bytes();prefs=json.loads(initial);self.assertEqual(prefs['apiKey'],'secret-first-native-key');self.assertEqual(prefs['apiKeySource'],'stored');self.assertEqual(path.stat().st_mode&0o777,0o600)
     send(b'/auth\r',b'Custom Provider');custom_setup('cancelled-new-provider-key','must-not-become-active',server.url+'/alternate',anthropic=True)
     send(b'\x1b',b'Custom Provider');send(b'\x1b',b'Type your message');self.assertEqual(path.read_bytes(),initial)
     send(b'check committed profile\r',b'AUTH_CONTROLLER_REQUEST_DONE_1');self.assertEqual(server.records[-1][1]['model'],'actual-controller-model');self.assertEqual(server.headers[-1][0],b'POST /v1/chat/completions HTTP/1.1');self.assertEqual(server.headers[-1][1][b'authorization'],b'Bearer secret-first-native-key')
     send(b'/account\r',b'Account information');send(b'\r',b'Protocol:');send(b'\x1b',b'Account information');send(b'\x1b',b'Type your message')
     send(b'/settings\r',b'Settings');send(b'\x1b[B'*3+b'\r',b'Use environment variable');send(b'\r',b'API Key');send(b'secret-updated-native-key\r',b'Settings');send(b'\x1b',b'Type your message')
     send(b'check updated key\r',b'AUTH_CONTROLLER_REQUEST_DONE_2');self.assertEqual(server.headers[-1][1][b'authorization'],b'Bearer secret-updated-native-key')
     os.write(master,b'/quit\r');proc.wait(timeout=3)
     while select.select([master],[],[],.03)[0]:
      try:raw.extend(os.read(master,262144))
      except OSError:break
     self.assertIn(b'\x1b[?1049l',raw);self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),before)
     for secret in [b'secret-first-native-key',b'cancelled-new-provider-key',b'secret-updated-native-key']:self.assertNotIn(secret,raw)
     result=subprocess.run([str(ROOT/'qwen-x86'),'--cwd',str(work),'--prompt','restart uses private saved key'],env=env,capture_output=True,timeout=5,preexec_fn=disable_core);self.assertEqual(result.returncode,0,result.stderr);self.assertIn(b'AUTH_CONTROLLER_REQUEST_DONE',result.stdout);self.assertEqual(server.headers[-1][1][b'authorization'],b'Bearer secret-updated-native-key');self.assertEqual(server.records[-1][1]['model'],'actual-controller-model')
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)
if __name__=='__main__':unittest.main()
