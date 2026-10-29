"""Capture real reference/native command dialogs; visual evidence, not pass assertions."""
import argparse,json,pathlib,tempfile,time
from ui_capture import Session,ROOT
from bench_usage import ModelServer,text_reply

def run(clients=('reference','native')):
 base=pathlib.Path(tempfile.mkdtemp(prefix='qwen-dialog-capture-'));work=base/'workspace';work.mkdir()
 report={'reference_version':'0.24.5','scope':'Command-dialog comparison, isolated profiles; no fabricated sessions/plugins','frames':[]}
 with ModelServer(lambda req:([text_reply('DIALOG_FIXTURE_DONE')],0)) as server:
  for client in clients:
   for command in ['/model','/theme','/resume','/extensions','/agents manage','/help']:
    home=base/(client+'-'+command[1:].replace(' ','-'));home.mkdir();session=Session(client,work,home,server.url)
    try:
     session.wait('Ask permissions',30);time.sleep(.3);session.literal(command);session.key('Enter');time.sleep(.8)
     path=ROOT/'docs/ui-captures'/client/('dialog-'+command[1:].replace(' ','-'));session.save(path);report['frames'].append(str(path.relative_to(ROOT))+'.png')
    finally:session.close()
 (ROOT/'docs/ui-captures/dialog-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--client',choices=['reference','native','both'],default='both');args=parser.parse_args();run(['reference','native'] if args.client=='both' else [args.client])
