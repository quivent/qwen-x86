"""Blocked randomized 2x2 ablation of transport and process-exit waits.
Native ELF variants differ only in net.o/tools.o; no server ACK tuning.
"""
import hashlib,json,math,pathlib,random,statistics,subprocess,tempfile,ssl
import bench_usage as usage
from test_tls import make_certificates
ROOT=usage.ROOT;BUILD=ROOT/'build/wait-optimization'

def summary(values):
 ordered=sorted(values)
 return {'n':len(values),'mean':statistics.mean(values),'median':statistics.median(values),'p95':ordered[math.ceil(.95*len(values))-1],'min':min(values),'max':max(values)}
def bootstrap(values,stat=statistics.median):
 rng=random.Random(84321);samples=sorted(stat(rng.choices(values,k=len(values))) for _ in range(5000))
 return [samples[124],samples[4874]]
def variants():
 sources=next(line.split(':=',1)[1].split() for line in (ROOT/'Makefile').read_text().splitlines() if line.startswith('SOURCES :='))
 for label,oldnet,oldtools in [('tcp_only',False,True),('pidfd_only',True,False),('both',False,False)]:
  objects=[BUILD/'baseline-net.o' if name=='net' and oldnet else BUILD/'baseline-tools.o' if name=='tools' and oldtools else ROOT/'build'/(name+'.o') for name in sources]
  subprocess.run(['ld','-static','-z','noexecstack','-s','-o',str(BUILD/label),*map(str,objects)],check=True)
 return {label:BUILD/label for label in ['baseline','tcp_only','pidfd_only','both']}

def main(runs=20):
 usage.SAMPLE_MEMORY=False;bins=variants();original=usage.CLIENTS['assembly'];rng=random.Random(20261029)
 report={'verified':'2026-10-29','method':{'runs_per_variant_per_transport':runs,'design':'Randomized blocks; one run per variant and Go reference in each block; unmodified server ACK behavior; no memory sampler.','metric':'Sum of response-sent to next primary-request-received across five dependent tool steps, in milliseconds.','factorial':{'00':'baseline','10':'tcp_only','01':'pidfd_only','11':'both'},'bootstrap':'5000 paired-block resamples, percentile95% interval; descriptive uncertainty on this machine, no population guarantee.','predeclared_target':'Both changes: median and nearest-rank p95 tool-gap time below Go reference for each measured transport.'},'binaries':{label:{'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size} for label,path in bins.items()},'cases':{},'raw':{}}
 with tempfile.TemporaryDirectory(prefix='qwen-wait-ablation-') as directory:
  base=pathlib.Path(directory);ca,cert,key=make_certificates(base)
  context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=context.maximum_version=ssl.TLSVersion.TLSv1_3;context.set_ecdh_curve('X25519');context.load_cert_chain(cert,key)
  homes={label:base/(label+'-home') for label in [*bins,'go']}
  for home in homes.values():home.mkdir()
  for case in ['tool_chain_http','tool_chain_tls']:
   raw={label:[] for label in homes};blocks=[]
   for index in range(runs):
    order=list(homes);rng.shuffle(order);block={}
    for label in order:
     client='go' if label=='go' else 'assembly'
     if client=='assembly':usage.CLIENTS['assembly']=bins[label]
     row=usage.usage_run(case,client,base,homes[label],context,ca)
     raw[label].append(row);block[label]=row['total_client_tool_gap_ms']
     print(json.dumps({'case':case,'block':index,'variant':label,'gap_ms':round(block[label],3),'steps_ms':[round(x,3) for x in row['client_tool_gaps_ms']]}),flush=True)
    blocks.append(block)
   stats={label:summary([row['total_client_tool_gap_ms'] for row in rows]) for label,rows in raw.items()}
   effects={
    'tcp_main_effect_saved_ms':[(b['baseline']-b['tcp_only']+b['pidfd_only']-b['both'])/2 for b in blocks],
    'pidfd_main_effect_saved_ms':[(b['baseline']-b['pidfd_only']+b['tcp_only']-b['both'])/2 for b in blocks],
    'interaction_ms':[b['both']-b['tcp_only']-b['pidfd_only']+b['baseline'] for b in blocks],
    'baseline_minus_both_ms':[b['baseline']-b['both'] for b in blocks],
    'go_minus_both_ms':[b['go']-b['both'] for b in blocks]}
   report['raw'][case]=raw
   report['cases'][case]={'variants':stats,'paired_effects':{key:{'mean':statistics.mean(values),'median':statistics.median(values),'mean_ci95':bootstrap(values,statistics.mean),'median_ci95':bootstrap(values)} for key,values in effects.items()},'speedup_baseline_medians':stats['baseline']['median']/stats['both']['median'],'speedup_go_medians':stats['go']['median']/stats['both']['median'],'target_met':stats['both']['median']<stats['go']['median'] and stats['both']['p95']<stats['go']['p95']}
   (ROOT/'docs/wait-optimization.json').write_text(json.dumps(report,indent=2)+'\n')
 usage.CLIENTS['assembly']=original
 print('Saved docs/wait-optimization.json',flush=True)
if __name__=='__main__':main()
