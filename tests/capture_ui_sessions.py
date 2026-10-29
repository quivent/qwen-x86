"""Actual saved-session picker/preview against both complete terminal clients."""
import argparse,json,pathlib,tempfile,time
from ui_capture import Session,ROOT
from bench_usage import ModelServer,text_reply,flat_content
SAVED='SAVED_PREVIEW_START\n'+''.join(f'Preview line {i:02d}\n' for i in range(60))+'SAVED_PREVIEW_END'
def run(clients=('reference','native')):
 base=pathlib.Path(tempfile.mkdtemp(prefix='qwen-session-capture-'));work=base/'workspace';work.mkdir()
 report={'reference_version':'0.24.5','scope':'Sessions created by each actual client, read-only preview followed by cancel and real resume. No forged reference session files.','frames':[]}
 for client in clients:
  home=base/(client+'-home');home.mkdir()
  def handler(req):
   last=[flat_content(m.get('content','')) for m in req.get('messages',[]) if m.get('role')=='user'][-1]
   return [text_reply(SAVED if 'SAVED_PREVIEW_USER' in last else 'PREVIEW_CHECK_DONE')],0
  with ModelServer(handler) as server:
   s=Session(client,work,home,server.url,save_session=True)
   def capture(name):
    time.sleep(.3);p=ROOT/'docs/ui-captures'/client/name;s.save(p);report['frames'].append(str(p.relative_to(ROOT))+'.png')
   try:
    s.wait('Ask permissions',30);s.literal('SAVED_PREVIEW_USER');s.key('Enter');s.wait('SAVED_PREVIEW_END',30)
    s.literal('/clear');s.key('Enter');time.sleep(.5);s.literal('/resume');s.key('Enter');s.wait('Resume Session',30);s.wait('SAVED_PREVIEW_USER',15);capture('session-picker-populated')
    s.key('Space')
    if client=='native':s.wait('SAVED_PREVIEW_START',15)
    else:time.sleep(.8)
    report[client+'_preview_start_visible']='SAVED_PREVIEW_START' in s.text()
    capture('session-preview-top');s.key('NPage');capture('session-preview-scrolled');s.key('Escape');s.key('Escape')
    s.literal('AFTER_PREVIEW_CANCEL');s.key('Enter');s.wait('PREVIEW_CHECK_DONE',30)
    req=next(r['request'] for r in reversed(server.records) if r['request'].get('messages') and flat_content(r['request']['messages'][-1].get('content','')).find('AFTER_PREVIEW_CANCEL')>=0)
    assert not any(m.get('role')=='user' and flat_content(m.get('content','')).find('SAVED_PREVIEW_USER')>=0 for m in req['messages']),client+' preview changed active model history'
    s.literal('/resume');s.key('Enter');s.wait('Resume Session',15)
    # Select the real saved conversation by its query, rather than assuming
    # either client excludes the currently active session from its picker.
    s.key('/')
    for character in 'SAVED_PREVIEW_USER':
     s.run('send-keys','-t',s.target,'-l','--',character);time.sleep(.035)
    time.sleep(.2)
    s.key('Enter')
    s.key('Space')
    if client=='native':s.wait('SAVED_PREVIEW_START',15)
    else:time.sleep(.5)
    s.key('Enter');s.literal('AFTER_PREVIEW_RESUME');s.key('Enter');s.wait('PREVIEW_CHECK_DONE',30)
    deadline=time.monotonic()+10;req=None
    while time.monotonic()<deadline:
     req=next((r['request'] for r in reversed(server.records) if r['request'].get('messages') and flat_content(r['request']['messages'][-1].get('content','')).find('AFTER_PREVIEW_RESUME')>=0),None)
     if req:break
     time.sleep(.05)
    assert req and any(m.get('role')=='user' and flat_content(m.get('content','')).find('SAVED_PREVIEW_USER')>=0 for m in req['messages']),client+' preview Enter did not resume selected history'
    capture('session-resumed');report[client+'_cancel_preserved_history']=True;report[client+'_enter_resumed_history']=True
   finally:s.close()
 manifest=ROOT/'docs/ui-captures/session-manifest.json'
 if len(clients)==1 and manifest.exists():
  previous=json.loads(manifest.read_text())
  for key,value in previous.items():
   if any(key.startswith(client+'_') for client in ['reference','native'] if client not in clients):report[key]=value
 report['frames']=[str(p.relative_to(ROOT)) for client in ['reference','native'] for p in sorted((ROOT/'docs/ui-captures'/client).glob('session-*.png'))]
 (ROOT/'docs/ui-captures/session-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--client',choices=['reference','native','both'],default='both');args=parser.parse_args();run(['reference','native'] if args.client=='both' else [args.client])
