"""Native TLS 1.3 interoperability/security tests; Python/OpenSSL are SERVER oracles.

The application links only assembly objects. Temporary shared objects and Python
ssl/cryptography are test tools, never application transports or crypto helpers.
"""
import ctypes
import datetime
import hashlib
import hmac
import os
import select
import time
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import threading
import unittest

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

ROOT = Path(__file__).resolve().parents[1]


def make_certificates(directory):
    now = datetime.datetime.now(datetime.timezone.utc)
    root_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    root_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Native TLS Test Root")])
    root = (x509.CertificateBuilder().subject_name(root_name).issuer_name(root_name)
            .public_key(root_key.public_key()).serial_number(1)
            .not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=2))
            .add_extension(x509.BasicConstraints(ca=True, path_length=1), critical=True)
            .add_extension(x509.KeyUsage(False, False, False, False, False, True, True, False, False), critical=True)
            .sign(root_key, hashes.SHA256()))
    leaf_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    leaf_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "localhost")])
    leaf = (x509.CertificateBuilder().subject_name(leaf_name).issuer_name(root_name)
            .public_key(leaf_key.public_key()).serial_number(2)
            .not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=1))
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .add_extension(x509.KeyUsage(True, False, False, False, False, False, False, False, False), critical=True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
            .add_extension(x509.SubjectAlternativeName([x509.DNSName("localhost")]), critical=False)
            .sign(root_key, hashes.SHA256()))
    directory = Path(directory)
    ca_file = directory / "ca.pem"
    cert_file = directory / "server.pem"
    key_file = directory / "server.key"
    ca_file.write_bytes(root.public_bytes(serialization.Encoding.PEM))
    cert_file.write_bytes(leaf.public_bytes(serialization.Encoding.PEM) + root.public_bytes(serialization.Encoding.PEM))
    key_file.write_bytes(leaf_key.private_bytes(serialization.Encoding.PEM,
                                              serialization.PrivateFormat.PKCS8,
                                              serialization.NoEncryption()))
    return ca_file, cert_file, key_file


class LocalServer:
    def __init__(self, context, expected=b"hello", response=b"world", raw=None):
        self.context = context
        self.expected = expected
        self.response = response
        self.raw = raw
        self.received = b""
        self.failure = None
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.listener.settimeout(10)
        self.address = self.listener.getsockname()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        try:
            connection, _ = self.listener.accept()
            connection.settimeout(10)
            with connection:
                if self.raw is not None:
                    self.raw(connection)
                    return
                with self.context.wrap_socket(connection, server_side=True) as stream:
                    while len(self.received) < len(self.expected):
                        part = stream.recv(min(16384, len(self.expected) - len(self.received)))
                        if not part:
                            return
                        self.received += part
                    stream.sendall(self.response)
                    try:
                        stream.unwrap()
                    except (ssl.SSLError, OSError):
                        pass
        except (ssl.SSLError, OSError) as error:
            self.failure = error
        finally:
            self.listener.close()

    def finish(self):
        self.thread.join(timeout=12)
        if self.thread.is_alive():
            raise AssertionError("test TLS server did not exit")


def expand_label(secret, label, length):
    label = b"tls13 " + label
    info = length.to_bytes(2, "big") + bytes([len(label)]) + label + b"\x00"
    return hmac.new(secret, info + b"\x01", hashlib.sha256).digest()[:length]


