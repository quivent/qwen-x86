"""Production static ELF -> native DNS/TLS/HTTP/SSE/tools/session proof.

Python/OpenSSL provide only the local test SERVER and certificate fixtures.
The client is the actual Makefile-built assembly binary, with no TLS stub.
MemoryBIO keeps raw client wire bytes and decrypted application bytes separate,
so rejection tests can prove no HTTP request or credential reached the server.
"""
import json
import os
from pathlib import Path
import resource
import socket
import ssl
import subprocess
import tempfile
import threading
import unittest

from test_cli import answer, tool_events
from test_tls import make_certificates

ROOT = Path(__file__).resolve().parents[1]
FAKE_KEY = "fake-native-https-test-key-only-314159"


def disable_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


class HTTPSModelServer:
    def __init__(self, certificate, key, handlers, *, rejection_expected=False, hostname="localhost"):
        self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.context.minimum_version = ssl.TLSVersion.TLSv1_3
        self.context.maximum_version = ssl.TLSVersion.TLSv1_3
        self.context.load_cert_chain(str(certificate), str(key))
        self.handlers = handlers
        self.rejection_expected = rejection_expected
        self.requests = []
        self.headers = []
        self.targets = []
        self.protocols = []
        self.raw_client_wire = []
        self.application_bytes = []
        self.errors = []
        self.listener = socket.socket()
        self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(8)
        self.listener.settimeout(8)
        self.url = f"https://{hostname}:{self.listener.getsockname()[1]}/v1"
        self.thread = threading.Thread(target=self.serve, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def serve_one(self, connection, handler):
        incoming, outgoing = ssl.MemoryBIO(), ssl.MemoryBIO()
        transport = self.context.wrap_bio(incoming, outgoing, server_side=True)
        wire, plaintext = bytearray(), bytearray()
        self.raw_client_wire.append(wire)
        self.application_bytes.append(plaintext)

        def flush():
            while outgoing.pending:
                connection.sendall(outgoing.read())

        def acquire():
            block = connection.recv(16384)
            if not block:
                incoming.write_eof()
                return False
            wire.extend(block)
            incoming.write(block)
            return True

        # Handshake produces no application reads. A rejected certificate must
        # terminate here, before the model handler or HTTP parser can run.
        while True:
            try:
                transport.do_handshake()
                flush()
                self.protocols.append(transport.version())
                break
            except ssl.SSLWantReadError:
                flush()
                if not acquire():
                    if self.rejection_expected:
                        return
                    raise RuntimeError("native client closed during TLS handshake")
            except ssl.SSLWantWriteError:
                flush()
            except (ssl.SSLError, ConnectionResetError, BrokenPipeError):
                if self.rejection_expected:
                    return
                raise

        def read_plain():
            while True:
                try:
                    block = transport.read(16384)
                    plaintext.extend(block)
                    return block
                except ssl.SSLWantReadError:
                    flush()
                    if not acquire():
                        return b""
                except ssl.SSLWantWriteError:
                    flush()
                except ssl.SSLZeroReturnError:
                    return b""

        raw = bytearray()
        while b"\r\n\r\n" not in raw:
            block = read_plain()
            if not block:
                if self.rejection_expected:
                    return
                raise RuntimeError("native client closed before HTTP headers")
            raw.extend(block)
            if len(raw) > 2 * 1024 * 1024:
                raise RuntimeError("HTTP fixture request exceeded bound")
        header, body = bytes(raw).split(b"\r\n\r\n", 1)
        lines = header.split(b"\r\n")
        self.targets.append(lines[0])
        parsed_headers = {}
        for line in lines[1:]:
            key, separator, value = line.partition(b":")
            if not separator:
                raise RuntimeError("malformed HTTP fixture header")
            parsed_headers[key.lower()] = value.strip()
        self.headers.append(parsed_headers)
        length = int(parsed_headers[b"content-length"])
        if length > 2 * 1024 * 1024:
            raise RuntimeError("HTTP fixture request exceeded bound")
        while len(body) < length:
            block = read_plain()
            if not block:
                raise RuntimeError("native client closed before HTTP body")
            body += block
        request = json.loads(body[:length])
        self.requests.append(request)
        if self.rejection_expected:
            raise AssertionError("client sent an HTTP payload after certificate rejection")
        payload = handler(request)
        response = bytearray(b"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n")
        # Chunk boundaries split SSE delimiters and escaped tool argument JSON.
        for offset in range(0, len(payload), 11):
            chunk = payload[offset:offset + 11]
            response.extend(f"{len(chunk):x};test=native\r\n".encode() + chunk + b"\r\n")
        response.extend(b"0\r\nX-Fixture: native-tls\r\n\r\n")
        pending = bytes(response)
        while pending:
            try:
                consumed = transport.write(pending)
                pending = pending[consumed:]
                flush()
            except ssl.SSLWantWriteError:
                flush()
            except ssl.SSLWantReadError:
                flush()
                if not acquire():
                    raise RuntimeError("client closed during HTTPS response")
        # Send an authenticated close_notify; the client may already have
        # consumed [DONE] and closed its half, so no peer alert is required here.
        try:
            transport.unwrap()
        except (ssl.SSLWantReadError, ssl.SSLError):
            pass
        try:
            flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def serve(self):
        try:
            for handler in self.handlers:
                connection, _ = self.listener.accept()
                with connection:
                    connection.settimeout(8)
                    self.serve_one(connection, handler)
        except Exception as error:
            if not (self.rejection_expected and isinstance(error, (ssl.SSLError, ConnectionResetError, BrokenPipeError))):
                self.errors.append(error)
        finally:
            self.listener.close()

    def __exit__(self, *_):
        self.thread.join(10)
        if self.thread.is_alive():
            self.listener.close()
            raise AssertionError("production HTTPS CLI fixture hung")
        if self.errors:
            raise AssertionError(self.errors)


class HTTPSProductionCLITest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Build and execute the actual product, not a custom link with test TLS.
        subprocess.run(["make", "-j2"], cwd=ROOT, check=True, capture_output=True)
        cls.binary = ROOT / "qwen-x86"
        cls.certificates = tempfile.TemporaryDirectory(prefix="qwen-x86-https-certs-")
        cls.ca, cls.certificate, cls.key = make_certificates(cls.certificates.name)
        alternate = Path(cls.certificates.name) / "untrusted"
        alternate.mkdir()
        cls.untrusted_ca, _, _ = make_certificates(alternate)

    @classmethod
    def tearDownClass(cls):
        cls.certificates.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="qwen-x86-https-work-")
        self.base = Path(self.temporary.name)
        self.workspace, self.home = self.base / "workspace", self.base / "home"
        self.workspace.mkdir()
        self.home.mkdir()
        self.env = dict(os.environ)
        for key in ["QWEN_API_KEY", "OPENAI_API_KEY", "QWEN_BASE_URL", "OPENAI_BASE_URL", "QWEN_MODEL", "OPENAI_MODEL"]:
            self.env.pop(key, None)
        self.env.update(HOME=str(self.home), QWEN_API_KEY=FAKE_KEY)

    def tearDown(self):
        self.temporary.cleanup()

    def run_cli(self, url, ca, *args):
        return subprocess.run([str(self.binary), "--cwd", str(self.workspace), "--base-url", url, "--ca-file", str(ca), *args],
            env=self.env, cwd=ROOT, capture_output=True, timeout=15, preexec_fn=disable_core)

    def test_actual_static_elf_https_tool_roundtrip_and_saved_session(self):
        calls = [("write_file", {"path": "created.txt", "content": "Native HTTPS λ世界\n"})]
        def first(request):
            self.assertEqual(request["model"], "https-fixture-model")
            self.assertEqual(request["messages"][-1]["content"], "Create a UTF8 file")
            self.assertIn("write_file", [tool["function"]["name"] for tool in request["tools"]])
            return tool_events(calls, fragmented=True)
        def second(request):
            messages = request["messages"]
            self.assertEqual([m["role"] for m in messages], ["system", "user", "assistant", "tool"])
            self.assertEqual(messages[2]["tool_calls"][0]["function"]["name"], "write_file")
            self.assertEqual(messages[3]["tool_call_id"], "call-0")
            self.assertIn("written successfully", messages[3]["content"])
            self.assertEqual((self.workspace / "created.txt").read_text(), "Native HTTPS λ世界\n")
            return answer("Verified HTTPS tool round trip λ世界")
        with HTTPSModelServer(self.certificate, self.key, [first, second]) as server:
            result = self.run_cli(server.url, self.ca, "--model", "https-fixture-model", "--prompt", "Create a UTF8 file", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Verified HTTPS tool round trip λ世界", result.stdout.decode())
        self.assertEqual(len(server.requests), 2)
        self.assertEqual(server.protocols, ["TLSv1.3", "TLSv1.3"])
        self.assertEqual(server.targets, [b"POST /v1/chat/completions HTTP/1.1"] * 2)
        for header in server.headers:
            self.assertEqual(header[b"authorization"], b"Bearer " + FAKE_KEY.encode())
        for wire in server.raw_client_wire:
            self.assertNotIn(FAKE_KEY.encode(), wire)
            self.assertNotIn(b"Authorization:", wire)
            self.assertNotIn(b"POST /v1/chat/completions", wire)
        saved = list(self.home.rglob("session-*.json"))
        self.assertEqual(len(saved), 1)
        messages = json.loads(saved[0].read_text())
        self.assertEqual([m["role"] for m in messages], ["user", "assistant", "tool", "assistant"])
        self.assertEqual(messages[-1]["content"], "Verified HTTPS tool round trip λ世界")
        self.assertEqual(saved[0].stat().st_mode & 0o777, 0o600)
        self.assertNotIn(FAKE_KEY, saved[0].read_text())
        headers = subprocess.check_output(["readelf", "-l", str(self.binary)])
        self.assertNotIn(b"INTERP", headers)
        dynamic = subprocess.check_output(["readelf", "-d", str(self.binary)])
        self.assertNotIn(b"NEEDED", dynamic)

    def assert_rejected_before_http(self, hostname, ca):
        with HTTPSModelServer(self.certificate, self.key, [lambda _: answer("must not run")], rejection_expected=True, hostname=hostname) as server:
            result = self.run_cli(server.url, ca, "--prompt", "Do not send before authentication", "--yes")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(server.requests, [])
        self.assertEqual(server.headers, [])
        self.assertEqual(b"".join(server.application_bytes), b"")
        self.assertGreater(len(server.raw_client_wire), 0)
        for wire in server.raw_client_wire:
            self.assertNotIn(FAKE_KEY.encode(), wire)
            self.assertNotIn(b"Authorization:", wire)
            self.assertNotIn(b"POST /v1/chat/completions", wire)
        self.assertFalse((self.workspace / "created.txt").exists())
        for saved in self.home.rglob("session-*.json"):
            self.assertNotIn(FAKE_KEY, saved.read_text())

    def test_wrong_hostname_sends_no_http_or_api_key(self):
        # Server certificate has DNS SAN localhost, not an IP SAN for127.0.0.1.
        self.assert_rejected_before_http("127.0.0.1", self.ca)

    def test_untrusted_ca_sends_no_http_or_api_key(self):
        self.assert_rejected_before_http("localhost", self.untrusted_ca)


if __name__ == "__main__":
    unittest.main()
