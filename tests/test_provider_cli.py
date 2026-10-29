"""Production ELF selects actual configured providers and executes native tools."""
import base64,fcntl,json,os,pathlib,pty,select,socket,struct,subprocess,tempfile,termios,time,unittest
from test_cli import ConcurrentServer,disable_core
ROOT=pathlib.Path(__file__).resolve().parents[1]
def ae(type,**rest):return b'data: '+json.dumps({'type':type,**rest}).encode()+b'\n\n'
def anthropic_answer(text):return ae('content_block_start',index=0,content_block={'type':'text','text':''})+ae('content_block_delta',index=0,delta={'type':'text_delta','text':text})+ae('message_delta',delta={'stop_reason':'end_turn'})+ae('message_stop')
def anthropic_tool():return ae('content_block_start',index=1,content_block={'type':'tool_use','id':'native-anthropic-read','name':'read_file','input':{}})+ae('content_block_delta',index=1,delta={'type':'input_json_delta','partial_json':'{"path":"note.txt"}'})+ae('message_delta',delta={'stop_reason':'tool_use'})+ae('message_stop')
class ProviderServer(ConcurrentServer):
 def __init__(self,handler):super().__init__(handler);self.headers=[]
 def reply(self,connection,channel):
  try:
   with connection:
    connection.settimeout(5);raw=b''
    while b'\r\n\r\n' not in raw:
     part=connection.recv(8192)
     if not part:return
     raw+=part
    head,body=raw.split(b'\r\n\r\n',1);lines=head.split(b'\r\n');headers={k.lower():v.strip() for k,v in (line.split(b':',1) for line in lines[1:])};length=int(headers[b'content-length'])
    while len(body)<length:body+=connection.recv(8192)
    req=json.loads(body);self.headers.append((lines[0],headers));self.records.append((channel,req));payload=self.handler(req)
    connection.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\nContent-Length: '+str(len(payload)).encode()+b'\r\n\r\n')
    # Real HTTP fragmentation differs from provider SSE logical records.
    for i in range(0,len(payload),13):connection.sendall(payload[i:i+13])
  except Exception as e:self.errors.append(e)
