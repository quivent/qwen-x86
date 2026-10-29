"""Change server ACK scheduling only; production clients remain unchanged."""
import json,pathlib,ssl,tempfile
import bench_usage as usage
from test_tls import make_certificates

def main():
 usage.SAMPLE_MEMORY=False
 report={'verified':'2026-10-29','scope':'Diagnostic: same production binaries and five tools; server TCP_QUICKACK off/on. No client changes. Three runs per case, alternating ACK mode.','raw':{},'cases':{}}
 with tempfile.TemporaryDirectory(prefix='qwen-ack-diagnostic-') as folder:
  base=pathlib.Path(folder);ca,cert,key=make_certificates(base)
  context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=context.maximum_version=ssl.TLSVersion.TLSv1_3;context.set_ecdh_curve('X25519');context.load_cert_chain(cert,key)
  for kind in ['tool_chain_http','tool_chain_tls']:
   report['raw'][kind]={}
   for client in ['assembly','go']:
    home=base/(kind+client);home.mkdir()
    rows={'default_ack':[],'quick_ack':[]}
    for repeat in range(3):
     for enabled in ([False,True] if repeat%2==0 else [True,False]):
      row=usage.usage_run(kind,client,base,home,context,ca,quick_ack=enabled)
      mode='quick_ack' if enabled else 'default_ack';rows[mode].append(row)
      print(json.dumps({'case':kind,'client':client,'mode':mode,'gaps_ms':row['client_tool_gaps_ms']}),flush=True)
    report['raw'][kind][client]=rows
   report['cases'][kind]={client:{mode:usage.summarize(rows) for mode,rows in modes.items()} for client,modes in report['raw'][kind].items()}
 (usage.ROOT/'docs/tcp-ack-diagnostic.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
