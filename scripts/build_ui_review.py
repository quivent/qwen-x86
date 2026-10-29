"""Build a local side-by-side review artifact from actual terminal captures."""
import html,json,pathlib
root=pathlib.Path(__file__).resolve().parents[1];directory=root/'docs/ui-captures'
names=sorted({p.stem for p in (directory/'reference').glob('*.png')} & {p.stem for p in (directory/'native').glob('*.png')})
data={name:{client:{'text':(directory/client/(name+'.txt')).read_text(),'cursor':json.loads((directory/client/(name+'.json')).read_text())['cursor']} for client in ['reference','native']} for name in names}
page='''<!doctype html><meta charset="utf-8"><title>Qwen terminal UI comparison</title>
<style>body{margin:24px;background:#171923;color:#ddd;font:16px system-ui}select,button{font:inherit;padding:6px}main{display:grid;grid-template-columns:1fr 1fr;gap:16px}img{width:100%;height:auto;border:1px solid #555}pre{overflow:auto;font:12px monospace;line-height:1.4}small{color:#b6b6c8}h1{font-size:24px}body.overlay main{display:block;position:relative}body.overlay section:last-child{position:absolute;top:0;left:0;width:100%;opacity:.5}body.overlay pre{display:none}body.overlay section:last-child h2{visibility:hidden}</style>
<h1>Qwen terminal UI comparison</h1><p>Actual Qwen Code 0.24.5 Ink and assembly executable captures. These are review evidence; capture coverage does not establish parity.</p>
<p><label>State <select id="state"></select></label> <button id="mode">Toggle 50% overlay</button></p>
<main><section><h2>Original Qwen Code</h2><img id="reference" alt="Reference terminal capture"><small id="reference-cursor"></small><pre id="reference-text"></pre></section><section><h2>Assembly client</h2><img id="native" alt="Native terminal capture"><small id="native-cursor"></small><pre id="native-text"></pre></section></main>
<p>Temporary paths, application identity, reference-only notices and rotating tips can differ. Compare geometry, typography, focus, content and behavior directly. Raw captures and cell attributes are stored next to each image. Command dialogs may still differ substantially.</p>
<script>const data=DATA;const chooser=document.querySelector('#state');for(const name of Object.keys(data)){const option=document.createElement('option');option.value=name;option.textContent=name;chooser.append(option)}function render(){const name=chooser.value;for(const client of ['reference','native']){document.getElementById(client).src=client+'/'+name+'.png';document.getElementById(client+'-text').textContent=data[name][client].text;document.getElementById(client+'-cursor').textContent='Terminal cursor (column row): '+data[name][client].cursor}}chooser.onchange=render;document.getElementById('mode').onclick=()=>document.body.classList.toggle('overlay');render()</script>'''.replace('DATA',json.dumps(data,ensure_ascii=False).replace('<','\\u003c'))
(directory/'index.html').write_text(page)
print('Built',directory/'index.html','with',len(names),'paired states')

frames=[]
for name in names:
 for client in ['reference','native']:
  metadata=json.loads((directory/client/(name+'.json')).read_text())
  frames.append({'state':name,'client':client,'image':client+'/'+name+'.png','binary_sha256':metadata.get('binary_sha256'),'columns':metadata['columns'],'rows':metadata['rows']})
(directory/'manifest.json').write_text(json.dumps({'reference_version':'0.24.5','scope':'Paired actual terminal captures from the parity, dialog, rich-response and saved-session fixture books. No overall parity pass is asserted.','paired_states':len(names),'frames':frames,'scenario_reports':['parity-manifest.json','dialog-manifest.json','rich-manifest.json','session-manifest.json']},indent=2)+'\n')
