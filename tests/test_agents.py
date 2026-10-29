"""Native forked-agent manager tested with a syscall-only assembly worker.
The fixture worker is assembly too: Python never runs inside forked workers.
"""
import ctypes
import json
import os
import select
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKER = r'''
.intel_syntax noprefix
.section .rodata
meta: .ascii "@session:/tmp/native-agent-session.json\n"
.equ meta_len,.-meta
meta_follow: .ascii "@session:/tmp/native-agent-followup.json\n"
.equ meta_follow_len,.-meta_follow
bad_meta: .ascii "not trusted metadata\n"
.equ bad_meta_len,.-bad_meta
no_meta: .ascii "@session:\n"
.equ no_meta_len,.-no_meta
disabled_meta: .ascii "@session:disabled\n"
.equ disabled_meta_len,.-disabled_meta
report: .ascii "native report\n"
.equ report_len,.-report
resumed: .ascii "resumed native conversation\n"
.equ resumed_len,.-resumed
private_good: .ascii "private state=0\n"
.equ private_good_len,.-private_good
private_bad: .ascii "SHARED STATE ERROR\n"
.equ private_bad_len,.-private_bad
nested_name: .asciz "spawn_agent"
nested_args: .ascii "{\"name\":\"nested\",\"prompt\":\"fast\"}"
.equ nested_args_len,.-nested_args
pause_one: .quad 1,0
pause_long: .quad 20,0
.section .bss
scratch: .skip 8
huge: .skip 8192
nested_output: .skip 4096
.section .text
.global agents_test_worker
agents_test_worker:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 cmp BYTE PTR [r12],98
 je .Lbad
 cmp BYTE PTR [r12],110
 je .Lnosave
 cmp BYTE PTR [r12],100
 je .Ldisabled
 test r13,r13
 jnz .Lfollow_meta
 lea rsi,[rip+meta]
 mov edx,OFFSET FLAT:meta_len
 jmp .Lmeta
.Lfollow_meta:
 lea rsi,[rip+meta_follow]
 mov edx,OFFSET FLAT:meta_follow_len
 jmp .Lmeta
.Lnosave:
 lea rsi,[rip+no_meta]
 mov edx,OFFSET FLAT:no_meta_len
 jmp .Lmeta
.Ldisabled:
 lea rsi,[rip+disabled_meta]
 mov edx,OFFSET FLAT:disabled_meta_len
 jmp .Lmeta
.Lbad:
 lea rsi,[rip+bad_meta]
 mov edx,OFFSET FLAT:bad_meta_len
.Lmeta:
 mov edi,1
 mov eax,1
 syscall
 cmp BYTE PTR [r12],115
 je .Lslow
 cmp BYTE PTR [r12],108
 je .Llong
 cmp BYTE PTR [r12],104
 je .Lhuge
 cmp BYTE PTR [r12],112
 je .Lprivate
 cmp BYTE PTR [r12],114
 je .Lrecursive
 cmp BYTE PTR [r12],99
 je .Lclose
 jmp .Lreport
.Lslow:
 lea rdi,[rip+pause_one]
 xor esi,esi
 mov eax,35
 syscall
 jmp .Lreport
.Llong:
 lea rdi,[rip+pause_long]
 xor esi,esi
 mov eax,35
 syscall
 jmp .Lreport
.Lclose:
 call agents_close@PLT
 jmp .Lreport
.Lrecursive:
 lea rdi,[rip+nested_name]
 lea rsi,[rip+nested_args]
 mov edx,OFFSET FLAT:nested_args_len
 lea rcx,[rip+nested_output]
 mov r8d,4096
 call agents_execute@PLT
 mov rdx,rax
 lea rsi,[rip+nested_output]
 mov edi,1
 mov eax,1
 syscall
 jmp .Lexit
.Lprivate:
 lea rsi,[rip+private_good]
 mov edx,OFFSET FLAT:private_good_len
 cmp QWORD PTR [rip+scratch],0
 je .Lprivate_store
 lea rsi,[rip+private_bad]
 mov edx,OFFSET FLAT:private_bad_len
.Lprivate_store:
 mov QWORD PTR [rip+scratch],1
 mov edi,1
 mov eax,1
 syscall
 jmp .Lexit
.Lhuge:
 lea rdi,[rip+huge]
 mov ecx,8192
 mov al,120
 rep stosb
 mov r14d,12
.Lhuge_write:
 mov edi,1
 lea rsi,[rip+huge]
 mov edx,8192
 mov eax,1
 syscall
 dec r14d
 jnz .Lhuge_write
 jmp .Lexit
.Lreport:
 lea rsi,[rip+report]
 mov edx,OFFSET FLAT:report_len
 test r13,r13
 jz .Lreport_write
 lea rsi,[rip+resumed]
 mov edx,OFFSET FLAT:resumed_len
.Lreport_write:
 mov edi,1
 mov eax,1
 syscall
.Lexit:
 xor edi,edi
 mov eax,60
 syscall
.section .note.GNU-stack,"",@progbits
'''


class AgentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="qwen-x86-agents-")
        build = Path(cls.build.name)
        for name in ("agents", "json", "runtime"):
            subprocess.run(["as", "--64", "-I", str(ROOT / "src"), "-o", str(build / (name + ".o")), str(ROOT / "src" / (name + ".s"))], check=True)
        fixture = build / "worker.s"
        fixture.write_text(WORKER)
        subprocess.run(["as", "--64", "-o", str(build / "worker.o"), str(fixture)], check=True)
        subprocess.run(["ld", "-shared", "-Bsymbolic", "-o", str(build / "agents.so"), *[str(build / (name + ".o")) for name in ("agents", "json", "runtime", "worker")]], check=True)
        cls.lib = ctypes.CDLL(str(build / "agents.so"))
        cls.lib.agents_init.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        cls.lib.agents_init.restype = ctypes.c_long
        cls.lib.agents_handles.argtypes = [ctypes.c_char_p]
        cls.lib.agents_handles.restype = ctypes.c_long
        cls.lib.agents_execute.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
        cls.lib.agents_execute.restype = ctypes.c_long
        cls.worker = ctypes.cast(cls.lib.agents_test_worker, ctypes.c_void_p)
        leader = build / "leader.s"
        leader.write_text(r'''
.intel_syntax noprefix
.section .rodata
name: .asciz "spawn_agent"
args: .ascii "{\"name\":\"worker\",\"prompt\":\"long\"}"
.equ args_len,.-args
newline: .ascii "\n"
.section .bss
output: .skip 65537
.section .text
.global _start
_start:
 lea rdi,[rip+agents_test_worker]
 mov esi,1
 call agents_init
 lea rdi,[rip+name]
 lea rsi,[rip+args]
 mov edx,OFFSET FLAT:args_len
 lea rcx,[rip+output]
 mov r8d,65537
 call agents_execute
 mov rdx,rax
 mov edi,1
 lea rsi,[rip+output]
 mov eax,1
 syscall
 mov edi,1
 lea rsi,[rip+newline]
 mov edx,1
 mov eax,1
 syscall
.Lpause:
 mov eax,34
 syscall
 jmp .Lpause
.section .note.GNU-stack,"",@progbits
''')
        subprocess.run(["as", "--64", "-o", str(build / "leader.o"), str(leader)], check=True)
        cls.leader = build / "parent-death-test"
        subprocess.run(["ld", "-static", "-z", "noexecstack", "-o", str(cls.leader), *[str(build / (name + ".o")) for name in ("leader", "agents", "json", "runtime", "worker")]], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.lib.agents_close()
        cls.build.cleanup()

    def setUp(self):
        self.lib.agents_close()
        self.assertEqual(self.lib.agents_init(self.worker, 2), 0)

    def tearDown(self):
        self.lib.agents_close()

    def call(self, name, args, raw=False):
        body = json.dumps(args).encode()
        out = ctypes.create_string_buffer(65537)
        n = self.lib.agents_execute(name.encode(), body, len(body), out, len(out))
        self.assertGreaterEqual(n, 0)
        text = out.raw[:n].decode()
        return text if raw else json.loads(text)

    def spawn(self, prompt="fast", name="reader"):
        return self.call("spawn_agent", {"name": name, "prompt": prompt})

    def wait(self, job, seconds=3):
        return self.call("wait_agent", {"id": job["id"], "timeout_seconds": seconds})

    def test_native_parallel_workers_overlap_and_limit(self):
        start = time.monotonic()
        first = self.spawn("slow", "one")
        second = self.spawn("slow", "two")
        self.assertNotEqual(first["pid"], second["pid"])
        self.assertNotEqual(first["pid"], os.getpid())
        self.assertIn("limit", self.call("spawn_agent", {"name": "third", "prompt": "slow"}, raw=True))
        a, b = self.wait(first), self.wait(second)
        self.assertLess(time.monotonic() - start, 1.8)
        self.assertEqual((a["status"], b["status"]), ("completed", "completed"))
        self.assertEqual(a["report"], "native report\n")
        self.assertEqual(a["session"], "/tmp/native-agent-session.json")

    def test_private_state_and_child_close_cannot_cancel_parent_jobs(self):
        first, second = self.spawn("private", "one"), self.spawn("private", "two")
        self.assertEqual(self.wait(first)["report"], "private state=0\n")
        self.assertEqual(self.wait(second)["report"], "private state=0\n")
        slow = self.spawn("slow", "survivor")
        closer = self.spawn("close", "closer")
        self.assertEqual(self.wait(closer)["status"], "completed")
        self.assertEqual(self.wait(slow)["status"], "completed")

    def test_followup_uses_saved_session_and_new_metadata(self):
        first = self.spawn()
        complete = self.wait(first)
        response = self.call("send_agent_message", {"id": first["id"], "message": "followup"})
        self.assertEqual(response["id"], first["id"])
        self.assertNotEqual(response["pid"], complete["pid"])
        complete = self.wait(first)
        self.assertEqual(complete["report"], "resumed native conversation\n")
        self.assertEqual(complete["session"], "/tmp/native-agent-followup.json")

    def test_running_followup_rejected_and_wait_timeout_does_not_kill(self):
        first = self.spawn("long")
        self.assertIn("still running", self.call("send_agent_message", {"id": first["id"], "message": "later"}, raw=True))
        start = time.monotonic()
        status = self.wait(first, 1)
        self.assertGreaterEqual(time.monotonic() - start, 0.9)
        self.assertEqual(status["status"], "running")
        cancelled = self.call("cancel_agent", {"id": first["id"]})
        self.assertEqual(cancelled["status"], "cancelled")
        with self.assertRaises(ChildProcessError):
            os.waitpid(first["pid"], os.WNOHANG)

    def test_large_report_drained_and_explicitly_truncated(self):
        first = self.spawn("huge")
        complete = self.wait(first)
        self.assertEqual(complete["status"], "completed")
        self.assertTrue(complete["report_truncated"])
        self.assertGreater(len(complete["report"]), 1000)
        self.assertLessEqual(len(complete["report"]), 65536)

    def test_readonly_mode_recursive_guard_and_bad_metadata(self):
        self.assertIn("read-only", self.call("spawn_agent", {"name": "writer", "prompt": "fast", "mode": "write"}, raw=True))
        recursive = self.spawn("recursive")
        complete = self.wait(recursive)
        self.assertEqual(complete["status"], "completed")
        self.assertIn("recursive delegation is disabled", complete["report"])
        bad = self.spawn("bad")
        complete = self.wait(bad)
        self.assertEqual(complete["status"], "failed")
        self.assertEqual(complete["session"], "")
        self.assertIn("no saved session", self.call("send_agent_message", {"id": bad["id"], "message": "follow"}, raw=True))

    def test_list_close_reap_and_no_fd_leaks(self):
        before = len(os.listdir("/proc/self/fd"))
        first = self.spawn("long", "one")
        second = self.spawn("long", "two")
        rows = self.call("list_agents", {})
        self.assertEqual({row["id"] for row in rows}, {first["id"], second["id"]})
        self.lib.agents_close()
        for job in (first, second):
            with self.assertRaises(ChildProcessError):
                os.waitpid(job["pid"], os.WNOHANG)
        self.assertEqual(len(os.listdir("/proc/self/fd")), before)
        self.assertIn("closed", self.call("list_agents", {}, raw=True))

    def test_completed_slot_reuse_monotonic_ids_and_handles(self):
        ids = []
        for i in range(12):
            job = self.spawn(name=f"reader-{i}")
            ids.append(job["id"])
            self.assertEqual(self.wait(job)["status"], "completed")
        self.assertEqual(ids, sorted(set(ids)))
        retained = self.call("list_agents", {})
        self.assertEqual({job["id"] for job in retained}, set(ids[-8:]))
        self.assertEqual(self.lib.agents_handles(b"spawn_agent"), 1)
        self.assertEqual(self.lib.agents_handles(b"read_file"), 0)


    def test_stateless_reports_are_valid_but_cannot_resume(self):
        for prompt in ("nosave", "disabled"):
            job = self.spawn(prompt)
            result = self.wait(job)
            self.assertEqual(result["status"], "completed")
            self.assertEqual(result["session"], "")
            self.assertEqual(result["report"], "native report\n")
            self.assertIn("no saved session", self.call("send_agent_message", {"id": job["id"], "message": "followup"}, raw=True))

    def test_invalid_wait_timeouts_rejected(self):
        job = self.spawn("long")
        for timeout in (0, -1, 121, "1", 1.5):
            self.assertIn("Error:", self.call("wait_agent", {"id": job["id"], "timeout_seconds": timeout}, raw=True))

    def test_worker_dies_if_native_parent_is_killed(self):
        parent = subprocess.Popen([str(self.leader)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        child_pid = None
        try:
            ready, _, _ = select.select([parent.stdout], [], [], 3)
            self.assertTrue(ready, "native leader did not spawn worker")
            job = json.loads(parent.stdout.readline())
            child_pid = job["pid"]
            parent.kill()
            parent.wait(timeout=3)
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                status = Path(f"/proc/{child_pid}/status")
                try:
                    text = status.read_text()
                except (FileNotFoundError, ProcessLookupError):
                    return  # /proc can disappear while the kernel serves a read.
                if "State:\tZ" in text:
                    return  # Kernel killed worker; its new parent owns reaping.
                time.sleep(0.01)
            self.fail("worker survived its parent")
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait()
            if child_pid:
                try:
                    os.kill(child_pid, 9)
                except ProcessLookupError:
                    pass
            if parent.stdout:
                parent.stdout.close()
            if parent.stderr:
                parent.stderr.close()



if __name__ == "__main__":
    unittest.main()
