"""Production ELF reuses one authenticated TLS connection across tool rounds."""
import json, os, socket, ssl, subprocess, tempfile, threading, unittest
from pathlib import Path
from test_cli import answer, tool_events, disable_core
from test_tls import make_certificates
ROOT = Path(__file__).resolve().parents[1]
class HTTPSKeepaliveTest(unittest.TestCase):
 def test_two_model_posts_use_one_verified_connection(self):
  subprocess.run(['make','-j2'],cwd=ROOT,check=True,capture_output=True)
  with tempfile.TemporaryDirectory(prefix='qwen-native-keepalive-') as folder:
   base=Path(folder); ca,cert,key=make_certificates(base)
   work=base/'work';work.mkdir();home=base/'home';home.mkdir()
   (work/'evidence.txt').write_text('verified persistent transport')
   context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
   context.minimum_version=context.maximum_version=ssl.TLSVersion.TLSv1_3
   context.load_cert_chain(cert,key)
   listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen(2);listener.settimeout(8)
   port=listener.getsockname()[1]; requests=[]; errors=[]
   def serve():
    try:
     raw,_=listener.accept();raw.settimeout(8)
     with context.wrap_socket(raw,server_side=True) as conn:
      buffered=b''
      for index in range(2):
       while b'\r\n\r\n' not in buffered:
        block=conn.recv(8192)
        if not block:raise EOFError('request headers')
        buffered+=block
       header,buffered=buffered.split(b'\r\n\r\n',1)
       headers=dict(line.split(b':',1) for line in header.split(b'\r\n')[1:])
       length=int(next(value for key,value in headers.items() if key.lower()==b'content-length'))
       while len(buffered)<length:
        block=conn.recv(8192)
        if not block:raise EOFError('request body')
        buffered+=block
       requests.append(json.loads(buffered[:length]));buffered=buffered[length:]
       payload=tool_events([('read_file',{'path':'evidence.txt'})]) if index==0 else answer('persistent TLS verified')
       conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: '+str(len(payload)).encode()+b'\r\n\r\n'+payload)
      conn.settimeout(3)
      try:conn.recv(8192)
      except (ssl.SSLError,ConnectionResetError):pass
    except Exception as error:errors.append(repr(error))
    finally:listener.close()
   thread=threading.Thread(target=serve,daemon=True);thread.start()
   env=dict(os.environ,HOME=str(home),QWEN_API_KEY='fixture-only-key')
   for name in ['QWEN_BASE_URL','OPENAI_BASE_URL','QWEN_MODEL','OPENAI_MODEL']:env.pop(name,None)
   process=subprocess.run([str(ROOT/'qwen-x86'),'--cwd',str(work),'--ca-file',str(ca),'--base-url',f'https://localhost:{port}/v1','--no-save','-p','Read evidence.txt'],env=env,capture_output=True,timeout=15,preexec_fn=disable_core)
   thread.join(10);self.assertFalse(thread.is_alive());self.assertEqual(errors,[])
   self.assertEqual(process.returncode,0,process.stderr);self.assertIn(b'persistent TLS verified',process.stdout)
   self.assertEqual(len(requests),2);self.assertEqual(requests[1]['messages'][-1]['role'],'tool')
   self.assertIn('verified persistent transport',requests[1]['messages'][-1]['content'])
if __name__=='__main__':unittest.main()
