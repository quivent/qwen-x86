"""Production ELF delegates to actual external-process protocol fixtures.
No provider credentials or live external model calls are used.
"""
import json,os,pathlib,subprocess,tempfile,unittest
from test_cli import ConcurrentServer,answer,tool_events,disable_core
from test_agent_executor import FIXTURE
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ExternalExecutorCLITests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def workflow(self,kind,follow=False,missing=False):
  with tempfile.TemporaryDirectory(prefix='native-external-cli-') as d:
   home=pathlib.Path(d);bin=home/'bin';bin.mkdir();log=home/'external.jsonl'
   if not missing:
    executable=bin/('codex' if kind=='codex' else 'claude-agent-acp');executable.write_text(FIXTURE);executable.chmod(0o700)
   env=dict(os.environ,HOME=d,PATH=str(bin),QWEN_API_KEY='fake-native-model-key',EXECUTOR_LOG=str(log),EXECUTOR_CASE='normal')
   for key in ['OPENAI_API_KEY','OPENAI_BASE_URL','OPENAI_MODEL','QWEN_BASE_URL','QWEN_MODEL']:env.pop(key,None)
   seen=[];stage=0;job=None;reports=[]
   def handler(req):
    nonlocal stage,job
    seen.append(req);i=stage;stage+=1
    tools=[m for m in req['messages'] if m['role']=='tool']
    if i==0:return tool_events([('spawn_agent',{'name':'external fixture','prompt':'perform verified task λ','agent_type':kind})])
    if i==1:
     job=json.loads(tools[-1]['content']);return tool_events([('wait_agent',{'id':job['id'],'timeout_seconds':3})])
    if i==2:
     result=json.loads(tools[-1]['content']);reports.append(result)
     if follow:return tool_events([('send_agent_message',{'id':job['id'],'message':'followup verified task'})])
     return answer('parent verified external report')
    if i==3:
     if kind=='codex':
      self.assertIn('one-shot',tools[-1]['content']);return answer('parent verified one-shot restriction')
     result=json.loads(tools[-1]['content']);return tool_events([('wait_agent',{'id':result['id'],'timeout_seconds':3})])
    if i==4:
     reports.append(json.loads(tools[-1]['content']));return answer('parent verified actual ACP continuation')
    raise AssertionError('external worker incorrectly called model provider')
   with ConcurrentServer(handler) as server:
    args=[str(ROOT/'qwen-x86'),'--yes','--base-url',server.url,'--cwd',d,'--prompt','delegate external fixture']
    if not follow:args.insert(1,'--no-save')
    proc=subprocess.run(args,env=env,capture_output=True,timeout=12,preexec_fn=disable_core)
   self.assertEqual(proc.returncode,0,((proc.stdout+proc.stderr).decode(errors='replace'),len(seen),stage,[m for req in seen for m in req['messages'] if m['role']=='tool']));self.assertTrue(reports)
   if missing:
    self.assertEqual(reports[0]['status'],'failed');self.assertIn('not installed',reports[0]['report']);self.assertFalse(log.exists());return
   for report in reports:
    self.assertEqual(report['status'],'completed',report);self.assertIn('verified '+('Codex' if kind=='codex' else 'ACP')+' λ answer',report['report'])
   records=[json.loads(x) for x in log.read_text().splitlines()];frames=[r['frame'] for r in records if 'frame'in r]
   if kind=='codex':self.assertEqual(sum(f.get('method')=='thread/start' for f in frames),1);self.assertEqual(len(seen),4 if follow else 3)
   elif follow:
    self.assertEqual(sum(f.get('method')=='session/new' for f in frames),1);self.assertEqual(sum(f.get('method')=='session/load' for f in frames),1);self.assertEqual(len(seen),5)
   else:self.assertEqual(len(seen),3)
 def test_production_codex_delegation_and_one_shot_guard(self):self.workflow('codex',follow=True)
 def test_production_acp_saved_followup_uses_session_load(self):self.workflow('claude-code',follow=True)
 def test_production_missing_external_adapter_does_not_fallback_to_model(self):self.workflow('claude-code',missing=True)
