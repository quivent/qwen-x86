"""Actual Qwen modelProviders data, no invented models or copied credentials."""
import ctypes as C,json,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ProviderModelsTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();p=pathlib.Path(cls.tmp.name)
  for name in ['ui_provider_catalog','json']:
   subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(p/(name+'.o')),str(ROOT/'src'/(name+'.s'))],check=True)
  so=p/'providers.so';subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(so),str(p/'ui_provider_catalog.o'),str(p/'json.o')],check=True);cls.lib=C.CDLL(str(so))
  cls.lib.ui_provider_models_load.argtypes=[C.c_void_p,C.c_size_t];cls.lib.ui_provider_models_load.restype=C.c_int64
  cls.lib.ui_provider_model_catalog.argtypes=[C.c_void_p,C.c_size_t];cls.lib.ui_provider_model_catalog.restype=C.c_int64
  cls.lib.ui_provider_model_get.argtypes=[C.c_size_t];cls.lib.ui_provider_model_get.restype=C.c_void_p
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):self.lib.ui_provider_models_reset()
 def load(self,value):
  raw=json.dumps(value).encode();return self.lib.ui_provider_models_load(raw,len(raw))
 def record(self,index):
  p=self.lib.ui_provider_model_get(index);self.assertTrue(p)
  return {key:C.string_at(p+offset).decode() for key,offset in [('id',0),('name',256),('provider',512),('protocol',640),('base',704),('env',2752),('description',3008)]}|{'context':C.c_uint64.from_address(p+3520).value,'supported':C.c_uint64.from_address(p+3528).value}
 def test_actual_profiles_protocol_mappings_wire_api_and_metadata(self):
  value={'providerProtocol':{'team':'openai'},'modelProviders':{'team':[{'id':'real-model','name':'Team model','baseUrl':'https://models.example/v1','envKey':'TEAM_API_KEY','description':'Configured provider','generationConfig':{'contextWindowSize':131072},'apiKey':'MUST_NOT_COPY'}],'anthropic':[{'id':'claude-real','envKey':'ANTHROPIC_API_KEY'}],'openai':[{'id':'responses-real','wireApi':'responses'}]}}
  self.assertEqual(self.load(value),3)
  r=self.record(0);self.assertEqual(r,{'id':'real-model','name':'Team model','provider':'team','protocol':'openai','base':'https://models.example/v1','env':'TEAM_API_KEY','description':'Configured provider','context':131072,'supported':1})
  self.assertEqual(self.record(1)['protocol'],'anthropic');self.assertEqual(self.record(1)['supported'],1)
  self.assertEqual(self.record(2)['protocol'],'openai-responses');self.assertEqual(self.record(2)['supported'],1)
  data=C.string_at(self.lib.ui_provider_model_get(0),4096);self.assertNotIn(b'MUST_NOT_COPY',data)
 def test_duplicate_composite_keys_and_later_scope_override(self):
  self.assertEqual(self.load({'modelProviders':{'openai':[{'id':'same','name':'First','baseUrl':'https://a.test'},{'id':'same','name':'Duplicate ignored','baseUrl':'https://a.test'},{'id':'same','name':'Distinct endpoint','baseUrl':'https://b.test'}]}}),2)
  self.assertEqual(self.record(0)['name'],'First');self.assertEqual(self.record(1)['name'],'Distinct endpoint')
  self.assertEqual(self.load({'modelProviders':{'openai':[{'id':'same','name':'Workspace','baseUrl':'https://a.test'}]}}),1)
  self.assertEqual(self.record(0)['name'],'Workspace');self.assertEqual(self.lib.ui_provider_model_catalog(None,0),2)
 def test_malformed_fields_caps_and_control_rejection(self):
  self.assertEqual(self.load({'modelProviders':{'openai':[{}, {'id':'bad\nmodel'},{'id':'good','name':'\x1bBAD','description':'a\x00b'}]}}),1)
  self.assertEqual(self.record(0)['name'],'good');self.assertEqual(self.record(0)['description'],'')
  self.assertEqual(self.load({'modelProviders':[]}),-22)
  self.assertEqual(self.load({'modelProviders':{'openai':[{'id':str(i)} for i in range(70)]}}),-28)
  self.assertFalse(self.lib.ui_provider_model_get(999))
  raw=C.create_string_buffer(80);C.memset(raw,0xa5,len(raw));self.assertEqual(self.lib.ui_provider_model_catalog(C.byref(raw,8),1),1);self.assertEqual(raw.raw[:8],b'\xa5'*8);self.assertEqual(raw.raw[32:],b'\xa5'*48)
if __name__=='__main__':unittest.main()
