"""RFC 7748 and independent-oracle tests for the native x86-64 primitive.

Python/cryptography and the temporary shared object are test tools, never linked
application dependencies. The tests prove results/bounds; they do not claim a
complete side-channel or cryptographic implementation audit.
"""
import concurrent.futures
import ctypes
import mmap
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

try:
    from cryptography.hazmat.primitives.asymmetric.x25519 import (
        X25519PrivateKey, X25519PublicKey)
except ImportError:
    X25519PrivateKey = X25519PublicKey = None

ROOT = Path(__file__).resolve().parents[1]
BASE = bytes([9]) + bytes(31)
P = 2**255 - 19
VECTORS = [
    ("a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4",
     "e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c",
     "c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552"),
    ("4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d",
     "e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493",
     "95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957"),
]


class X25519Assembly(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="qwen-x86-x25519-test-")
        cls.obj = Path(cls.temp.name) / "x25519.o"
        shared = Path(cls.temp.name) / "x25519.so"
        subprocess.run(["as", "-I", str(ROOT / "src"), "-o", str(cls.obj),
                        str(ROOT / "src/x25519.s")], check=True)
        # Assembly-only ABI witness: no C compiler or runtime adapter.
        witness = Path(cls.temp.name) / "abi.s"
        witness.write_text('''
.intel_syntax noprefix
.text
.globl x25519_abi_witness
x25519_abi_witness:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 movabs rbx,0x1122334455667788
 movabs rbp,0x2233445566778899
 movabs r12,0x33445566778899aa
 movabs r13,0x445566778899aabb
 movabs r14,0x5566778899aabbcc
 movabs r15,0x66778899aabbccdd
 call x25519@PLT
 mov [rsp],rax
 xor r10d,r10d
 movabs rax,0x1122334455667788
 xor rax,rbx
 or r10,rax
 movabs rax,0x2233445566778899
 xor rax,rbp
 or r10,rax
 movabs rax,0x33445566778899aa
 xor rax,r12
 or r10,rax
 movabs rax,0x445566778899aabb
 xor rax,r13
 or r10,rax
 movabs rax,0x5566778899aabbcc
 xor rax,r14
 or r10,rax
 movabs rax,0x66778899aabbccdd
 xor rax,r15
 or r10,rax
 mov rax,[rsp]
 test r10,r10
 jz 1f
 mov eax,1
1:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.section .note.GNU-stack,"",@progbits
''')
        abi_obj = Path(cls.temp.name) / "abi.o"
        subprocess.run(["as", "-o", str(abi_obj), str(witness)], check=True)
        subprocess.run(["ld", "-shared", "-z", "noexecstack", "-o", str(shared),
                        str(cls.obj), str(abi_obj)], check=True)
        cls.lib = ctypes.CDLL(str(shared))
        for name in ["x25519", "x25519_abi_witness"]:
            function = getattr(cls.lib, name)
            function.argtypes = [ctypes.c_void_p] * 3
            function.restype = ctypes.c_int64

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def exchange(self, scalar, peer, function=None):
        self.assertEqual(len(scalar), 32)
        self.assertEqual(len(peer), 32)
        scalar_buffer = ctypes.create_string_buffer(scalar, 32)
        peer_buffer = ctypes.create_string_buffer(peer, 32)
        output = ctypes.create_string_buffer(b"\xa5" * 48, 48)
        result = (function or self.lib.x25519)(scalar_buffer, peer_buffer,
                                             ctypes.byref(output, 8))
        self.assertEqual(scalar_buffer.raw, scalar, "input scalar was modified")
        self.assertEqual(peer_buffer.raw, peer, "input peer was modified")
        self.assertEqual(output.raw[:8], b"\xa5" * 8)
        self.assertEqual(output.raw[40:], b"\xa5" * 8)
        value = output.raw[8:40]
        self.assertLess(int.from_bytes(value, "little"), P, "output is not canonical")
        self.assertEqual(result, -1 if value == bytes(32) else 0)
        return result, value

    def test_rfc7748_two_vectors(self):
        for scalar, peer, expected in VECTORS:
            with self.subTest(vector=expected):
                result, value = self.exchange(bytes.fromhex(scalar), bytes.fromhex(peer))
                self.assertEqual(result, 0)
                self.assertEqual(value.hex(), expected)

    def test_rfc_alice_bob_agreement(self):
        alice = bytes.fromhex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        bob = bytes.fromhex("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        _, alice_public = self.exchange(alice, BASE)
        _, bob_public = self.exchange(bob, BASE)
        self.assertEqual(alice_public.hex(), "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
        self.assertEqual(bob_public.hex(), "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")
        _, shared_a = self.exchange(alice, bob_public)
        _, shared_b = self.exchange(bob, alice_public)
        self.assertEqual(shared_a, shared_b)
        self.assertEqual(shared_a.hex(), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742")

    def test_rfc_1000_iterations(self):
        scalar = peer = BASE
        for iteration in range(1000):
            old_scalar = scalar
            result, scalar = self.exchange(scalar, peer)
            self.assertEqual(result, 0)
            peer = old_scalar
            if iteration == 0:
                self.assertEqual(scalar.hex(), "422c8e7a6227d7bca1350b3e2bb7279f7897b87bb6854b783c60e80311ae3079")
        self.assertEqual(scalar.hex(), "684cf59ba83309552800ef566f2f4d3c1c3887c49360e3875f2eb94d99532c51")

    def test_scalar_clamp_and_peer_high_bit(self):
        rng = random.Random(7748)
        for _ in range(20):
            scalar = rng.randbytes(32)
            canonical = bytearray(scalar)
            canonical[0] &= 248
            canonical[31] = canonical[31] & 127 | 64
            self.assertEqual(self.exchange(scalar, BASE), self.exchange(bytes(canonical), BASE))
            high_bit = BASE[:31] + bytes([BASE[31] | 128])
            self.assertEqual(self.exchange(scalar, BASE), self.exchange(scalar, high_bit))

    def test_low_order_and_noncanonical_peers(self):
        scalar = bytes.fromhex(VECTORS[0][0])
        for point in [0, 1, P - 1, P, P + 1]:
            result, value = self.exchange(scalar, point.to_bytes(32, "little"))
            self.assertEqual(result, -1)
            self.assertEqual(value, bytes(32))
        for point in range(2, 19):
            canonical = point.to_bytes(32, "little")
            noncanonical = (P + point).to_bytes(32, "little")
            self.assertEqual(self.exchange(scalar, canonical), self.exchange(scalar, noncanonical))

    @unittest.skipIf(X25519PrivateKey is None, "Python cryptography test oracle unavailable")
    def test_randomized_independent_cryptography_oracle(self):
        rng = random.Random(0x25519)
        for _ in range(160):
            scalar, peer = rng.randbytes(32), rng.randbytes(32)
            expected = X25519PrivateKey.from_private_bytes(scalar).exchange(
                X25519PublicKey.from_public_bytes(peer))
            self.assertEqual(self.exchange(scalar, peer)[1], expected)

    def test_exact_alias_and_unaligned_buffers(self):
        scalar, peer, expected = [bytes.fromhex(x) for x in VECTORS[0]]
        for alias in ["scalar", "peer"]:
            first = ctypes.create_string_buffer(b"\xa5" + scalar + b"\xa5", 34)
            second = ctypes.create_string_buffer(b"\xa5" + peer + b"\xa5", 34)
            out = ctypes.byref(first if alias == "scalar" else second, 1)
            result = self.lib.x25519(ctypes.byref(first, 1), ctypes.byref(second, 1), out)
            self.assertEqual(result, 0)
            self.assertEqual(ctypes.string_at(out, 32), expected)
            self.assertEqual(first.raw[0], 0xa5)
            self.assertEqual(first.raw[-1], 0xa5)
            self.assertEqual(second.raw[0], 0xa5)
            self.assertEqual(second.raw[-1], 0xa5)

    def test_system_v_callee_saved_registers(self):
        scalar, peer, expected = [bytes.fromhex(x) for x in VECTORS[0]]
        result, value = self.exchange(scalar, peer, self.lib.x25519_abi_witness)
        self.assertEqual(result, 0)
        self.assertEqual(value, expected)

    def test_concurrent_reentrancy(self):
        def worker(seed):
            scalar = random.Random(seed).randbytes(32)
            output = ctypes.create_string_buffer(32)
            result = self.lib.x25519(scalar, BASE, output)
            return scalar, result, output.raw
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            rows = list(executor.map(worker, range(80)))
        for scalar, result, value in rows:
            self.assertEqual((result, value), self.exchange(scalar, BASE))

    def test_guard_page_exact_input_and_output_spans(self):
        page = mmap.PAGESIZE
        memory = mmap.mmap(-1, page * 6, prot=mmap.PROT_READ | mmap.PROT_WRITE)
        base = ctypes.addressof(ctypes.c_char.from_buffer(memory))
        system = ctypes.CDLL(None)
        system.mprotect.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
        for index in [1, 3, 5]:
            self.assertEqual(system.mprotect(base + page * index, page, 0), 0)
        try:
            scalar, peer, expected = [bytes.fromhex(x) for x in VECTORS[0]]
            scalar_ptr, peer_ptr, output_ptr = [base + page * index - 32 for index in [1, 3, 5]]
            ctypes.memmove(scalar_ptr, scalar, 32)
            ctypes.memmove(peer_ptr, peer, 32)
            self.assertEqual(self.lib.x25519(scalar_ptr, peer_ptr, output_ptr), 0)
            self.assertEqual(ctypes.string_at(output_ptr, 32), expected)
        finally:
            for index in [1, 3, 5]:
                system.mprotect(base + page * index, page, mmap.PROT_READ | mmap.PROT_WRITE)
            memory.close()

    def test_no_external_dependencies(self):
        self.assertEqual(subprocess.check_output(["nm", "-u", str(self.obj)], text=True).strip(), "")


if __name__ == "__main__":
    unittest.main()
