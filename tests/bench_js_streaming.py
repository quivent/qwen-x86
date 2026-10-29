"""Supplement: original JavaScript explicit partial streaming output mode."""
import json,pathlib,tempfile
import bench_usage as usage

def main():
 usage.SAMPLE_MEMORY=False
 original=usage.command
 def command(*args,**kwargs):
  cmd,env=original(*args,**kwargs)
  if args[0]=='javascript':
   cmd[cmd.index('--output-format')+1]='stream-json';cmd.append('--include-partial-messages')
  return cmd,env
 usage.command=command
 rows=[]
 with tempfile.TemporaryDirectory(prefix='qwen-stream-json-bench-') as directory:
  base=pathlib.Path(directory);home=base/'home';home.mkdir()
  usage.usage_run('warmup','javascript',base,home,None,None)
  for _ in range(3):rows.append(usage.usage_run('paced_stream','javascript',base,home,None,None))
 result={'scope':'JavaScript paced8KiB stream in explicit stream-json + include-partial-messages mode; no memory sampling;3runs afterwarmup.','raw':rows,'summary':usage.summarize(rows)}
 (usage.ROOT/'docs/javascript-streaming-mode.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result['summary'],indent=2))
if __name__=='__main__':main()
