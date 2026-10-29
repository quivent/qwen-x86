"""Rich-response screen comparison against the actual original renderer."""
import argparse,json,pathlib,tempfile,time
from ui_capture import Session,ROOT
from bench_usage import ModelServer,text_reply
CASES={
 'rich-table':'## Files\n\n| File | Result |\n| --- | --- |\n| `main.s` | **Built** |\n| `λ-song.txt` | Unicode 世界 |\n\nUI_RICH_DONE',
 'rich-math':'## Formula\n\n$$\n\\frac{a}{b} + \\sqrt{x}\n$$\n\nThe parameter is $\\alpha$.\n\nUI_RICH_DONE',
 'rich-mermaid':'## Flow\n\n```mermaid\nflowchart LR\nA[Read] --> B[Write]\nB --> C[Done]\n```\n\nUI_RICH_DONE',
}
def run(clients=('reference','native')):
 base=pathlib.Path(tempfile.mkdtemp(prefix='qwen-rich-capture-'));work=base/'workspace';work.mkdir()
 report={'reference_version':'0.24.5','scope':'Same complete response supplied to actual reference/native terminal renderer; images are evidence, not passing parity assertions.','frames':[]}
 for client in clients:
  for name,response in CASES.items():
   home=base/(client+'-'+name);home.mkdir()
   with ModelServer(lambda req:([text_reply(response)],0)) as server:
    session=Session(client,work,home,server.url)
    try:
     session.wait('Ask permissions',30);session.literal('UI_RICH_'+name);session.key('Enter');session.wait('UI_RICH_DONE',30);time.sleep(.5)
     path=ROOT/'docs/ui-captures'/client/name;session.save(path);report['frames'].append(str(path.relative_to(ROOT))+'.png')
    finally:session.close()
 (ROOT/'docs/ui-captures/rich-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--client',choices=['reference','native','both'],default='both');args=parser.parse_args();run(['reference','native'] if args.client=='both' else [args.client])
