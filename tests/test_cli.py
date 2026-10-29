"""End-to-end static assembly ELF tests with native-only test TLS stub.
No test helper executable is part of production: local server/oracles live in
Python, while every application operation is executed by the assembled ELF.
"""
import json
import os
from pathlib import Path
import pty
import resource
import select
import socket
import subprocess
import tempfile
import termios
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


def disable_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def event(delta, finish=None):
    choice = {"index": 0, "delta": delta}
    if finish is not None:
        choice["finish_reason"] = finish
    return b"data: " + json.dumps({"choices": [choice]}, ensure_ascii=True).encode() + b"\n\n"


def answer(text):
    return event({"content": text}, "stop") + b"data: [DONE]\n\n"


def tool_events(calls, finish="tool_calls", done=True, fragmented=False):
    data = b""
    if fragmented:
        # Every string fragment is separately JSON escaped on the wire, then
        # assembled by the native SSE parser before the native tool decoder.
        for index, (name, args) in enumerate(calls):
            raw = json.dumps(args, ensure_ascii=True)
            data += event({"tool_calls": [{"index": index, "id": f"call-{index}", "type": "function", "function": {"name": name, "arguments": raw[:7]}}]})
            for offset in range(7, len(raw), 11):
                data += event({"tool_calls": [{"index": index, "function": {"arguments": raw[offset:offset + 11]}}]})
    else:
        values = [{"index": i, "id": f"call-{i}", "type": "function", "function": {"name": name, "arguments": json.dumps(args)}} for i, (name, args) in enumerate(calls)]
        data += event({"tool_calls": values})
    if finish is not None:
        data += event({}, finish)
    if done:
        data += b"data: [DONE]\n\n"
    return data


