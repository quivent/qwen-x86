"""Native ASM JSON contract tests. Python/ctypes are test tools only."""
import concurrent.futures
import ctypes
import json
import mmap
import os
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAX_JSON = 1048576
MAX_TOKENS = 8192


class Token(ctypes.Structure):
    _fields_ = [("type", ctypes.c_uint64), ("start", ctypes.c_uint64),
                ("length", ctypes.c_uint64), ("end", ctypes.c_uint64)]


class JSONAssembly(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="qwen-x86-json-test-")
        obj = Path(cls.temp.name) / "json.o"
        so = Path(cls.temp.name) / "json.so"
        subprocess.run(["as", "-I", str(ROOT / "src"), "-o", str(obj),
                        str(ROOT / "src/json.s")], check=True)
        subprocess.run(["ld", "-shared", "-z", "noexecstack", "-o", str(so), str(obj)], check=True)
        cls.lib = ctypes.CDLL(str(so))
        cls.lib.json_parse.argtypes = [ctypes.c_void_p, ctypes.c_size_t,
                                      ctypes.POINTER(Token), ctypes.c_size_t]
        cls.lib.json_parse.restype = ctypes.c_ssize_t
        cls.lib.json_decode.argtypes = cls.lib.json_quote.argtypes = [
            ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t]
        cls.lib.json_decode.restype = cls.lib.json_quote.restype = ctypes.c_ssize_t
        cls.lib.json_find.argtypes = [ctypes.c_void_p, ctypes.POINTER(Token),
                                     ctypes.c_size_t, ctypes.c_void_p]
        cls.lib.json_find.restype = ctypes.c_ssize_t

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def parse(self, source, capacity=MAX_TOKENS):
        if isinstance(source, str):
            source = source.encode("utf-8")
        tokens = (Token * (capacity + 1))()
        tokens[capacity] = Token(*([0xA5A5A5A5A5A5A5A5] * 4))
        count = self.lib.json_parse(source, len(source), tokens, capacity)
        self.assertEqual(tuple(getattr(tokens[capacity], k) for k, _ in Token._fields_),
                         (0xA5A5A5A5A5A5A5A5,) * 4, "token capacity overwritten")
        return source, tokens, count

    def text_call(self, operation, source, capacity=None):
        if isinstance(source, str):
            source = source.encode("utf-8")
        if capacity is None:
            capacity = len(source) * 6 + 2
        output = ctypes.create_string_buffer(b"\xa5" * (capacity + 16))
        result = operation(ctypes.byref(output, 8), source, len(source), capacity)
        self.assertEqual(output.raw[:8], b"\xa5" * 8)
        self.assertEqual(output.raw[capacity + 8:capacity + 16], b"\xa5" * 8,
                         "output capacity overwritten")
        return result, output.raw[8:8 + max(0, result)]

    def decode(self, source):
        size, output = self.text_call(self.lib.json_decode, source)
        self.assertGreaterEqual(size, 0)
        return output.decode("utf-8")

    def rebuild(self, source, tokens, index=0):
        token = tokens[index]
        raw = source[token.start:token.start + token.length]
        if token.type == 1:
            out = {}
            cursor = index + 1
            while cursor < token.end:
                key = self.rebuild(source, tokens, cursor)
                out[key] = self.rebuild(source, tokens, cursor + 1)
                cursor = tokens[cursor + 1].end
            self.assertEqual(cursor, token.end)
            return out
        if token.type == 2:
            out = []
            cursor = index + 1
            while cursor < token.end:
                out.append(self.rebuild(source, tokens, cursor))
                cursor = tokens[cursor].end
            self.assertEqual(cursor, token.end)
            return out
        self.assertEqual(token.end, index + 1)
        if token.type == 3:
            return self.decode(raw)
        if token.type == 4:
            return json.loads(raw)
        return {5: True, 6: False, 7: None}[token.type]

    def assert_document(self, value, ensure_ascii=False):
        encoded = json.dumps(value, ensure_ascii=ensure_ascii, separators=(",", ":")).encode()
        source, tokens, count = self.parse(encoded)
        self.assertGreater(count, 0, repr(encoded))
        self.assertEqual(tokens[0].end, count)
        for i, token in enumerate(tokens[:count]):
            self.assertGreater(token.end, i)
            self.assertLessEqual(token.end, count)
            self.assertLessEqual(token.start + token.length, len(source))
        self.assertEqual(self.rebuild(source, tokens), value)
        return source, tokens, count

    def test_scalar_and_container_types(self):
        for value in [None, True, False, 0, -12, 12.25, 1.2e-40, "", "hello", [], {},
                      [1, True, {"role": "assistant", "a": [1, 2, None]}]]:
            with self.subTest(value=value):
                self.assert_document(value)

    def test_token_offsets_and_subtree_end(self):
        source, tokens, count = self.parse(b' {"x":[1,{"y":"z"}],"last":false} \n')
        self.assertEqual(count, 9)
        self.assertEqual(tokens[0].start, 1)
        self.assertEqual(tokens[0].length, len(source.strip()))
        self.assertEqual([t.end for t in tokens[:count]], [9, 2, 7, 4, 7, 6, 7, 8, 9])
        self.assertEqual(source[tokens[6].start:tokens[6].start + tokens[6].length], b"z")

    def test_strict_invalid_grammar(self):
        invalid = [b"", b" ", b"{", b"[", b"[1,]", b"{\"a\":1,}", b"[,1]", b"[1 2]",
                   b"{1:2}", b"{\"a\" 2}", b"{\"a\":}", b"{\"a\":1 \"b\":2}",
                   b"true false", b"nullx", b"tru", b"False", b"NaN", b"Infinity", b"+1",
                   b"01", b"-01", b"-", b".1", b"1.", b"1e", b"1e+", b"1e-", b"--1",
                   b"1.0.0", b"1e1e1", b"0x10", b"\x0bnull", b"\xef\xbb\xbf{}",
                   b'"unterminated', b'"trailing\\', b'"\\x00"', b'"\\u001"', b'"\\u00gg"',
                   b'"unescaped\nnewline"', b'"\x00"', b"[]junk", b"{}{}"]
        for source in invalid:
            with self.subTest(source=source):
                self.assertLess(self.parse(source)[2], 0)

    def test_valid_number_forms(self):
        for source in [b"0", b"-0", b"0.0", b"-0.0", b"1e0", b"1E+2", b"1e-2",
                       b"123456789012345678901234567890", b"9.123456789e+9999"]:
            with self.subTest(source=source):
                _, tokens, count = self.parse(source)
                self.assertEqual(count, 1)
                self.assertEqual(tokens[0].length, len(source))

    def test_all_ascii_controls_escape(self):
        for byte in range(128):
            text = chr(byte)
            count, quoted = self.text_call(self.lib.json_quote, text)
            self.assertGreaterEqual(count, 2)
            self.assertEqual(json.loads(quoted), text)
            self.assertEqual(self.decode(quoted[1:-1]), text)
            self.assertGreater(self.parse(quoted)[2], 0)

    def test_unicode_boundary_roundtrips(self):
        points = [0x7f, 0x80, 0x7ff, 0x800, 0xd7ff, 0xe000, 0xffff,
                  0x10000, 0x10ffff, 0x1f600, 0x20ac]
        text = "".join(map(chr, points))
        for ensure_ascii in [False, True]:
            self.assert_document({"unicode": text}, ensure_ascii)
        count, quoted = self.text_call(self.lib.json_quote, text)
        self.assertEqual(json.loads(quoted), text)
        self.assertEqual(self.decode(quoted[1:-1]), text)

    def test_invalid_utf8_and_surrogates_rejected(self):
        invalid_utf8 = [b"\x80", b"\xbf", b"\xc0\x80", b"\xc1\xbf", b"\xc2", b"\xe0\x80\x80",
                        b"\xe2\x82", b"\xed\xa0\x80", b"\xf0\x80\x80\x80", b"\xf4\x90\x80\x80",
                        b"\xf5\x80\x80\x80", b"\xff", b"\xe2a\xac"]
        for raw in invalid_utf8:
            with self.subTest(raw=raw):
                self.assertLess(self.parse(b'"' + raw + b'"')[2], 0)
                self.assertLess(self.text_call(self.lib.json_decode, raw)[0], 0)
                self.assertLess(self.text_call(self.lib.json_quote, raw)[0], 0)
        for raw in [b"\\ud800", b"\\udc00", b"\\udfff", b"\\ud800\\u0000",
                    b"\\udbff\\udbff", b"\\ud800z", b"\\ud800\\u123", b"\\ud800\\uGGGG"]:
            with self.subTest(raw=raw):
                self.assertLess(self.parse(b'"' + raw + b'"')[2], 0)
                self.assertLess(self.text_call(self.lib.json_decode, raw)[0], 0)

    def test_find_nested_subtrees_and_escaped_keys(self):
        source, tokens, count = self.parse('{"nested":{"value":7},"r\\u006fle":"assistant","é😀":true,"":null}')
        self.assertGreater(count, 0)
        role = self.lib.json_find(source, tokens, 0, b"role")
        self.assertEqual(self.rebuild(source, tokens, role), "assistant")
        unicode_index = self.lib.json_find(source, tokens, 0, "é😀".encode())
        self.assertEqual(self.rebuild(source, tokens, unicode_index), True)
        nested = self.lib.json_find(source, tokens, 0, b"nested")
        nested_value = self.lib.json_find(source, tokens, nested, b"value")
        self.assertEqual(self.rebuild(source, tokens, nested_value), 7)
        empty = self.lib.json_find(source, tokens, 0, b"")
        self.assertEqual(self.rebuild(source, tokens, empty), None)
        self.assertEqual(self.lib.json_find(source, tokens, 0, b"missing"), -1)
        self.assertEqual(self.lib.json_find(source, tokens, role, b"role"), -1)
        self.assertEqual(self.lib.json_find(source, tokens, count, b"role"), -1)

    def test_depth_capacity_and_input_limits(self):
        self.assertGreater(self.parse("[" * 64 + "0" + "]" * 64, 100)[2], 0)
        self.assertEqual(self.parse("[" * 65 + "0" + "]" * 65, 100)[2], -2)
        self.assertEqual(self.parse("{}", 0)[2], -2)
        self.assertEqual(self.parse("[1]", 1)[2], -2)
        self.assertEqual(self.parse("[1]", 2)[2], 2)
        self.assertEqual(self.parse("1" * (MAX_JSON + 1))[2], -2)
        self.assertEqual(self.parse("[" + ",".join(["0"] * MAX_TOKENS) + "]")[2], -2)

    def test_output_exact_capacity_and_overflow(self):
        for text in ["", "plain", '\n\x00"\\', "é😀"]:
            wanted = self.text_call(self.lib.json_quote, text)[1]
            self.assertEqual(self.text_call(self.lib.json_quote, text, len(wanted))[1], wanted)
            self.assertEqual(self.text_call(self.lib.json_quote, text, len(wanted) - 1)[0], -2)
            raw = wanted[1:-1]
            decoded = text.encode()
            self.assertEqual(self.text_call(self.lib.json_decode, raw, len(decoded))[1], decoded)
            if decoded:
                self.assertEqual(self.text_call(self.lib.json_decode, raw, len(decoded) - 1)[0], -2)
            self.assertEqual(self.lib.json_quote(None, text.encode(), len(text.encode()), len(wanted)), len(wanted))
            self.assertEqual(self.lib.json_decode(None, raw, len(raw), len(decoded)), len(decoded))

    def test_truncations(self):
        source = b'{"nested":[1,2,{"text":"hello\\uD83D\\uDE00"}]}'
        for length in range(len(source)):
            with self.subTest(length=length):
                self.assertLess(self.parse(source[:length])[2], 0)
        self.assertGreater(self.parse(source)[2], 0)

    def test_generated_json_properties(self):
        rng = random.Random(20261029)
        def value(depth=0):
            scalar = [None, True, False, rng.randrange(-10**15, 10**15),
                      rng.random() * 1e30, "é😀\n" + str(rng.randrange(1000))]
            if depth > 4:
                return rng.choice(scalar)
            kind = rng.randrange(4)
            if kind == 0:
                return [value(depth + 1) for _ in range(rng.randrange(5))]
            if kind == 1:
                return {"key" + str(i): value(depth + 1) for i in range(rng.randrange(5))}
            return rng.choice(scalar)
        for _ in range(400):
            self.assert_document(value(), ensure_ascii=bool(rng.randrange(2)))

    def test_reentrant_concurrent_calls(self):
        def worker(index):
            source = json.dumps({"worker": index, "unicode": "é😀", "array": [index, None]}).encode()
            tokens = (Token * 20)()
            count = self.lib.json_parse(source, len(source), tokens, 20)
            return count, self.lib.json_find(source, tokens, 0, b"worker")
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(worker, range(500)))
        self.assertTrue(all(count == 9 and found == 2 for count, found in results))

    def test_guard_page_acquired_extent(self):
        page = mmap.PAGESIZE
        mapping = mmap.mmap(-1, page * 3, prot=mmap.PROT_READ | mmap.PROT_WRITE)
        base = ctypes.addressof(ctypes.c_char.from_buffer(mapping))
        system = ctypes.CDLL(None)
        system.mprotect.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
        self.assertEqual(system.mprotect(base, page, 0), 0)
        self.assertEqual(system.mprotect(base + 2 * page, page, 0), 0)
        try:
            for raw in [b'{}', b'true', b'false', b'null', b'1e-2', b'"hello"',
                        b'"\\uD83D\\uDE00"', b'"\\u123"', b'"unterminated', b'"\\']:
                pointer = base + 2 * page - len(raw)
                ctypes.memmove(pointer, raw, len(raw))
                tokens = (Token * 64)()
                result = self.lib.json_parse(pointer, len(raw), tokens, 64)
                if raw in [b'"\\u123"', b'"unterminated', b'"\\']:
                    self.assertLess(result, 0)
                else:
                    self.assertGreater(result, 0)
            for raw in [b'', b'plain', b'\\uD83D\\uDE00', 'é😀'.encode(), b'\xf0\x9f\x98']:
                pointer = base + 2 * page - len(raw)
                ctypes.memmove(pointer, raw, len(raw))
                output = ctypes.create_string_buffer(100)
                self.lib.json_decode(output, pointer, len(raw), 100)
                self.lib.json_quote(output, pointer, len(raw), 100)
            for raw in [b'', b'hello', b'\x00\n', 'é😀'.encode()]:
                wanted = self.text_call(self.lib.json_quote, raw)[1]
                pointer = base + 2 * page - len(wanted)
                result = self.lib.json_quote(pointer, raw, len(raw), len(wanted))
                self.assertEqual(result, len(wanted))
                self.assertEqual(ctypes.string_at(pointer, result), wanted)
        finally:
            system.mprotect(base, page, mmap.PROT_READ | mmap.PROT_WRITE)
            system.mprotect(base + 2 * page, page, mmap.PROT_READ | mmap.PROT_WRITE)
            mapping.close()

    def test_deterministic_mutation_fuzz(self):
        rng = random.Random(0xC0DE)
        documents = [b'{"a":[1,true,null,"text"],"b":-1.5e2}', b'[[{}],false]',
                     b'"\\uD83D\\uDE00"', b'0.5e-2']
        alphabet = b'{}[],:0123456789eE+-.truefalsn"\\ abcxyz\t\n'
        for _ in range(5000):
            source = bytearray(rng.choice(documents))
            mode = rng.randrange(3)
            if mode == 0:
                del source[rng.randrange(len(source))]
            elif mode == 1:
                source[rng.randrange(len(source))] = rng.choice(alphabet)
            else:
                source.insert(rng.randrange(len(source) + 1), rng.choice(alphabet))
            try:
                expected = json.loads(source)
                # Python accepts isolated UTF-16 surrogates; this parser rejects
                # those non-scalar results intentionally.
                rendered = json.dumps(expected, ensure_ascii=False)
                rendered.encode('utf-8')
                valid = True
            except (ValueError, UnicodeError):
                valid = False
            raw, tokens, result = self.parse(bytes(source))
            self.assertEqual(result > 0, valid, repr(bytes(source)))
            if valid:
                self.assertEqual(self.rebuild(raw, tokens), expected)

    def test_no_external_native_dependencies(self):
        obj = Path(self.temp.name) / "json.o"
        undefined = subprocess.check_output(["nm", "-u", str(obj)], text=True)
        self.assertEqual(undefined.strip(), "")


if __name__ == "__main__":
    unittest.main()
