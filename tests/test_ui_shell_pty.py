"""Real controlling-terminal shell input/output and cancellation; native ELF."""
import os,pathlib,pty,select,struct,subprocess,tempfile,termios,fcntl,time,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class InteractiveShellTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  (base/'main.s').write_text('''.intel_syntax noprefix
.section .text
.global _start
_start:
 mov r12,rsp
 mov rdi,[r12+16]
 xor esi,esi
1: cmp byte ptr [rdi+rsi],0
 je 2f
 inc rsi
 jmp 1b
2: mov rdx,[r12+24]
 mov rax,[r12]
 lea rcx,[r12+rax*8+16]
 lea r8,[rip+output]
 mov r9d,65536
 call ui_shell_execute_pty
 test rax,rax
 js fail
 mov r13,rax
 mov eax,1
 mov edi,1
 lea rsi,[rip+marker]
 mov edx,10
 syscall
 mov eax,1
 mov edi,1
 lea rsi,[rip+output]
 mov rdx,r13
 syscall
 call ui_shell_pty_cancelled
 test rax,rax
 jnz cancel
 call ui_shell_pty_status
 test rax,rax
 jnz fail
 mov eax,60
 xor edi,edi
 syscall
fail: mov eax,60
 mov edi,42
 syscall
cancel: mov eax,60
 mov edi,43
 syscall
.section .rodata
marker: .ascii "[CAPTURE]\\n"
.section .bss
output: .skip 65536
''')
  for name,path in [('pty',ROOT/'src/ui_shell_pty.s'),('main',base/'main.s')]:subprocess.run(['as','--64','-I',str(ROOT/'src'),str(path),'-o',str(base/f'{name}.o')],check=True)
  cls.binary=base/'pty-shell';subprocess.run(['ld','-static','-z','noexecstack',str(base/'main.o'),str(base/'pty.o'),'-o',str(cls.binary)],check=True)
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def run_pty(self,command,send=None,cap=65536):
  master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));saved=termios.tcgetattr(slave)
  proc=subprocess.Popen([str(self.binary),command,str(ROOT)],stdin=slave,stdout=slave,stderr=slave,env=dict(os.environ,NATIVE_PTY_TOKEN='preserved'))
  out=bytearray();sent=False;deadline=time.monotonic()+4
  try:
   while time.monotonic()<deadline:
    if select.select([master],[],[],.02)[0]:
     try:out.extend(os.read(master,65536))
     except OSError:pass
    if send and not sent and send[0] in out:os.write(master,send[1]);sent=True
    if proc.poll() is not None:
     for _ in range(3):
      if select.select([master],[],[],.02)[0]:
       try:out.extend(os.read(master,65536))
       except OSError:pass
     break
   self.assertIsNotNone(proc.poll(),'interactive shell stalled: '+repr(bytes(out[-1000:])))
   self.assertEqual(termios.tcgetattr(slave),saved,'terminal state changed')
   return proc.returncode,bytes(out)
  finally:
   if proc.poll() is None:proc.kill();proc.wait()
   os.close(master);os.close(slave)
 def test_actual_tty_stdin_prompt_unicode_environment_and_capture(self):
  code,out=self.run_pty('test -t 0 && test -t 1 && test -t 2 || exit 7; printf "INPUT-READY:"; read answer; printf "RESULT:%s:%s\\n" "$answer" "$NATIVE_PTY_TOKEN"',send=(b'INPUT-READY:','λ answer\r'.encode()))
  self.assertEqual(code,0,out);self.assertIn('RESULT:λ answer:preserved'.encode(),out);self.assertIn(b'[CAPTURE]',out);self.assertGreaterEqual(out.count('RESULT:λ answer:preserved'.encode()),2)
 def test_real_ctrl_c_kills_shell_and_restores_terminal(self):
  with tempfile.TemporaryDirectory() as d:
   pidfile=pathlib.Path(d)/'child.pid';start=time.monotonic();code,out=self.run_pty('sleep 30 & echo $! > '+str(pidfile)+'; printf CANCEL-READY; wait',send=(b'CANCEL-READY',b'\x03'))
   self.assertEqual(code,43,out);self.assertLess(time.monotonic()-start,3);pid=int(pidfile.read_text());deadline=time.monotonic()+2
   while time.monotonic()<deadline:
    try:
     status=pathlib.Path(f'/proc/{pid}/status').read_text()
     if '\nState:\tZ' in status:break
    except FileNotFoundError:break
    time.sleep(.01)
   else:self.fail(f'background child {pid} survived cancellation')
 def test_nonzero_exit_is_reported_and_output_drained(self):
  code,out=self.run_pty('printf failure-output; exit 9');self.assertEqual(code,42,out);self.assertIn(b'failure-output',out)
 def test_non_terminal_rejected_without_spawning(self):
  proc=subprocess.run([str(self.binary),'touch /tmp/native-pty-must-not-spawn',str(ROOT)],input=b'',capture_output=True,timeout=2);self.assertEqual(proc.returncode,42)