class RecordProxy:
    """Server-side fault/fragmentation oracle; no app transport uses this code."""
    def __init__(self, server, keylog, mutate=None, fragment=False):
        self.target = server.address
        self.keylog = Path(keylog)
        self.mutate = mutate
        self.fragment = fragment
        self.corrupted = False
        self.failure = None
        self.random = None
        self.sequence = 0
        self.fragment_sequence = 0
        self.handshake_finished = False
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.listener.settimeout(10)
        self.address = self.listener.getsockname()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def transform(self, record):
        if self.mutate == "fragment_handshake" and record[0] == 22:
            payload = record[5:]
            return b"".join(b"\x16\x03\x03" + len(payload[i:i+19]).to_bytes(2, "big") + payload[i:i+19]
                            for i in range(0, len(payload), 19))
        if record[0] != 23 or self.corrupted or not self.mutate or self.handshake_finished:
            return record
        if self.mutate == "tag":
            self.corrupted = True
            return record[:-1] + bytes([record[-1] ^ 1])
        secret = None
        for line in self.keylog.read_text().splitlines():
            fields = line.split()
            if len(fields) == 3 and fields[0] == "SERVER_HANDSHAKE_TRAFFIC_SECRET" and fields[1] == self.random:
                secret = bytes.fromhex(fields[2])
        if secret is None:
            raise AssertionError("server test keylog missing the handshake traffic secret")
        key = expand_label(secret, b"key", 16)
        iv = expand_label(secret, b"iv", 12)
        nonce = bytes(a ^ b for a, b in zip(iv, self.sequence.to_bytes(12, "big")))
        self.sequence += 1
        plaintext = bytearray(AESGCM(key).decrypt(nonce, record[5:], record[:5]))
        content_end = len(plaintext)
        while content_end and plaintext[content_end - 1] == 0:
            content_end -= 1
        if not content_end or plaintext[content_end - 1] != 22:
            return record
        if self.mutate == "fragment_handshake":
            payload = bytes(plaintext[:content_end - 1])
            cursor = 0
            while cursor + 4 <= len(payload):
                length = int.from_bytes(payload[cursor + 1:cursor + 4], "big")
                if payload[cursor] == 20:
                    self.handshake_finished = True
                cursor += 4 + length
            output = bytearray()
            for index in range(0, len(payload), 37):
                inner = payload[index:index + 37] + b"\x16"
                header = b"\x17\x03\x03" + (len(inner) + 16).to_bytes(2, "big")
                nonce = bytes(a ^ b for a, b in zip(iv, self.fragment_sequence.to_bytes(12, "big")))
                self.fragment_sequence += 1
                output.extend(header + AESGCM(key).encrypt(nonce, inner, header))
            return bytes(output)
        cursor = 0
        while cursor + 4 <= content_end - 1:
            kind = plaintext[cursor]
            length = int.from_bytes(plaintext[cursor + 1:cursor + 4], "big")
            end = cursor + 4 + length
            if end > content_end - 1:
                break
            target = 15 if self.mutate == "certificate_verify" else 20
            if kind == target:
                offset = cursor + (8 if kind == 15 else 4)
                plaintext[offset] ^= 1
                self.corrupted = True
                return record[:5] + AESGCM(key).encrypt(nonce, bytes(plaintext), record[:5])
            cursor = end
        return record

    def run(self):
        try:
            client, _ = self.listener.accept()
            upstream = socket.create_connection(self.target, timeout=10)
            with client, upstream:
                server_bytes = bytearray()
                client_initial = bytearray()
                while True:
                    ready, _, _ = select.select([client, upstream], [], [], 10)
                    if not ready:
                        return
                    for source in ready:
                        data = source.recv(65536)
                        if not data:
                            return
                        if source is client:
                            if self.random is None:
                                client_initial.extend(data)
                                if len(client_initial) >= 43:
                                    self.random = bytes(client_initial[11:43]).hex()
                            upstream.sendall(data)
                        else:
                            server_bytes.extend(data)
                            while len(server_bytes) >= 5:
                                length = 5 + int.from_bytes(server_bytes[3:5], "big")
                                if len(server_bytes) < length:
                                    break
                                record = bytes(server_bytes[:length])
                                del server_bytes[:length]
                                record = self.transform(record)
                                chunk = 7 if self.fragment else len(record)
                                for index in range(0, len(record), chunk):
                                    client.sendall(record[index:index + chunk])
        except (OSError, ssl.SSLError) as error:
            self.failure = error
        except Exception as error:
            self.failure = error
        finally:
            self.listener.close()

    def finish(self):
        self.thread.join(timeout=12)
        if self.thread.is_alive():
            raise AssertionError("test record proxy did not exit")
        if isinstance(self.failure, AssertionError):
            raise self.failure


