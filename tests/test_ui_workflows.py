"""Production PTY workflows: visible UI choices change real backend behavior."""
import fcntl,json,os,pathlib,pty,select,struct,subprocess,tempfile,termios,time,unittest
from test_cli import ConcurrentServer,answer,tool_events,disable_core
ROOT=pathlib.Path(__file__).resolve().parents[1]
def tool_answer(name,args):return tool_events([(name,args)])

class UIWorkflowTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):subprocess.run(['make','-s','qwen-x86'],cwd=ROOT,check=True)
 def start(self,handler,save=False):
  self.tmp=tempfile.TemporaryDirectory(prefix='qwen-ui-workflow-');self.addCleanup(self.tmp.cleanup);self.root=pathlib.Path(self.tmp.name);self.work=self.root/'workspace';self.work.mkdir();self.home=self.root/'home';self.home.mkdir()
  self.server=ConcurrentServer(handler);self.server.__enter__();self.addCleanup(lambda:self.server.__exit__(None,None,None))
  self.master,self.slave=pty.openpty();fcntl.ioctl(self.slave,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,0,0));self.before=termios.tcgetattr(self.slave)
  env={k:v for k,v in os.environ.items() if k not in ['QWEN_BASE_URL','OPENAI_BASE_URL','QWEN_MODEL','OPENAI_MODEL','OPENAI_API_KEY']};env.update(HOME=str(self.home),QWEN_API_KEY='fixture-only',TERM='xterm-256color')
  self.proc=subprocess.Popen([str(ROOT/'qwen-x86'),*([] if save else ['--no-save']),'--cwd',str(self.work),'--base-url',self.server.url],stdin=self.slave,stdout=self.slave,stderr=self.slave,env=env,preexec_fn=disable_core);self.raw=bytearray();self.addCleanup(self.stop);self.until(lambda:b'Type your message' in self.raw)
 def stop(self):
  if self.proc.poll() is None:self.proc.kill();self.proc.wait(timeout=2)
  os.close(self.master);os.close(self.slave)
 def drain(self):
  if select.select([self.master],[],[],.02)[0]:
   try:self.raw.extend(os.read(self.master,262144))
   except OSError:pass
 def until(self,predicate,seconds=5):
  end=time.monotonic()+seconds
  while not predicate() and time.monotonic()<end and self.proc.poll() is None:self.drain()
  self.assertTrue(predicate(),repr(bytes(self.raw[-2500:])))
 def settle(self):
  end=time.monotonic()+.15
  while time.monotonic()<end:self.drain()
 def send(self,data):os.write(self.master,data);self.settle()
 def quit(self):
  self.send(b'/quit\r');self.proc.wait(timeout=3);self.assertEqual(self.proc.returncode,0);self.assertEqual(termios.tcgetattr(self.slave),self.before)
 def test_write_always_changes_mode_and_allows_distinct_edits(self):
  def handler(req):
   tools=[m for m in req['messages'] if m['role']=='tool']
   if len(tools)==0:return tool_answer('write_file',{'path':'first.txt','content':'first'})
   if len(tools)==1:return tool_answer('write_file',{'path':'second.txt','content':'second'})
   if len(tools)==2:return tool_answer('edit_file',{'path':'first.txt','old_string':'first','new_string':'edited'})
   return answer('WORKFLOW_ALL_EDITS_COMPLETE')
  self.start(handler);self.send(b'change files\r');self.until(lambda:b'Allow this action' in self.raw or b'allow always' in self.raw.lower())
  self.send(b'\x1b[B\r');self.until(lambda:b'WORKFLOW_ALL_EDITS_COMPLETE' in self.raw)
  self.assertEqual((self.work/'first.txt').read_text(),'edited');self.assertEqual((self.work/'second.txt').read_text(),'second');self.assertEqual(len(self.server.records),4)
  self.assertTrue(b'auto-accept edits' in self.raw,repr(bytes(self.raw[-800:])));self.quit()
 def test_resume_shell_entries_do_not_pollute_normal_prompt_history(self):
  self.start(lambda req:answer('RESUME_SHELL_DONE'))
  directory=self.home/'.local/state/qwen-x86';directory.mkdir(parents=True,exist_ok=True)
  wrapper='I ran the following shell command:\n```sh\nprintf restored\n```\n\nThis produced the following result:\n```\nrestored\n```'
  saved=directory/'session-shell-fixture.json'
  saved.write_text(json.dumps([{'role':'user','content':'saved normal prompt'},{'role':'assistant','content':'saved answer'},{'role':'user','content':wrapper}]))
  before=saved.read_bytes();marker=len(self.raw);self.send(b'/resume\r');self.until(lambda:b'saved normal prompt' in self.raw[marker:]);self.send(b'\r');self.settle()
  self.send(b'\x1b[A\r');self.until(lambda:len(self.server.records)==1);self.settle()
  users=[m['content'] for m in self.server.records[0][1]['messages'] if m['role']=='user']
  self.assertEqual(users,['saved normal prompt',wrapper,'saved normal prompt'])
  self.assertEqual(saved.read_bytes(),before);self.assertFalse((self.work/'restored').exists());self.quit()
 def test_clear_resets_model_context_but_ctrl_l_only_clears_screen(self):
  self.start(lambda req:answer('CLEAR_WORKFLOW_DONE'))
  self.send(b'first context\r');self.until(lambda:len(self.server.records)==1);self.settle()
  self.send(b'\x0c');self.send(b'still same context\r');self.until(lambda:len(self.server.records)==2);self.settle()
  users=[m['content'] for m in self.server.records[1][1]['messages'] if m['role']=='user']
  self.assertEqual(users,['first context','still same context'])
  self.send(b'/clear\r');self.send(b'fresh context\r');self.until(lambda:len(self.server.records)==3);self.settle()
  users=[m['content'] for m in self.server.records[2][1]['messages'] if m['role']=='user']
  self.assertEqual(users,['fresh context']);self.quit()
 def test_retry_shortcut_replays_failed_request_without_duplicate_user(self):
  calls=[0]
  def handler(req):
   calls[0]+=1
   return b'data: not-json\n\n' if calls[0]==1 else answer('RETRY_WORKFLOW_DONE')
  self.start(handler);self.send(b'retry this prompt\r');self.until(lambda:b'malformed model stream' in self.raw)
  self.send(b'\x19');self.until(lambda:b'RETRY_WORKFLOW_DONE' in self.raw)
  self.assertEqual(len(self.server.records),2)
  users=[m['content'] for m in self.server.records[1][1]['messages'] if m['role']=='user']
  self.assertEqual(users,['retry this prompt']);self.quit()
 def test_provider_error_keeps_status_and_details_visible_then_retries(self):
  calls=[0]
  def handler(req):
   calls[0]+=1
   if calls[0]==1:return 429,json.dumps({'error':{'message':'Fixture rate limit λ \x1b]52;c;ATTACK\x07'}}).encode()
   return answer('PROVIDER_RETRY_DONE')
  self.start(handler);self.send(b'provider failure case\r');self.until(lambda:b'HTTP 429: Fixture rate limit' in self.raw)
  self.assertNotIn(b'ATTACK',self.raw);self.assertNotIn(b'no TLS error',self.raw)
  self.send(b'\x19');self.until(lambda:b'PROVIDER_RETRY_DONE' in self.raw)
  self.assertEqual(len(self.server.records),2)
  self.assertEqual([m['content'] for m in self.server.records[1][1]['messages'] if m['role']=='user'],['provider failure case']);self.quit()
 def test_idle_session_feedback_remains_visible_without_a_request(self):
  self.start(lambda req:answer('unused'))
  marker=len(self.raw);self.send(b'/session\r');self.until(lambda:b'session-' in self.raw[marker:])
  self.assertEqual(len(self.server.records),0);self.quit()
 def test_unavailable_slash_command_does_not_make_model_request(self):
  self.start(lambda req:answer('ORDINARY_PROMPT_DONE'))
  marker=len(self.raw);self.send(b'/does-not-exist\r');self.until(lambda:b'Command unavailable' in self.raw[marker:]);self.assertEqual(len(self.server.records),0)
  self.send(b'ordinary prompt\r');self.until(lambda:b'ORDINARY_PROMPT_DONE' in self.raw)
  self.assertEqual([m['content'] for m in self.server.records[0][1]['messages'] if m['role']=='user'],['ordinary prompt']);self.quit()
 def test_help_is_tabbed_modal_and_never_submits_tab_text(self):
  self.start(lambda req:answer('HELP_CLOSED_NORMAL_DONE'))
  marker=len(self.raw);self.send(b'/help\r');self.until(lambda:b'general' in self.raw[marker:] and b'custom-commands' in self.raw[marker:])
  marker=len(self.raw);self.send(b'\t');self.until(lambda:b'/model' in self.raw[marker:])
  marker=len(self.raw);self.send(b'\t');self.until(lambda:b'/skill' in self.raw[marker:])
  self.assertEqual(len(self.server.records),0)
  self.send(b'\x1b');self.settle();self.send(b'after help\r');self.until(lambda:b'HELP_CLOSED_NORMAL_DONE' in self.raw)
  users=[m['content'] for m in self.server.records[0][1]['messages'] if m['role']=='user']
  self.assertEqual(users,['after help']);self.quit()
 def test_mermaid_copy_uses_cumulative_labels_and_exact_source(self):
  import base64
  def handler(req):
   last=[m['content'] for m in req['messages'] if m['role']=='user'][-1]
   return answer('```mermaid\n'+('graph TD; A-->B' if last=='first diagram' else 'graph LR; C-->D')+'\n```\nDIAGRAM_'+last.replace(' ','_'))
  self.start(handler);self.send(b'first diagram\r');self.until(lambda:b'DIAGRAM_first_diagram' in self.raw)
  self.send(b'second diagram\r');self.until(lambda:b'DIAGRAM_second_diagram' in self.raw)
  self.assertIn(b'/copy mermaid 2',self.raw)
  marker=len(self.raw);self.send(b'/copy mermaid 2\r')
  expected=b'\x1b]52;c;'+base64.b64encode(b'graph LR; C-->D\n')+b'\x07'
  self.until(lambda:expected in self.raw[marker:]);self.assertEqual(len(self.server.records),2);self.quit()
 def test_latex_copy_uses_cumulative_labels_and_original_source(self):
  import base64
  def handler(req):
   user=[m['content'] for m in req['messages'] if m['role']=='user'][-1]
   return answer('$$\n'+('\\sqrt{x}' if user=='second math' else '\\frac{a}{b}')+'\n$$\nMATH_'+user.replace(' ','_'))
  self.start(handler);self.send(b'first math\r');self.until(lambda:b'MATH_first_math' in self.raw)
  self.send(b'second math\r');self.until(lambda:b'MATH_second_math' in self.raw)
  self.assertIn(b'/copy latex 2',self.raw)
  marker=len(self.raw);self.send(b'/copy latex 2\r')
  expected=b'\x1b]52;c;'+base64.b64encode(b'\\sqrt{x}\n')+b'\x07'
  self.until(lambda:expected in self.raw[marker:]);self.assertIn(b'Clipboard copy requested',self.raw[marker:])
  self.assertEqual(len(self.server.records),2,'clipboard action made a model request')
  marker=len(self.raw);self.send(b'/copy latex 99\r');self.assertNotIn(b'\x1b]52;c;',self.raw[marker:]);self.quit()
 def test_plan_mode_denies_mutation_and_model_selection_changes_request(self):
  def handler(req):
   if req['messages'][-1]['role']=='tool':return answer('PLAN_RESULT_COMPLETE')
   return tool_answer('write_file',{'path':'denied.txt','content':'should not write'})
  self.start(handler);self.send(b'/model precise-custom-model\r');self.send(b'/approval-mode plan\r');self.send(b'plan a change\r');self.until(lambda:b'PLAN_RESULT_COMPLETE' in self.raw)
  self.assertFalse((self.work/'denied.txt').exists());self.assertEqual(self.server.records[0][1]['model'],'precise-custom-model')
  tool=self.server.records[1][1]['messages'][-1];self.assertEqual(tool['role'],'tool');self.assertIn('denied',tool['content']);self.quit()


 def test_file_and_image_attachments_reach_provider_as_actual_content(self):
  import base64
  self.start(lambda req:answer('ATTACHMENTS_DELIVERED'))
  (self.work/'document λ.txt').write_text('REAL_ATTACHMENT_CONTENT λ')
  image=b'\x89PNG\r\n\x1a\n'+bytes(range(19));(self.work/'image.png').write_bytes(image)
  self.send('Inspect @"document λ.txt" and @image.png\r'.encode());self.until(lambda:b'ATTACHMENTS_DELIVERED' in self.raw)
  parts=self.server.records[0][1]['messages'][-1]['content'];self.assertEqual(parts[0]['text'],'Inspect @"document λ.txt" and @image.png')
  self.assertIn('REAL_ATTACHMENT_CONTENT λ',parts[1]['text']);self.assertEqual(base64.b64decode(parts[2]['image_url']['url'].split(',')[1]),image);self.quit()
 def test_rename_modal_and_multiselect_delete_change_saved_sessions(self):
  self.start(lambda req:answer('SAVED_FOR_SESSION_ACTIONS'),save=True)
  self.send(b'current session prompt\r');self.until(lambda:b'SAVED_FOR_SESSION_ACTIONS' in self.raw);self.settle()
  directory=self.home/'.local/state/qwen-x86';active=next(directory.glob('session-*.json'));before=active.read_bytes()
  marker=len(self.raw);self.send(b'/rename\r');self.until(lambda:b'Rename Session' in self.raw[marker:]);self.send('Reviewed λ title\r'.encode());self.until(lambda:b'Session renamed.' in self.raw)
  self.assertEqual(active.read_bytes(),before);self.assertEqual(json.loads(pathlib.Path(str(active)+'.title').read_text()),'Reviewed λ title')
  first=directory/'session-fixture-first.json';second=directory/'session-fixture-second.json'
  for path,title in [(first,'first disposable session'),(second,'second disposable session')]:path.write_text(json.dumps([{'role':'user','content':title}]))
  marker=len(self.raw);self.send(b'/delete\r');self.until(lambda:b'Delete Sessions' in self.raw[marker:]);self.send(b' \x1b[B \r');self.until(lambda:b'Permanently delete selected sessions?' in self.raw);self.send(b'\x1b[B\r');self.until(lambda:b'Selected sessions deleted.' in self.raw)
  self.assertFalse(first.exists());self.assertFalse(second.exists());self.assertTrue(active.exists());self.assertEqual(len(self.server.records),1);self.quit()

 def test_agent_create_view_and_delete_use_real_definition(self):
  self.start(lambda req:answer('unused'),save=True)
  marker=len(self.raw);self.send(b'/agents create\r');self.until(lambda:b'Agent name' in self.raw[marker:]);self.send(b'precise-reviewer\r');self.until(lambda:b'Save to' in self.raw[marker:]);self.send(b'\r');self.until(lambda:b'Agent instructions' in self.raw[marker:]);self.send(b'Inspect actual changes and verify claims.\r');self.until(lambda:b'Agent created.' in self.raw)
  path=self.work/'.qwen/agents/precise-reviewer.md';self.assertTrue(path.exists());self.assertIn('Inspect actual changes',path.read_text())
  marker=len(self.raw);self.send(b'/agents manage\r');self.until(lambda:b'precise-reviewer' in self.raw[marker:]);self.send(b'\r');self.until(lambda:b'Choose Action' in self.raw[marker:]);self.send(b'\r');self.until(lambda:b'Inspect actual changes' in self.raw[marker:]);self.send(b'\x1b');self.send(b'\x1b[B\x1b[B\r');self.until(lambda:b'Delete this agent definition?' in self.raw[marker:]);self.send(b'\x1b[B\r');self.until(lambda:not path.exists());self.send(b'\x1b');self.assertEqual(len(self.server.records),0);self.quit()
 def test_extension_toggle_changes_actual_prompt_command_availability(self):
  self.start(lambda req:answer('PLUGIN_PROMPT_ACTUALLY_EXECUTED'),save=True)
  directory=self.work/'.qwen/extensions/native-demo';directory.mkdir(parents=True);(directory/'qwen-extension.json').write_text('{"name":"native-demo","version":"1"}');(directory/'commands').mkdir();(directory/'commands/review.md').write_text('Review $ARGUMENTS carefully.')
  self.send(b'/reload-plugins\r');marker=len(self.raw);self.send(b'/extensions\r');self.until(lambda:b'native-demo' in self.raw[marker:]);self.send(b' ');self.until(lambda:(directory/'.qwen-x86-disabled').exists());self.send(b'\x1b');self.send(b'/native-demo:review changes\r');self.settle();self.assertEqual(len(self.server.records),0)
  marker=len(self.raw);self.send(b'/extensions\r');self.until(lambda:b'native-demo' in self.raw[marker:]);self.send(b' ');self.until(lambda:not (directory/'.qwen-x86-disabled').exists());self.send(b'\x1b');self.send(b'/native-demo:review changes\r');self.until(lambda:b'PLUGIN_PROMPT_ACTUALLY_EXECUTED' in self.raw);self.assertEqual(self.server.records[0][1]['messages'][-1]['content'],'Review changes carefully.');self.quit()

if __name__=='__main__':unittest.main()
