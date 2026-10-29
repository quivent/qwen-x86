"""Pinned source builtin definitions, rendered and consumed natively."""
import ctypes as C,json,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class BuiltinTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();base=pathlib.Path(cls.tmp.name);subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/'src/ui_agents_builtin.s'),'-o',str(base/'builtin.o')],check=True);subprocess.run(['ld','-shared','-Bsymbolic',str(base/'builtin.o'),'-o',str(base/'builtin.so')],check=True);cls.lib=C.CDLL(str(base/'builtin.so'))
  cls.lib.ui_agent_builtin_catalog.argtypes=[C.c_void_p,C.c_size_t];cls.lib.ui_agent_builtin_catalog.restype=C.c_int64
  for name in ['ui_agent_builtin_read','ui_agent_builtin_prompt']:fn=getattr(cls.lib,name);fn.argtypes=[C.c_char_p,C.c_void_p,C.c_size_t];fn.restype=C.c_int64
  cls.lib.ui_agent_builtin_policy.argtypes=[C.c_char_p];cls.lib.ui_agent_builtin_policy.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def test_all_source_definitions_catalog_prompts_and_metadata_match(self):
  source=json.loads((ROOT/'data/agents/qwen-0.24.5-builtins.json').read_text());items=(C.c_void_p*18)();self.assertEqual(self.lib.ui_agent_builtin_catalog(items,6),6)
  for i,agent in enumerate(source):
   self.assertEqual(C.string_at(items[i*3]).decode(),agent['name']);self.assertEqual(C.string_at(items[i*3+1]).decode(),agent['description']);self.assertEqual(C.string_at(items[i*3+2]).decode(),'<builtin:'+agent['name']+'>')
   out=C.create_string_buffer(65536);n=self.lib.ui_agent_builtin_prompt(agent['name'].upper().encode(),out,len(out));self.assertEqual(out.raw[:n].decode(),agent['systemPrompt']);n=self.lib.ui_agent_builtin_read(C.string_at(items[i*3+2]),out,len(out));self.assertEqual(json.loads(out.raw[:n]),agent)
 def test_real_source_policy_and_external_executors_not_faked(self):
  expected={'general-purpose':1,'Explore':0,'statusline-setup':1,'review-agent':1,'claude-code':-3,'codex':-4}
  for name,policy in expected.items():self.assertEqual(self.lib.ui_agent_builtin_policy(name.encode()),policy)
  self.assertEqual(self.lib.ui_agent_builtin_policy(b'unknown'),-2)
 def test_invalid_lookup_and_bounds_preserve_output(self):
  out=C.create_string_buffer(b'unchanged',128)
  self.assertEqual(self.lib.ui_agent_builtin_read(b'<builtin:codex>extra',out,len(out)),-2);self.assertEqual(self.lib.ui_agent_builtin_prompt(b'Explore',out,4),-28);self.assertEqual(out.value,b'unchanged')
