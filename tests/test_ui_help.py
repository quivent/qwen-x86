"""Static native Help.tsx tab contract; reference capture is pinned in docs."""
import ctypes as C
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class HelpTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.temp=tempfile.TemporaryDirectory(prefix='qwen-x86-help-');out=Path(cls.temp.name)
  subprocess.run(['as','-I',str(ROOT/'src'),'-o',str(out/'help.o'),str(ROOT/'src/ui_help.s')],check=True)
  subprocess.run(['ld','-shared','-Bsymbolic','-z','noexecstack','-o',str(out/'help.so'),str(out/'help.o')],check=True)
  cls.lib=C.CDLL(str(out/'help.so'));cls.lib.ui_help_format.argtypes=[C.c_size_t,C.c_size_t,C.c_void_p,C.c_size_t];cls.lib.ui_help_format.restype=C.c_int64;cls.lib.ui_help_catalog.argtypes=[C.c_void_p,C.c_size_t];cls.lib.ui_help_catalog.restype=C.c_int64
 @classmethod
 def tearDownClass(cls):cls.temp.cleanup()
 def catalog(self):
  out=(C.c_void_p*9)();self.assertEqual(self.lib.ui_help_catalog(out,3),3)
  return [(C.string_at(out[i]).decode(),C.string_at(out[i+1]).decode(),C.string_at(out[i+2]).decode()) for i in range(0,9,3)]
 def format(self,tab=0,cols=90,cap=8192):
  out=C.create_string_buffer(cap+32);C.memset(out,0xa5,len(out))
  n=self.lib.ui_help_format(tab,cols,C.byref(out,16),cap)
  self.assertEqual(out.raw[:16],b'\xa5'*16);self.assertEqual(out.raw[cap+16:],b'\xa5'*16)
  return n,out.raw[16:16+max(n,0)].decode()
 def test_original_100_column_general_body(self):
  n,text=self.format();self.assertGreater(n,0)
  reference=(ROOT/'docs/ui-captures/reference/dialog-help.txt').read_text().splitlines()
  start=next(i for i,line in enumerate(reference) if 'Qwen Code understands' in line)
  end=next(i for i in range(start,len(reference)) if 'For more help:' in reference[i])
  expected=[line[5:line.rfind('│')].rstrip() for line in reference[start:end+1]]
  # Native has completion but no unsupported ghost-text feature.
  expected=[line.replace('Accept ghost text or c…','Accept completion      ') for line in expected]
  self.assertEqual([line.rstrip() for line in text.splitlines()],expected)
 def test_widths_unicode_padding_and_bounds(self):
  for terminal_width in [80,100,120]:
   cols=terminal_width-10;n,text=self.format(cols=cols);self.assertGreater(n,0)
   self.assertTrue(all(len(line)<=cols for line in text.splitlines()))
   row=next(line for line in text.splitlines() if line.startswith('Tab '))
   self.assertEqual(row.index('Alt+←/→'),((cols-2)//2)+2)
  for cols in [24,30,43,44,45,46,47,48]:
   n,text=self.format(cols=cols);self.assertGreater(n,0);self.assertTrue(all(len(line)<=cols for line in text.splitlines()))
  n,text=self.format(cols=30);self.assertGreater(n,0);self.assertEqual(sum(line.startswith('Ctrl+Q ') for line in text.splitlines()),1)
  self.assertTrue(all(len(line)<=30 for line in text.splitlines()))
  self.assertEqual(self.format(cols=20)[0],-22);self.assertEqual(self.format(tab=3)[0],-22)
  for cap in [0,1,32,100]:self.assertEqual(self.format(cap=cap)[0],-28)
  for tab in [1,2]:self.assertEqual(self.format(tab=tab)[1],self.catalog()[tab][2])
 def test_original_tab_names_order_and_general_shortcuts(self):
  tabs=self.catalog();self.assertEqual([tab[0] for tab in tabs],['general','commands','custom-commands'])
  reference=(ROOT/'docs/ui-captures/reference/dialog-help.txt').read_text()
  self.assertIn('Qwen Code   general   commands   custom-commands',reference)
  body=tabs[0][2]
  for shortcut in ['@','!','/','Tab','Esc Esc','Ctrl+L','Ctrl+Q','Ctrl+J','Shift+Tab','Alt+←/→','↑/↓']:
   self.assertIn(shortcut,reference);self.assertIn(shortcut,body)
  self.assertNotIn('ghost text',body)
  self.assertIn('https://qwenlm.github.io/qwen-code-docs/',body)
 def test_commands_match_native_routes_and_custom_invocation(self):
  tabs=self.catalog();commands=tabs[1][2];custom=tabs[2][2];source=(ROOT/'src/main.s').read_text()
  for command in ['/help','/new','/clear','/reset','/retry','/model','/theme','/approval-mode','/resume','/sessions','/session','/plugins','/agents','/about','/quit']:
   self.assertIn(command,commands);self.assertIn(f'.asciz "{command}"',source)
  for unavailable in ['/compress','/memory','/auth','/reload-plugins','/telemetry','/stats']:
   self.assertNotIn(unavailable,commands)
  self.assertIn('/plugin:command arguments',custom);self.assertIn('/skill plugin:skill arguments',custom)
  self.assertIn('~/.config/qwen-go/plugins',custom);self.assertIn('.qwen-go/plugins',custom)
  self.assertIn('approval',custom)
 def test_bounds_measurement_and_static_plain_text(self):
  self.assertEqual(self.lib.ui_help_catalog(None,0),3)
  self.assertEqual(self.lib.ui_help_catalog(None,3),-22)
  for cap in [1,2]:
   raw=C.create_string_buffer(104);C.memset(raw,0xa5,len(raw))
   self.assertEqual(self.lib.ui_help_catalog(C.byref(raw,16),cap),-28);self.assertEqual(raw.raw,b'\xa5'*104)
  raw=C.create_string_buffer(104);C.memset(raw,0xa5,len(raw));self.assertEqual(self.lib.ui_help_catalog(C.byref(raw,16),100),3)
  self.assertEqual(raw.raw[:16],b'\xa5'*16);self.assertEqual(raw.raw[88:],b'\xa5'*16)
  for label,description,body in self.catalog():
   self.assertLess(len(body.encode()),4096)
   self.assertNotIn('\x1b',body)
   self.assertFalse(any(ord(c)<32 and c!='\n' for c in label+description+body))
if __name__=='__main__':unittest.main()
