"""Native socket and DNS fixtures. Only immutable OS file paths / DNS port are
bound to temporary local fixtures at assembly time; application instructions and
wire parsing are unchanged. Public-network probing is explicitly opt-in.
"""
import ctypes
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


def dns_name(name):
    return b"".join(bytes([len(label)]) + label.encode() for label in name.split(".")) + b"\0"


class Resolver:
    def __init__(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(("127.0.0.1", 0))
        self.socket.settimeout(0.1)
        self.port = self.socket.getsockname()[1]
        self.mode = "normal"
        self.requests = []
        self.stopped = threading.Event()
        self.failure = None
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        while not self.stopped.is_set():
            try:
                query, peer = self.socket.recvfrom(4096)
            except socket.timeout:
                continue
            except OSError:
                return
            self.requests.append(query)
            if len(query) < 17:
                self.failure = AssertionError("DNS query too short")
                return
            identifier = query[:2]
            question = query[12:]
            cname = dns_name("alias.fixture.test")
            first = b"\xc0\x0c" + struct.pack("!HHIH", 5, 1, 30, len(cname)) + cname
            answer = b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 30, 4) + socket.inet_aton("127.0.0.1")
            flags = 0x8180
            if self.mode == "truncated":
                flags |= 0x0200
            elif self.mode == "rcode":
                flags |= 3
            elif self.mode == "wrong_id":
                identifier = bytes([identifier[0] ^ 1, identifier[1]])
            elif self.mode == "wrong_question":
                question = bytes([question[0], question[1] ^ 1]) + question[2:]
            elif self.mode == "bad_rdata":
                answer = b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 30, 60000) + b"\x7f"
            result = identifier + struct.pack("!HHHHH", flags, 1, 2, 0, 0) + question + first + answer
            if self.mode == "too_short":
                result = result[:11]
            try:
                self.socket.sendto(result, peer)
            except OSError:
                return

    def close(self):
        self.stopped.set()
        self.socket.close()
        self.thread.join(timeout=2)
        if self.failure:
            raise self.failure


class TCPPeer:
    def __init__(self, expected=b"", response=b""):
        self.expected, self.response = expected, response
        self.received = b""
        self.failure = None
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.listener.settimeout(4)
        self.port = self.listener.getsockname()[1]
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        try:
            stream, _ = self.listener.accept()
            stream.settimeout(4)
            with stream:
                while len(self.received) < len(self.expected):
                    part = stream.recv(1003)
                    if not part:
                        return
                    self.received += part
                for i in range(0, len(self.response), 97):
                    stream.sendall(self.response[i:i + 97])
        except OSError as error:
            self.failure = error
        finally:
            self.listener.close()

    def finish(self):
        self.thread.join(timeout=5)
        if self.thread.is_alive():
            raise AssertionError("TCP fixture did not exit")
        if self.failure:
            raise self.failure