class ProviderCLITests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def invoke_configured_profile(self,protocol,handler):
  with tempfile.TemporaryDirectory(prefix='qwen-provider-cli-') as d:
   base=pathlib.Path(d);home=base/'home';home.mkdir();work=base/'workspace';work.mkdir();(work/'note.txt').write_text('actual native file result')
   image=b'\x89PNG\r\n\x1a\n'+bytes(range(19));(work/'fixture.png').write_bytes(image)
   with ProviderServer(handler) as server:
    settings=home/'.qwen';settings.mkdir();p=settings/'settings.json';p.write_text(json.dumps({'modelProviders':{protocol:[{'id':'configured-provider-fixture','name':'Configured Native Provider','baseUrl':server.url,'envKey':'FIXTURE_PROVIDER_KEY'}]}}));p.chmod(0o600)
    env={k:v for k,v in os.environ.items() if k not in ['QWEN_BASE_URL','OPENAI_BASE_URL','QWEN_MODEL','OPENAI_MODEL','OPENAI_API_KEY']};env.update(HOME=str(home),QWEN_API_KEY='initial-fixture-key',FIXTURE_PROVIDER_KEY='provider-fixture-private',TERM='xterm-256color')
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,0,0));before=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--cwd',str(work),'--base-url',server.url,'--yes'],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);raw=bytearray()
    def until(predicate,timeout=7):
     end=time.monotonic()+timeout
     while not predicate() and time.monotonic()<end and proc.poll() is None:
      if select.select([master],[],[],.03)[0]:
       try:raw.extend(os.read(master,262144))
       except OSError:break
     self.assertTrue(predicate(),repr(bytes(raw[-3000:])))
    try:
     until(lambda:b'Type your message' in raw);os.write(master,b'/model\r');until(lambda:b'Configured Native Provider' in raw);os.write(master,b'\x1b[A\r');time.sleep(.15)
     os.write(master,b'Inspect @fixture.png and read note\r');until(lambda:b'PROVIDER_NATIVE_DONE_2' in raw)
     os.write(master,b'Continue using history\r');until(lambda:b'PROVIDER_NATIVE_DONE_3' in raw);os.write(master,b'/quit\r');proc.wait(timeout=4)
     self.assertEqual(proc.returncode,0);self.assertEqual(termios.tcgetattr(slave),before);self.assertEqual(len(server.records),3);self.assertNotIn(b'provider-fixture-private',raw)
     saved=list((home/'.local/state/qwen-x86').glob('session-*.json'));self.assertEqual(len(saved),1);history=json.loads(saved[0].read_text());prefs=json.loads((home/'.config/qwen-x86/ui.json').read_text());self.assertEqual(prefs['authType'],protocol);self.assertNotIn('provider-fixture-private',(home/'.config/qwen-x86/ui.json').read_text())
     return [r for _,r in server.records],server.headers,history,image
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)
 def test_responses_production_tool_images_and_encrypted_reasoning_replay(self):
  calls=0;reasoning={'type':'reasoning','id':'rs_fixture','summary':[],'encrypted_content':'opaque-native-reasoning'}
  def handler(req):
   nonlocal calls
   calls+=1
   if calls==1:
    events=[{'type':'response.output_item.done','output_index':0,'item':reasoning},{'type':'response.output_item.added','output_index':1,'item':{'type':'function_call','id':'fc_internal','call_id':'native-responses-read','name':'read_file','arguments':''}},{'type':'response.function_call_arguments.delta','output_index':1,'delta':'{"path":"note.txt"}'},{'type':'response.completed','response':{'status':'completed'}}]
   else:events=[{'type':'response.output_text.delta','delta':'PROVIDER_NATIVE_DONE_'+str(calls)},{'type':'response.completed','response':{'status':'completed'}}]
   return b''.join(b'data: '+json.dumps(e).encode()+b'\n\n' for e in events)
  records,headers,history,image=self.invoke_configured_profile('openai-responses',handler)
  for path,h in headers:self.assertEqual(path,b'POST /v1/responses HTTP/1.1');self.assertEqual(h[b'authorization'],b'Bearer provider-fixture-private');self.assertNotIn(b'x-api-key',h)
  for r in records:
   self.assertIn('reasoning.encrypted_content',r['include']);self.assertFalse(r['store']);images=[b for m in r['input'] for b in m.get('content',[]) if isinstance(b,dict) and b.get('type')=='input_image'];self.assertEqual(len(images),1);self.assertEqual(base64.b64decode(images[0]['image_url'].split(',')[1]),image)
  self.assertIn(reasoning,records[1]['input']);self.assertTrue(any(m.get('type')=='function_call_output' and 'actual native file result' in m['output'] for m in records[1]['input']))
  assistant=next(m for m in history if m['role']=='assistant' and m.get('tool_calls'));self.assertEqual(assistant['provider_metadata']['items'],[reasoning])
 def test_gemini_production_tool_images_and_signed_model_parts_replay(self):
  calls=0;part={'functionCall':{'id':'native-google-read','name':'read_file','args':{'path':'note.txt'}},'thoughtSignature':'opaque-native-thought-signature'}
  def handler(req):
   nonlocal calls
   calls+=1;parts=[part] if calls==1 else [{'text':'PROVIDER_NATIVE_DONE_'+str(calls)}]
   return b'data: '+json.dumps({'candidates':[{'content':{'role':'model','parts':parts},'finishReason':'STOP'}]}).encode()+b'\n\n'
  records,headers,history,image=self.invoke_configured_profile('gemini',handler)
  for path,h in headers:self.assertEqual(path,b'POST /v1beta/models/configured-provider-fixture:streamGenerateContent?alt=sse HTTP/1.1');self.assertEqual(h[b'x-goog-api-key'],b'provider-fixture-private');self.assertNotIn(b'authorization',h)
  for r in records:
   images=[b['inlineData'] for m in r['contents'] for b in m['parts'] if 'inlineData' in b];self.assertEqual(len(images),1);self.assertEqual(base64.b64decode(images[0]['data']),image)
  self.assertIn({'role':'model','parts':[part]},records[1]['contents']);self.assertTrue(any('actual native file result' in b['functionResponse']['response']['output'] for m in records[1]['contents'] for b in m['parts'] if 'functionResponse' in b))
  assistant=next(m for m in history if m['role']=='assistant' and m.get('tool_calls'));self.assertEqual(assistant['provider_metadata']['parts'],[part])
 def test_anthropic_real_model_selection_tool_loop_images_and_saved_history(self):
  with tempfile.TemporaryDirectory(prefix='qwen-anthropic-cli-') as d:
   base=pathlib.Path(d);home=base/'home';home.mkdir();work=base/'workspace';work.mkdir();(work/'note.txt').write_text('actual native file result')
   image=b'\x89PNG\r\n\x1a\n'+bytes(range(19));(work/'fixture.png').write_bytes(image)
   def handler(req):
    if len(server.records)==1:return anthropic_tool()
    return anthropic_answer('ANTHROPIC_NATIVE_DONE_'+str(len(server.records)))
   with ProviderServer(handler) as server:
    settings=home/'.qwen';settings.mkdir();p=settings/'settings.json';p.write_text(json.dumps({'providerProtocol':{'fixture-provider':'anthropic'},'modelProviders':{'fixture-provider':[{'id':'configured-claude-fixture','name':'Configured Anthropic','baseUrl':server.url,'envKey':'FIXTURE_ANTHROPIC_KEY','description':'Local native protocol fixture'}]}}));p.chmod(0o600)
    env={k:v for k,v in os.environ.items() if k not in ['QWEN_BASE_URL','OPENAI_BASE_URL','QWEN_MODEL','OPENAI_MODEL','OPENAI_API_KEY']};env.update(HOME=str(home),QWEN_API_KEY='initial-fixture-key',FIXTURE_ANTHROPIC_KEY='anthropic-fixture-private',TERM='xterm-256color')
    master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,0,0));before=termios.tcgetattr(slave)
    proc=subprocess.Popen([str(ROOT/'qwen-x86'),'--cwd',str(work),'--base-url',server.url,'--yes'],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=disable_core);raw=bytearray()
    def until(predicate,timeout=7):
     end=time.monotonic()+timeout
     while not predicate() and time.monotonic()<end and proc.poll() is None:
      if select.select([master],[],[],.03)[0]:
       try:raw.extend(os.read(master,262144))
       except OSError:break
     self.assertTrue(predicate(),repr(bytes(raw[-3000:])))
    try:
     until(lambda:b'Type your message' in raw);os.write(master,b'/model\r');until(lambda:b'Configured Anthropic' in raw)
     # Runtime row is initially selected; previous row is the actual profile.
     os.write(master,b'\x1b[A\r');time.sleep(.15)
     os.write(master,b'Inspect @fixture.png and read note\r');until(lambda:b'ANTHROPIC_NATIVE_DONE_2' in raw)
     os.write(master,b'Continue using history\r');until(lambda:b'ANTHROPIC_NATIVE_DONE_3' in raw)
     os.write(master,b'/quit\r');proc.wait(timeout=4);self.assertEqual(proc.returncode,0)
     self.assertEqual(termios.tcgetattr(slave),before);self.assertEqual(len(server.records),3)
     for path,headers in server.headers:
      self.assertEqual(path,b'POST /v1/messages HTTP/1.1');self.assertEqual(headers[b'x-api-key'],b'anthropic-fixture-private');self.assertEqual(headers[b'anthropic-version'],b'2023-06-01');self.assertNotIn(b'authorization',headers)
     for _,req in server.records:
      self.assertEqual(req['model'],'configured-claude-fixture');self.assertIn('input_schema',req['tools'][0]);blocks=[b for m in req['messages'] for b in m['content'] if b['type']=='image'];self.assertEqual(len(blocks),1);self.assertEqual(base64.b64decode(blocks[0]['source']['data']),image)
     second=server.records[1][1];results=[b for m in second['messages'] for b in m['content'] if b['type']=='tool_result'];self.assertEqual(len(results),1);self.assertIn('actual native file result',results[0]['content'])
     saved=list((home/'.local/state/qwen-x86').glob('session-*.json'));self.assertEqual(len(saved),1);history=json.loads(saved[0].read_text());self.assertTrue(any(m['role']=='tool' for m in history));self.assertIsInstance(history[0]['content'],list)
     prefs=json.loads((home/'.config/qwen-x86/ui.json').read_text());self.assertEqual(prefs['model'],'configured-claude-fixture');self.assertEqual(prefs['authType'],'anthropic');self.assertEqual(prefs['apiKeyEnv'],'FIXTURE_ANTHROPIC_KEY');self.assertNotIn('anthropic-fixture-private',(home/'.config/qwen-x86/ui.json').read_text());self.assertNotIn(b'anthropic-fixture-private',raw)
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=2)
     os.close(master);os.close(slave)
if __name__=='__main__':unittest.main()
