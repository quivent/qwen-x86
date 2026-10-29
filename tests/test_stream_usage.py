"""Actual native SSE parser usage counters, including final empty-choices events."""
import ctypes as C,json,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class StreamUsageTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory();base=pathlib.Path(cls.temp.name)
  for name in ['stream','json','runtime']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  subprocess.run(['ld','-shared','-Bsymbolic',*[str(base/f'{name}.o') for name in ['stream','json','runtime']],'-o',str(base/'usage.so')],check=True)
  cls.lib=C.CDLL(str(base/'usage.so'));cls.lib.stream_begin.argtypes=[C.c_void_p];cls.lib.stream_feed.argtypes=[C.c_void_p,C.c_size_t];cls.lib.stream_feed.restype=C.c_int64;cls.lib.stream_finish.restype=C.c_int64;cls.lib.stream_usage_snapshot.argtypes=[C.c_void_p];cls.lib.stream_usage_snapshot.restype=C.c_int64;cls.lib.stream_result.restype=C.c_void_p
 @classmethod
 def tearDownClass(cls):cls.temp.cleanup()
 def setUp(self):self.lib.stream_begin(None)
 def usage(self):
  out=(C.c_uint64*4)();present=self.lib.stream_usage_snapshot(out);self.assertEqual(present,out[3]);return tuple(out)
 def event(self,value,fragment=0):
  raw=b'data: '+json.dumps(value,separators=(',',':')).encode()+b'\n\n'
  if fragment:
   for i in range(0,len(raw),fragment):self.assertEqual(self.lib.stream_feed(raw[i:i+fragment],len(raw[i:i+fragment])),0)
  else:self.assertEqual(self.lib.stream_feed(raw,len(raw)),0)
 def finish(self):
  raw=b'data: [DONE]\n\n';self.assertEqual(self.lib.stream_feed(raw,len(raw)),0);self.assertEqual(self.lib.stream_finish(),0)
 def test_final_usage_empty_choices_fragmented_and_content_preserved(self):
  self.event({'choices':[{'delta':{'content':'hello λ'},'finish_reason':None}],'usage':None},1)
  self.assertEqual(self.usage(),(0,0,0,0))
  self.event({'choices':[{'delta':{},'finish_reason':'stop'}]})
  self.event({'choices':[],'usage':{'prompt_tokens':1234,'completion_tokens':56,'total_tokens':1290,'prompt_tokens_details':{'cached_tokens':100}}},3)
  self.assertEqual(self.usage(),(1234,56,1290,1));self.finish();self.assertEqual(C.string_at(self.lib.stream_result()).decode(),'hello λ')
 def test_usage_in_content_event_updates_latest_report_and_resets_per_stream(self):
  self.event({'choices':[{'delta':{'content':'x'},'finish_reason':'stop'}],'usage':{'prompt_tokens':7,'completion_tokens':8,'total_tokens':15}})
  self.event({'choices':[],'usage':{'prompt_tokens':9,'completion_tokens':10,'total_tokens':19}})
  self.finish();self.assertEqual(self.usage(),(9,10,19,1))
  self.lib.stream_begin(None);self.assertEqual(self.usage(),(0,0,0,0))
 def test_invalid_optional_usage_does_not_invent_or_corrupt_counters(self):
  malformed=[None,{},'text',{'prompt_tokens':1,'completion_tokens':2},*[{'prompt_tokens':x,'completion_tokens':2,'total_tokens':3} for x in [-1,1.25,True,'1',2**63,10**40]]]
  for value in malformed:self.event({'choices':[],'usage':value});self.assertEqual(self.usage(),(0,0,0,0))
  self.event({'choices':[],'usage':{'prompt_tokens':10,'completion_tokens':20,'total_tokens':30}})
  self.event({'choices':[],'usage':{'prompt_tokens':11,'completion_tokens':False,'total_tokens':31}})
  self.assertEqual(self.usage(),(10,20,30,1));self.finish()
 def test_zero_and_largest_supported_actual_integer_values(self):
  self.event({'choices':[],'usage':{'prompt_tokens':0,'completion_tokens':0,'total_tokens':0}})
  self.assertEqual(self.usage(),(0,0,0,1))
  self.event({'choices':[],'usage':{'prompt_tokens':2**63-1,'completion_tokens':0,'total_tokens':2**63-1}})
  self.assertEqual(self.usage(),(2**63-1,0,2**63-1,1));self.finish()
 def test_usage_does_not_count_as_successful_stream_termination(self):
  self.event({'choices':[],'usage':{'prompt_tokens':1,'completion_tokens':2,'total_tokens':3}})
  self.assertLess(self.lib.stream_finish(),0)
if __name__=='__main__':unittest.main()
