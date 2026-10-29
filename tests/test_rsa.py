"""RSA oracle tests for the production x86-64 assembly, no runtime C crypto."""
import ctypes
import hashlib
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa, utils

ROOT = Path(__file__).resolve().parents[1]
DER_SHA256 = bytes.fromhex("3031300d060960864801650304020105000420")


class RSATest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="qwen-x86-rsa-")
        build = Path(cls.build.name)
        for name in ("rsa", "sha256"):
            subprocess.run(["as", "--64", "-I", str(ROOT / "src"), "-o", str(build / (name + ".o")), str(ROOT / "src" / (name + ".s"))], check=True)
        subprocess.run(["ld", "-shared", "-o", str(build / "rsa.so"), str(build / "rsa.o"), str(build / "sha256.o")], check=True)
        cls.lib = ctypes.CDLL(str(build / "rsa.so"))
        cls.lib.rsa_public.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_void_p]
        cls.lib.rsa_public.restype = ctypes.c_long
        for name in ("rsa_pss_sha256_verify", "rsa_pkcs1_sha256_verify"):
            f = getattr(cls.lib, name)
            f.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
            f.restype = ctypes.c_long
        cls.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.message = b"Self-contained x86-64 application TLS authentication"
        cls.digest = hashlib.sha256(cls.message).digest()

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def public(self, value, modulus, size, exponent=65537):
        n = modulus.to_bytes(size, "big")
        sig = value.to_bytes(size, "big")
        out = ctypes.create_string_buffer(size)
        status = self.lib.rsa_public(sig, len(sig), n, len(n), exponent, out)
        return status, int.from_bytes(out.raw, "big")

    def verify(self, name, key, sig, digest=None):
        n = key.public_key().public_numbers().n
        modulus = n.to_bytes((n.bit_length() + 7) // 8, "big")
        return getattr(self.lib, name)(modulus, len(modulus), sig, len(sig), digest or self.digest)

    @staticmethod
    def sign_encoded(key, encoded):
        p = key.private_numbers()
        signature = pow(int.from_bytes(encoded, "big"), p.d, p.public_numbers.n)
        return signature.to_bytes(len(encoded), "big")

    def test_public_matches_pow_across_widths_and_carry_boundaries(self):
        rng = random.Random(0x4C4954484F53)
        for size in (128, 132, 192, 256, 384, 512):
            for n in ((1 << (size * 8 - 1)) | 1, (1 << (size * 8)) - 1, rng.getrandbits(size * 8) | (1 << (size * 8 - 1)) | 1):
                for value in (0, 1, 2, n - 1, rng.randrange(n)):
                    with self.subTest(size=size, value=value & 255):
                        status, actual = self.public(value, n, size)
                        self.assertEqual(status, 0)
                        self.assertEqual(actual, pow(value, 65537, n))

    def test_public_rejects_bad_parameters(self):
        n = self.key.public_key().public_numbers().n
        self.assertEqual(self.public(n, n, 256)[0], -1)
        self.assertEqual(self.public(n + 1, n, 256)[0], -1)
        self.assertEqual(self.public(1, n - 1, 256)[0], -1)  # even modulus
        self.assertEqual(self.public(1, n >> 1, 256)[0], -1)  # unnormalized
        self.assertEqual(self.public(1, n, 256, exponent=3)[0], -1)
        for size in (0, 64, 127, 129, 513):
            out = ctypes.create_string_buffer(512)
            self.assertEqual(self.lib.rsa_public(b"\0" * max(size, 1), size, b"\xff" * max(size, 1), size, 65537, out), -1)
        out = ctypes.create_string_buffer(256)
        modulus = n.to_bytes(256, "big")
        self.assertEqual(self.lib.rsa_public(None, 256, modulus, 256, 65537, out), -1)
        self.assertEqual(self.lib.rsa_public(b"\0" * 256, 255, modulus, 256, 65537, out), -1)

    def test_oracle_signatures_all_supported_standard_sizes(self):
        for bits in (1024, 2048, 4096):
            key = self.key if bits == 2048 else rsa.generate_private_key(public_exponent=65537, key_size=bits)
            for pad, name in ((padding.PKCS1v15(), "rsa_pkcs1_sha256_verify"), (padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=32), "rsa_pss_sha256_verify")):
                with self.subTest(bits=bits, scheme=name):
                    signature = key.sign(self.digest, pad, utils.Prehashed(hashes.SHA256()))
                    self.assertEqual(self.verify(name, key, signature), 1)
                    self.assertEqual(self.verify(name, key, signature[:-1] + bytes([signature[-1] ^ 1])), 0)
                    self.assertEqual(self.verify(name, key, signature, bytes([self.digest[0] ^ 1]) + self.digest[1:]), 0)
                    self.assertEqual(self.verify(name, key, signature[1:]), 0)

    def test_pkcs1_exact_padding_and_digestinfo(self):
        size = 256
        trailer = DER_SHA256 + self.digest
        encoded = b"\0\1" + b"\xff" * (size - len(trailer) - 3) + b"\0" + trailer
        self.assertEqual(self.verify("rsa_pkcs1_sha256_verify", self.key, self.sign_encoded(self.key, encoded)), 1)
        positions = (0, 1, 2, size - 53, size - 52, size - 51, size - 40, size - 33, size - 32, size - 1)
        for pos in positions:
            bad = bytearray(encoded)
            bad[pos] ^= 1
            with self.subTest(position=pos):
                self.assertEqual(self.verify("rsa_pkcs1_sha256_verify", self.key, self.sign_encoded(self.key, bad)), 0)

    @staticmethod
    def pss_encoded(digest, size=256, salt=b"s" * 32, mutate_db=None):
        h = hashlib.sha256(b"\0" * 8 + digest + salt).digest()
        db = bytearray(b"\0" * (size - 66) + b"\1" + salt)
        if mutate_db is not None:
            mutate_db(db)
        mask = b"".join(hashlib.sha256(h + i.to_bytes(4, "big")).digest() for i in range((len(db) + 31) // 32))
        masked = bytearray(a ^ b for a, b in zip(db, mask))
        masked[0] &= 0x7F
        return bytes(masked) + h + b"\xbc"

    def test_pss_exact_encoding_and_mgf1(self):
        encoded = self.pss_encoded(self.digest)
        self.assertEqual(len(encoded), 256)
        self.assertEqual(self.verify("rsa_pss_sha256_verify", self.key, self.sign_encoded(self.key, encoded)), 1)
        bad_encodings = []
        for position in (0, 1, 127, 222, 223, 254, 255):
            bad = bytearray(encoded)
            bad[position] ^= 1
            bad_encodings.append(bad)
        bad_encodings.append(self.pss_encoded(self.digest, mutate_db=lambda db: db.__setitem__(1, 1)))
        bad_encodings.append(self.pss_encoded(self.digest, mutate_db=lambda db: db.__setitem__(-33, 2)))
        for i, bad in enumerate(bad_encodings):
            with self.subTest(case=i):
                self.assertEqual(self.verify("rsa_pss_sha256_verify", self.key, self.sign_encoded(self.key, bad)), 0)
        # Only a32-byte salt is negotiated/supported by this verifier.
        signature = self.key.sign(self.digest, padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=20), utils.Prehashed(hashes.SHA256()))
        self.assertEqual(self.verify("rsa_pss_sha256_verify", self.key, signature), 0)


if __name__ == "__main__":
    unittest.main()
