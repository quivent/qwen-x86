"""Native customThemes schema and real formatter palette application."""
import ctypes as C,json,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class CustomThemeTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();p=pathlib.Path(cls.tmp.name);objects=[]
  for name in ['ui_custom_themes','json','ui_markdown','ui_mermaid','ui_input','runtime']:
   obj=p/(name+'.o');objects.append(str(obj));subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(obj),str(ROOT/'src'/(name+'.s'))],check=True)
  so=p/'themes.so';subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(so),*objects],check=True);cls.lib=C.CDLL(str(so))
  cls.lib.ui_custom_themes_load.argtypes=[C.c_void_p,C.c_size_t];cls.lib.ui_custom_themes_load.restype=C.c_int64
  cls.lib.ui_custom_theme_find.argtypes=[C.c_char_p];cls.lib.ui_custom_theme_find.restype=C.c_int64
  cls.lib.ui_custom_theme_name.argtypes=[C.c_size_t];cls.lib.ui_custom_theme_name.restype=C.c_char_p
  cls.lib.ui_custom_theme_palette.argtypes=[C.c_size_t,C.c_size_t];cls.lib.ui_custom_theme_palette.restype=C.c_void_p
  cls.lib.ui_custom_theme_gradient.argtypes=[C.c_size_t,C.c_size_t];cls.lib.ui_custom_theme_gradient.restype=C.c_void_p
  cls.lib.ui_custom_theme_catalog.argtypes=[C.c_void_p,C.c_size_t];cls.lib.ui_custom_theme_catalog.restype=C.c_int64
  cls.lib.ui_markdown_set_theme_reader.argtypes=[C.c_void_p];cls.lib.ui_mermaid_set_theme_reader.argtypes=[C.c_void_p]
  cls.lib.ui_format_markdown_ex.argtypes=[C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_size_t,C.c_size_t];cls.lib.ui_format_markdown_ex.restype=C.c_int64
  cls.lib.ui_markdown_set_theme_reader(C.cast(cls.lib.ui_custom_theme_palette,C.c_void_p));cls.lib.ui_mermaid_set_theme_reader(C.cast(cls.lib.ui_custom_theme_palette,C.c_void_p))
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def setUp(self):self.lib.ui_custom_themes_reset()
 def load(self,value):
  raw=json.dumps(value,ensure_ascii=False).encode();return self.lib.ui_custom_themes_load(raw,len(raw))
 def palette(self,id=17,kind=0,n=7):
  p=self.lib.ui_custom_theme_palette(id,kind);self.assertTrue(p);row=C.cast(p,C.POINTER(C.c_void_p));return [C.string_at(row[i]) for i in range(n)]
 def test_flat_semantic_override_palette_schema_and_layering(self):
  self.assertEqual(self.load({'customThemes':{'Moon':{'Foreground':'#123','AccentPurple':'gold','text':{'primary':'#112233','secondary':'gray','accent':'#abc'},'border':{'focused':'redBright'}}}}),1)
  self.assertEqual(self.lib.ui_custom_theme_find(b'Moon'),17);self.assertEqual(self.lib.ui_custom_theme_name(17),b'Moon')
  self.assertEqual(self.palette(),[b'\x1b[38;2;17;34;51m',b'\x1b[90m',b'\x1b[38;2;170;187;204m',b'\x1b[38;2;170;217;76m',b'\x1b[38;2;242;109;120m',b'\x1b[38;2;255;215;0m',b'\x1b[91m'])
  self.assertEqual(self.load({'customThemes':{'Moon':{'Foreground':'blue'},'Sun':{'name':'Named Sun','AccentGreen':'#010203'}}}),2)
  self.assertEqual(self.lib.ui_custom_theme_find(b'Moon'),17);self.assertEqual(self.palette()[0],b'\x1b[34m');self.assertEqual(self.lib.ui_custom_theme_find(b'Named Sun'),18)
  self.assertEqual(self.lib.ui_custom_theme_catalog(None,0),2)
 def test_formatter_and_mermaid_use_actual_custom_colors(self):
  self.assertEqual(self.load({'customThemes':{'Neon':{'text':{'code':'#123456','accent':'#778899','link':'#aabbcc'},'AccentYellow':'#010203'}}}),1)
  raw=b'`inline`\n```python\nreturn "value"\n```\n```mermaid\nflowchart LR\nA-->B\n```';out=C.create_string_buffer(65536)
  n=self.lib.ui_format_markdown_ex(raw,len(raw),out,len(out),80,17);self.assertGreater(n,0);body=out.raw[:n]
  for color in [b'\x1b[38;2;18;52;86m',b'\x1b[38;2;170;187;204m',b'\x1b[38;2;1;2;3m',b'\x1b[38;2;119;136;153m']:self.assertIn(color,body)
  self.assertIn(b'Mermaid flowchart',body)
 def test_custom_gradient_uses_actual_source_stop_interpolation(self):
  self.assertEqual(self.load({'customThemes':{'Gradient':{'GradientColors':['#ff0000','#00ff00','#0000ff'],'ui':{'gradient':['#000000','#ffffff']}}}}),1)
  for width in [36,37]:
   row=C.cast(self.lib.ui_custom_theme_gradient(17,width),C.POINTER(C.c_void_p))
   for x in range(width):
    color=(255*x+(width-1)//2)//(width-1);expected=f'\x1b[38;2;{color};{color};{color}m'.encode();self.assertEqual(C.string_at(row[x]),expected)
  self.assertFalse(self.lib.ui_custom_theme_gradient(17,80))
  p=self.lib.ui_custom_theme_palette(17,3);self.assertTrue(p)
 def test_limits_controls_copy_and_defaults(self):
  self.assertEqual(self.load({'other':'ignored'}),0)
  self.assertEqual(self.load({'customThemes':{'x':{'Foreground':'\x1b]52;SECRET\x07'}}}),1)
  self.assertEqual(self.palette()[0],b'\x1b[39m')
  self.assertEqual(self.load({'customThemes':{'\x1bBad':{}}}),-22)
  self.assertEqual(self.load({'customThemes':{str(i):{} for i in range(20)}}),-28)
  self.assertFalse(self.lib.ui_custom_theme_palette(999,0));self.assertIsNone(self.lib.ui_custom_theme_name(999));self.assertFalse(self.lib.ui_custom_theme_palette(17,99))
  raw=C.create_string_buffer(80);C.memset(raw,0xa5,len(raw));self.assertEqual(self.lib.ui_custom_theme_catalog(C.byref(raw,8),1),1);self.assertEqual(raw.raw[:8],b'\xa5'*8);self.assertEqual(raw.raw[32:],b'\xa5'*48)
if __name__=='__main__':unittest.main()
