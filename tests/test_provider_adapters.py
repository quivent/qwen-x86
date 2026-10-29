"""Native Anthropic request/SSE protocol oracle fixtures, no network/credentials."""
import ctypes as C,json,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class AdapterTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();p=pathlib.Path(cls.tmp.name)
  for name in ['provider_adapters','runtime','json']:
   subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(p/(name+'.o')),str(ROOT/'src'/(name+'.s'))],check=True)
  so=p/'adapters.so';subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(so),*[str(p/(n+'.o')) for n in ['provider_adapters','runtime','json']]],check=True);cls.lib=C.CDLL(str(so))
  for n in ['provider_translate_request','provider_translate_stream']:
   f=getattr(cls.lib,n);f.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t];f.restype=C.c_int64
  cls.lib.provider_stream_metadata.argtypes=[C.c_void_p,C.c_size_t];cls.lib.provider_stream_metadata.restype=C.c_int64
  cls.lib.provider_stream_reset.argtypes=[C.c_char_p];cls.lib.provider_stream_reset.restype=C.c_int64;cls.lib.provider_stream_error.restype=C.c_char_p
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def call(self,name,raw,protocol=b'anthropic',cap=1000000):
  if not isinstance(raw,bytes):raw=json.dumps(raw,ensure_ascii=False).encode()
  out=C.create_string_buffer(cap+32);C.memset(out,0xa5,len(out));n=getattr(self.lib,name)(protocol,raw,len(raw),C.byref(out,16),cap)
  self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[16+cap:],b'\xa5'*16)
  return n,out.raw[16:16+max(n,0)]
 def test_native_anthropic_request_system_tools_and_parallel_results(self):
  request={'model':'configured-claude','messages':[{'role':'system','content':'System 世界'},{'role':'developer','content':'Developer rules'},{'role':'user','content':'Inspect'},{'role':'assistant','content':'I will inspect','tool_calls':[{'id':'call_1','type':'function','function':{'name':'read_file','arguments':'{"path":"a.txt"}'}},{'id':'call_2','type':'function','function':{'name':'list_directory','arguments':'{}'}}]},{'role':'tool','tool_call_id':'call_1','content':'hello'},{'role':'tool','tool_call_id':'call_2','content':'a.txt'}],'tools':[{'type':'function','function':{'name':'read_file','description':'Read a file','parameters':{'type':'object','properties':{'path':{'type':'string'}}}}}],'temperature':0.2,'max_tokens':2048}
  n,raw=self.call('provider_translate_request',request);self.assertGreater(n,0);r=json.loads(raw)
  self.assertEqual(r['system'],[{'type':'text','text':'System 世界'},{'type':'text','text':'Developer rules'}]);self.assertTrue(r['stream']);self.assertEqual(r['max_tokens'],2048)
  self.assertEqual(r['messages'][1]['content'][1],{'type':'tool_use','id':'call_1','name':'read_file','input':{'path':'a.txt'}})
  self.assertEqual(r['messages'][2]['content'][0],{'type':'tool_result','tool_use_id':'call_1','content':'hello'});self.assertEqual(len(r['messages'][2]['content']),2)
  self.assertEqual(r['tools'][0]['input_schema'],request['tools'][0]['function']['parameters']);self.assertEqual(r['temperature'],0.2)
 def test_anthropic_image_content_preserved_in_user_history(self):
  blocks=[{'type':'text','text':'Inspect image'}, {'type':'image_url','image_url':{'url':'data:image/png;base64,iVBORw=='}},{'type':'image_url','image_url':{'url':'https://example.test/image.png'}}]
  n,body=self.call('provider_translate_request',{'model':'x','messages':[{'role':'user','content':blocks}]});self.assertGreater(n,0)
  content=json.loads(body)['messages'][0]['content'];self.assertEqual(content[0],{'type':'text','text':'Inspect image'})
  self.assertEqual(content[1],{'type':'image','source':{'type':'base64','media_type':'image/png','data':'iVBORw=='}})
  self.assertEqual(content[2],{'type':'image','source':{'type':'url','url':'https://example.test/image.png'}})
  for url in ['data:text/html;base64,AAAA','data:image/png;base64,A===','data:image/png;base64,AA?=','javascript:bad']:
   bad={'model':'x','messages':[{'role':'user','content':[{'type':'image_url','image_url':{'url':url}}]}]};self.assertEqual(self.call('provider_translate_request',bad)[0],-22)
 def test_responses_request_preserves_tools_images_and_call_ids(self):
  r={'model':'configured-responses','messages':[{'role':'system','content':'rules'},{'role':'user','content':[{'type':'text','text':'image'},{'type':'image_url','image_url':{'url':'data:image/png;base64,AAAA'}}]},{'role':'assistant','content':'checking','tool_calls':[{'id':'call-real','function':{'name':'read_file','arguments':'{"path":"x"}'}}]},{'role':'tool','tool_call_id':'call-real','content':'result'}],'tools':[{'function':{'name':'read_file','description':'Read','parameters':{'type':'object'}}}],'max_tokens':500}
  n,raw=self.call('provider_translate_request',r,b'openai-responses');self.assertGreater(n,0);body=json.loads(raw)
  self.assertFalse(body['store']);self.assertEqual(body['input'][0]['content'][0]['type'],'input_text');self.assertEqual(body['input'][1]['content'][1],{'type':'input_image','image_url':'data:image/png;base64,AAAA'})
  self.assertEqual(body['input'][3],{'type':'function_call','call_id':'call-real','name':'read_file','arguments':'{"path":"x"}'});self.assertEqual(body['input'][4],{'type':'function_call_output','call_id':'call-real','output':'result'})
  self.assertEqual(body['tools'][0],{'type':'function','name':'read_file','description':'Read','parameters':{'type':'object'},'strict':False});self.assertEqual(body['max_output_tokens'],500)
 def test_responses_stream_fragments_call_ids_and_final_arguments_fallback(self):
  events=[{'type':'response.output_text.delta','delta':'Checking '},{'type':'response.output_item.added','output_index':2,'item':{'type':'function_call','id':'fc-internal','call_id':'real-call-id','name':'read_file','arguments':''}},{'type':'response.function_call_arguments.delta','output_index':2,'delta':'{"path":'},{'type':'response.function_call_arguments.delta','output_index':2,'delta':'"x"}'},{'type':'response.output_item.done','output_index':2,'item':{'type':'function_call','call_id':'real-call-id','arguments':'{"path":"x"}'}},{'type':'response.completed','response':{'status':'completed'}}]
  self.lib.provider_stream_reset(b'openai-responses');out=b'';wire=b''.join(b'data: '+json.dumps(e).encode()+b'\n\n' for e in events)
  for i in range(0,len(wire),7):
   n,data=self.call('provider_translate_stream',wire[i:i+7],b'openai-responses');self.assertGreaterEqual(n,0);out+=data
  rows=[json.loads(line[6:]) for line in out.splitlines() if line.startswith(b'data: {')];calls=[r['choices'][0]['delta']['tool_calls'][0] for r in rows if 'tool_calls' in r['choices'][0]['delta']]
  self.assertEqual(calls[0]['id'],'real-call-id');self.assertTrue(all(c['index']==0 for c in calls));self.assertEqual(''.join(c['function'].get('arguments','') for c in calls),'{"path":"x"}');self.assertTrue(out.endswith(b'data: [DONE]\n\n'))
  self.lib.provider_stream_reset(b'openai-responses');wire=b'data: {"type":"response.failed","response":{"error":{"message":"Actual provider error"}}}\n\n';self.assertEqual(self.call('provider_translate_stream',wire,b'openai-responses')[0],-22);self.assertEqual(self.lib.provider_stream_error(),b'Actual provider error')
 def test_responses_encrypted_reasoning_metadata_roundtrips_tool_history(self):
  reasoning={'type':'reasoning','id':'rs_fixture','summary':[],'encrypted_content':'opaque-fixture-reasoning'}
  self.lib.provider_stream_reset(b'openai-responses')
  event={'type':'response.output_item.done','output_index':0,'item':reasoning};wire=b'data: '+json.dumps(event).encode()+b'\n\n';self.assertGreaterEqual(self.call('provider_translate_stream',wire,b'openai-responses')[0],0)
  out=C.create_string_buffer(65536);n=self.lib.provider_stream_metadata(out,len(out));self.assertGreater(n,0);metadata=json.loads(out.raw[:n]);self.assertEqual(metadata,{'protocol':'openai-responses','items':[reasoning]})
  request={'model':'configured','messages':[{'role':'user','content':'work'},{'role':'assistant','content':'','provider_metadata':metadata,'tool_calls':[{'id':'call1','function':{'name':'read_file','arguments':'{}'}}]},{'role':'tool','tool_call_id':'call1','content':'result'}]}
  n,body=self.call('provider_translate_request',request,b'openai-responses');self.assertGreater(n,0);parsed=json.loads(body);self.assertIn('reasoning.encrypted_content',parsed['include']);self.assertEqual(parsed['input'][1],reasoning);self.assertEqual(parsed['input'][2]['type'],'function_call')
  self.lib.provider_stream_reset(b'openai-responses');self.assertEqual(self.lib.provider_stream_metadata(out,len(out)),0)
 def test_gemini_request_real_function_responses_images_and_signed_history(self):
  signed={'functionCall':{'id':'call-g','name':'read_file','args':{'path':'x'}},'thoughtSignature':'opaque-signed-fixture'}
  request={'model':'gemini-configured','messages':[{'role':'system','content':'rules'},{'role':'user','content':[{'type':'text','text':'look'},{'type':'image_url','image_url':{'url':'data:image/png;base64,AAAA'}}]},{'role':'assistant','content':'','tool_calls':[{'id':'call-g','function':{'name':'read_file','arguments':'{"path":"x"}'}}],'provider_metadata':{'protocol':'gemini','parts':[signed]}},{'role':'tool','tool_call_id':'call-g','content':'actual result'}],'tools':[{'function':{'name':'read_file','parameters':{'type':'object','properties':{'path':{'type':'string'}}}}}]}
  n,raw=self.call('provider_translate_request',request,b'gemini');self.assertGreater(n,0);body=json.loads(raw)
  self.assertEqual(body['systemInstruction'],{'parts':[{'text':'rules'}]});self.assertEqual(body['contents'][0]['parts'][1],{'inlineData':{'mimeType':'image/png','data':'AAAA'}})
  self.assertEqual(body['contents'][1],{'role':'model','parts':[signed]});self.assertEqual(body['contents'][2]['parts'][0],{'functionResponse':{'id':'call-g','name':'read_file','response':{'output':'actual result'}}});self.assertIn('parametersJsonSchema',body['tools'][0]['functionDeclarations'][0]);self.assertNotIn('model',body)
 def test_gemini_sse_preserves_thought_signatures_and_tools(self):
  part={'functionCall':{'id':'real-google-id','name':'read_file','args':{'path':'x'}},'thoughtSignature':'opaque-signed-part'}
  events=[{'candidates':[{'content':{'role':'model','parts':[{'text':'Checking '}]}}]},{'candidates':[{'content':{'role':'model','parts':[part]},'finishReason':'STOP'}]}]
  self.lib.provider_stream_reset(b'gemini');wire=b''.join(b'data: '+json.dumps(e).encode()+b'\n\n' for e in events);out=b''
  for i in range(0,len(wire),3):
   n,data=self.call('provider_translate_stream',wire[i:i+3],b'gemini');self.assertGreaterEqual(n,0);out+=data
  rows=[json.loads(line[6:]) for line in out.splitlines() if line.startswith(b'data: {')];calls=[r['choices'][0]['delta']['tool_calls'][0] for r in rows if 'tool_calls' in r['choices'][0]['delta']]
  self.assertEqual(calls[0]['id'],'real-google-id');self.assertEqual(json.loads(calls[0]['function']['arguments']),{'path':'x'});self.assertEqual(rows[-1]['choices'][0]['finish_reason'],'tool_calls');self.assertTrue(out.endswith(b'data: [DONE]\n\n'))
  out=C.create_string_buffer(65536);n=self.lib.provider_stream_metadata(out,len(out));self.assertGreater(n,0);self.assertEqual(json.loads(out.raw[:n]),{'protocol':'gemini','parts':[{'text':'Checking '},part]})
  self.lib.provider_stream_reset(b'gemini');wire=b'data: {"promptFeedback":{"blockReason":"SAFETY"}}\n\n';self.assertEqual(self.call('provider_translate_stream',wire,b'gemini')[0],-22);self.assertEqual(self.lib.provider_stream_error(),b'SAFETY')
 def test_gemini_missing_server_ids_use_persisted_local_tracking_only(self):
  part={'functionCall':{'name':'read_file','args':{}},'thoughtSignature':'signed-no-server-id'}
  self.lib.provider_stream_reset(b'gemini');wire=b'data: '+json.dumps({'candidates':[{'content':{'parts':[part]},'finishReason':'STOP'}]}).encode()+b'\n\n'
  n,body=self.call('provider_translate_stream',wire,b'gemini');self.assertGreater(n,0);rows=[json.loads(line[6:]) for line in body.splitlines() if line.startswith(b'data: {')];id=rows[0]['choices'][0]['delta']['tool_calls'][0]['id'];self.assertTrue(id.startswith('gemini-call-'))
  out=C.create_string_buffer(65536);n=self.lib.provider_stream_metadata(out,len(out));metadata=json.loads(out.raw[:n]);self.assertEqual(metadata['parts'],[part]);self.assertEqual(metadata['generated_ids'],[id])
  request={'model':'configured','messages':[{'role':'user','content':'work'},{'role':'assistant','content':'','tool_calls':[{'id':id,'function':{'name':'read_file','arguments':'{}'}}],'provider_metadata':metadata},{'role':'tool','tool_call_id':id,'content':'result'}]}
  n,raw=self.call('provider_translate_request',request,b'gemini');self.assertGreater(n,0);body=json.loads(raw);self.assertEqual(body['contents'][1]['parts'],[part]);response=body['contents'][2]['parts'][0]['functionResponse'];self.assertNotIn('id',response);self.assertEqual(response['name'],'read_file')
 def events(self,events,fragment=17):
  self.assertEqual(self.lib.provider_stream_reset(b'anthropic'),0);out=b''
  wire=b''.join(b'event: '+e['type'].encode()+b'\r\ndata: '+json.dumps(e,ensure_ascii=False).encode()+b'\r\n\r\n' for e in events)
  for i in range(0,len(wire),fragment):
   n,data=self.call('provider_translate_stream',wire[i:i+fragment]);self.assertGreaterEqual(n,0);out+=data
  return [json.loads(line[6:]) if line!=b'data: [DONE]' else '[DONE]' for line in out.splitlines() if line.startswith(b'data: ')]
 def test_fragmented_stream_text_dense_tool_indices_and_json_fragments(self):
  es=[{'type':'message_start','message':{}},{'type':'content_block_start','index':0,'content_block':{'type':'text','text':''}},{'type':'content_block_delta','index':0,'delta':{'type':'text_delta','text':'Hello 世界'}},{'type':'content_block_start','index':2,'content_block':{'type':'tool_use','id':'call_native','name':'read_file','input':{}}},{'type':'content_block_delta','index':2,'delta':{'type':'input_json_delta','partial_json':'{"path":'}},{'type':'content_block_delta','index':2,'delta':{'type':'input_json_delta','partial_json':'"file.txt"}'}},{'type':'message_delta','delta':{'stop_reason':'tool_use'}},{'type':'message_stop'}]
  for fragment in [1,17,99999]:
   rows=self.events(es,fragment);self.assertEqual(rows[-1],'[DONE]');parts=[r['choices'][0] for r in rows[:-1]]
   self.assertEqual(''.join(p['delta'].get('content','') for p in parts),'Hello 世界')
   calls=[p['delta']['tool_calls'][0] for p in parts if 'tool_calls' in p['delta']];self.assertTrue(all(c['index']==0 for c in calls));self.assertEqual(calls[0]['id'],'call_native')
   self.assertEqual(''.join(c['function'].get('arguments','') for c in calls),'{"path":"file.txt"}');self.assertEqual(parts[-1]['finish_reason'],'tool_calls')
 def test_nonempty_initial_tool_input_errors_reset_and_passthrough(self):
  rows=self.events([{'type':'content_block_start','index':1,'content_block':{'type':'tool_use','id':'a','name':'x','input':{'value':'世界'}}},{'type':'message_stop'}]);calls=[r['choices'][0]['delta']['tool_calls'][0] for r in rows[:-1] if 'tool_calls' in r['choices'][0]['delta']]
  self.assertEqual(json.loads(''.join(c['function'].get('arguments','') for c in calls)),{'value':'世界'})
  self.lib.provider_stream_reset(b'anthropic');n,_=self.call('provider_translate_stream',b'data: {"type":"error","error":{"message":"Quota exhausted"}}\n\n');self.assertEqual(n,-22);self.assertEqual(self.lib.provider_stream_error(),b'Quota exhausted')
  self.assertEqual(self.lib.provider_stream_reset(b'openai'),0)
  raw=b'data: unchanged\n\n';self.assertEqual(self.call('provider_translate_stream',raw,b'openai')[1],raw)
  request=b'{"model":"unchanged"}';self.assertEqual(self.call('provider_translate_request',request,b'qwen-oauth')[1],request)
 def test_capacity_malformed_and_unsupported_are_bounded(self):
  request={'model':'x','messages':[{'role':'user','content':'hello'}]}
  for cap in [0,1,32]:self.assertEqual(self.call('provider_translate_request',request,cap=cap)[0],-28)
  for request in [{}, {'model':'x','messages':[],'tools':[{'type':'function'}]}, {'model':'x','messages':[{'role':'assistant','tool_calls':[{'id':'x','function':{'name':'x','arguments':'[]'}}]}]}]:self.assertEqual(self.call('provider_translate_request',request)[0],-22)
  self.assertEqual(self.call('provider_translate_request',{},b'unknown')[0],-22)
  self.lib.provider_stream_reset(b'anthropic');self.assertEqual(self.call('provider_translate_stream',b'data: invalid\n\n')[0],-22)
if __name__=='__main__':unittest.main()
