"""Local controlled usage benchmarks; all clients run their actual installed code.
No real model, account credentials, cloud requests or user workspace changes.
"""
import argparse, hashlib, json, os, pathlib, resource, signal, socket, socketserver
import ssl, statistics, subprocess, tempfile, threading, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
SAMPLE_MEMORY=True
CLIENTS={'assembly':ROOT/'qwen-x86','go':pathlib.Path.home()/'.local/bin/qwen-go','javascript':pathlib.Path.home()/'.local/bin/qwen'}

def chunk(delta,finish=None):
 c={'index':0,'delta':delta}
 if finish is not None:c['finish_reason']=finish
 return b'data: '+json.dumps({'id':'usage-benchmark','object':'chat.completion.chunk','created':1,'model':'bench-model','choices':[c]},separators=(',',':')).encode()+b'\n\n'
def text_reply(text):return chunk({'role':'assistant','content':text},'stop')+b'data: [DONE]\n\n'
def tool_reply(name,args,id='bench-call'):
 return chunk({'role':'assistant','tool_calls':[{'index':0,'id':id,'type':'function','function':{'name':name,'arguments':json.dumps(args)}}]},'tool_calls')+b'data: [DONE]\n\n'
class ModelServer(socketserver.ThreadingTCPServer):
 allow_reuse_address=True;daemon_threads=True
 def __init__(self,scenario,context=None,quick_ack=False):
  self.quick_ack=quick_ack
  self.scenario=scenario;self.records=[];self.errors=[];self.first_request=None;self.first_sent=None;self.last_sent=None;self.context=context;self.lock=threading.Lock()
  super().__init__(('127.0.0.1',0),Handler)
  self.url=('https://localhost:' if context else 'http://127.0.0.1:')+str(self.server_address[1])+'/v1'
 def get_request(self):
  connection,address=super().get_request();connection.settimeout(15);connection.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
  if self.context:connection=self.context.wrap_socket(connection,server_side=True)
  return connection,address
 def handle_error(self,request,client_address):
  import traceback
  self.errors.append(traceback.format_exc())
 def __enter__(self):self.thread=threading.Thread(target=self.serve_forever,kwargs={'poll_interval':.02},daemon=True);self.thread.start();return self
 def __exit__(self,*_):self.shutdown();self.server_close();self.thread.join(2)
class Handler(socketserver.StreamRequestHandler):
 def handle(self):
  while True:
   if self.server.quick_ack:self.connection.setsockopt(socket.IPPROTO_TCP,socket.TCP_QUICKACK,1)
   line=self.rfile.readline()
   if not line:return
   headers={}
   while True:
    item=self.rfile.readline()
    if item in (b'\r\n',b'\n',b''):break
    key,value=item.split(b':',1);headers[key.lower()]=value.strip()
   if self.server.quick_ack:self.connection.setsockopt(socket.IPPROTO_TCP,socket.TCP_QUICKACK,1)
   if b'content-length' not in headers:raise RuntimeError('Missing Content-Length')
   request=json.loads(self.rfile.read(int(headers[b'content-length'])))
   if self.server.quick_ack:self.connection.setsockopt(socket.IPPROTO_TCP,socket.TCP_QUICKACK,1)
   now=time.perf_counter()
   record={'received':now,'request':request,'target':line.decode().strip(),'cipher':self.connection.cipher()[0] if isinstance(self.connection,ssl.SSLSocket) else None}
   with self.server.lock:
    self.server.records.append(record)
    if self.server.first_request is None:self.server.first_request=now
   record['auxiliary']=is_auxiliary(request)
   payload,pace=([text_reply('No durable memories to save.')],0) if record['auxiliary'] else self.server.scenario(request)
   self.connection.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nContent-Length: '+str(sum(map(len,payload))).encode()+b'\r\n\r\n')
   # Identical model preparation time lets the memory sampler see every process.
   time.sleep(.02)
   for block in payload:
    if self.server.first_sent is None:self.server.first_sent=time.perf_counter()
    self.connection.sendall(block)
    if pace:time.sleep(pace)
   record['sent']=time.perf_counter();self.server.last_sent=record['sent']

