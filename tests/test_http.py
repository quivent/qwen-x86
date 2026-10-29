"""Native assembly HTTP framing tested against fragmented local TCP replies.
The TLS stub belongs solely to this plaintext test fixture; production links
src/tls.s and has no TLS fallback path.
"""
import ctypes
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
CALLBACK = ctypes.CFUNCTYPE(ctypes.c_long, ctypes.c_void_p, ctypes.c_size_t)


class HTTPTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="qwen-x86-http-")
        build = Path(cls.build.name)
        for name in ("http", "net"):
            subprocess.run(["as", "--64", "-I", str(ROOT / "src"), "-o", str(build / (name + ".o")), str(ROOT / "src" / (name + ".s"))], check=True)
        stub = build / "tls-test-stub.s"
        stub.write_text('.intel_syntax noprefix\n.text\n.global tls_connect,tls_read,tls_write,tls_close,tls_pending,tls_after_fork,test_http_fork_drop\ntls_connect:\ntls_read:\ntls_write:\n mov rax,-95\n ret\ntls_close:\ntls_after_fork:\ntls_pending:\n xor eax,eax\n ret\ntest_http_fork_drop:\n sub rsp,8\n mov eax,57\n syscall\n test rax,rax\n jnz .Lparent\n call http_after_fork@PLT\n xor edi,edi\n mov eax,60\n syscall\n.Lparent:\n add rsp,8\n ret\n.section .note.GNU-stack,"",@progbits\n')
        subprocess.run(["as", "--64", "-o", str(build / "stub.o"), str(stub)], check=True)
        subprocess.run(["ld", "-shared", "-Bsymbolic", "-o", str(build / "http.so"), str(build / "http.o"), str(build / "net.o"), str(build / "stub.o")], check=True)
        cls.lib = ctypes.CDLL(str(build / "http.so"))
        cls.lib.http_request.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t, CALLBACK]
        cls.lib.http_request.restype = ctypes.c_long
        cls.lib.http_status.restype = ctypes.c_long
        cls.lib.http_close.restype = ctypes.c_long
        cls.lib.http_after_fork.restype = ctypes.c_long
        cls.lib.test_http_fork_drop.restype = ctypes.c_long
        cls.lib.http_set_ca.argtypes = [ctypes.c_char_p]
        cls.lib.http_set_ca.restype = ctypes.c_long
        cls.lib.http_set_content_type.argtypes = [ctypes.c_char_p]
        cls.lib.http_set_content_type.restype = ctypes.c_long

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def setUp(self):
        self.lib.http_close()
        self.lib.http_set_content_type(None)
        self.lib.http_set_ca(None)

    def tearDown(self):
        self.lib.http_close()

    def exchange(self, response, *, fragmented=False, key=b"dummy-key", body=b'{"message":"hello"}', path="/chat/completions", host="127.0.0.1", scheme="http", abort=False):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(3)
        port = listener.getsockname()[1]
        requests = []
        failures = []
        def serve():
            try:
                connection, _ = listener.accept()
                with connection:
                    connection.settimeout(3)
                    raw = b""
                    while b"\r\n\r\n" not in raw:
                        part = connection.recv(8192)
                        if not part:
                            requests.append(raw)
                            return
                        raw += part
                    header, payload = raw.split(b"\r\n\r\n", 1)
                    length = 0
                    for line in header.split(b"\r\n")[1:]:
                        name, _, value = line.partition(b":")
                        if name.lower() == b"content-length":
                            length = int(value)
                    while len(payload) < length:
                        part = connection.recv(8192)
                        if not part:
                            break
                        payload += part
                    requests.append(header + b"\r\n\r\n" + payload)
                    try:
                        if fragmented:
                            for byte in response:
                                connection.sendall(bytes([byte]))
                        else:
                            connection.sendall(response)
                        connection.shutdown(socket.SHUT_WR)
                    except (BrokenPipeError, ConnectionResetError, OSError):
                        pass  # Parse rejection and callback abort close early.
            except Exception as exc:
                failures.append(exc)
            finally:
                listener.close()
        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        chunks = []
        seen_status = []
        @CALLBACK
        def callback(ptr, length):
            chunks.append(ctypes.string_at(ptr, length))
            seen_status.append(self.lib.http_status())
            return 1 if abort else 0
        status = self.lib.http_request(f"{scheme}://{host}:{port}{path}".encode(), key, body, len(body), callback)
        thread.join(4)
        self.assertFalse(thread.is_alive(), "server or native request hung")
        self.assertFalse(failures, failures)
        self.assertEqual(len(requests), 1)
        return status, b"".join(chunks), requests[0], seen_status

    def test_content_length_fragmented_and_request_headers(self):
        response = b"HTTP/1.1 200 OK\r\nContent-Length: 11\r\nX-Test: yes\r\n\r\nhello world"
        status, body, request, seen = self.exchange(response, fragmented=True)
        self.assertEqual((status, body), (200, b"hello world"))
        self.assertTrue(all(code == 200 for code in seen))
        self.assertIn(b"POST /chat/completions HTTP/1.1\r\n", request)
        self.assertIn(b"Authorization: Bearer dummy-key\r\n", request)
        self.assertIn(b"Content-Length: 19\r\n", request)
        self.assertTrue(request.endswith(b'{"message":"hello"}'))

    def test_chunked_extensions_trailers_and_case(self):
        response = b"HTTP/1.1 200 OK\r\nTransfer-Encoding: ChUnKeD\r\n\r\n2;foo=bar\r\nhe\r\n3;quoted=\"x\"\r\nllo\r\n0\r\nX-Checksum: done\r\n\r\n"
        status, body, _, _ = self.exchange(response, fragmented=True)
        self.assertEqual((status, body), (200, b"hello"))

    def test_many_chunks_do_not_share_header_budget(self):
        payload = b"x" * 12000
        framed = b"1\r\nx\r\n" * len(payload) + b"0\r\n\r\n"
        status, body, _, _ = self.exchange(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + framed)
        self.assertEqual((status, body), (200, payload))

    def test_close_framed_error_response_and_no_key(self):
        status, body, request, seen = self.exchange(b"HTTP/1.0 401 Unauthorized\r\nX-Info: test\r\n\r\nprovider error", key=b"")
        self.assertEqual((status, body), (401, b"provider error"))
        self.assertNotIn(b"Authorization:", request)
        self.assertTrue(all(code == 401 for code in seen))

    def test_interim_and_empty_response(self):
        status, body, _, _ = self.exchange(b"HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
        self.assertEqual((status, body), (200, b"ok"))
        status, body, _, _ = self.exchange(b"HTTP/1.1 204 No Content\r\n\r\n")
        self.assertEqual((status, body), (204, b""))

    def test_request_target_query_localhost_and_content_type(self):
        self.assertEqual(self.lib.http_set_content_type(b"application/x-www-form-urlencoded"), 0)
        status, body, request, _ = self.exchange(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n", host="LOCALHOST", path="?model=test", key=b"")
        self.assertEqual((status, body), (200, b""))
        self.assertTrue(request.startswith(b"POST /?model=test HTTP/1.1\r\n"))
        self.assertIn(b"Host: localhost:", request)
        self.assertIn(b"Content-Type: application/x-www-form-urlencoded\r\n", request)
        self.assertEqual(self.lib.http_set_content_type(b"application/json\r\nInjected: true"), -22)

    def test_truncated_known_length_or_chunks_fail(self):
        for response in (
            b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nabc",
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabc",
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n",
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabcxx0\r\n\r\n",
        ):
            with self.subTest(response=response):
                self.assertLess(self.exchange(response)[0], 0)

    def test_framing_conflicts_and_bad_status_fail(self):
        headers = (
            b"Content-Length: 1\r\nContent-Length: 1\r\n",
            b"Content-Length: 1\r\nTransfer-Encoding: chunked\r\n",
            b"Content-Length: -1\r\n",
            b"Content-Length: +1\r\n",
            b"Content-Length: 1, 1\r\n",
            b"Transfer-Encoding: gzip, chunked\r\n",
            b"Transfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n",
            b" Bad-Fold: no\r\n",
            b"BrokenHeader\r\n",
            b"X-Bad: a\x00b\r\n",
        )
        for header in headers:
            with self.subTest(header=header):
                self.assertLess(self.exchange(b"HTTP/1.1 200 OK\r\n" + header + b"\r\nx")[0], 0)
        for status in (b"HTTP/2 200 OK", b"HTTP/1.1 20 OK", b"HTTP/1.1 999 Bad", b"HTTP/1.1 200xBad"):
            self.assertLess(self.exchange(status + b"\r\n\r\n")[0], 0)

    def test_limits_and_forbidden_trailers(self):
        for response in (
            b"HTTP/1.1 200 OK\r\nContent-Length: 67108865\r\n\r\n",
            b"HTTP/1.1 200 OK\r\nContent-Length: 9999999999999999999999999\r\n\r\n",
            b"HTTP/1.1 200 OK\r\nX-Huge: " + b"x" * 65536 + b"\r\n\r\n",
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4000001\r\n",
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\nContent-Length: 0\r\n\r\n",
        ):
            self.assertLess(self.exchange(response)[0], 0)

    def test_callback_abort_and_fd_cleanup(self):
        before = len(os.listdir("/proc/self/fd"))
        for _ in range(8):
            status, _, _, _ = self.exchange(b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello", abort=True)
            self.assertEqual(status, -125)
        self.assertEqual(len(os.listdir("/proc/self/fd")), before)

    def test_url_and_key_injection_rejected_without_connection(self):
        @CALLBACK
        def callback(ptr, length):
            self.fail("invalid request delivered a response")
            return 1
        urls = (
            b"http://example.com/test", b"ftp://127.0.0.1/test", b"http://user@127.0.0.1/test",
            b"http://127.0.0.1:0/test", b"http://127.0.0.1:65536/test", b"http://127.0.0.1:/test",
            b"http://127.0.0.1/test\r\nInjected: true", b"http://127.0.0.1/test#fragment",
            b"http://127.0.0.1/" + b"a" * 2049, b"http:///test", b"http://[::1]/test",
        )
        for url in urls:
            with self.subTest(url=url[:80]):
                self.assertEqual(self.lib.http_request(url, b"", b"{}", 2, callback), -22)
        self.assertEqual(self.lib.http_request(b"http://127.0.0.1:1/test", b"key\r\nInjected: true", b"{}", 2, callback), -22)

    def persistent_exchange(self, *, chunked=False, fork_between=False):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(2)
        listener.settimeout(3)
        port = listener.getsockname()[1]
        accepted = []
        requests = []
        failures = []
        def serve():
            try:
                connection, _ = listener.accept()
                accepted.append(True)
                with connection:
                    connection.settimeout(3)
                    for i in range(2):
                        raw = b""
                        while b"\r\n\r\n" not in raw:
                            chunk = connection.recv(8192)
                            if not chunk:
                                raise AssertionError("cached connection closed before second request")
                            raw += chunk
                        header, body = raw.split(b"\r\n\r\n", 1)
                        length = next(int(line.partition(b":")[2]) for line in header.split(b"\r\n") if line.lower().startswith(b"content-length:"))
                        while len(body) < length:
                            body += connection.recv(8192)
                        requests.append((header, body))
                        payload = f"response-{i}".encode()
                        if chunked:
                            wire = b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: Keep-Alive\r\n\r\n" + f"{len(payload):x}\r\n".encode() + payload + b"\r\n0\r\nX-End: yes\r\n\r\n"
                        else:
                            wire = b"HTTP/1.1 200 OK\r\nContent-Length: " + str(len(payload)).encode() + b"\r\n\r\n" + payload
                        connection.sendall(wire)
                    # Explicit http_close must release the retained descriptor.
                    self.assertEqual(connection.recv(1), b"")
            except Exception as exc:
                failures.append(exc)
            finally:
                listener.close()
        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        results = []
        @CALLBACK
        def callback(ptr, n):
            results.append(ctypes.string_at(ptr, n))
            return 0
        url = f"http://127.0.0.1:{port}/chat/completions".encode()
        statuses = [self.lib.http_request(url, b"first-key", b"{}", 2, callback)]
        if fork_between:
            # The child executes only the native assembly fork/drop/exit path.
            pid = self.lib.test_http_fork_drop()
            self.assertGreater(pid, 0)
            _, status = os.waitpid(pid, 0)
            self.assertEqual(status, 0)
        statuses.append(self.lib.http_request(url, b"second-key", b"{ }", 3, callback))
        self.lib.http_close()
        thread.join(4)
        self.assertFalse(thread.is_alive())
        self.assertFalse(failures, failures)
        self.assertEqual(statuses, [200, 200])
        self.assertEqual(b"".join(results), b"response-0response-1")
        self.assertEqual(len(accepted), 1)
        self.assertEqual(len(requests), 2)
        self.assertIn(b"Connection: keep-alive", requests[0][0])
        self.assertIn(b"Authorization: Bearer second-key", requests[1][0])
        return requests

    def test_keepalive_content_length_reuses_one_connection(self):
        before = len(os.listdir("/proc/self/fd"))
        self.persistent_exchange()
        self.assertEqual(len(os.listdir("/proc/self/fd")), before)

    def test_keepalive_chunked_reuses_one_connection(self):
        self.persistent_exchange(chunked=True)

    def test_after_fork_drops_child_reference_without_closing_parent_socket(self):
        self.persistent_exchange(fork_between=True)

    def test_response_close_http10_and_extra_bytes_disable_cache(self):
        for response in (
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok",
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: keep-alive, close\r\n\r\nok",
            b"HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nok",
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokUNEXPECTED",
        ):
            status, payload, _, _ = self.exchange(response)
            self.assertEqual((status, payload), (200, b"ok"))
            # A cacheable result owns exactly one descriptor until close. These
            # results must not retain any descriptor at all.
            before = len(os.listdir("/proc/self/fd"))
            self.lib.http_close()
            self.assertEqual(len(os.listdir("/proc/self/fd")), before)

    def test_origin_change_replaces_instead_of_leaking_cached_descriptor(self):
        response = b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"
        before = len(os.listdir("/proc/self/fd"))
        self.exchange(response)
        self.assertEqual(len(os.listdir("/proc/self/fd")), before + 1)
        self.exchange(response)
        self.assertEqual(len(os.listdir("/proc/self/fd")), before + 1)
        self.lib.http_close()
        self.assertEqual(len(os.listdir("/proc/self/fd")), before)

    def test_stale_keepalive_failure_never_retries_post(self):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(2)
        listener.settimeout(1)
        port = listener.getsockname()[1]
        closed = threading.Event()
        accepted = []
        failures = []
        def serve():
            try:
                connection, _ = listener.accept()
                accepted.append(True)
                with connection:
                    raw = b""
                    while b"\r\n\r\n" not in raw:
                        raw += connection.recv(8192)
                    header, body = raw.split(b"\r\n\r\n", 1)
                    length = next(int(line.partition(b":")[2]) for line in header.split(b"\r\n") if line.lower().startswith(b"content-length:"))
                    while len(body) < length:
                        body += connection.recv(8192)
                    connection.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
                closed.set()
                listener.settimeout(0.3)
                try:
                    other, _ = listener.accept()
                    accepted.append(True)
                    other.close()
                except socket.timeout:
                    pass
            except Exception as exc:
                failures.append(exc)
            finally:
                closed.set()
                listener.close()
        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        @CALLBACK
        def callback(ptr, n):
            return 0
        url = f"http://127.0.0.1:{port}/chat/completions".encode()
        self.assertEqual(self.lib.http_request(url, b"", b"{}", 2, callback), 200)
        self.assertTrue(closed.wait(2))
        self.assertLess(self.lib.http_request(url, b"", b"{}", 2, callback), 0)
        thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertFalse(failures, failures)
        self.assertEqual(len(accepted), 1, "POST was retried on another connection")

    def test_ca_change_invalidates_cached_connection(self):
        response = b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"
        before = len(os.listdir("/proc/self/fd"))
        self.exchange(response)
        self.assertEqual(len(os.listdir("/proc/self/fd")), before + 1)
        self.assertEqual(self.lib.http_set_ca(b"/tmp/new-ca-policy.pem"), 0)
        self.assertEqual(len(os.listdir("/proc/self/fd")), before)

    def test_https_has_no_plaintext_fallback(self):
        status, body, request, _ = self.exchange(b"", scheme="https")
        self.assertEqual((status, body, request), (-95, b"", b""))


if __name__ == "__main__":
    unittest.main()
