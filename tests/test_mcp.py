"""Native stdio MCP fixtures. Python is only the explicitly configured test server;
application transport, process lifecycle and JSON-RPC are entirely assembly."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVER = r'''
import json, os, sys, time
mode=sys.argv[1]; marker=sys.argv[2]
open(marker,'w').write(str(os.getpid()))
fds={}
for fd in os.listdir('/proc/self/fd'):
 if int(fd)>2:
  try:fds[fd]=os.readlink('/proc/self/fd/'+fd)
  except FileNotFoundError:pass
open(marker+'.info','w').write(json.dumps({'pid':os.getpid(),'group':os.getpgrp(),'fds':fds,'environment':os.environ.get('MCP_TEST_OVERRIDE')}))
def send(obj):
 data=json.dumps(obj,ensure_ascii=False)+'\n'
 if mode=='fragment':
  for p in range(0,len(data),3):sys.stdout.write(data[p:p+3]);sys.stdout.flush()
 else: print(data,flush=True)
for line in sys.stdin:
 req=json.loads(line); method=req.get('method'); ident=req.get('id')
 if method=='notifications/initialized':continue
 if mode=='hang' or (mode=='hang_call' and method=='tools/call'):time.sleep(10)
 if mode=='truncated':sys.stdout.write('{"jsonrpc":');sys.stdout.flush();sys.exit()
 if mode=='oversize':sys.stdout.write('x'*1048576+'\n');sys.stdout.flush();continue
 if method=='initialize':
  send({'jsonrpc':'2.0','method':'notifications/progress','params':{}})
  send({'jsonrpc':'2.0','id':77,'method':'ping'})
  assert json.loads(sys.stdin.readline())=={'jsonrpc':'2.0','id':77,'result':{}}
  send({'jsonrpc':'2.0','id':'client-request','method':'unsupported/method'})
  assert json.loads(sys.stdin.readline())['error']['code']==-32601
  send({'jsonrpc':'2.0','id':ident+100,'result':{}})
  result={'protocolVersion':'2024-11-05','capabilities':{'tools':{}},'serverInfo':{'name':'fixture','version':'1'}}
  if mode=='wrong_version':result['protocolVersion']='1900-01-01'
  if mode=='no_tools':result['capabilities']={}
 elif method=='tools/list':
  tool={'name':'echo.native','description':'Native fixture ✓','inputSchema':{'type':'object','properties':{'value':{'type':'string'}}}}
  result={'tools':[tool,tool] if mode=='duplicate' else [tool]}
 elif method=='tools/call':
  if mode=='rpc_error':
   send({'jsonrpc':'2.0','id':ident,'error':{'code':-32000,'message':'fixture failure'}});continue
  if mode=='structured':result={'structuredContent':{'answer':42}}
  elif mode=='binary':result={'content':[{'type':'image','data':'SECRET_BINARY','mimeType':'image/png'}]}
  elif mode=='large':result={'content':[{'type':'text','text':'a'*70000}]}
  else:result={'content':[{'type':'text','text':'héllo 🎵 '+req['params']['arguments'].get('value','')},{'type':'text','text':os.environ.get('MCP_TEST_OVERRIDE','missing')}]}
 else: result={}
 send({'jsonrpc':'2.0','id':ident,'result':result})
'''

class NativeMCP(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory(prefix='qwen-x86-mcp-')
  cls.path=Path(cls.temp.name)
  cls.server=cls.path/'fixture.py';cls.server.write_text(SERVER)
  objects=[]
  for name in ['mcp','json','runtime']:
   obj=cls.path/(name+'.o');objects.append(str(obj))
   subprocess.run(['as','-I',str(ROOT/'src'),'--defsym','MCP_TIMEOUT_MS=500','-o',str(obj),str(ROOT/'src'/(name+'.s'))],check=True)
  shared=cls.path/'mcp.so'
  subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(shared),*objects],check=True)
  cls.lib=ctypes.CDLL(str(shared))
  cls.Callback=ctypes.CFUNCTYPE(ctypes.c_int64,ctypes.c_char_p)
  cls.CancelCallback=ctypes.CFUNCTYPE(ctypes.c_int64)
  cls.lib.mcp_set_cancel.argtypes=[ctypes.c_void_p]
  cls.lib.mcp_set_cancel.restype=ctypes.c_int64
  cls.lib.mcp_init.argtypes=[ctypes.c_void_p,ctypes.c_uint64,ctypes.c_void_p]
  cls.lib.mcp_register.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.mcp_execute.argtypes=[ctypes.c_char_p,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.mcp_definitions.argtypes=[ctypes.c_void_p,ctypes.c_size_t]
  cls.lib.mcp_handles.argtypes=[ctypes.c_char_p]
  for name in ['mcp_init','mcp_register','mcp_execute','mcp_definitions','mcp_handles','mcp_close','mcp_after_fork']:
   getattr(cls.lib,name).restype=ctypes.c_int64
 @classmethod
 def tearDownClass(cls):cls.lib.mcp_close();cls.temp.cleanup()
 def setUp(self):
  self.approvals=[];self.answer=1
  self.callback=self.Callback(lambda text:self.approvals.append(text.decode()) or self.answer)
  self.env=(ctypes.c_char_p*3)(b'PATH=/usr/bin:/bin',b'MCP_TEST_OVERRIDE=original',None)
  self.lib.mcp_init(self.callback,0,self.env)
  self.marker=self.path/('marker-'+self._testMethodName)
  self.marker.unlink(missing_ok=True)
 def tearDown(self):self.lib.mcp_close()
 def register(self,mode='normal',name='fixture',extra=None,plugin='test'):
  config={'command':sys.executable,'args':[str(self.server),mode,str(self.marker)],'env':{'MCP_TEST_OVERRIDE':'${extensionPath}/expanded'}}
  if extra:config.update(extra)
  raw=json.dumps({name:config}).encode()
  return self.lib.mcp_register(plugin.encode(),str(self.path).encode(),raw,len(raw))
 def execute(self,name,args=None,cap=65536):
  raw=json.dumps(args or {}).encode();buf=ctypes.create_string_buffer(cap+16)
  ctypes.memset(buf,0xa5,len(buf))
  n=self.lib.mcp_execute(name.encode(),raw,len(raw),ctypes.byref(buf,8),cap)
  self.assertEqual(buf.raw[:8],b'\xa5'*8);self.assertEqual(buf.raw[cap+8:],b'\xa5'*8)
  return n,buf.raw[8:8+max(n,0)].decode()
 def definitions(self,cap=65536):
  buf=ctypes.create_string_buffer(cap)
  n=self.lib.mcp_definitions(buf,cap)
  self.assertGreaterEqual(n,0)
  return json.loads(b'['+buf.raw[:n]+b']')
 def connect(self,mode='normal'):
  self.assertEqual(self.register(mode),0)
  n,text=self.execute('connect_mcp_server',{'server':'test:fixture'})
  self.assertGreater(n,0);self.assertIn('connected;',text)
  tools=self.definitions();self.assertEqual(len(tools),1)
  return tools[0]['function']['name']
 def test_approved_handshake_schema_and_call(self):
  name=self.connect()
  self.assertTrue(name.startswith('mcp_'));self.assertLessEqual(len(name),64)
  self.assertEqual(self.lib.mcp_handles(name.encode()),1)
  self.assertEqual(self.lib.mcp_handles(b'unknown'),0)
  self.assertEqual(self.definitions()[0]['function']['parameters']['type'],'object')
  n,text=self.execute(name,{'value':'✓'})
  self.assertGreater(n,0);self.assertEqual(text,'héllo 🎵 ✓\n'+str(self.path)+'/expanded')
  self.assertEqual(len(self.approvals),2)
 def test_loading_and_startup_denial_never_executes(self):
  self.assertEqual(self.register(),0);self.assertFalse(self.marker.exists())
  self.answer=0
  n,text=self.execute('connect_mcp_server',{'server':'test:fixture'})
  self.assertIn('denied',text);self.assertFalse(self.marker.exists());self.assertEqual(self.definitions(),[])
 def test_headless_denies_and_yes_allows(self):
  self.lib.mcp_init(None,0,self.env);self.register()
  self.assertIn('denied',self.execute('connect_mcp_server',{'server':'test:fixture'})[1]);self.assertFalse(self.marker.exists())
  self.lib.mcp_init(None,1,self.env);name=self.connect();self.assertGreater(self.execute(name)[0],0)
 def test_call_denial_is_separate(self):
  name=self.connect();self.answer=0
  self.assertIn('denied',self.execute(name)[1]);self.assertEqual(len(self.approvals),2)
 def test_child_setup_and_path_resolution(self):
  self.register(extra={'command':Path(sys.executable).name,'env':{'PATH':str(Path(sys.executable).parent),'MCP_TEST_OVERRIDE':'${CLAUDE_PLUGIN_ROOT}/child'}})
  self.assertIn('connected;',self.execute('connect_mcp_server',{'server':'test:fixture'})[1])
  info=json.loads(Path(str(self.marker)+'.info').read_text())
  self.assertEqual(info['pid'],info['group']);self.assertEqual(info['fds'],{})
  self.assertEqual(info['environment'],str(self.path)+'/child')
 def test_fragmented_stdio(self):self.assertGreater(self.execute(self.connect('fragment'))[0],0)
 def test_config_limits_duplicates_and_remote_rejection(self):
  self.assertEqual(self.register(),0);self.assertLess(self.register(),0)
  raw=b'{"remote":{"url":"https://example.invalid"}}'
  self.assertEqual(self.lib.mcp_register(b'test',b'/tmp',raw,len(raw)),0)
  self.assertIn('Unsupported',self.execute('connect_mcp_server',{'server':'test:remote'})[1])
  self.assertFalse(self.marker.exists())
  self.assertLess(self.register(name='../escape'),0)
  for i in range(2):self.assertEqual(self.register(name='s'+str(i)),0)
  self.assertLess(self.register(name='fifth'),0)
 def test_config_argument_and_environment_bounds(self):
  for extra in [{'args':['value']*33},{'env':{'E'+str(i):'value' for i in range(33)}},{'transport':'http'},{'command':'/does/not/exist'}]:
   self.lib.mcp_init(self.callback,0,self.env)
   self.register(extra=extra)
   text=self.execute('connect_mcp_server',{'server':'test:fixture'})[1]
   self.assertTrue('Unsupported' in text or 'failed' in text)
   self.assertFalse(self.marker.exists());self.assertEqual(self.definitions(),[])
 def test_definitions_buffer_is_bounded(self):
  self.connect();buf=ctypes.create_string_buffer(b'X'*24)
  self.assertLess(self.lib.mcp_definitions(ctypes.byref(buf,8),8),0)
  self.assertEqual(buf.raw[:8],b'X'*8);self.assertEqual(buf.raw[16:24],b'X'*8)
 def test_secret_flags_redacted_without_environment_values(self):
  self.register(extra={'args':[str(self.server),'normal',str(self.marker),'--api-key','NEVER_PRINT_SECRET','--token=NEVER_PRINT_TOKEN'],'env':{'SECRET':'NEVER_PRINT_ENV'}})
  self.answer=0;self.execute('connect_mcp_server',{'server':'test:fixture'})
  self.assertEqual(len(self.approvals),1)
  preview=self.approvals[0]
  for secret in ['NEVER_PRINT_SECRET','NEVER_PRINT_TOKEN','NEVER_PRINT_ENV']:self.assertNotIn(secret,preview)
  self.assertIn('[redacted]',preview)
 def test_negotiation_rejects_wrong_version_and_missing_capability(self):
  for mode in ['wrong_version','no_tools']:
   self.lib.mcp_init(self.callback,0,self.env);self.register(mode)
   self.assertIn('failed',self.execute('connect_mcp_server',{'server':'test:fixture'})[1]);self.assertEqual(self.definitions(),[])
 def test_duplicate_tools_fail_closed(self):
  self.register('duplicate');self.assertIn('failed',self.execute('connect_mcp_server',{'server':'test:fixture'})[1]);self.assertEqual(self.definitions(),[])
 def test_rpc_error_structured_binary_and_caps(self):
  name=self.connect('rpc_error');self.assertIn('JSON-RPC error',self.execute(name)[1])
  self.lib.mcp_init(self.callback,0,self.env);name=self.connect('structured');self.assertEqual(json.loads(self.execute(name)[1]),{'answer':42})
  self.lib.mcp_init(self.callback,0,self.env);name=self.connect('binary');self.assertIn('omitted',self.execute(name)[1])
  self.lib.mcp_init(self.callback,0,self.env);name=self.connect('large');self.assertLess(self.execute(name,cap=64)[0],0)
 def test_cancel_callback_stops_and_reaps_waiting_server(self):
  for mode in ['hang','hang_call']:
   self.lib.mcp_init(self.callback,0,self.env)
   self.marker.unlink(missing_ok=True)
   name=None
   if mode=='hang_call':name=self.connect(mode)
   else:self.assertEqual(self.register(mode),0)
   probes=[]
   def cancel():
    probes.append(time.monotonic())
    return -125 if len(probes)>=3 else 0
   callback=self.CancelCallback(cancel)
   self.assertEqual(self.lib.mcp_set_cancel(callback),0)
   started=time.monotonic()
   if name:self.assertIn('failed',self.execute(name)[1])
   else:self.assertIn('failed',self.execute('connect_mcp_server',{'server':'test:fixture'})[1])
   self.assertGreaterEqual(len(probes),3)
   self.assertLess(time.monotonic()-started,0.45)
   self.assertEqual(self.definitions(),[])
   self.assertTrue(self.marker.exists())
   with self.assertRaises(ProcessLookupError):os.kill(int(self.marker.read_text()),0)
 def test_timeout_truncation_and_oversize_cleanup(self):
  for mode in ['hang','truncated','oversize']:
   self.lib.mcp_init(self.callback,0,self.env);self.register(mode)
   before=time.monotonic();self.assertIn('failed',self.execute('connect_mcp_server',{'server':'test:fixture'})[1]);self.assertLess(time.monotonic()-before,2)
   self.assertEqual(self.definitions(),[])
   if self.marker.exists():
    pid=int(self.marker.read_text())
    with self.assertRaises(ProcessLookupError):os.kill(pid,0)
 def test_after_fork_does_not_kill_parent_server(self):
  name=self.connect();server_pid=int(self.marker.read_text())
  child=os.fork()
  if child==0:
   result=self.lib.mcp_after_fork();os._exit(0 if result==0 else 1)
  _,status=os.waitpid(child,0);self.assertEqual(status,0)
  os.kill(server_pid,0);self.assertGreater(self.execute(name)[0],0)
  self.lib.mcp_close()
  with self.assertRaises(ProcessLookupError):os.kill(server_pid,0)
 def test_invalid_args_and_tiny_cap(self):
  self.register()
  out=ctypes.create_string_buffer(8)
  self.assertLess(self.lib.mcp_execute(b'list_mcp_servers',b'[]',2,out,8),0)
  self.assertLess(self.execute('list_mcp_servers',cap=1)[0],0)
  self.assertEqual(self.lib.mcp_handles(b'list_mcp_servers'),1)
  self.assertEqual(self.lib.mcp_handles(b'connect_mcp_server'),1)
  self.assertLess(self.lib.mcp_definitions(None,0),0)
  self.assertEqual(self.lib.mcp_definitions(out,1),0)

if __name__=='__main__':unittest.main()
