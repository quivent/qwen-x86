"""Record the original and native visible UI through a controlled model fixture."""
import argparse,json,pathlib,sys,tempfile,time
from ui_capture import Session,ROOT
from bench_usage import ModelServer,text_reply,tool_reply,flat_content
MARKDOWN='## Result\n\nUI_CASE_MARKDOWN_DONE\n\nThis is **bold**, *italic*, and `inline code`.\n\n```python\nprint("Hello, world")\n```\n\n- First item\n- Second item\n\n> A quoted line\n'
def run(clients):
 base=pathlib.Path(tempfile.mkdtemp(prefix='qwen-ui-capture-'));work=base/'workspace';work.mkdir()
 report={'reference_version':'0.24.5','scope':'Actual default Ink reference and production assembly, same local mock provider, explicit default approval mode, fixturecapture.txt resetbetweenclients, auto-update disabled in isolated profiles.','frames':[]}
 for client in clients:
  (work/'capture.txt').unlink(missing_ok=True)
  home=base/(client+'-home');home.mkdir()
  def handler(request):
   users=[flat_content(m.get('content','')) for m in request.get('messages',[]) if m.get('role')=='user']
   last=users[-1] if users else ''
   if 'UI_CASE_LONG' in last:return [text_reply('UI_CASE_LONG_START\n'+''.join(f'Line {i:03d}: terminal resize and scroll reference\n' for i in range(1,85))+'UI_CASE_LONG_DONE')],0
   if 'UI_CASE_TOOL' in last:
    if request['messages'][-1]['role']=='tool':return [text_reply('UI_CASE_TOOL_DONE')],0
    definitions={x['function']['name']:x['function'] for x in request.get('tools',[]) if x.get('type')=='function'}
    props=definitions['write_file']['parameters']['properties']
    arguments={'file_path':str(work/'capture.txt'),'content':'A visible edit preview\n'} if 'file_path' in props else {'path':'capture.txt','content':'A visible edit preview\n'}
    return [tool_reply('write_file',arguments)],0
   return [text_reply(MARKDOWN)],0
  with ModelServer(handler) as server:
   session=Session(client,work,home,server.url)
   try:
    session.wait('Ask permissions',30)
    time.sleep(.5)
    for columns,rows in [(100,30),(80,24),(120,40)]:
     session.resize(columns,rows)
     path=ROOT/'docs/ui-captures'/client/f'initial-{columns}x{rows}'
     session.save(path);report['frames'].append(str(path.relative_to(ROOT))+'.png')
    session.resize(100,30)
    session.literal('/he');time.sleep(.2);session.save(ROOT/'docs/ui-captures'/client/'slash-completion')
    session.key('Escape');session.key('C-u');session.literal('UI_CASE_MARKDOWN');session.key('Enter');session.wait('UI_CASE_MARKDOWN_DONE',20);time.sleep(.6);session.save(ROOT/'docs/ui-captures'/client/'markdown')
    session.literal('UI_CASE_TOOL');session.key('Enter');session.wait('Allow',20);time.sleep(.2);session.save(ROOT/'docs/ui-captures'/client/'approval');session.key('1');time.sleep(.2);session.key('Enter');session.wait('UI_CASE_TOOL_DONE',20);time.sleep(.3);session.save(ROOT/'docs/ui-captures'/client/'tool-complete')
    session.literal('UI_CASE_LONG');session.key('Enter');session.wait('UI_CASE_LONG_DONE',20);time.sleep(.3);session.save(ROOT/'docs/ui-captures'/client/'long-response')
    session.key('PPage');time.sleep(.2);session.save(ROOT/'docs/ui-captures'/client/'scrolled')
    session.resize(80,24);session.save(ROOT/'docs/ui-captures'/client/'resized')
   finally:session.close()
  report[client+'_requests']=len(server.records)
 report['frames']=[str(p.relative_to(ROOT)) for client in clients for p in sorted((ROOT/'docs/ui-captures'/client).glob('*.png')) if not p.name.startswith('dialog-')]
 (ROOT/'docs/ui-captures/parity-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--client',choices=['reference','native','both'],default='both');a=parser.parse_args();run(['reference','native'] if a.client=='both' else [a.client])
