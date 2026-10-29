"""Independent AES-NI/GCM proofs. Only assembly is linked into the tested DSO.

NIST examples: https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_GCM.pdf
Construction: NIST SP800-38D,96-bit IV profile, full128-bit tag.
Python cryptography is an independent test oracle, never an app dependency.
"""
import concurrent.futures
import ctypes as C
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    AESGCM = None

ROOT = Path(__file__).resolve().parents[1]


def buffer(data):
    return C.create_string_buffer(data, max(1, len(data)))


class Request(C.Structure):
    _fields_ = [
        ("roundkeys", C.c_void_p), ("nonce", C.c_void_p),
        ("aad", C.c_void_p), ("aadlen", C.c_uint64),
        ("input", C.c_void_p), ("inputlen", C.c_uint64),
        ("output", C.c_void_p), ("tag", C.c_void_p),
    ]


class AESGCMTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if "aes" not in Path("/proc/cpuinfo").read_text():
            raise unittest.SkipTest("AES-NI CPU is required by this target")
        cls.temporary = tempfile.TemporaryDirectory(prefix="qwen-x86-aesgcm-")
        cls.directory = Path(cls.temporary.name)
        obj = cls.directory / "aesgcm.o"
        cls.library_path = cls.directory / "aesgcm.so"
        subprocess.run(["as", "-o", str(obj), str(ROOT / "src/aesgcm.s")], check=True)
        subprocess.run(["ld", "-shared", "-z", "noexecstack", "-o", str(cls.library_path), str(obj)], check=True)
        cls.lib = C.CDLL(str(cls.library_path))
        cls.lib.aes128_expand.argtypes = [C.c_void_p, C.c_void_p]
        cls.lib.aes128_block.argtypes = [C.c_void_p, C.c_void_p, C.c_void_p]
        cls.lib.gcm_encrypt.argtypes = [C.POINTER(Request)]
        cls.lib.gcm_decrypt.argtypes = [C.POINTER(Request)]
        for name in ["aes128_expand", "aes128_block", "gcm_encrypt", "gcm_decrypt"]:
            getattr(cls.lib, name).restype = C.c_long

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def prepare(self, key, nonce, aad, plaintext, *, inplace=False):
        keybuf = buffer(key)
        keys = buffer(bytes(176))
        self.assertEqual(self.lib.aes128_expand(keybuf, keys), 0)
        noncebuf, aadbuf, incoming = buffer(nonce), buffer(aad), buffer(plaintext)
        outgoing = incoming if inplace else buffer(b"\xa5" * len(plaintext))
        tag = buffer(bytes(16))
        req = Request(C.addressof(keys), C.addressof(noncebuf), C.addressof(aadbuf), len(aad), C.addressof(incoming), len(plaintext), C.addressof(outgoing), C.addressof(tag))
        keep = (keybuf, keys, noncebuf, aadbuf, incoming, outgoing, tag)
        return req, keep

    def encrypt(self, key, nonce, aad, plaintext, *, inplace=False):
        req, keep = self.prepare(key, nonce, aad, plaintext, inplace=inplace)
        before = bytes(req)
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), 0)
        self.assertEqual(bytes(req), before, "request cartography was modified")
        return keep[-2].raw[:len(plaintext)], keep[-1].raw

    def decrypt(self, key, nonce, aad, ciphertext, tag, *, inplace=False):
        req, keep = self.prepare(key, nonce, aad, ciphertext, inplace=inplace)
        C.memmove(keep[-1], tag, 16)
        code = self.lib.gcm_decrypt(C.byref(req))
        return code, keep[-2].raw[:len(ciphertext)]

    def test_fips197_aes128_block_and_round_keys(self):
        key = buffer(bytes.fromhex("000102030405060708090a0b0c0d0e0f"))
        keys = buffer(bytes(176))
        self.assertEqual(self.lib.aes128_expand(key, keys), 0)
        self.assertEqual(keys.raw[:16], key.raw)
        self.assertEqual(keys.raw[-16:].hex(), "13111d7fe3944a17f307a78b4d2b30c5")
        data = buffer(bytes.fromhex("00112233445566778899aabbccddeeff"))
        self.assertEqual(self.lib.aes128_block(keys, data, data), 0)
        self.assertEqual(data.raw.hex(), "69c4e0d86a7b0430d8cdb78070b4c55a")

    def test_nist_zero_key_empty_and_single_block(self):
        ciphertext, tag = self.encrypt(bytes(16), bytes(12), b"", b"")
        self.assertEqual(ciphertext, b"")
        self.assertEqual(tag.hex(), "58e2fccefa7e3061367f1d57a4e7455a")
        ciphertext, tag = self.encrypt(bytes(16), bytes(12), b"", bytes(16))
        self.assertEqual(ciphertext.hex(), "0388dace60b6a392f328c2b971b2fe78")
        self.assertEqual(tag.hex(), "ab6e47d42cec13bdf53a67b21257bddf")
        self.assertEqual(self.decrypt(bytes(16), bytes(12), b"", ciphertext, tag), (0, bytes(16)))

    def test_nist_four_block_no_aad(self):
        key = bytes.fromhex("feffe9928665731c6d6a8f9467308308")
        nonce = bytes.fromhex("cafebabefacedbaddecaf888")
        plaintext = bytes.fromhex("d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255")
        ciphertext, tag = self.encrypt(key, nonce, b"", plaintext)
        self.assertEqual(ciphertext.hex(), "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985")
        self.assertEqual(tag.hex(), "4d5c2af327cd64a62cf35abd2ba6fab4")
        self.assertEqual(self.decrypt(key, nonce, b"", ciphertext, tag), (0, plaintext))

    def test_nist_partial_block_with_aad(self):
        key = bytes.fromhex("feffe9928665731c6d6a8f9467308308")
        nonce = bytes.fromhex("cafebabefacedbaddecaf888")
        aad = bytes.fromhex("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        plaintext = bytes.fromhex("d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39")
        ciphertext, tag = self.encrypt(key, nonce, aad, plaintext)
        self.assertEqual(ciphertext.hex(), "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091")
        self.assertEqual(tag.hex(), "5bc94fbc3221a5db94fae95ae7121a47")
        self.assertEqual(self.decrypt(key, nonce, aad, ciphertext, tag), (0, plaintext))

    @unittest.skipUnless(AESGCM, "cryptography oracle not installed in this Python environment")
    def test_random_lengths_against_independent_oracle(self):
        rng = random.Random(19738)
        lengths = [0, 1, 2, 7, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 255, 256, 257, 1023, 4096, 16384]
        for length in lengths:
            for aadlen in [0, 1, 15, 16, 17, 31, 32, 33, 128]:
                key, nonce, aad, plain = rng.randbytes(16), rng.randbytes(12), rng.randbytes(aadlen), rng.randbytes(length)
                expected = AESGCM(key).encrypt(nonce, plain, aad)
                cipher, tag = self.encrypt(key, nonce, aad, plain)
                self.assertEqual(cipher + tag, expected, (length, aadlen))
                self.assertEqual(self.decrypt(key, nonce, aad, cipher, tag), (0, plain))

    @unittest.skipUnless(AESGCM, "cryptography oracle not installed in this Python environment")
    def test_concurrent_independent_contexts_are_reentrant(self):
        def work(index):
            rng = random.Random(index)
            key, nonce, aad, plain = rng.randbytes(16), rng.randbytes(12), rng.randbytes(index % 29), rng.randbytes(index * 17)
            cipher, tag = self.encrypt(key, nonce, aad, plain)
            self.assertEqual(cipher + tag, AESGCM(key).encrypt(nonce, plain, aad))
            self.assertEqual(self.decrypt(key, nonce, aad, cipher, tag), (0, plain))
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            list(pool.map(work, range(96)))

    def test_invalid_tag_never_exposes_plaintext(self):
        key, nonce, aad, plain = bytes(range(16)), bytes(range(12)), b"TLS-header", b"private plaintext" * 7
        cipher, tag = self.encrypt(key, nonce, aad, plain)
        for index in range(16):
            wrong = bytearray(tag)
            wrong[index] ^= 1
            self.assertEqual(self.decrypt(key, nonce, aad, cipher, bytes(wrong)), (-1, b"\xa5" * len(cipher)))
            self.assertEqual(self.decrypt(key, nonce, aad, cipher, bytes(wrong), inplace=True), (-1, cipher))

    def test_invalid_aad_nonce_and_ciphertext_are_rejected(self):
        key, nonce, aad, plain = bytes(range(16)), bytes(range(12)), b"associated", b"private plaintext"
        cipher, tag = self.encrypt(key, nonce, aad, plain)
        bad_nonce = bytes([nonce[0] ^ 1]) + nonce[1:]
        self.assertEqual(self.decrypt(key, bad_nonce, aad, cipher, tag)[0], -1)
        self.assertEqual(self.decrypt(key, nonce, aad + b"!", cipher, tag)[0], -1)
        bad_cipher = bytes([cipher[0] ^ 1]) + cipher[1:]
        self.assertEqual(self.decrypt(key, nonce, aad, bad_cipher, tag)[0], -1)

    def test_exact_inplace_encrypt_and_decrypt(self):
        for length in [0, 1, 15, 16, 17, 33, 4096]:
            plain = bytes(index % 256 for index in range(length))
            cipher, tag = self.encrypt(bytes(16), bytes(12), b"AAD", plain, inplace=True)
            self.assertEqual(self.decrypt(bytes(16), bytes(12), b"AAD", cipher, tag, inplace=True), (0, plain))

    def test_partial_overlap_is_rejected_without_modifying_buffers(self):
        req, keep = self.prepare(bytes(16), bytes(12), b"", bytes(range(48)))
        for offset in [1, 7, 16, 31]:
            req.inputlen = 32
            req.input, req.output = C.addressof(keep[-3]), C.addressof(keep[-3]) + offset
            before = keep[-3].raw
            self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
            self.assertEqual(keep[-3].raw, before)
            req.input, req.output = req.output, req.input
            self.assertEqual(self.lib.gcm_decrypt(C.byref(req)), -22)
            self.assertEqual(keep[-3].raw, before)

    def test_appended_tag_is_supported(self):
        req, keep = self.prepare(bytes(16), bytes(12), b"AAD", b"a" * 31)
        combined = buffer(bytes(47))
        req.output, req.tag = C.addressof(combined), C.addressof(combined) + 31
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), 0)
        cipher, tag = self.encrypt(bytes(16), bytes(12), b"AAD", b"a" * 31)
        self.assertEqual(combined.raw, cipher + tag)

    def test_overflow_nulls_and_counter_limits_are_rejected_early(self):
        req, keep = self.prepare(bytes(16), bytes(12), b"", b"data")
        for length in [0xFFFFFFFE1, (1 << 64) - 1]:
            req.inputlen = length
            self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
            self.assertEqual(self.lib.gcm_decrypt(C.byref(req)), -22)
        req.inputlen = 16
        req.input = (1 << 64) - 8
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
        req.inputlen = 4
        req.input = C.addressof(keep[-3])
        req.aadlen = 1 << 61
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
        req.aadlen, req.aad = 1, None
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
        req.aadlen, req.tag = 0, None
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
        self.assertEqual(self.lib.gcm_decrypt(None), -22)

    def test_tag_cannot_overwrite_ciphertext_or_key_schedule(self):
        req, keep = self.prepare(bytes(16), bytes(12), b"", bytes(32))
        req.tag = req.output + 1
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
        req.tag = C.addressof(keep[-1])
        req.output = req.roundkeys + 16
        before = keep[1].raw
        self.assertEqual(self.lib.gcm_encrypt(C.byref(req)), -22)
        self.assertEqual(keep[1].raw, before)

    def test_unaligned_key_schedule_and_data(self):
        key = buffer(b"x" + bytes(16))
        keys = buffer(bytes(177))
        inp, out = buffer(b"x" + bytes(16)), buffer(bytes(17))
        self.assertEqual(self.lib.aes128_expand(C.addressof(key) + 1, C.addressof(keys) + 1), 0)
        self.assertEqual(self.lib.aes128_block(C.addressof(keys) + 1, C.addressof(inp) + 1, C.addressof(out) + 1), 0)
        self.assertEqual(out.raw[1:].hex(), "66e94bd4ef8a2c3b884cfa59ca342b2e")

    def test_no_linked_runtime_or_writable_global_storage(self):
        dynamic = subprocess.check_output(["readelf", "-d", str(self.library_path)], text=True)
        self.assertNotIn("(NEEDED)", dynamic)
        symbols = subprocess.check_output(["nm", "-S", str(self.library_path)], text=True)
        for line in symbols.splitlines():
            fields = line.split()
            if len(fields) >= 4:
                self.assertNotIn(fields[-2], ["B", "b", "D", "d"], line)


if __name__ == "__main__":
    unittest.main()
