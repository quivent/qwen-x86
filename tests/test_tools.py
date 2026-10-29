"""Exercise the actual syscall-only assembly via a shared-library ABI harness.
Python is a test harness, never a runtime dependency of qwen-x86.
"""
import ctypes
import errno
import json
import os
import pty
import termios
import threading
import tty
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeToolsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="qwen-x86-tools-test-")
        build = Path(cls.build.name)
        for name in ("json", "tools"):
            subprocess.run(["as", "--64", "-I", str(ROOT / "src"), "-o", str(build / (name + ".o")), str(ROOT / "src" / (name + ".s"))], cwd=ROOT, check=True)
        cancel = build / "cancel-fixture.s"
        cancel.write_text(r'''
.intel_syntax noprefix
.section .bss
.Lcancel_seen: .skip 8
.section .text
.global tools_test_cancel,tools_test_cancel_reset,tools_test_cancel_seen
tools_test_cancel_reset:
 mov QWORD PTR [rip+.Lcancel_seen],0
 xor eax,eax
 ret
tools_test_cancel_seen:
 mov rax,QWORD PTR [rip+.Lcancel_seen]
 ret
tools_test_cancel:
 cmp QWORD PTR [rip+.Lcancel_seen],0
 jne .Lcancel_sticky
 sub rsp,24
 mov DWORD PTR [rsp],0
 mov WORD PTR [rsp+4],1
 mov WORD PTR [rsp+6],0
 mov rdi,rsp
 mov esi,1
 xor edx,edx
 mov eax,7
 syscall
 test rax,rax
 jle .Lcancel_none
 test WORD PTR [rsp+6],1
 jz .Lcancel_none
 xor edi,edi
 lea rsi,[rsp+16]
 mov edx,1
 xor eax,eax
 syscall
 cmp rax,1
 jne .Lcancel_none
 cmp BYTE PTR [rsp+16],3
 jne .Lcancel_none
 mov QWORD PTR [rip+.Lcancel_seen],1
 add rsp,24
.Lcancel_sticky:
 mov rax,-125
 ret
.Lcancel_none:
 xor eax,eax
 add rsp,24
 ret
.section .note.GNU-stack,"",@progbits
''')
        subprocess.run(["as", "--64", "-o", str(build / "cancel.o"), str(cancel)], check=True)
        subprocess.run(["ld", "-shared", "-o", str(build / "tools.so"), str(build / "tools.o"), str(build / "json.o"), str(build / "cancel.o")], check=True)
        cls.lib = ctypes.CDLL(str(build / "tools.so"))
        cls.lib.tools_set_workspace.argtypes = [ctypes.c_char_p]
        cls.lib.tools_set_workspace.restype = ctypes.c_long
        cls.lib.tools_set_approval.argtypes = [ctypes.c_void_p, ctypes.c_long]
        cls.lib.tools_set_approval.restype = ctypes.c_long
        cls.lib.tools_set_cancel.argtypes = [ctypes.c_void_p]
        cls.lib.tools_test_cancel_seen.restype = ctypes.c_long
        cls.lib.tool_execute.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
        cls.lib.tool_execute.restype = ctypes.c_long

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory(prefix="qwen-x86-workspace-")
        self.root = Path(self.workspace.name)
        self.assertEqual(self.lib.tools_set_workspace(os.fsencode(self.root)), 0)
        self.lib.tools_set_approval(None, 0)
        self.lib.tools_set_cancel(None)
        self.lib.tools_test_cancel_reset()
        self.callback = None

    def tearDown(self):
        self.lib.tools_set_cancel(None)
        self.lib.tools_set_approval(None, 0)
        self.workspace.cleanup()

    def call(self, name, args, cap=65537):
        raw = json.dumps(args, ensure_ascii=True).encode()
        out = ctypes.create_string_buffer(cap)
        n = self.lib.tool_execute(name.encode(), raw, len(raw), out, cap)
        self.assertGreaterEqual(n, 0)
        self.assertLess(n, cap)
        self.assertEqual(out[n], b"\x00")
        return out.raw[:n].decode("utf-8", errors="replace")

    def allow(self):
        self.lib.tools_set_approval(None, 1)

    def test_closed_output_waits_for_child_exit_and_releases_pidfds(self):
        self.allow()
        before = set(os.listdir("/proc/self/fd"))
        for _ in range(8):
            output = self.call("run_shell", {"command": "exec 1>&- 2>&-; sleep 0.01; exit 7", "timeout_seconds": 1})
            self.assertIn("exited unsuccessfully", output)
        self.assertEqual(set(os.listdir("/proc/self/fd")), before)

    def test_error_status_is_independent_of_file_and_shell_text(self):
        (self.root / "message.txt").write_text("Error: this is ordinary file content")
        self.assertTrue(self.call("read_file", {"path":"message.txt"}).startswith("Error:"))
        self.assertEqual(self.lib.tools_last_error(), 0)
        self.call("read_file", {"path":"missing.txt"})
        self.assertEqual(self.lib.tools_last_error(), 1)
        self.allow()
        self.call("run_shell", {"command":"printf 'Error: ordinary stdout'"})
        self.assertEqual(self.lib.tools_last_error(), 0)
        self.call("run_shell", {"command":"exit 7"})
        self.assertEqual(self.lib.tools_last_error(), 1)
        self.call("read_file", {"path":"message.txt"})
        self.assertEqual(self.lib.tools_last_error(), 0)

    def test_read_unicode_and_limit(self):
        (self.root / "café.txt").write_text("hello\nλ世界\n")
        self.assertEqual(self.call("read_file", {"path": "café.txt"}), "hello\nλ世界\n")
        (self.root / "exact").write_bytes(b"a" * 65536)
        self.assertEqual(len(self.call("read_file", {"path": "exact"})), 65536)
        (self.root / "large").write_bytes(b"a" * 65537)
        self.assertIn("Error:", self.call("read_file", {"path": "large"}))
        self.assertIn("Error:", self.call("read_file", {"path": "."}))

    def test_paths_cannot_escape_or_follow_symlinks(self):
        with tempfile.TemporaryDirectory() as other:
            outside = Path(other)
            (outside / "secret").write_text("private")
            (self.root / "escape").symlink_to(outside, target_is_directory=True)
            (self.root / "link").symlink_to(outside / "secret")
            self.allow()
            for path in ("../secret", str(outside / "secret"), "escape/secret", "link", "escape/new", "a/../../secret", "bad\x00path"):
                with self.subTest(path=path):
                    self.assertIn("Error:", self.call("read_file", {"path": path}))
                    self.assertIn("Error:", self.call("write_file", {"path": path, "content": "bad"}))
            self.assertEqual((outside / "secret").read_text(), "private")

    def test_list_does_not_follow_symlinks(self):
        (self.root / "a").write_text("a")
        (self.root / "sub").mkdir()
        (self.root / "link").symlink_to("/etc")
        result = self.call("list_directory", {})
        self.assertEqual(set(result.splitlines()), {"a", "sub/", "link"})
        self.assertIn("Empty", self.call("list_directory", {"path": "sub"}))
        self.assertIn("Error:", self.call("list_directory", {"path": "link"}))
        self.assertIn("Error:", self.call("list_directory", {"path": None}))

    def test_mutations_deny_without_callback(self):
        (self.root / "a").write_text("original")
        self.assertIn("denied", self.call("write_file", {"path": "a", "content": "bad"}))
        self.assertIn("denied", self.call("edit_file", {"path": "a", "old_string": "original", "new_string": "bad"}))
        self.assertIn("denied", self.call("run_shell", {"command": "touch bad"}))
        self.assertEqual((self.root / "a").read_text(), "original")
        self.assertFalse((self.root / "bad").exists())

    def test_atomic_write_preserves_permissions_and_exact_edit(self):
        self.allow()
        p = self.root / "private"
        p.write_text("one old three")
        p.chmod(0o600)
        self.assertNotIn("Error:", self.call("write_file", {"path": "private", "content": "one old three"}))
        self.assertEqual(p.stat().st_mode & 0o777, 0o600)
        p.chmod(0o666)
        old_umask = os.umask(0o077)
        try:
            self.assertNotIn("Error:", self.call("write_file", {"path": "private", "content": "one old three"}))
        finally:
            os.umask(old_umask)
        self.assertEqual(p.stat().st_mode & 0o777, 0o666)
        self.assertNotIn("Error:", self.call("edit_file", {"path": "private", "old_string": "old", "new_string": "new"}))
        self.assertEqual(p.read_text(), "one new three")
        self.assertNotIn("Error:", self.call("edit_file", {"path": "private", "old_string": "new", "new_string": ""}))
        self.assertEqual(p.read_text(), "one  three")
        p.write_text("old old")
        self.assertIn("multiple", self.call("edit_file", {"path": "private", "old_string": "old", "new_string": "new"}))
        self.assertEqual(p.read_text(), "old old")
        self.assertIn("not found", self.call("edit_file", {"path": "private", "old_string": "absent", "new_string": "new"}))
        self.assertEqual(list(self.root.glob(".qwen-x86-tmp-*")), [])

    def test_missing_content_does_not_implicitly_erase(self):
        self.allow()
        p = self.root / "a"
        p.write_text("keep")
        for tool, args in [("write_file", {"path": "a"}), ("write_file", {"path": "a", "content": None}), ("edit_file", {"path": "a", "old_string": "keep"})]:
            self.assertIn("Error:", self.call(tool, args))
            self.assertEqual(p.read_text(), "keep")

    def test_callback_sees_complete_action_and_concurrent_edit_is_preserved(self):
        p = self.root / "a"
        p.write_text("before")
        prompts = []
        callback_type = ctypes.CFUNCTYPE(ctypes.c_long, ctypes.c_char_p)
        def approve(text):
            prompts.append(text.decode())
            p.write_text("changed concurrently")
            return 1
        self.callback = callback_type(approve)
        self.lib.tools_set_approval(self.callback, 0)
        self.assertIn("Error:", self.call("edit_file", {"path": "a", "old_string": "before", "new_string": "after"}))
        self.assertEqual(p.read_text(), "changed concurrently")
        self.assertIn('"new_string": "after"', prompts[0])

    def test_shell_capture_exit_and_workspace(self):
        self.allow()
        result = self.call("run_shell", {"command": "printf output; printf diagnostic >&2; exit 7"})
        self.assertIn("output", result)
        self.assertIn("diagnostic", result)
        self.assertIn("Error:", result)
        self.assertEqual(self.call("run_shell", {"command": "pwd"}).strip(), str(self.root))
        result = self.call("run_shell", {"command": "head -c 80000 /dev/zero | tr '\\0' x"})
        self.assertIn("truncated", result)
        self.assertLessEqual(len(result), 65536)

    def test_shell_timeout_even_if_child_closes_output(self):
        self.allow()
        for command in ("sleep 10", "exec 1>&- 2>&-; sleep 10"):
            start = time.monotonic()
            result = self.call("run_shell", {"command": command, "timeout_seconds": 1})
            elapsed = time.monotonic() - start
            self.assertIn("timed out", result)
            self.assertGreaterEqual(elapsed, 0.9)
            self.assertLess(elapsed, 3)

    def test_raw_ctrl_c_cancels_shell_and_entire_process_group(self):
        self.allow()
        master, slave = pty.openpty()
        tty.setraw(slave, termios.TCSANOW)
        self.assertFalse(termios.tcgetattr(slave)[3] & termios.ISIG)
        saved_stdin = os.dup(0)
        self.lib.tools_set_cancel(ctypes.cast(self.lib.tools_test_cancel, ctypes.c_void_p))
        sender = threading.Thread(target=lambda: (time.sleep(0.2), os.write(master, b"\x03")))
        try:
            os.dup2(slave, 0)
            sender.start()
            start = time.monotonic()
            result = self.call("run_shell", {"command": "sleep 30 & printf '%s\\n' \"$!\"; wait"})
            elapsed = time.monotonic() - start
            self.assertLess(elapsed, 2)
            self.assertIn("cancelled", result)
            self.assertNotIn("timed out", result)
            self.assertEqual(self.lib.tools_test_cancel_seen(), 1)
            # The callback remains sticky for parent-loop cleanup; it is not
            # cleared by the shell runner after collecting its children.
            self.assertEqual(self.lib.tools_test_cancel(), -125)
            descendant = int(result.splitlines()[0])
            status = Path(f"/proc/{descendant}/status")
            # wait4 reaps our direct shell, while its killed background process
            # may still be scheduling its exit on another CPU. Require the
            # whole-group kill to become observable within a bounded deadline.
            deadline = time.monotonic() + 2
            while True:
                try:
                    text = status.read_text()
                except OSError as error:
                    if error.errno not in (errno.ENOENT, errno.ESRCH):
                        raise
                    text = ""
                if not text or "State:\tZ" in text:
                    break
                if time.monotonic() >= deadline:
                    self.fail(f"Shell descendant {descendant} survived process-group "
                              f"cancellation for 2 seconds:\n{text}")
                time.sleep(0.01)
        finally:
            sender.join(timeout=2)
            os.dup2(saved_stdin, 0)
            os.close(saved_stdin)
            self.lib.tools_set_cancel(None)
            os.close(master)
            os.close(slave)

    def test_invalid_json_and_unknown_tool(self):
        self.assertIn("Error:", self.call("unknown", {}))
        self.assertIn("Error:", self.call("read_file", {"path": None}))
        raw = b'{"path":'
        out = ctypes.create_string_buffer(65537)
        n = self.lib.tool_execute(b"read_file", raw, len(raw), out, len(out))
        self.assertGreater(n, 0)
        self.assertTrue(out.value.startswith(b"Error:"))


if __name__ == "__main__":
    unittest.main()