def tree_memory(pid):
 pending=[pid];seen=set();rss=pss=0
 while pending:
  current=pending.pop()
  if current in seen:continue
  seen.add(current)
  try:
   for task in pathlib.Path(f'/proc/{current}/task').iterdir():
    try:pending.extend(map(int,(task/'children').read_text().split()))
    except (OSError,ValueError):pass
   fields={line.split(':',1)[0]:line.split(':',1)[1].strip().split()[0] for line in pathlib.Path(f'/proc/{current}/smaps_rollup').read_text().splitlines() if ':' in line}
   rss+=int(fields.get('Rss',0));pss+=int(fields.get('Pss',0))
  except (OSError,ValueError):pass
 return rss,pss

def command(client,workspace,server,home,ca=None):
 env=dict(os.environ)
 for key in list(env):
  if key.startswith(('QWEN','OPENAI','ANTHROPIC','GEMINI','GOOGLE_API','NODE_OPTIONS')):env.pop(key,None)
 env.update(HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_CACHE_HOME=str(home/'.cache'),QWEN_HOME=str(home/'.qwen'),OPENAI_API_KEY='local-fixture-key-only',QWEN_API_KEY='local-fixture-key-only',NO_COLOR='1',DISABLE_TELEMETRY='1',QWEN_CODE_DISABLE_TELEMETRY='1')
 prompt='Run the local usage benchmark. Follow the supplied tool calls and return the supplied answer.'
 if client=='javascript':
  args=[str(CLIENTS[client]),'--auth-type','openai','--openai-base-url',server.url,'--openai-api-key','local-fixture-key-only','--model','bench-model','--prompt',prompt,'--yolo','--output-format','text','--telemetry=false']
 else:args=[str(CLIENTS[client]),'--cwd',str(workspace),'--base-url',server.url,'--model','bench-model','--prompt',prompt,'--yes']
 if ca:
  if client=='assembly':args+=['--ca-file',str(ca)]
  elif client=='go':env['SSL_CERT_FILE']=str(ca)
  else:env['NODE_EXTRA_CA_CERTS']=str(ca)
 return args,env

