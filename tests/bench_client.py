"""Warm startup and idle-terminal comparisons; no model inference/network calls."""
import fcntl,json,os,pathlib,pty,select,statistics,struct,subprocess,tempfile,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
BINARIES={'assembly':ROOT/'qwen-x86','go':pathlib.Path.home()/'.local/bin/qwen-go'}
def startup(binary,env=None):
 for _ in range(5):subprocess.run([str(binary),'--version'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,env=env)
 samples=[]
 for _ in range(50):
  start=time.perf_counter_ns();subprocess.run([str(binary),'--version'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,env=env);samples.append((time.perf_counter_ns()-start)/1e6)
 return {'median_ms':round(statistics.median(samples),4),'p95_ms':round(sorted(samples)[47],4),'runs':50,'cache':'warm'}
def idle(binary,label):
 with tempfile.TemporaryDirectory(prefix='qwen-idle-') as folder:
  master,slave=pty.openpty();fcntl.ioctl(slave,0x5414,struct.pack('HHHH',24,100,0,0));env=dict(os.environ,HOME=folder,TERM='xterm-256color')
  args=[str(binary),'--demo','--cwd',folder]
  if label=='assembly':args+=['--no-save']
  proc=subprocess.Popen(args,stdin=slave,stdout=slave,stderr=slave,env=env,close_fds=True);os.close(slave)
  try:
   output=b'';deadline=time.monotonic()+5
   while b'QWEN' not in output and time.monotonic()<deadline:
    if select.select([master],[],[],0.1)[0]:
     part=os.read(master,65536);output+=part
     # Native terminal libraries may query terminal background/cursor.
     if b'\x1b]11;' in part:os.write(master,b'\x1b]11;rgb:0000/0000/0000\x1b\\')
     if b'\x1b[6n' in part:os.write(master,b'\x1b[1;1R')
   if b'QWEN' not in output:raise RuntimeError(label+' did not display its interface')
   time.sleep(.15)
   fields={}
   for line in pathlib.Path(f'/proc/{proc.pid}/status').read_text().splitlines():
    key,_,value=line.partition(':')
    if key in ['VmRSS','VmSize','RssAnon','RssFile']:fields[key+'_KiB']=int(value.split()[0])
   os.write(master,b'/quit\r')
   proc.wait(timeout=3)
   if proc.returncode:raise RuntimeError((label,'exit',proc.returncode))
   return fields
  finally:
   if proc.poll() is None:proc.kill();proc.wait()
   os.close(master)
def main():
 result={'verified':'2026-10-29','scope':'Warm --version process startup and idle offline terminal; not model inference speed or feature-parity proof.','clients':{}}
 for label,binary in BINARIES.items():
  result['clients'][label]={'elf_bytes':binary.stat().st_size,'startup':startup(binary),'idle_terminal':idle(binary,label)}
 original=pathlib.Path.home()/'.local/bin/qwen'
 original_tree=pathlib.Path.home()/'.local/lib/qwen-code'
 if original.exists() and original_tree.is_dir():
  with tempfile.TemporaryDirectory(prefix='qwen-original-bench-') as folder:
   env=dict(os.environ,HOME=folder,NO_COLOR='1',DISABLE_TELEMETRY='1',QWEN_CODE_DISABLE_TELEMETRY='1')
   result['clients']['original_javascript']={'installed_file_bytes':sum(p.stat().st_size for p in original_tree.rglob('*') if p.is_file() and not p.is_symlink()),'startup':startup(original,env),'idle_terminal':'not measured'}
  result['startup_ratio_javascript_over_assembly']=round(result['clients']['original_javascript']['startup']['median_ms']/result['clients']['assembly']['startup']['median_ms'],2)
 result['startup_ratio_go_over_assembly']=round(result['clients']['go']['startup']['median_ms']/result['clients']['assembly']['startup']['median_ms'],2)
 (ROOT/'docs/benchmark.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
