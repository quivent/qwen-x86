"""Real production static ELF, raw PTY, model tool batch, and stdin-byte Ctrl+C.
The fixture sends no OS signal to the app: byte3 traverses the native cancellation
callback, shell cleanup, skipped tool results, session save, and prompt recovery.
"""
import json
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import tempfile
import termios
import time
import unittest

from test_cli import ConcurrentServer, answer, tool_events, disable_core

ROOT = Path(__file__).resolve().parents[1]


class NativeCancellationCLI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['make', '-s', 'qwen-x86'], cwd=ROOT, check=True)
        cls.binary = ROOT / 'qwen-x86'

    def test_raw_ctrl_c_cancels_shell_and_skips_remaining_batch(self):
        with tempfile.TemporaryDirectory(prefix='qwen-x86-cancel-cli-') as directory:
            base = Path(directory)
            home, workspace = base / 'home', base / 'workspace'
            home.mkdir()
            workspace.mkdir()
            environment = dict(os.environ)
            for key in ['OPENAI_API_KEY', 'OPENAI_BASE_URL', 'OPENAI_MODEL',
                        'QWEN_API_KEY', 'QWEN_BASE_URL', 'QWEN_MODEL']:
                environment.pop(key, None)
            environment.update(HOME=str(home), QWEN_API_KEY='dummy-cancel-fixture-key')
            calls = [
                ('run_shell', {'command': 'echo $$ > shell.pid; printf ready > ready; sleep 30', 'timeout_seconds': 60}),
                ('write_file', {'path': 'must-not-write.txt', 'content': 'This must never execute.'}),
            ]

            def model(request):
                if request['messages'][-1]['role'] == 'user':
                    return tool_events(calls, fragmented=True)
                return answer('Unexpected extra model request after cancellation.')

            with ConcurrentServer(model) as server:
                master, slave = pty.openpty()
                original = termios.tcgetattr(slave)
                process = subprocess.Popen([str(self.binary), '--cwd', str(workspace),
                    '--base-url', server.url, '--yes'], stdin=slave, stdout=slave,
                    stderr=slave, env=environment, cwd=ROOT, preexec_fn=disable_core)
                output = bytearray()

                def drain(timeout=0.02):
                    ready, _, _ = select.select([master], [], [], timeout)
                    if ready:
                        try:
                            output.extend(os.read(master, 65536))
                        except OSError:
                            pass

                def until(predicate, timeout, explanation):
                    deadline = time.monotonic() + timeout
                    while not predicate() and time.monotonic() < deadline:
                        if process.poll() is not None:
                            break
                        drain()
                    self.assertTrue(predicate(), explanation + ': ' + repr(bytes(output)))

                try:
                    prompt = b'> '
                    until(lambda: prompt in output, 4, 'initial prompt missing')
                    raw = termios.tcgetattr(slave)
                    self.assertFalse(raw[3] & termios.ISIG)
                    os.write(master, b'Run the two-tool cancellation batch\r')
                    until(lambda: (workspace / 'ready').exists(), 4, 'shell ready marker missing')
                    shell_pid = int((workspace / 'shell.pid').read_text())
                    tail = len(output)
                    started = time.monotonic()
                    os.write(master, b'\x03')
                    until(lambda: b'Canceled.' in output[tail:] and prompt in output[tail:],
                          3, 'raw Ctrl+C did not return to prompt')
                    self.assertLess(time.monotonic() - started, 3)
                    self.assertIsNone(process.poll(), bytes(output))
                    self.assertFalse((workspace / 'must-not-write.txt').exists())
                    with self.assertRaises(ProcessLookupError):
                        os.kill(shell_pid, 0)
                    sessions = list(home.rglob('session-*.json'))
                    self.assertEqual(len(sessions), 1)
                    history = json.loads(sessions[0].read_text())
                    self.assertEqual([item['role'] for item in history], ['user', 'assistant', 'tool', 'tool'])
                    tool_calls = history[1]['tool_calls']
                    self.assertEqual(len(tool_calls), 2)
                    self.assertEqual([item['tool_call_id'] for item in history[2:]],
                                     [item['id'] for item in tool_calls])
                    self.assertIn('cancel', history[2]['content'].lower())
                    self.assertIn('cancel', history[3]['content'].lower())
                    self.assertIn('not executed', history[3]['content'])
                    self.assertNotIn('dummy-cancel-fixture-key', sessions[0].read_text())
                    # Keep the mock endpoint available to observe any automatic retry.
                    end = time.monotonic() + 0.25
                    while time.monotonic() < end:
                        drain()
                    self.assertEqual(len(server.records), 1)
                    os.write(master, b'/quit\r')
                    process.wait(timeout=3)
                    self.assertEqual(process.returncode, 0, bytes(output))
                    self.assertEqual(termios.tcgetattr(slave), original)
                finally:
                    pid_file = workspace / 'shell.pid'
                    if pid_file.exists():
                        try:
                            os.killpg(int(pid_file.read_text()), signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=3)
                    os.close(master)
                    os.close(slave)


if __name__ == '__main__':
    unittest.main()