class Server:
    def __init__(self, handlers, chunked=False):
        self.handlers = handlers
        self.chunked = chunked
        self.requests = []
        self.targets = []
        self.errors = []
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(4)
        self.listener.settimeout(4)
        self.url = f"http://127.0.0.1:{self.listener.getsockname()[1]}/v1"
        self.thread = threading.Thread(target=self.serve, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def serve(self):
        try:
            for handler in self.handlers:
                connection, _ = self.listener.accept()
                with connection:
                    connection.settimeout(4)
                    raw = b""
                    while b"\r\n\r\n" not in raw:
                        part = connection.recv(8192)
                        if not part:
                            raise RuntimeError("application closed before request headers")
                        raw += part
                    headers, body = raw.split(b"\r\n\r\n", 1)
                    self.targets.append(headers.split(b"\r\n", 1)[0])
                    content_length = next(int(line.partition(b":")[2]) for line in headers.split(b"\r\n") if line.lower().startswith(b"content-length:"))
                    while len(body) < content_length:
                        part = connection.recv(8192)
                        if not part:
                            raise RuntimeError("application closed before request body")
                        body += part
                    request = json.loads(body)
                    self.requests.append(request)
                    payload = handler(request)
                    if self.chunked:
                        wire = b"HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n"
                        for offset in range(0, len(payload), 13):
                            chunk = payload[offset:offset + 13]
                            wire += f"{len(chunk):x};test=yes\r\n".encode() + chunk + b"\r\n"
                        wire += b"0\r\nX-End: yes\r\n\r\n"
                    else:
                        wire = b"HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/event-stream\r\nContent-Length: " + str(len(payload)).encode() + b"\r\n\r\n" + payload
                    try:
                        connection.sendall(wire)
                    except (BrokenPipeError, ConnectionResetError):
                        pass
        except Exception as exc:
            self.errors.append(exc)
        finally:
            self.listener.close()

    def __exit__(self, *_):
        self.thread.join(5)
        if self.thread.is_alive():
            raise AssertionError("native application/model fixture hung")
        if self.errors:
            raise AssertionError(self.errors)


class ConcurrentServer:
    """A model fixture that can serve parent and native workers simultaneously."""
    def __init__(self, handler, keepalive=False):
        self.handler = handler
        self.keepalive = keepalive
        self.records = []
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(16)
        self.listener.settimeout(0.1)
        self.url = f"http://127.0.0.1:{self.listener.getsockname()[1]}/v1"
        self.stop = threading.Event()
        self.errors = []
        self.workers = []
        self.thread = threading.Thread(target=self.serve, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def serve(self):
        while not self.stop.is_set():
            try:
                connection, _ = self.listener.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            worker = threading.Thread(target=self.reply, args=(connection, len(self.workers)), daemon=True)
            self.workers.append(worker)
            worker.start()

    def reply(self, connection, channel):
        try:
            with connection:
                connection.settimeout(4)
                while True:
                    raw = b""
                    while b"\r\n\r\n" not in raw:
                        part = connection.recv(8192)
                        if not part:
                            if raw:
                                raise AssertionError("model client closed during headers")
                            return
                        raw += part
                    headers, body = raw.split(b"\r\n\r\n", 1)
                    length = next(int(line.partition(b":")[2]) for line in headers.split(b"\r\n") if line.lower().startswith(b"content-length:"))
                    while len(body) < length:
                        part = connection.recv(8192)
                        if not part:
                            raise AssertionError("model client closed before JSON body")
                        body += part
                    request = json.loads(body)
                    self.records.append((channel, request))
                    payload = self.handler(request)
                    status = 200
                    if isinstance(payload, tuple):
                        status, payload = payload
                    mode = b"keep-alive" if self.keepalive else b"close"
                    content_type = b"text/event-stream" if status == 200 else b"application/json"
                    connection.sendall(b"HTTP/1.1 " + str(status).encode() + b" Fixture\r\nConnection: " + mode + b"\r\nContent-Type: " + content_type + b"\r\nContent-Length: " + str(len(payload)).encode() + b"\r\n\r\n" + payload)
                    if not self.keepalive:
                        return
        except Exception as exc:
            self.errors.append(exc)

    def __exit__(self, *_):
        self.stop.set()
        self.listener.close()
        self.thread.join(2)
        for worker in self.workers:
            worker.join(5)
        if self.errors:
            raise AssertionError(self.errors)
        if any(worker.is_alive() for worker in self.workers):
            raise AssertionError("delegated model fixture hung")


class CLITest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="qwen-x86-cli-")
        build = Path(cls.build.name)
        names = ("main", "runtime", "json", "stream", "terminal", "tools", "http", "net", "agents", "plugins", "mcp", "mcp_server", "oauth", "sha256", "ui", "ui_input", "ui_markdown", "ui_mermaid", "ui_sessions", "ui_external_editor", "ui_paths", "ui_tool_preview", "ui_shell", "ui_preferences", "ui_error_response", "ui_help")
        for name in names:
            subprocess.run(["as", "--64", "-I", str(ROOT / "src"), "-o", str(build / (name + ".o")), str(ROOT / "src" / (name + ".s"))], cwd=ROOT, check=True)
        stub = build / "tls-test-stub.s"
        stub.write_text('.intel_syntax noprefix\n.text\n.global tls_connect,tls_read,tls_write,tls_close,tls_error,tls_pending,tls_after_fork\ntls_connect:\ntls_read:\ntls_write:\n mov rax,-95\n ret\ntls_close:\ntls_after_fork:\ntls_pending:\ntls_error:\n xor eax,eax\n ret\n.section .note.GNU-stack,"",@progbits\n')
        subprocess.run(["as", "--64", "-o", str(build / "stub.o"), str(stub)], check=True)
        cls.binary = build / "qwen-x86-test"
        subprocess.run(["ld", "-static", "-z", "noexecstack", "-o", str(cls.binary), *[str(build / (name + ".o")) for name in names], str(build / "stub.o")], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def setUp(self):
        self.storage = tempfile.TemporaryDirectory(prefix="qwen-x86-cli-work-")
        root = Path(self.storage.name)
        self.workspace = root / "workspace"
        self.home = root / "home"
        self.workspace.mkdir()
        self.home.mkdir()
        self.env = dict(os.environ)
        for key in ("QWEN_API_KEY", "OPENAI_API_KEY", "QWEN_BASE_URL", "OPENAI_BASE_URL", "QWEN_MODEL", "OPENAI_MODEL"):
            self.env.pop(key, None)
        self.env.update(HOME=str(self.home), QWEN_API_KEY="dummy-cli-key")

    def tearDown(self):
        self.storage.cleanup()

    def run_cli(self, *args, timeout=8):
        return subprocess.run([str(self.binary), "--cwd", str(self.workspace), *args], cwd=ROOT, env=self.env, capture_output=True, timeout=timeout, preexec_fn=disable_core)

    def test_static_demo_and_help(self):
        result = self.run_cli("--demo", "--no-save", "--prompt", "hello")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"native qwen-x86 assembly client", result.stdout)
        self.assertEqual(list(self.home.rglob("*.json")), [])
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn(b"--resume", result.stdout)
        headers = subprocess.check_output(["readelf", "-l", str(self.binary)])
        self.assertNotIn(b"INTERP", headers)

    def test_all_five_tools_unicode_and_session_resume(self):
        (self.workspace / "seed").write_text("seed evidence")
        calls = [
            ("read_file", {"path": "seed"}),
            ("list_directory", {"path": "."}),
            ("write_file", {"path": "created", "content": "λoriginal\n"}),
            ("edit_file", {"path": "created", "old_string": "original", "new_string": "updated"}),
            ("run_shell", {"command": "printf shell-native", "timeout_seconds": 1}),
        ]
        def first(request):
            self.assertGreaterEqual(len(request["tools"]), 10)
            self.assertTrue({"read_file", "list_directory", "write_file", "edit_file", "run_shell", "spawn_agent", "wait_agent"}.issubset({tool["function"]["name"] for tool in request["tools"]}))
            self.assertEqual(request["model"], "test-model")
            self.assertEqual(request["messages"][-1]["content"], "Make λ世界")
            return tool_events(calls, fragmented=True)
        def second(request):
            messages = request["messages"]
            self.assertEqual([m["role"] for m in messages], ["system", "user", "assistant", "tool", "tool", "tool", "tool", "tool"])
            self.assertEqual(len(messages[2]["tool_calls"]), 5)
            self.assertEqual([m["tool_call_id"] for m in messages[3:]], [f"call-{i}" for i in range(5)])
            self.assertEqual(messages[3]["content"], "seed evidence")
            self.assertIn("seed", messages[4]["content"])
            self.assertIn("written successfully", messages[5]["content"])
            self.assertIn("edited successfully", messages[6]["content"])
            self.assertEqual(messages[7]["content"], "shell-native")
            return answer("Native round trip complete λ世界")
        with Server([first, second], chunked=True) as server:
            result = self.run_cli("--prompt", "Make λ世界", "--model", "test-model", "--base-url", server.url, "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("λ世界", result.stdout.decode())
        self.assertEqual((self.workspace / "created").read_text(), "λupdated\n")
        files = list(self.home.rglob("session-*.json"))
        self.assertEqual(len(files), 1)
        saved = json.loads(files[0].read_text())
        self.assertEqual(len(saved), 8)
        self.assertEqual(saved[-1]["content"], "Native round trip complete λ世界")
        self.assertNotIn("dummy-cli-key", files[0].read_text())
        self.assertEqual(files[0].stat().st_mode & 0o777, 0o600)
        def resumed(request):
            self.assertEqual(len(request["messages"]), 10)
            self.assertEqual(request["messages"][-2]["content"], "Native round trip complete λ世界")
            self.assertEqual(request["messages"][-1]["content"], "continue")
            return answer("resumed")
        with Server([resumed]) as server:
            result = self.run_cli("--prompt", "continue", "--resume", str(files[0]), "--base-url", server.url)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"resumed", result.stdout)

    def test_headless_permission_denial_preserves_files(self):
        (self.workspace / "seed").write_text("keep")
        calls = [("write_file", {"path": "new", "content": "bad"}), ("edit_file", {"path": "seed", "old_string": "keep", "new_string": "bad"}), ("run_shell", {"command": "touch bad"})]
        def second(request):
            tools = [m for m in request["messages"] if m["role"] == "tool"]
            self.assertEqual(len(tools), 3)
            self.assertTrue(all("denied" in m["content"] for m in tools))
            return answer("denied safely")
        with Server([lambda _: tool_events(calls), second]) as server:
            result = self.run_cli("--no-save", "--prompt", "try writes", "--base-url", server.url)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.workspace / "seed").read_text(), "keep")
        self.assertFalse((self.workspace / "new").exists())
        self.assertFalse((self.workspace / "bad").exists())

    def test_malformed_or_truncated_stream_never_executes_tools(self):
        calls = [("write_file", {"path": "bad", "content": "must not happen"})]
        payloads = [
            tool_events(calls, finish=None, done=False),
            tool_events(calls, finish=None, done=False) + b"data: {broken json}\n\n",
            tool_events(calls, finish="length", done=True),
        ]
        for payload in payloads:
            with self.subTest(payload=payload[-80:]):
                with Server([lambda _, data=payload: data]) as server:
                    result = self.run_cli("--no-save", "--yes", "--prompt", "do not execute incomplete", "--base-url", server.url)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertFalse((self.workspace / "bad").exists())

    def test_fully_qualified_endpoint_with_trailing_slash(self):
        with Server([lambda _: answer("ok")]) as server:
            result = self.run_cli("--no-save", "--prompt", "hello", "--base-url", server.url + "/chat/completions/")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(server.targets, [b"POST /v1/chat/completions HTTP/1.1"])

    def delegated_model_roundtrip(self, save=True):
        lock = threading.Lock()
        barrier = threading.Barrier(2)
        parent_round = 0
        first_ids = []
        active_children = 0
        peak_children = 0
        child_requests = []
        def tool_response(calls):
            values = [{"index": i, "id": f"round-{parent_round}-{i}", "type": "function", "function": {"name": name, "arguments": json.dumps(args)}} for i, (name, args) in enumerate(calls)]
            return event({"tool_calls": values}, "tool_calls") + b"data: [DONE]\n\n"
        def handle(request):
            nonlocal parent_round, active_children, peak_children
            messages = request["messages"]
            worker = "read-only subagent" in messages[0]["content"]
            if worker:
                self.assertEqual({tool["function"]["name"] for tool in request["tools"]}, {"read_file", "list_directory"})
                self.assertNotIn("parent-private", json.dumps(messages))
                child_requests.append(messages)
                if len(messages) == 2:
                    self.assertIn(messages[-1]["content"], ("child-one", "child-two"))
                    with lock:
                        active_children += 1
                        peak_children = max(peak_children, active_children)
                    barrier.wait(timeout=3)
                    time.sleep(0.03)
                    with lock:
                        active_children -= 1
                    return answer("native " + messages[-1]["content"])
                self.assertEqual(len(messages), 4)
                self.assertEqual(messages[-1]["content"], "follow-up")
                self.assertEqual(messages[-2]["content"], "native child-one")
                return answer("native followup")
            parent_round += 1
            if parent_round == 1:
                return tool_response([("spawn_agent", {"name": "one", "prompt": "child-one"}), ("spawn_agent", {"name": "two", "prompt": "child-two"})])
            if parent_round == 2:
                results = [json.loads(message["content"]) for message in messages[-2:]]
                first_ids.extend(result["id"] for result in results)
                self.assertEqual(len(set(first_ids)), 2)
                return tool_response([("wait_agent", {"id": identifier, "timeout_seconds": 3}) for identifier in first_ids])
            if parent_round == 3:
                results = [json.loads(message["content"]) for message in messages[-2:]]
                self.assertEqual([result["status"] for result in results], ["completed", "completed"])
                self.assertEqual([result["report"].strip() for result in results], ["native child-one", "native child-two"])
                if not save:
                    self.assertTrue(all(result["session"] == "" for result in results))
                    return answer("Both native workers completed.")
                self.assertTrue(all(Path(result["session"]).is_file() for result in results))
                return tool_response([("send_agent_message", {"id": first_ids[0], "message": "follow-up"})])
            if parent_round == 4:
                return tool_response([("wait_agent", {"id": first_ids[0], "timeout_seconds": 3})])
            if parent_round == 5:
                result = json.loads(messages[-1]["content"])
                self.assertEqual(result["status"], "completed")
                self.assertEqual(result["report"].strip(), "native followup")
                return answer("Both native workers completed.")
            raise AssertionError(f"unexpected parent round {parent_round}")
        with ConcurrentServer(handle, keepalive=True) as server:
            args = ["--prompt", "Delegate parent-private task", "--base-url", server.url]
            if not save:
                args.append("--no-save")
            result = self.run_cli(*args, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"Both native workers completed.", result.stdout)
        self.assertNotIn(b"native child-one", result.stdout)
        self.assertEqual(peak_children, 2, "model requests from delegated processes did not overlap")
        self.assertEqual(len(child_requests), 3 if save else 2)
        parent_channels = {channel for channel, request in server.records if "read-only subagent" not in request["messages"][0]["content"]}
        child_channels = {channel for channel, request in server.records if "read-only subagent" in request["messages"][0]["content"]}
        self.assertEqual(len(parent_channels), 1, "parent model/tool rounds did not reuse their connection")
        self.assertEqual(len(child_channels), 3 if save else 2)
        self.assertTrue(parent_channels.isdisjoint(child_channels), "forked child reused its parent's connection")
        snapshots = list(self.home.rglob("session-*.json"))
        if save:
            self.assertGreaterEqual(len(snapshots), 4)
            for path in snapshots:
                json.loads(path.read_text())
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertNotIn("dummy-cli-key", path.read_text())
        else:
            self.assertEqual(snapshots, [])

    def test_native_parallel_model_calls_followup_and_saved_child_context(self):
        self.delegated_model_roundtrip(save=True)

    def test_native_parallel_stateless_children_do_not_force_hidden_saving(self):
        self.delegated_model_roundtrip(save=False)

    def test_native_child_cannot_write_even_when_parent_uses_yes(self):
        parent_round = 0
        child_round = 0
        identifier = None
        def handle(request):
            nonlocal parent_round, child_round, identifier
            messages = request["messages"]
            if "read-only subagent" in messages[0]["content"]:
                child_round += 1
                self.assertEqual({tool["function"]["name"] for tool in request["tools"]}, {"read_file", "list_directory"})
                if child_round == 1:
                    return tool_events([("write_file", {"path": "forbidden", "content": "bad"})])
                self.assertIn("read-only", messages[-1]["content"])
                return answer("mutation denied")
            parent_round += 1
            if parent_round == 1:
                return tool_events([("spawn_agent", {"name": "restricted", "prompt": "test restriction"})])
            if parent_round == 2:
                identifier = json.loads(messages[-1]["content"])["id"]
                return tool_events([("wait_agent", {"id": identifier, "timeout_seconds": 3})])
            result = json.loads(messages[-1]["content"])
            self.assertEqual(result["status"], "completed")
            self.assertIn("mutation denied", result["report"])
            return answer("read-only boundary preserved")
        with ConcurrentServer(handle) as server:
            result = self.run_cli("--yes", "--no-save", "--prompt", "Delegate", "--base-url", server.url, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.workspace / "forbidden").exists())
        self.assertIn(b"read-only boundary preserved", result.stdout)

    def test_terminal_restored_after_request_failure(self):
        # Pick a closed local port; the failure must return to a functioning
        # prompt and restore the exact termios state on /quit.
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
        listener.close()
        master, slave = pty.openpty()
        before = termios.tcgetattr(slave)
        process = subprocess.Popen([str(self.binary), "--cwd", str(self.workspace), "--no-save", "--base-url", f"http://127.0.0.1:{port}/v1"], stdin=slave, stdout=slave, stderr=slave, env=self.env, cwd=ROOT, preexec_fn=disable_core)
        output = bytearray()
        def read_until(needle, timeout=4):
            end = time.monotonic() + timeout
            while needle not in output and time.monotonic() < end:
                readable, _, _ = select.select([master], [], [], 0.05)
                if readable:
                    try:
                        output.extend(os.read(master, 65536))
                    except OSError:
                        break
            self.assertIn(needle, output, bytes(output))
        try:
            read_until(b"Qwen Code")
            os.write(master, b"ask\r")
            read_until(b"Request failed")
            os.write(master, b"/quit\r")
            process.wait(timeout=4)
            self.assertEqual(process.returncode, 0, bytes(output))
            self.assertEqual(termios.tcgetattr(slave), before)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    unittest.main()