class NetAssembly(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="qwen-x86-net-test-")
        cls.root = Path(cls.temp.name)
        cls.resolver = Resolver()
        cls.resolv = cls.root / "resolv.conf"
        cls.hosts = cls.root / "hosts"
        source = (ROOT / "src/net.s").read_text()
        source = source.replace('.asciz "/etc/resolv.conf"', '.asciz "' + str(cls.resolv) + '"')
        source = source.replace('.asciz "/etc/hosts"', '.asciz "' + str(cls.hosts) + '"')
        fixture = cls.root / "net-fixture.s"
        fixture.write_text(source)
        obj = cls.root / "net.o"
        shared = cls.root / "net.so"
        subprocess.run(["as", "-I", str(ROOT / "src"), "--defsym",
                        "DNS_PORT=" + str(cls.resolver.port), "-o", str(obj), str(fixture)], check=True)
        subprocess.run(["ld", "-shared", "-Bsymbolic", "-z", "noexecstack",
                        "-o", str(shared), str(obj)], check=True)
        cls.lib = ctypes.CDLL(str(shared))
        cls.lib.net_connect.argtypes = [ctypes.c_char_p, ctypes.c_uint64]
        cls.lib.net_connect.restype = ctypes.c_int64
        cls.lib.net_read.argtypes = cls.lib.net_write.argtypes = [ctypes.c_int64, ctypes.c_void_p, ctypes.c_size_t]
        cls.lib.net_read.restype = cls.lib.net_write.restype = ctypes.c_int64
        cls.lib.net_close.argtypes = [ctypes.c_int64]
        cls.lib.net_close.restype = ctypes.c_int64
        cls.lib.net_check_cancel.argtypes = []
        cls.lib.net_check_cancel.restype = ctypes.c_int64
        cls.lib.net_set_interactive.argtypes = [ctypes.c_uint64]
        cls.cancelled = ctypes.c_uint64.in_dll(cls.lib, "net_cancelled")
        cls.lib.net_set_interactive(0)

    @classmethod
    def tearDownClass(cls):
        cls.resolver.close()
        cls.temp.cleanup()

    def setUp(self):
        self.cancelled.value = 0
        self.resolver.mode = "normal"
        self.resolver.requests.clear()
        self.hosts.write_text("")
        self.resolv.write_text("# Local test resolver\nnameserver 127.0.0.1\n")

    def test_connected_socket_disables_nagle_for_interactive_requests(self):
        peer = TCPPeer()
        fd = self.lib.net_connect(b"127.0.0.1", peer.port)
        self.assertGreaterEqual(fd, 0)
        view = socket.socket(fileno=fd)
        try:
            self.assertEqual(view.getsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY), 1)
        finally:
            view.detach()
            self.lib.net_close(fd)
            peer.finish()

    def test_direct_ipv4_connect_and_partial_io(self):
        request = bytes(range(256)) * 200
        response = b"response:" + request
        server = TCPPeer(request, response)
        fd = self.lib.net_connect(b"127.0.0.1", server.port)
        self.assertGreaterEqual(fd, 0)
        try:
            self.assertEqual(self.lib.net_write(fd, request, len(request)), len(request))
            out = ctypes.create_string_buffer(203)
            received = bytearray()
            while True:
                count = self.lib.net_read(fd, out, 203)
                self.assertGreaterEqual(count, 0)
                if count == 0:
                    break
                received.extend(out.raw[:count])
            self.assertEqual(bytes(received), response)
        finally:
            self.lib.net_close(fd)
            server.finish()
        self.assertEqual(server.received, request)
        self.assertEqual(self.resolver.requests, [])

    def test_hosts_aliases_case_and_ipv6_skip(self):
        self.hosts.write_text("# fixture\n::1 ignored-v6\n  127.0.0.1 first ALIAS.fixture.test # trailing comment\n")
        server = TCPPeer()
        fd = self.lib.net_connect(b"alias.FIXTURE.test", server.port)
        self.assertGreaterEqual(fd, 0)
        self.lib.net_close(fd)
        server.finish()
        self.assertEqual(self.resolver.requests, [], "hosts match unexpectedly used DNS")

    def test_dotted_resolver_and_cname_answer(self):
        server = TCPPeer()
        fd = self.lib.net_connect(b"native.fixture.test", server.port)
        self.assertGreaterEqual(fd, 0)
        self.lib.net_close(fd)
        server.finish()
        self.assertEqual(len(self.resolver.requests), 1)
        query = self.resolver.requests[0]
        self.assertEqual(query[2:12], struct.pack("!HHHHH", 0x0100, 1, 0, 0, 0))
        self.assertEqual(query[12:], dns_name("native.fixture.test") + b"\x00\x01\x00\x01")

    def test_dns_rejects_bad_packets(self):
        for mode in ["truncated", "rcode", "wrong_id", "wrong_question", "bad_rdata", "too_short"]:
            with self.subTest(mode=mode):
                self.resolver.mode = mode
                result = self.lib.net_connect(b"invalid.fixture.test", 9)
                if result >= 0:
                    self.lib.net_close(result)
                self.assertEqual(result, -113)

    def test_missing_or_short_resolver_file_fails_closed(self):
        for contents in ["", "# none\n", "nameserv", "#" * 4090 + "\nname", "nameserver invalid\n"]:
            with self.subTest(contents=contents[:30]):
                self.resolv.write_text(contents)
                self.assertEqual(self.lib.net_connect(b"absent.fixture.test", 9), -113)
        self.assertEqual(self.resolver.requests, [])

    def test_invalid_or_oversized_domain_fails_before_dns(self):
        for hostname in [b"", b"a..b", b"x" * 64 + b".test", b"a." * 200 + b"z", b"space name.test"]:
            with self.subTest(hostname=hostname[:30]):
                self.assertEqual(self.lib.net_connect(hostname, 9), -113)
        self.assertEqual(self.resolver.requests, [])

    def test_wait_cancellation(self):
        left, right = socket.socketpair()
        left.setblocking(False)
        self.cancelled.value = 1
        try:
            output = ctypes.create_string_buffer(8)
            self.assertEqual(self.lib.net_read(left.fileno(), output, 8), -125)
        finally:
            self.cancelled.value = 0
            left.close()
            right.close()

    def test_nonblocking_raw_stdin_cancellation_probe(self):
        saved = os.dup(0)
        reader, writer = os.pipe()
        try:
            os.dup2(reader, 0)
            self.cancelled.value = 0
            self.lib.net_set_interactive(1)
            start = time.monotonic()
            self.assertEqual(self.lib.net_check_cancel(), 0)
            self.assertLess(time.monotonic() - start, 0.2)
            os.write(writer, b"x\x03y")
            self.assertEqual(self.lib.net_check_cancel(), 0)
            self.assertEqual(self.cancelled.value, 0)
            self.assertEqual(self.lib.net_check_cancel(), -125)
            self.assertEqual(self.cancelled.value, 1)
            self.assertEqual(self.lib.net_check_cancel(), -125)
            self.cancelled.value = 0
            self.lib.net_set_interactive(0)
            self.assertEqual(self.lib.net_check_cancel(), 0)
            self.assertEqual(os.read(reader, 1), b"y")
            os.close(writer)
            writer = -1
            self.lib.net_set_interactive(1)
            self.assertEqual(self.lib.net_check_cancel(), 0)
        finally:
            os.dup2(saved, 0)
            os.close(saved)
            os.close(reader)
            if writer >= 0:
                os.close(writer)
            self.cancelled.value = 0
            self.lib.net_set_interactive(0)

    def test_no_external_dependencies(self):
        self.assertEqual(subprocess.check_output(["nm", "-u", str(self.root / "net.o")], text=True).strip(), "")


if __name__ == "__main__":
    unittest.main()