class TLSAssembly(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="qwen-x86-tls-test-")
        objects = []
        for name in ["tls", "net", "sha256", "x25519", "aesgcm", "x509", "rsa"]:
            obj = Path(cls.temp.name) / (name + ".o")
            subprocess.run(["as", "-I", str(ROOT / "src"), "-o", str(obj),
                            str(ROOT / "src" / (name + ".s"))], check=True)
            objects.append(obj)
        shared = Path(cls.temp.name) / "tls.so"
        subprocess.run(["ld", "-shared", "-Bsymbolic", "-z", "noexecstack", "-o",
                        str(shared)] + [str(p) for p in objects], check=True)
        cls.lib = ctypes.CDLL(str(shared))
        cls.lib.tls_connect.argtypes = [ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p]
        cls.lib.tls_connect.restype = ctypes.c_int64
        cls.lib.tls_read.argtypes = cls.lib.tls_write.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        cls.lib.tls_read.restype = cls.lib.tls_write.restype = ctypes.c_int64
        cls.lib.tls_close.restype = ctypes.c_int64
        cls.lib.tls_pending.restype = ctypes.c_uint64
        cls.lib.tls_after_fork.restype = ctypes.c_int64
        cls.lib.tls_error.restype = ctypes.c_char_p
        cls.ca_file, cert, key = make_certificates(cls.temp.name)
        cls.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        cls.context.minimum_version = ssl.TLSVersion.TLSv1_3
        cls.context.maximum_version = ssl.TLSVersion.TLSv1_3
        cls.context.load_cert_chain(cert, key)
        cls.context.set_alpn_protocols(["http/1.1"])
        cls.keylog = Path(cls.temp.name) / "server-test-keylog.txt"
        cls.context.keylog_filename = str(cls.keylog)
        other = Path(cls.temp.name) / "unrelated"
        other.mkdir()
        cls.unrelated_ca, _, _ = make_certificates(other)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def tearDown(self):
        self.lib.tls_close()

    def connect(self, server, hostname=b"localhost", ca_file=None):
        connection = socket.create_connection(server.address, timeout=10)
        connection.setblocking(False)
        result = self.lib.tls_connect(connection.fileno(), hostname,
                                      str(ca_file or self.ca_file).encode())
        return connection, result

    def test_native_authenticated_tls13_roundtrip(self):
        server = LocalServer(self.context)
        connection, result = self.connect(server)
        try:
            self.assertEqual(result, 0, self.lib.tls_error().decode())
            self.assertEqual(self.lib.tls_write(b"hello", 5), 5)
            output = ctypes.create_string_buffer(32)
            count = self.lib.tls_read(output, 32)
            self.assertEqual(count, 5, self.lib.tls_error().decode())
            self.assertEqual(output.raw[:count], b"world")
            self.assertEqual(self.lib.tls_read(output, 32), 0)
            self.lib.tls_close()
        finally:
            connection.close()
            server.finish()
        self.assertEqual(server.received, b"hello")

    def test_pending_plaintext_tracks_partial_reads_and_close(self):
        server = LocalServer(self.context, response=b"0123456789")
        connection, result = self.connect(server)
        try:
            self.assertEqual(result, 0, self.lib.tls_error().decode())
            self.assertEqual(self.lib.tls_pending(), 0)
            self.assertEqual(self.lib.tls_write(b"hello", 5), 5)
            output = ctypes.create_string_buffer(32)
            self.assertEqual(self.lib.tls_read(output, 3), 3)
            self.assertEqual(output.raw[:3], b"012")
            self.assertEqual(self.lib.tls_pending(), 7)
            self.assertEqual(self.lib.tls_read(output, 2), 2)
            self.assertEqual(output.raw[:2], b"34")
            self.assertEqual(self.lib.tls_pending(), 5)
            self.assertEqual(self.lib.tls_read(output, 32), 5)
            self.assertEqual(output.raw[:5], b"56789")
            self.assertEqual(self.lib.tls_pending(), 0)
            self.assertEqual(self.lib.tls_read(output, 32), 0)
            self.assertEqual(self.lib.tls_pending(), 0)
            self.lib.tls_close()
            self.assertEqual(self.lib.tls_pending(), 0)
        finally:
            connection.close()
            server.finish()

    def test_fork_detaches_private_tls_state_without_touching_parent(self):
        parent_server = LocalServer(self.context, response=b"parent intact")
        child_server = LocalServer(self.context, response=b"child fresh")
        connection, result = self.connect(parent_server)
        reader, writer = os.pipe()
        child = -1
        try:
            self.assertEqual(result, 0, self.lib.tls_error().decode())
            child = os.fork()
            if child == 0:
                os.close(reader)
                child_connection = None
                try:
                    if self.lib.tls_after_fork() != 0:
                        raise AssertionError("fork detach failed")
                    # The API must leave FD ownership with HTTP, even in a child.
                    os.fstat(connection.fileno())
                    os.close(connection.fileno())
                    if self.lib.tls_pending() != 0:
                        raise AssertionError("copied plaintext remains pending")
                    child_connection, status = self.connect(child_server)
                    if status != 0:
                        raise AssertionError(self.lib.tls_error().decode())
                    if self.lib.tls_write(b"hello", 5) != 5:
                        raise AssertionError("child write failed")
                    output = ctypes.create_string_buffer(32)
                    count = self.lib.tls_read(output, 32)
                    if output.raw[:count] != b"child fresh":
                        raise AssertionError("child response mismatch")
                    self.lib.tls_close()
                    child_connection.close()
                    os.write(writer, b"ok")
                    os._exit(0)
                except BaseException as error:
                    os.write(writer, repr(error).encode()[:2000])
                    os._exit(1)
            os.close(writer)
            writer = -1
            _, status = os.waitpid(child, 0)
            child = -1
            self.assertEqual(status, 0, os.read(reader, 2000).decode())
            self.assertEqual(self.lib.tls_write(b"hello", 5), 5)
            output = ctypes.create_string_buffer(32)
            count = self.lib.tls_read(output, 32)
            self.assertEqual(output.raw[:count], b"parent intact")
            self.assertEqual(self.lib.tls_read(output, 32), 0)
            self.lib.tls_close()
        finally:
            if child > 0:
                os.kill(child, 9)
                os.waitpid(child, 0)
            os.close(reader)
            if writer >= 0:
                os.close(writer)
            self.lib.tls_close()
            connection.close()
            parent_server.finish()
            child_server.finish()

    def test_wrong_hostname_rejected_before_application_data(self):
        server = LocalServer(self.context)
        connection, result = self.connect(server, hostname=b"wrong.example")
        try:
            self.assertLess(result, 0)
            self.assertIn("certificate", self.lib.tls_error().decode())
            self.assertLess(self.lib.tls_write(b"GET / HTTP/1.1\r\n\r\n", 18), 0)
        finally:
            self.lib.tls_close()
            connection.close()
            server.finish()
        self.assertEqual(server.received, b"")

    def test_unknown_ca_rejected(self):
        unknown = self.unrelated_ca
        server = LocalServer(self.context)
        connection, result = self.connect(server, ca_file=unknown)
        try:
            self.assertLess(result, 0)
            self.assertIn("certificate", self.lib.tls_error().decode())
        finally:
            self.lib.tls_close()
            connection.close()
            server.finish()
        self.assertEqual(server.received, b"")

    def test_large_writes_and_small_reads(self):
        request = bytes(range(256)) * 160
        response = b"native-record-boundaries:" + request
        server = LocalServer(self.context, expected=request, response=response)
        connection, result = self.connect(server)
        try:
            self.assertEqual(result, 0, self.lib.tls_error().decode())
            self.assertEqual(self.lib.tls_write(request, len(request)), len(request))
            output = ctypes.create_string_buffer(113)
            received = bytearray()
            while True:
                count = self.lib.tls_read(output, len(output))
                self.assertGreaterEqual(count, 0, self.lib.tls_error().decode())
                if count == 0:
                    break
                received.extend(output.raw[:count])
            self.assertEqual(bytes(received), response)
            self.lib.tls_close()
        finally:
            connection.close()
            server.finish()
        self.assertEqual(server.received, request)

    def test_fragmented_transport_records(self):
        server = LocalServer(self.context)
        proxy = RecordProxy(server, self.keylog, fragment=True)
        connection, result = self.connect(proxy)
        try:
            self.assertEqual(result, 0, self.lib.tls_error().decode())
            self.assertEqual(self.lib.tls_write(b"hello", 5), 5)
            output = ctypes.create_string_buffer(20)
            count = self.lib.tls_read(output, 20)
            self.assertEqual(output.raw[:count], b"world")
            self.assertEqual(self.lib.tls_read(output, 20), 0)
            self.lib.tls_close()
        finally:
            connection.close()
            proxy.finish()
            server.finish()

    def test_handshake_messages_fragmented_across_records(self):
        server = LocalServer(self.context)
        proxy = RecordProxy(server, self.keylog, mutate="fragment_handshake")
        connection, result = self.connect(proxy)
        try:
            self.assertEqual(result, 0, self.lib.tls_error().decode())
            self.assertTrue(proxy.handshake_finished)
            self.assertGreater(proxy.fragment_sequence, 20)
            self.assertEqual(self.lib.tls_write(b"hello", 5), 5)
            output = ctypes.create_string_buffer(b"\xa5" * 32, 32)
            count = self.lib.tls_read(ctypes.byref(output, 8), 7)
            self.assertEqual(count, 5, self.lib.tls_error().decode())
            self.assertEqual(output.raw[8:13], b"world")
            self.assertEqual(output.raw[:8], b"\xa5" * 8)
            self.assertEqual(output.raw[15:], b"\xa5" * 17)
            self.assertEqual(self.lib.tls_read(output, 32), 0)
            self.lib.tls_close()
        finally:
            connection.close()
            proxy.finish()
            server.finish()

    def test_bad_tag_signature_and_finished_are_rejected(self):
        expected_errors = {"tag": "authentication", "certificate_verify": "CertificateVerify", "finished": "Finished"}
        for mode, expected in expected_errors.items():
            with self.subTest(mode=mode):
                server = LocalServer(self.context)
                proxy = RecordProxy(server, self.keylog, mutate=mode)
                connection, result = self.connect(proxy)
                try:
                    self.assertLess(result, 0)
                    self.assertIn(expected, self.lib.tls_error().decode())
                    self.assertTrue(proxy.corrupted, "fault oracle did not reach target message")
                    self.assertLess(self.lib.tls_write(b"not authenticated", 17), 0)
                finally:
                    self.lib.tls_close()
                    connection.close()
                    proxy.finish()
                    server.finish()
                self.assertEqual(server.received, b"")

    def test_client_hello_explicit_profile(self):
        captured = []
        def capture(connection):
            header = b""
            while len(header) < 5:
                header += connection.recv(5 - len(header))
            length = int.from_bytes(header[3:5], "big")
            body = b""
            while len(body) < length:
                body += connection.recv(length - len(body))
            captured.append((header, body))
        server = LocalServer(self.context, raw=capture)
        connection, result = self.connect(server)
        try:
            self.assertLess(result, 0)  # Capture peer does not complete TLS.
        finally:
            self.lib.tls_close()
            connection.close()
            server.finish()
        header, hello = captured[0]
        self.assertEqual(header[:3], b"\x16\x03\x01")
        self.assertEqual(hello[0], 1)
        self.assertEqual(int.from_bytes(hello[1:4], "big"), len(hello) - 4)
        self.assertEqual(hello[4:6], b"\x03\x03")
        self.assertEqual(hello[38], 0)
        self.assertEqual(hello[39:45], b"\x00\x02\x13\x01\x01\x00")
        extensions_length = int.from_bytes(hello[45:47], "big")
        self.assertEqual(extensions_length, len(hello) - 47)
        cursor = 47
        extensions = {}
        while cursor < len(hello):
            kind = int.from_bytes(hello[cursor:cursor + 2], "big")
            length = int.from_bytes(hello[cursor + 2:cursor + 4], "big")
            self.assertNotIn(kind, extensions)
            extensions[kind] = hello[cursor + 4:cursor + 4 + length]
            cursor += 4 + length
        self.assertEqual(extensions[43], b"\x02\x03\x04")
        self.assertEqual(extensions[10], b"\x00\x02\x00\x1d")
        self.assertEqual(extensions[13], b"\x00\x02\x08\x04")
        self.assertEqual(extensions[50], b"\x00\x02\x04\x01")
        self.assertEqual(extensions[51][:6], b"\x00\x24\x00\x1d\x00\x20")
        self.assertEqual(len(extensions[51]), 38)
        self.assertEqual(extensions[16], b"\x00\x09\x08http/1.1")

    def test_truncated_server_handshake_is_rejected(self):
        def truncated(connection):
            connection.recv(4096)
            connection.sendall(b"\x16\x03\x03\x00\x10\x02\x00")
        server = LocalServer(self.context, raw=truncated)
        connection, result = self.connect(server)
        try:
            self.assertLess(result, 0)
            self.assertIn("ended early", self.lib.tls_error().decode())
        finally:
            self.lib.tls_close()
            connection.close()
            server.finish()

    @unittest.skipUnless(os.environ.get("QWEN_X86_LIVE_TLS_TEST") == "1", "explicit opt-in public network probe")
    def test_live_default_qwen_tls_without_http_or_credentials(self):
        self.lib.net_connect.argtypes = [ctypes.c_char_p, ctypes.c_uint64]
        self.lib.net_connect.restype = ctypes.c_int64
        self.lib.net_close.argtypes = [ctypes.c_int64]
        host = b"dashscope-intl.aliyuncs.com"
        fd = self.lib.net_connect(host, 443)
        self.assertGreaterEqual(fd, 0, "public native DNS/TCP probe failed")
        try:
            result = self.lib.tls_connect(fd, host, b"/etc/ssl/certs/ca-certificates.crt")
            self.assertEqual(result, 0, self.lib.tls_error().decode())
        finally:
            self.lib.tls_close()
            self.lib.net_close(fd)

    def test_no_native_external_runtime_symbols(self):
        shared = Path(self.temp.name) / "tls.so"
        self.assertEqual(subprocess.check_output(["nm", "-u", str(shared)], text=True).strip(), "")


if __name__ == "__main__":
    unittest.main()
