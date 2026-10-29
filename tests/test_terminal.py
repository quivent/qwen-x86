"""Native terminal proofs: assemble/link a syscall-only witness and drive a PTY.

No C library, JavaScript, Go runtime, or third-party Python modules are linked.
"""
import errno
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
TERMINAL = ROOT / "src" / "terminal.s"


def literal(data):
    return ".byte " + ",".join(str(byte) for byte in data) + "\n" if data else ".byte 0\n"


class TerminalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="qwen-x86-terminal-")
        cls.directory = Path(cls.temporary.name)
        cls.object = cls.directory / "terminal.o"
        subprocess.run(["as", "-o", str(cls.object), str(TERMINAL)], check=True)
        cls.counter = 0

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def witness(self, body, data="", bss=""):
        type(self).counter += 1
        name = self.directory / f"witness-{self.counter}"
        asm = name.with_suffix(".s")
        asm.write_text(""".intel_syntax noprefix
.section .text
.globl _start
_start:
""" + body + """
 mov eax,60
 xor edi,edi
 syscall
.section .rodata
""" + data + "\n.section .bss\n" + bss + '\n.section .note.GNU-stack,"",@progbits\n')
        obj = name.with_suffix(".o")
        subprocess.run(["as", "-o", str(obj), str(asm)], check=True)
        subprocess.run(["ld", "-o", str(name), str(obj), str(self.object)], check=True)
        return name

    def writer(self, chunks):
        data = ""
        body = " call term_init\n"
        for i, chunk in enumerate(chunks):
            data += f"chunk{i}:\n" + literal(chunk)
            body += f" lea rdi,[rip+chunk{i}]\n mov esi,{len(chunk)}\n call term_write\n"
        body += " call term_restore\n"
        return self.witness(body, data)

    def reader(self, capacity=128, approve=False):
        body = """ call term_init
 mov eax,1
 mov edi,1
 lea rsi,[rip+ready]
 mov edx,5
 syscall
"""
        if approve:
            body += " lea rdi,[rip+question]\n call term_approve\n"
        else:
            body += f" lea rdi,[rip+buffer]\n mov esi,{capacity}\n call term_readline\n"
        body += """ mov r12,rax
 call term_restore
 mov eax,1
 mov edi,1
 lea rsi,[rip+result]
 mov edx,8
 syscall
"""
        if approve:
            body += """ mov byte ptr [rip+buffer],'0'
 add byte ptr [rip+buffer],r12b
 mov edx,1
 lea rsi,[rip+buffer]
"""
        else:
            body += """ lea rsi,[rip+buffer]
 mov rdx,r12
 test r12,r12
 jns .Lresult_write
 lea rsi,[rip+eof]
 mov edx,3
 cmp r12,-1
 je .Lresult_write
 lea rsi,[rip+cancel]
 mov edx,6
 cmp r12,-2
 je .Lresult_write
 lea rsi,[rip+error]
 mov edx,5
.Lresult_write:
"""
        body += """ mov eax,1
 mov edi,1
 syscall
"""
        return self.witness(body, 'ready: .ascii "READY"\nresult: .ascii "\\nRESULT:"\neof: .ascii "EOF"\ncancel: .ascii "CANCEL"\nerror: .ascii "ERROR"\nquestion: .asciz "Run this exact action?"\n', f"buffer: .skip {max(capacity, 16)}\n")

    def exercise_pty(self, executable, data):
        master, slave = pty.openpty()
        original = termios.tcgetattr(slave)
        child = subprocess.Popen([str(executable)], stdin=slave, stdout=slave, stderr=slave)
        output = bytearray()
        try:
            deadline = time.monotonic() + 3
            while b"READY" not in output:
                self.assertLess(time.monotonic(), deadline, "TTY witness never became ready")
                if select.select([master], [], [], .1)[0]:
                    output.extend(os.read(master, 65536))
            raw = termios.tcgetattr(slave)
            self.assertEqual(raw[3] & (termios.ECHO | termios.ICANON | termios.ISIG), 0)
            os.write(master, data)
            while child.poll() is None:
                self.assertLess(time.monotonic(), deadline, "TTY witness did not complete")
                if select.select([master], [], [], .05)[0]:
                    output.extend(os.read(master, 65536))
            while select.select([master], [], [], 0)[0]:
                try:
                    output.extend(os.read(master, 65536))
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
            self.assertEqual(child.returncode, 0)
            self.assertEqual(termios.tcgetattr(slave), original, "terminal mode was not restored")
            return bytes(output)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
            os.close(master)
            os.close(slave)

    def test_plain_fallback_and_utf8_output(self):
        text = "Plain café · 世界\n".encode()
        out = subprocess.check_output([str(self.writer([text]))], input=b"")
        self.assertEqual(out, text)

    def test_csi_osc_clipboard_and_control_bytes_are_stripped(self):
        chunks = [b"one\x1b[2Jtwo\x1b]52;c;secret\x07three\x00\x03\x7f\tfour\n"]
        out = subprocess.check_output([str(self.writer(chunks))], input=b"")
        self.assertEqual(out, b"onetwothree\tfour\n")

    def test_escape_state_survives_stream_chunk_boundaries(self):
        chunks = [b"a\x1b", b"[3", b"1mb\x1b]52;", b"c;never", b"\x1b", b"\\c"]
        out = subprocess.check_output([str(self.writer(chunks))], input=b"")
        self.assertEqual(out, b"abc")

    def test_other_terminal_string_commands_are_stripped(self):
        out = subprocess.check_output([str(self.writer([b"a\x1bPdata\x1b\\b\x1b_ignored\x1b\\c"]))], input=b"")
        self.assertEqual(out, b"abc")

    def test_large_output_drains_all_buffer_flushes(self):
        text = ("λ漢字 packet\n" * 10000).encode()
        out = subprocess.check_output([str(self.writer([text]))], input=b"")
        self.assertEqual(out, text)

    def test_raw_tty_editing_restores_original_mode(self):
        out = self.exercise_pty(self.reader(), b"hello worlx\x7fd\r")
        self.assertIn(b"RESULT:hello world", out)

    def test_backspace_removes_an_entire_utf8_codepoint(self):
        out = self.exercise_pty(self.reader(), "a界".encode() + b"\x7fz\r")
        self.assertIn(b"RESULT:az", out)

    def test_four_byte_unicode_backspace(self):
        out = self.exercise_pty(self.reader(), "hello😀".encode() + b"\x7f!\r")
        self.assertIn(b"RESULT:hello!", out)

    def test_ctrl_c_cancels_without_signal_termination(self):
        out = self.exercise_pty(self.reader(), b"discard this\x03")
        self.assertIn(b"RESULT:CANCEL", out)

    def test_ctrl_d_reports_eof_when_empty(self):
        out = self.exercise_pty(self.reader(), b"\x04")
        self.assertIn(b"RESULT:EOF", out)

    def test_arrows_are_not_inserted_and_alt_enter_adds_line(self):
        out = self.exercise_pty(self.reader(), b"a\x1b[Db\x1b\rc\r")
        self.assertIn(b"RESULT:ab\r\nc", out)

    def test_input_capacity_preserves_utf8_boundaries(self):
        out = self.exercise_pty(self.reader(capacity=3), "界a".encode() + b"\r")
        self.assertIn(b"RESULT:a", out)

    def test_approval_defaults_to_no_and_only_single_y_allows(self):
        for answer, expected in [(b"\r", b"0"), (b"n\r", b"0"), (b"yes\r", b"0"), (b"y\r", b"1"), (b"Y\r", b"1")]:
            with self.subTest(answer=answer):
                out = self.exercise_pty(self.reader(approve=True), answer)
                self.assertIn(b"RESULT:" + expected, out)

    def test_unicode_c1_controls_are_removed_across_chunk_boundaries(self):
        chunks = [b"a\xc2", b"\x9b2J", b"\xc2", b"\x85", b"b\xc2", b"\xa9c"]
        out = subprocess.check_output([str(self.writer(chunks))], input=b"")
        self.assertEqual(out, "a2Jb©c".encode())
        all_controls = "before" + "".join(chr(value) for value in range(0x80, 0xA0)) + "after"
        out = subprocess.check_output([str(self.writer([all_controls.encode()]))], input=b"")
        self.assertEqual(out, b"beforeafter")

    def test_valid_utf8_continuations_and_copyright_are_preserved(self):
        chunks = [b"\xe4", b"\xb8", b"\x96", b"\xf0\x9f", b"\x98", b"\x80", b"\xc2", b"\xa9"]
        out = subprocess.check_output([str(self.writer(chunks))], input=b"")
        self.assertEqual(out, "世😀©".encode())
        latin = "".join(chr(value) for value in range(0xA0, 0x100)).encode()
        self.assertEqual(subprocess.check_output([str(self.writer([latin]))], input=b""), latin)

    def test_stray_c1_bytes_are_omitted_without_mangling_valid_utf8(self):
        chunks = [b"left\x80\x85\x9b\x9fright", " 漢字".encode()]
        self.assertEqual(subprocess.check_output([str(self.writer(chunks))], input=b""), "leftright 漢字".encode())

    def test_delayed_c2_pair_at_output_buffer_boundary(self):
        text = b"x" * 4095 + "©z".encode()
        self.assertEqual(subprocess.check_output([str(self.writer([text]))], input=b""), text)

    def test_explicit_boundary_clears_unterminated_osc_before_approval(self):
        bad, prompt = b"safe\x1b]52;c;unfinished", b"Allow action? [y/N]"
        body = f""" call term_init
 lea rdi,[rip+bad]
 mov esi,{len(bad)}
 call term_write
 call term_reset_filter
 lea rdi,[rip+prompt]
 mov esi,{len(prompt)}
 call term_write
 call term_restore
"""
        executable = self.witness(body, "bad:\n" + literal(bad) + "prompt:\n" + literal(prompt))
        self.assertEqual(subprocess.check_output([str(executable)], input=b""), b"safeAllow action? [y/N]")

    def test_status_and_banner_boundaries_cannot_be_hidden_by_untrusted_fields(self):
        bad = b"visible\x1b]52;c;unfinished"
        model = b"model\x1b]52;c;unfinished\0"
        cwd = b"/safe/workspace\0"
        status = b"Approval remains visible\x1b]unfinished\0"
        tail = b"TRUSTED TAIL"
        body = f""" call term_init
 lea rdi,[rip+bad]
 mov esi,{len(bad)}
 call term_write
 lea rdi,[rip+status]
 call term_status
 lea rdi,[rip+model]
 lea rsi,[rip+cwd]
 call term_banner
 lea rdi,[rip+tail]
 mov esi,{len(tail)}
 call term_write
 call term_restore
"""
        data = "bad:\n" + literal(bad) + "status:\n" + literal(status) + "model:\n" + literal(model) + "cwd:\n" + literal(cwd) + "tail:\n" + literal(tail)
        out = subprocess.check_output([str(self.witness(body, data))], input=b"")
        self.assertIn(b"Approval remains visible", out)
        self.assertIn(b"Model: model", out)
        self.assertIn(b"/safe/workspace", out)
        self.assertTrue(out.endswith(tail))

    def test_stdout_epipe_returns_instead_of_sigpipe_termination(self):
        executable = self.witness(""" call term_init
 lea rdi,[rip+message]
 mov esi,5
 call term_write
 cmp rax,-32
 je .Lgood
 mov eax,60
 mov edi,99
 syscall
.Lgood:
 call term_restore
""", 'message: .ascii "hello"\n')
        read_fd, write_fd = os.pipe()
        os.close(read_fd)
        try:
            result = subprocess.run([str(executable)], stdin=subprocess.DEVNULL, stdout=write_fd)
            self.assertEqual(result.returncode, 0)
        finally:
            os.close(write_fd)


if __name__ == "__main__":
    unittest.main()
