"""Actual interactive terminal benchmark; screen review remains a separate gate."""
import argparse,hashlib,json,pathlib,statistics,tempfile,threading,time
from ui_capture import Session,ROOT
from bench_usage import ModelServer,chunk,tree_memory,text_reply,flat_content

def ticks(pid):
 try:
  fields=pathlib.Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
  return int(fields[11])+int(fields[12])
 except (OSError,ValueError):return 0

def tree_ticks(pid):
 pending=[pid];seen=set();total=0
 while pending:
  current=pending.pop()
  if current in seen:continue
  seen.add(current);total+=ticks(current)
  try:
   for task in pathlib.Path(f'/proc/{current}/task').iterdir():
    try:pending.extend(map(int,(task/'children').read_text().split()))
    except (OSError,ValueError):pass
  except OSError:pass
 return total

def main(runs,memory=False):
 import os
 raw={client:[] for client in ['native','reference']}
 text='## Terminal stream\n\n'+''.join(f'Line {i:04d}: **rendered text**, `code`, Unicode λ世界.\n' for i in range(1000))+'\nBENCH_UI_END'
 blocks=[chunk({'content':text[i:i+128]}) for i in range(0,len(text),128)]+[chunk({},'stop'),b'data: [DONE]\n\n']
 for client in raw:
  for run in range(runs):
   with tempfile.TemporaryDirectory(prefix='qwen-ui-bench-') as folder:
    base=pathlib.Path(folder);work=base/'workspace';work.mkdir();home=base/'home';home.mkdir()
    def handler(req):
     users=[flat_content(m.get('content','')) for m in req.get('messages',[]) if m.get('role')=='user']
     return ([text_reply('BENCH_UI_VERIFIED')],0) if users and users[-1]=='BENCH_UI_VERIFY' else (blocks,.002)
    with ModelServer(handler) as server:
     start=time.perf_counter();session=Session(client,work,home,server.url,100,30,save_session=True)
     stop=threading.Event();peak=[0,0];pid=int(session.run('display-message','-p','-t',session.target,'#{pane_pid}'))
     def sample():
      while not stop.is_set():
       rss,pss=tree_memory(pid);peak[0]=max(peak[0],rss);peak[1]=max(peak[1],pss);stop.wait(.01)
     sampler=threading.Thread(target=sample)
     if memory:sampler.start()
     try:
      session.wait('Ask permissions',30);ready=time.perf_counter();before=tree_ticks(pid);session.literal('BENCH_UI_STREAM');session.key('Enter')
      session.wait('BENCH_UI_END',30);visible=time.perf_counter();cpu=tree_ticks(pid)-before
      if server.first_sent is None:raise RuntimeError('No model response served')
      row={'launch_to_ready_ms':(ready-start)*1000,'response_first_byte_to_end_visible_ms':(visible-server.first_sent)*1000,'cpu_after_ready_ms':cpu/os.sysconf('SC_CLK_TCK')*1000,'sampled_peak_tree_rss_kib':peak[0] if memory else None,'sampled_peak_tree_pss_kib':peak[1] if memory else None,'requests':len(server.records),'binary_sha256':session.binary_sha256}
      session.literal('BENCH_UI_VERIFY');session.key('Enter');session.wait('BENCH_UI_VERIFIED',30)
      verify=[r for r in server.records if r['request'].get('messages') and flat_content(r['request']['messages'][-1].get('content',''))=='BENCH_UI_VERIFY']
      if not verify or not any(m.get('role')=='assistant' and flat_content(m.get('content',''))==text for m in verify[-1]['request']['messages']):raise AssertionError('Full streamed transcript was not retained exactly')
      row['full_transcript_verified']=True
      raw[client].append(row);print(json.dumps({'client':client,'run':run+1,**row}),flush=True)
     finally:
      stop.set()
      if memory:sampler.join()
      session.close()
 summary={client:{key:statistics.median(row[key] for row in rows) for key in rows[0] if isinstance(rows[0][key],(float,int))} for client,rows in raw.items()}
 report={'reference_version':'0.24.5','scope':'Real interactive static assembly and default Qwen Ink renderer through tmux,100x30,controlled HTTP model; no real inference. Both clients retain default session saving. Workload is not full UI parity.','method':{'runs':runs,'verification':'A subsequent model request must contain the entire exact streamed assistant text; that verification request is outside the timed interval.','content_utf8_bytes':len(text.encode()),'content_chunks':len(blocks)-2,'pacing_ms':2,'screen_poll_ms':100,'pass':'memory (timings excluded from comparisons)' if memory else 'timing (memory sampler disabled)','memory_sample_ms':10 if memory else None,'startup':'Includes tmux launch and ready-screen polling, not bare executable startup.','cpu':'Sum /proc CPU deltas over live process tree after ready; 10ms scheduler quantization on this host, excludes children that exit before final sample.','limits':['UI completion latency includes controlled pacing and up to100ms terminal polling delay.','Sampling and tmux add overhead.','Clients differ in available features and session bookkeeping implementations.','Captures/interaction tests, not benchmark numbers, determine UI correctness.']},'raw':raw,'median':summary}
 (ROOT/'docs'/('ui-benchmark-memory.json' if memory else 'ui-benchmark.json')).write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--runs',type=int,default=3);p.add_argument('--memory',action='store_true');args=p.parse_args();main(args.runs,args.memory)