def run_process(client,workspace,home,server,ca=None):
 args,env=command(client,workspace,server,home,ca)
 start=time.perf_counter();proc=subprocess.Popen(args,cwd=workspace,env=env,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
 output={'stdout':bytearray(),'stderr':bytearray()};first_visible=[None];peak=[0,0];stop=threading.Event()
 def reader(name,pipe):
  while True:
   data=os.read(pipe.fileno(),65536)
   if not data:break
   output[name].extend(data)
   if name=='stdout' and first_visible[0] is None and b'BENCH_' in output[name]:first_visible[0]=time.perf_counter()
 def sample():
  while not stop.is_set():
   rss,pss=tree_memory(proc.pid);peak[0]=max(peak[0],rss);peak[1]=max(peak[1],pss);stop.wait(.005)
 threads=[threading.Thread(target=reader,args=(name,getattr(proc,name)),daemon=True) for name in output]
 for thread in threads:thread.start()
 sampler=threading.Thread(target=sample,daemon=True)
 if SAMPLE_MEMORY:sampler.start()
 try:
  deadline=start+30
  while True:
   found,status,usage=os.wait4(proc.pid,os.WNOHANG)
   if found:break
   if time.perf_counter()>deadline:
    os.killpg(proc.pid,signal.SIGKILL);os.wait4(proc.pid,0);raise RuntimeError(client+' exceeded30s: '+bytes(output['stderr'])[-3000:].decode(errors='replace'))
   time.sleep(.001)
  end=time.perf_counter();proc.returncode=os.waitstatus_to_exitcode(status)
 finally:
  stop.set()
  if SAMPLE_MEMORY:sampler.join(1)
  for thread in threads:thread.join(2)
  proc.stdout.close();proc.stderr.close()
 if proc.returncode:raise RuntimeError(client+f' exit{proc.returncode}: '+bytes(output['stderr'])[-4000:].decode(errors='replace')+' SERVER:'+str(server.errors))
 if server.errors:raise RuntimeError(str(server.errors))
 if server.first_sent is None:raise RuntimeError('No model response consumed')
 result={'wall_ms':(end-start)*1000,'startup_to_request_ms':(server.first_request-start)*1000,'first_response_to_exit_ms':(end-server.first_sent)*1000,'cpu_ms':(usage.ru_utime+usage.ru_stime)*1000,'sampled_peak_tree_pss_kib':peak[1] if SAMPLE_MEMORY else None,'sampled_peak_tree_rss_kib':peak[0] if SAMPLE_MEMORY else None,'requests':len(server.records),'stdout_bytes':len(output['stdout']),'first_visible_after_response_ms':(first_visible[0]-server.first_sent)*1000 if first_visible[0] else None,'auxiliary_requests':sum(r.get('auxiliary',False) for r in server.records),'tls_ciphers':sorted({r['cipher'] for r in server.records if r['cipher']})}
 return result,bytes(output['stdout']),bytes(output['stderr'])

def probe(client):
 with tempfile.TemporaryDirectory(prefix='qwen-usage-probe-') as folder:
  base=pathlib.Path(folder);home=base/'home';home.mkdir();work=base/'work';work.mkdir()
  with ModelServer(lambda request:([text_reply('BENCH_OK')],0)) as server:
   result,out,err=run_process(client,work,home,server)
   print(json.dumps({'client':client,'result':result,'stdout':out.decode(errors='replace')[:1000],'stderr':err.decode(errors='replace')[:2000],'request_summaries':[{'stream':r['request'].get('stream'),'model':r['request'].get('model'),'tools':len(r['request'].get('tools',[])),'last_message':str(r['request'].get('messages',[])[-1:])[:250]} for r in server.records],'tools':[t['function'] for t in server.records[0]['request'].get('tools',[])]},indent=2))

def flat_content(value):
 if isinstance(value,str):return value
 if isinstance(value,list):return '\n'.join(flat_content(x) for x in value)
 if isinstance(value,dict):return flat_content(value.get('text',value.get('content','')))
 return ''
def is_auxiliary(request):
 return any(m.get('role')=='user' and flat_content(m.get('content','')).startswith('Managed memory has TWO directories') for m in request.get('messages',[]))
def multi_tools(calls):
 return chunk({'role':'assistant','tool_calls':[{'index':i,'id':f'bench-call-{i}','type':'function','function':{'name':name,'arguments':json.dumps(args)}} for i,(name,args) in enumerate(calls)]},'tool_calls')+b'data: [DONE]\n\n'

class Scenario:
 def __init__(self,kind,client,workspace):
  self.kind=kind;self.client=client;self.workspace=workspace;self.turn=0;self.worker_intervals=[]
  self.text='BENCH_STREAM_'+('0123456789abcdef'*4)*(1024 if kind=='burst_stream' else 128)
  self.blocks=[chunk({'role':'assistant','content':'BENCH_STREAM_'})]+[chunk({'content':'0123456789abcdef'*4}) for _ in range(1024 if kind=='burst_stream' else 128)]+[chunk({},'stop')+b'data: [DONE]\n\n']
  self.initial='before_marker\n'+('generated benchmark content\n'*300)
  self.final=self.initial.replace('before_marker','after_marker')
  if kind.startswith('tool_chain'):(workspace/'input.txt').write_text('FIXTURE_READ_MARKER\n'+('read benchmark line\n'*1600))
 def path_args(self,name):
  return {'file_path':str(self.workspace/name)} if self.client=='javascript' else {'path':name}
 def __call__(self,request):
  if self.kind in ['burst_stream','paced_stream']:return self.blocks,.002 if self.kind=='paced_stream' else 0
  if self.kind.startswith('tool_chain'):
   index=self.turn;self.turn+=1
   tools=[('read_file',self.path_args('input.txt')),('write_file',dict(self.path_args('result.txt'),content=self.initial)),('read_file',self.path_args('result.txt')),('edit' if self.client=='javascript' else 'edit_file',dict(self.path_args('result.txt'),old_string='before_marker',new_string='after_marker')),('run_shell_command' if self.client=='javascript' else 'run_shell',{'command':'sha256sum result.txt'})]
   if index:
    outputs=[flat_content(m.get('content','')) for m in request['messages'] if m.get('role')=='tool']
    if not outputs:raise AssertionError('Tool result missing')
    last=outputs[-1]
    if index==1 and 'FIXTURE_READ_MARKER' not in last:raise AssertionError('Read did not return expected data: '+last[:300])
    if index==5 and hashlib.sha256(self.final.encode()).hexdigest() not in last:raise AssertionError('Shell checksum missing: '+last[:400])
   return [tool_reply(*tools[index],id=f'call-{index}') if index<len(tools) else text_reply('BENCH_TOOL_DONE')],0
  if self.kind=='parallel_workers':
   users=[flat_content(m.get('content','')) for m in request['messages'] if m.get('role')=='user']
   marker=next((x for x in users if 'BENCH_WORKER_' in x),None)
   if marker:
    start=time.perf_counter();time.sleep(.15);self.worker_intervals.append((start,time.perf_counter()));return [text_reply('BENCH_WORKER_DONE_'+marker.split('BENCH_WORKER_',1)[1][0])],0
   index=self.turn;self.turn+=1
   if index==0:return [multi_tools([('spawn_agent',{'name':f'worker{i}','prompt':f'BENCH_WORKER_{i}','mode':'read-only'}) for i in range(2)])],0
   results=[json.loads(flat_content(m.get('content',''))) for m in request['messages'] if m.get('role')=='tool']
   if index==1:return [multi_tools([('wait_agent',{'id':x['id'],'timeout_seconds':2}) for x in results[-2:]])],0
   for item in results[-2:]:
    if item.get('status')!='completed':raise AssertionError('Worker incomplete: '+str(item))
    if 'BENCH_WORKER_DONE_' not in item.get('report',item.get('result','')):raise AssertionError('Worker report missing')
   return [text_reply('BENCH_PARALLEL_DONE')],0
  return [text_reply('BENCH_WARMUP')],0
 def verify(self,out):
  if self.kind in ['burst_stream','paced_stream']:
   if self.text.encode() not in out:raise AssertionError('Stream bytes do not match expected output')
  elif self.kind.startswith('tool_chain'):
   if (self.workspace/'result.txt').read_text()!=self.final:raise AssertionError('Incorrect final file')
   if b'BENCH_TOOL_DONE' not in out:raise AssertionError('Final tool response missing')
  elif self.kind=='parallel_workers':
   if len(self.worker_intervals)!=2:raise AssertionError('Expected two workers')
   overlap=min(x[1] for x in self.worker_intervals)-max(x[0] for x in self.worker_intervals)
   if overlap<.1:raise AssertionError('Workers did not overlap')
   if b'BENCH_PARALLEL_DONE' not in out:raise AssertionError('Final worker response missing')

def usage_run(kind,client,base,home,context,ca,quick_ack=False):
 with tempfile.TemporaryDirectory(prefix='work-',dir=base) as directory:
  workspace=pathlib.Path(directory);scenario=Scenario(kind,client,workspace)
  with ModelServer(scenario,context if kind.endswith('_tls') else None,quick_ack=quick_ack) as server:
   result,out,err=run_process(client,workspace,home,server,ca if kind.endswith('_tls') else None)
   scenario.verify(out)
   records=[r for r in server.records if not r.get('auxiliary')]
   result['main_requests']=len(records)
   result['client_tool_gaps_ms']=[(b['received']-a['sent'])*1000 for a,b in zip(records,records[1:])] if kind.startswith('tool_chain') else []
   if result['client_tool_gaps_ms']:result['total_client_tool_gap_ms']=sum(result['client_tool_gaps_ms'])
   if kind in ['burst_stream','paced_stream']:
    result['content_bytes']=len(scenario.text.encode());result['sse_content_chunks']=1025 if kind=='burst_stream' else 129
   if kind=='parallel_workers':result['worker_overlap_ms']=(min(x[1] for x in scenario.worker_intervals)-max(x[0] for x in scenario.worker_intervals))*1000
   return result

def summarize(rows):
 result={'runs':len(rows)}
 for key in rows[0]:
  values=[row[key] for row in rows]
  if all(isinstance(x,(int,float)) for x in values):
   result[key]={'median':round(statistics.median(values),3),'min':round(min(values),3),'max':round(max(values),3)}
  elif key=='tls_ciphers':result[key]=sorted(set(x for value in values for x in value))
 return result

def main(runs,memory_results=None):
 from test_tls import make_certificates
 report={'verified':'2026-10-29','scope':'Warm-cache headless real CLI commands against a controlled local model fixture; identical primary content/tools, no paid model calls. Fresh workspace/session for each run; isolated HOME retained per client after one unmeasured warmup. Default client features/session saving enabled.','method':{'runs_per_case':runs,'server_preparation_delay_ms_per_response':20,'paced_chunk_delay_ms':2,'burst_content_bytes':65549,'paced_content_bytes':8205,'tool_steps':['read32KiB','write8KiB','read_written_file','edit_one_marker','shell_sha256sum'],'parallel_workers':2,'worker_model_delay_ms':150,'memory':'Peak summed process-tree PSS/RSS sampled every5ms; PSS avoids double counting shared pages. Very brief peaks may be missed.','cpu':'wait4 user+system CPU for launched CLI, including waited descendants and launcher.','client_tool_gap':'Sum response-completely-sent to next primary request-received across five tool steps; includes tool execution, history/session handling and HTTP.','first_visible':'Time from first server SSE body write until BENCH_ marker observed on stdout; default headless text mode.','first_response_to_exit':'Includes controlled stream delays, subsequent fixture preparation, auxiliary model calls, session saving and shutdown.','limitations':['Python fixture/sampling overhead and OS scheduling affect small timings.','Different feature sets and default prompts; this is workload equivalence, not full feature parity.','No terminal TUI rendering, real model inference, WAN latency, long conversations or production load measured.','TLS uses each client negotiated cipher, reported per case.']},'cases':{},'raw':{}}
 with tempfile.TemporaryDirectory(prefix='qwen-usage-bench-') as folder:
  base=pathlib.Path(folder);ca,cert,key=make_certificates(base)
  context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=context.maximum_version=ssl.TLSVersion.TLSv1_3;context.set_ecdh_curve('X25519');context.load_cert_chain(cert,key)
  homes={}
  for client in CLIENTS:
   homes[client]=base/(client+'-home');homes[client].mkdir()
   usage_run('warmup',client,base,homes[client],context,ca)
  for kind in ['burst_stream','paced_stream','tool_chain_http','tool_chain_tls','parallel_workers']:
   clients=list(CLIENTS) if kind!='parallel_workers' else ['assembly','go']
   report['raw'][kind]={client:[] for client in clients}
   for repeat in range(runs):
    ordered=clients[repeat%len(clients):]+clients[:repeat%len(clients)]
    for client in ordered:
     row=usage_run(kind,client,base,homes[client],context,ca);report['raw'][kind][client].append(row)
     print(json.dumps({'case':kind,'client':client,'run':repeat+1,'wall_ms':round(row['wall_ms'],2),'active_ms':round(row['first_response_to_exit_ms'],2),'cpu_ms':round(row['cpu_ms'],2),'pss_kib':row['sampled_peak_tree_pss_kib'],'tool_gap_ms':round(row.get('total_client_tool_gap_ms',0),2)}),flush=True)
   report['cases'][kind]={client:summarize(rows) for client,rows in report['raw'][kind].items()}
   (ROOT/'docs/usage-benchmark.json').write_text(json.dumps(report,indent=2)+'\n')
 if memory_results:
  prior=json.loads(pathlib.Path(memory_results).read_text())
  report['memory_pass']={'method':prior['method']['memory'],'runs_per_case':prior['method']['runs_per_case'],'cases':{case:{client:{k:v for k,v in summary.items() if k.startswith('sampled_peak_tree_')} for client,summary in clients.items()} for case,clients in prior['cases'].items()},'raw':{case:{client:[{k:v for k,v in row.items() if k.startswith('sampled_peak_tree_')} for row in rows] for client,rows in clients.items()} for case,clients in prior['raw'].items()}}
 report['method']['timing_memory_sampler_enabled']=SAMPLE_MEMORY
 report['binary_sha256']={client:hashlib.sha256(path.read_bytes()).hexdigest() for client,path in CLIENTS.items() if client!='javascript'}
 report['versions']={client:subprocess.check_output([str(path),'--version'],text=True).strip() for client,path in CLIENTS.items()}
 (ROOT/'docs/usage-benchmark.json').write_text(json.dumps(report,indent=2)+'\n')
 print('Saved docs/usage-benchmark.json',flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--probe',choices=CLIENTS);parser.add_argument('--runs',type=int,default=5);parser.add_argument('--no-memory',action='store_true');parser.add_argument('--memory-results');args=parser.parse_args()
 SAMPLE_MEMORY=not args.no_memory
 if args.probe:probe(args.probe)
 else:main(args.runs,args.memory_results)
