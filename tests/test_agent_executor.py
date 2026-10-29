"""Real subprocess JSON-RPC conversations through the native external adapters.
Python is the *external CLI fixture*, never part of the native application.
"""
import ctypes as C,json,os,pathlib,subprocess,tempfile,unittest,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
FIXTURE=r'''#!/usr/bin/python3
import json,sys,os,time,pathlib
log=pathlib.Path(os.environ['EXECUTOR_LOG'])
def record(value):
 with log.open('a') as f:f.write(json.dumps(value)+'\n')
def send(v):
 raw=(json.dumps(v,ensure_ascii=False)+'\n').encode()
 if os.environ.get('EXECUTOR_CASE')=='fragmented':
  for i in range(0,len(raw),3):os.write(1,raw[i:i+3])
 else:os.write(1,raw)
def read():
 line=sys.stdin.readline()
 if not line:raise SystemExit(0)
 v=json.loads(line);record({'frame':v});return v
def reply(v,result):send({'jsonrpc':'2.0','id':v['id'],'result':result})
case=os.environ.get('EXECUTOR_CASE','normal');record({'argv':sys.argv,'cwd':os.getcwd(),'env':{k:v for k,v in os.environ.items() if k.startswith('QWEN_') or k in ['CODEX_THREAD_ID','NODE_OPTIONS','CLAUDECODE']}})
if case=='exit':raise SystemExit(9)
if case=='malformed':os.write(1,b'{broken\n');time.sleep(1);raise SystemExit(0)
if case=='hang':time.sleep(20);raise SystemExit(0)
if 'app-server' in sys.argv:
 v=read();assert v['method']=='initialize';reply(v,{})
 assert read()['method']=='initialized'
 v=read();assert v['method']=='thread/start';reply(v,{'thread':{'id':'thread-λ','ephemeral':case!='non-ephemeral'}})
 if case=='non-ephemeral':time.sleep(5);raise SystemExit(0)
 v=read();assert v['method']=='turn/start';turn='turn-real'
 send({'method':'turn/started','params':{'threadId':'thread-λ','turn':{'id':turn,'status':'inProgress'}}});reply(v,{'turn':{'id':turn}})
 if case in ['approve','cancel-only','unsupported']:
  method='item/commandExecution/requestApproval' if case!='unsupported' else 'unsupported/method'
  send({'id':'permission-λ','method':method,'params':{'availableDecisions':['cancel'] if case=='cancel-only' else ['accept','decline']}});answer=read();record({'permission':answer})
  if case=='unsupported':time.sleep(5);raise SystemExit(0)
 send({'method':'item/completed','params':{'threadId':'foreign','turnId':turn,'item':{'type':'agentMessage','phase':'final_answer','text':'MUST NOT DISPLAY'}}})
 send({'method':'item/completed','params':{'threadId':'thread-λ','turnId':turn,'item':{'type':'agentMessage','phase':'commentary','text':'not final'}}})
 send({'method':'item/completed','params':{'threadId':'thread-λ','turnId':'wrong-turn' if case=='wrong-turn' else turn,'item':{'type':'agentMessage','phase':'final_answer','text':' \t\n\u00a0\u2000\ufeff' if case=='whitespace' else 'verified Codex λ answer'}}})
 if case=='wrong-turn':time.sleep(5);raise SystemExit(0)
 send({'method':'turn/completed','params':{'threadId':'thread-λ','turn':{'id':turn,'status':'failed' if case=='failed' else 'completed'}}})
else:
 v=read();assert v['method']=='initialize';reply(v,{'protocolVersion':9 if case=='bad-version' else 1,'agentCapabilities':{'loadSession':case!='no-load'}})
 if case=='bad-version':time.sleep(5);raise SystemExit(0)
 v=read();assert v['method'] in ['session/new','session/load'];reply(v,{'sessionId':'session-λ' if v['method']=='session/new' else v['params']['sessionId'],'modes':{'availableModes':[{'id':x} for x in (['plan'] if case=='missing-mode' else ['default','plan','acceptEdits','bypassPermissions'])]}})
 if case=='missing-mode':time.sleep(5);raise SystemExit(0)
 v=read();assert v['method']=='session/set_mode';reply(v,{})
 v=read();assert v['method']=='session/prompt'
 if case in ['approve','duplicate-options']:
  send({'jsonrpc':'2.0','id':77,'method':'session/request_permission','params':{'sessionId':'session-λ','toolCall':{'toolCallId':'tool-1','title':'Write file λ','rawInput':{'path':'out.txt','content':'approved'}},'options':[{'optionId':'allow-1','kind':'allow_once'},{'optionId':'allow-1' if case=='duplicate-options' else 'deny-1','kind':'reject_once'}]}})
  answer=read();record({'permission':answer})
  if case=='duplicate-options':time.sleep(5);raise SystemExit(0)
 send({'method':'session/update','params':{'sessionId':'foreign','update':{'sessionUpdate':'agent_message_chunk','content':{'type':'text','text':'MUST NOT DISPLAY'}}}})
 for text in ['verified ACP ','λ answer']:
  send({'method':'session/update','params':{'sessionId':'session-λ','update':{'sessionUpdate':'agent_message_chunk','content':{'type':'text','text':text}}}})
 reply(v,{'stopReason':'end_turn'})
time.sleep(5)
'''
class ExternalExecutorTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  for name in ['agent_executor','json','runtime']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared','-Bsymbolic',*[str(base/(n+'.o')) for n in ['agent_executor','json','runtime']],'-o',str(base/'executor.so')],check=True);cls.lib=C.CDLL(str(base/'executor.so'))
  for name,args in {'agent_executor_available':[C.c_char_p,C.c_void_p],'agent_executor_execute':[C.c_char_p,C.c_char_p,C.c_char_p,C.c_void_p,C.c_void_p,C.c_size_t],'agent_executor_set_mode':[C.c_int],'agent_executor_set_cancel':[C.c_void_p],'agent_executor_set_approval':[C.c_void_p],'agent_executor_set_session':[C.c_char_p],'agent_executor_save_session':[C.c_char_p,C.c_int],'agent_executor_load_session':[C.c_char_p,C.c_char_p]}.items():fn=getattr(cls.lib,name);fn.argtypes=args;fn.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.base=pathlib.Path(self.tmp.name);self.bin=self.base/'bin';self.bin.mkdir();self.cwd=self.base/'workspace';self.cwd.mkdir();self.log=self.base/'protocol.jsonl'
  for name in ['codex','claude-agent-acp']:p=self.bin/name;p.write_text(FIXTURE);p.chmod(0o700)
  self.lib.agent_executor_set_mode(0);self.lib.agent_executor_set_cancel(None);self.lib.agent_executor_set_approval(None);self.lib.agent_executor_set_session(None)
 def env(self,case='normal',extra=None):
  env=dict(os.environ,PATH=str(self.bin),EXECUTOR_LOG=str(self.log),EXECUTOR_CASE=case,QWEN_SERVER_TOKEN='must-not-leak',QWEN_DAEMON_TOKEN='must-not-leak',QWEN_CODE_EXTERNAL_TOOL_GUARD_TOKEN='must-not-leak',QWEN_CODE_PRIVATE_ACP_CAPABILITY='must-not-leak',CODEX_THREAD_ID='must-not-leak',CLAUDECODE='must-not-leak',NODE_OPTIONS='must-not-leak',QWEN_API_KEY='own-external-env')
  env.update(extra or {});raw=[os.fsencode(k+'='+v) for k,v in env.items()];return (C.c_char_p*(len(raw)+1))(*raw,None)
 def execute(self,name='codex',case='normal',cap=65536):
  out=C.create_string_buffer(b'unchanged',65536);n=self.lib.agent_executor_execute(name.encode(),'perform verified task λ'.encode(),os.fsencode(self.cwd),self.env(case),out,cap);return n,out.raw[:n] if n>=0 else out.value
 def records(self):return [json.loads(x) for x in self.log.read_text().splitlines()]
 def test_codex_real_appserver_protocol_ephemeral_thread_and_final_phase(self):
  n,out=self.execute();self.assertGreater(n,0);self.assertEqual(out,'verified Codex λ answer'.encode());rows=self.records();self.assertEqual(rows[0]['argv'][1:],['app-server','--stdio']);self.assertEqual(rows[0]['cwd'],str(self.cwd));self.assertEqual(rows[0]['env'],{'QWEN_API_KEY':'own-external-env'})
  frames=[r['frame'] for r in rows if 'frame'in r];thread=next(x for x in frames if x.get('method')=='thread/start');self.assertEqual(thread['params']['approvalPolicy'],'never');self.assertTrue(thread['params']['ephemeral']);self.assertEqual(thread['params']['sandbox'],'read-only');self.assertEqual(frames[-1]['params']['input'][0]['text'],'perform verified task λ')
 def test_codex_sandbox_policy_modes_and_fragmented_transport(self):
  for mode,want in [(1,'workspace-write'),(2,'read-only'),(3,'danger-full-access')]:
   self.lib.agent_executor_set_mode(mode);self.log.unlink(missing_ok=True);n,out=self.execute(case='fragmented');self.assertGreater(n,0);frames=[r['frame'] for r in self.records() if 'frame'in r];self.assertEqual(next(x for x in frames if x.get('method')=='thread/start')['params']['sandbox'],want)
 def test_codex_unattended_requests_receive_only_offered_rejection(self):
  for case,want in [('approve','decline'),('cancel-only','cancel')]:
   self.log.unlink(missing_ok=True);n,out=self.execute(case=case);self.assertGreater(n,0);reply=next(r['permission'] for r in self.records() if 'permission'in r);self.assertEqual(reply['id'],'permission-λ');self.assertEqual(reply['result'],{'decision':want})
 def test_bad_protocol_wrong_identity_failed_turn_and_empty_executable_fail_closed(self):
  for case in ['malformed','wrong-turn','failed','non-ephemeral','exit','unsupported','whitespace']:
   with self.subTest(case=case):n,out=self.execute(case=case);self.assertLess(n,0);self.assertEqual(out,b'unchanged')
  (self.bin/'codex').unlink();self.assertEqual(self.lib.agent_executor_available(b'codex',self.env()),0);n,out=self.execute();self.assertEqual(n,-2)
 def test_acp_actual_handshake_mode_selection_chunks_and_permission_broker(self):
  requests=[];callback_type=C.CFUNCTYPE(C.c_int64,C.c_char_p,C.c_char_p,C.c_void_p,C.c_size_t)
  @callback_type
  def approve(title,tool,args,length):requests.append((title,tool,json.loads(C.string_at(args,length))));return 1
  self.lib.agent_executor_set_approval(approve);n,out=self.execute('claude-code','approve');self.assertGreater(n,0);self.assertEqual(out,'verified ACP λ answer'.encode());self.assertEqual(requests,[('Write file λ'.encode(),b'external_tool',{'path':'out.txt','content':'approved'})]);reply=next(r['permission'] for r in self.records() if 'permission'in r);self.assertEqual(reply['result'],{'outcome':{'outcome':'selected','optionId':'allow-1'}})
 def test_acp_missing_modes_bad_protocol_and_duplicate_options_rejected(self):
  for case in ['missing-mode','bad-version','duplicate-options']:
   n,out=self.execute('claude-code',case);self.assertLess(n,0);self.assertEqual(out,b'unchanged')
 def test_acp_without_approval_surface_denies_exact_option_and_continues(self):
  n,out=self.execute('claude-code','approve');self.assertGreater(n,0);reply=next(r['permission'] for r in self.records() if 'permission'in r);self.assertEqual(reply['result'],{'outcome':{'outcome':'selected','optionId':'deny-1'}})
 def test_cancel_and_capacity_cleanup_no_fd_leaks(self):
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()));callback_type=C.CFUNCTYPE(C.c_int64)
  @callback_type
  def cancel():return -125
  self.lib.agent_executor_set_cancel(cancel);start=time.monotonic();n,out=self.execute(case='hang');self.assertEqual(n,-125);self.assertLess(time.monotonic()-start,2);self.lib.agent_executor_set_cancel(None)
  n,out=self.execute(cap=2);self.assertEqual(n,-28);self.assertEqual(out,b'unchanged');self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)

 def test_acp_session_save_load_and_real_session_load_handshake(self):
  n,out=self.execute('claude-code');self.assertGreater(n,0);native=self.base/'session-native.json';native.write_text('[]');self.assertEqual(self.lib.agent_executor_save_session(os.fsencode(native),1),0);sidecar=pathlib.Path(str(native)+'.agent.json');self.assertEqual(json.loads(sidecar.read_text()),{'kind':'acp','sessionId':'session-λ','cwd':str(self.cwd)});self.assertEqual(sidecar.stat().st_mode&0o777,0o600)
  self.lib.agent_executor_set_session(None);self.assertEqual(self.lib.agent_executor_load_session(os.fsencode(native),os.fsencode(self.cwd)),0);self.log.unlink();n,out=self.execute('claude-code');self.assertGreater(n,0);frames=[r['frame'] for r in self.records() if 'frame'in r];load=next(f for f in frames if f.get('method')=='session/load');self.assertEqual(load['params'],{'sessionId':'session-λ','cwd':str(self.cwd),'mcpServers':[]});self.assertFalse(any(f.get('method')=='session/new' for f in frames))
  self.assertLess(self.lib.agent_executor_load_session(os.fsencode(native),b'/different-workspace'),0);self.assertFalse(list(self.base.glob('.agent-*')))
 def test_acp_resume_unsupported_never_creates_fresh_session_and_sidecars_safe(self):
  self.assertEqual(self.lib.agent_executor_set_session('prior-session'.encode()),0);n,out=self.execute('claude-code','no-load');self.assertEqual(n,-95);self.assertEqual(out,b'unchanged');frames=[r['frame'] for r in self.records() if 'frame'in r];self.assertEqual([x['method'] for x in frames],['initialize'])
  self.lib.agent_executor_set_session(None);self.execute('claude-code');native=self.base/'session-safe.json';native.write_text('[]');self.assertEqual(self.lib.agent_executor_save_session(os.fsencode(native),0),0);sidecar=pathlib.Path(str(native)+'.agent.json');self.assertFalse(sidecar.exists());self.assertEqual(self.lib.agent_executor_save_session(os.fsencode(native),1),0);before=sidecar.read_bytes()
  link=self.base/'session-linked.json';link.symlink_to(native);self.assertLess(self.lib.agent_executor_save_session(os.fsencode(link),1),0)
  sidecar.unlink();outside=self.base/'outside';outside.write_bytes(before);sidecar.symlink_to(outside);self.assertLess(self.lib.agent_executor_load_session(os.fsencode(native),os.fsencode(self.cwd)),0);self.assertEqual(outside.read_bytes(),before)
  sidecar.unlink();os.mkfifo(sidecar);self.assertLess(self.lib.agent_executor_load_session(os.fsencode(native),os.fsencode(self.cwd)),0)
