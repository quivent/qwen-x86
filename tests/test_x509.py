"""Native bounded X.509 profile proofs using independently generated RSA chains.

Certificate generation is Python-only test setup; the verifier is assembly linked
with the project's native SHA256/RSA implementations, with no runtime libraries.
"""
import ctypes as C
from datetime import datetime, timedelta, timezone
import ipaddress
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

try:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, rsa
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID, ObjectIdentifier
except ImportError:
    x509 = None

ROOT = Path(__file__).resolve().parents[1]
SIZE = 224


@unittest.skipUnless(x509, "run with ~/.venvs/oscillihue-main/bin/python for certificate generation")
class X509Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="qwen-x86-x509-")
        cls.directory = Path(cls.temporary.name)
        objects = []
        for name in ["x509", "sha256", "rsa"]:
            obj = cls.directory / (name + ".o")
            subprocess.run(["as", "-I", str(ROOT / "src"), "-o", str(obj), str(ROOT / "src" / (name + ".s"))], check=True)
            objects.append(str(obj))
        cls.library = cls.directory / "x509.so"
        subprocess.run(["ld", "-shared", "-Bsymbolic", "-z", "noexecstack", "-o", str(cls.library), *objects], check=True)
        cls.lib = C.CDLL(str(cls.library))
        cls.lib.x509_parse.argtypes = [C.c_void_p, C.c_size_t, C.c_void_p]
        cls.lib.x509_parse.restype = C.c_long
        cls.lib.x509_verify_chain.argtypes = [C.c_void_p, C.c_size_t, C.c_void_p, C.c_void_p]
        cls.lib.x509_verify_chain.restype = C.c_long
        cls.now = datetime.now(timezone.utc).replace(microsecond=0)
        cls.root_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.intermediate_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.leaf_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.root = cls.make("test root", cls.root_key, None, cls.root_key, ca=True, pathlen=2)
        cls.intermediate = cls.make("intermediate", cls.intermediate_key, cls.root, cls.root_key, ca=True, pathlen=0)
        cls.leaf = cls.make("misleading CN", cls.leaf_key, cls.intermediate, cls.intermediate_key, names=["example.test", "*.wild.example.test", ipaddress.ip_address("127.0.0.1")])

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    @classmethod
    def make(cls, name, key, issuer, signer, *, ca=False, pathlen=None, names=None, before=None, after=None, bc=True, ku=True, cert_sign=None, digital=None, eku="server", critical_unknown=False, name_constraints=False, signature=None):
        subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)])
        builder = (x509.CertificateBuilder().subject_name(subject).issuer_name(issuer.subject if issuer else subject)
                   .public_key(key.public_key()).serial_number(x509.random_serial_number())
                   .not_valid_before(before or cls.now - timedelta(days=1)).not_valid_after(after or cls.now + timedelta(days=365)))
        if bc:
            builder = builder.add_extension(x509.BasicConstraints(ca=ca, path_length=pathlen if ca else None), True)
        if ku:
            builder = builder.add_extension(x509.KeyUsage(digital_signature=(not ca if digital is None else digital), content_commitment=False,
                key_encipherment=False, data_encipherment=False, key_agreement=False,
                key_cert_sign=(ca if cert_sign is None else cert_sign), crl_sign=ca,
                encipher_only=None, decipher_only=None), True)
        if names is not None:
            san = [x509.DNSName(value) if isinstance(value, str) else x509.IPAddress(value) for value in names]
            builder = builder.add_extension(x509.SubjectAlternativeName(san), False)
        if not ca and eku:
            oid = ExtendedKeyUsageOID.SERVER_AUTH if eku == "server" else ExtendedKeyUsageOID.CLIENT_AUTH
            builder = builder.add_extension(x509.ExtendedKeyUsage([oid]), False)
        builder = builder.add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), False)
        if critical_unknown:
            builder = builder.add_extension(x509.UnrecognizedExtension(ObjectIdentifier("1.2.3.4.5"), b"\x05\x00"), True)
        if name_constraints:
            builder = builder.add_extension(x509.NameConstraints(permitted_subtrees=[x509.DNSName("example.test")], excluded_subtrees=None), True)
        return builder.sign(signer, signature or hashes.SHA256())

    def parse(self, certificate):
        der = certificate if isinstance(certificate, bytes) else certificate.public_bytes(serialization.Encoding.DER)
        buf, record = C.create_string_buffer(der), C.create_string_buffer(SIZE)
        return self.lib.x509_parse(buf, len(der), record), record, buf

    def verify(self, certificates, host="example.test", anchors=None):
        records = C.create_string_buffer(SIZE * len(certificates))
        keep = []
        for i, certificate in enumerate(certificates):
            der = certificate if isinstance(certificate, bytes) else certificate.public_bytes(serialization.Encoding.DER)
            buf = C.create_string_buffer(der)
            keep.append(buf)
            code = self.lib.x509_parse(buf, len(der), C.byref(records, i * SIZE))
            if code:
                return code
        pem = b"".join(c.public_bytes(serialization.Encoding.PEM) if not isinstance(c, bytes) else c for c in (anchors if anchors is not None else [self.root]))
        with tempfile.NamedTemporaryFile(dir=self.directory) as stream:
            stream.write(pem)
            stream.flush()
            return self.lib.x509_verify_chain(records, len(certificates), host.encode(), stream.name.encode())

    def test_valid_root_intermediate_leaf_and_external_root_lookup(self):
        self.assertEqual(self.verify([self.leaf, self.intermediate, self.root]), 0)
        self.assertEqual(self.verify([self.leaf, self.intermediate]), 0)
        direct = self.make("direct", self.leaf_key, self.root, self.root_key, names=["example.test"])
        self.assertEqual(self.verify([direct]), 0)

    def test_record_layout_and_epoch_fields_match_generator(self):
        code, record, keep = self.parse(self.leaf)
        self.assertEqual(code, 0)
        field = lambda offset: int.from_bytes(record.raw[offset:offset+8], "little")
        self.assertEqual(field(72), 256)
        self.assertEqual(field(80), 65537)
        self.assertEqual(field(104), 1)
        self.assertEqual(field(112), int((getattr(self.leaf, "not_valid_before_utc", None) or self.leaf.not_valid_before.replace(tzinfo=timezone.utc)).timestamp()))
        self.assertEqual(field(120), int((getattr(self.leaf, "not_valid_after_utc", None) or self.leaf.not_valid_after.replace(tzinfo=timezone.utc)).timestamp()))
        self.assertEqual(field(160) & 128, 128)
        self.assertEqual(field(168) & 1, 1)

    def test_dns_casefold_wildcard_exact_depth_and_ipv4(self):
        chain = [self.leaf, self.intermediate]
        for host in ["EXAMPLE.TEST", "x.wild.example.test", "127.0.0.1"]:
            with self.subTest(host=host):
                self.assertEqual(self.verify(chain, host), 0)
        for host in ["wrong.test", "wild.example.test", "a.b.wild.example.test", "127.0.0.2", "misleading CN", "example.test.evil", "example..test"]:
            with self.subTest(host=host):
                self.assertNotEqual(self.verify(chain, host), 0)

    def test_ip_reference_never_matches_a_dns_name(self):
        leaf = self.make("IP as DNS", self.leaf_key, self.root, self.root_key, names=["127.0.0.1"])
        self.assertNotEqual(self.verify([leaf], "127.0.0.1"), 0)

    def test_no_common_name_fallback(self):
        leaf = self.make("example.test", self.leaf_key, self.root, self.root_key, names=None)
        self.assertNotEqual(self.verify([leaf]), 0)

    def test_expired_and_not_yet_valid_certificates(self):
        expired = self.make("expired", self.leaf_key, self.root, self.root_key, names=["example.test"], before=self.now-timedelta(days=3), after=self.now-timedelta(days=1))
        future = self.make("future", self.leaf_key, self.root, self.root_key, names=["example.test"], before=self.now+timedelta(days=1), after=self.now+timedelta(days=2))
        self.assertNotEqual(self.verify([expired]), 0)
        self.assertNotEqual(self.verify([future]), 0)
        expired_root = self.make("old CA", self.root_key, None, self.root_key, ca=True, before=self.now-timedelta(days=3), after=self.now-timedelta(days=1))
        leaf = self.make("leaf", self.leaf_key, expired_root, self.root_key, names=["example.test"])
        self.assertNotEqual(self.verify([leaf], anchors=[expired_root]), 0)

    def test_generalized_time_and_leap_calendar(self):
        after = datetime(2052, 2, 29, 23, 59, 59, tzinfo=timezone.utc)
        before = datetime(2024, 2, 29, 0, 0, 0, tzinfo=timezone.utc)
        leaf = self.make("long", self.leaf_key, self.root, self.root_key, names=["example.test"], before=before, after=after)
        code, record, keep = self.parse(leaf)
        self.assertEqual(code, 0)
        self.assertEqual(int.from_bytes(record.raw[112:120], "little"), int(before.timestamp()))
        self.assertEqual(int.from_bytes(record.raw[120:128], "little"), int(after.timestamp()))
        self.assertEqual(self.verify([leaf]), 0)

    def test_bad_ca_basic_constraints_missing_and_false(self):
        for bc, ca in [(False, True), (True, False)]:
            inter = self.make("bad inter", self.intermediate_key, self.root, self.root_key, bc=bc, ca=ca)
            leaf = self.make("leaf", self.leaf_key, inter, self.intermediate_key, names=["example.test"])
            self.assertNotEqual(self.verify([leaf, inter]), 0)

    def test_key_usage_and_extended_key_usage_are_enforced(self):
        inter = self.make("bad signing usage", self.intermediate_key, self.root, self.root_key, ca=True, cert_sign=False)
        leaf = self.make("leaf", self.leaf_key, inter, self.intermediate_key, names=["example.test"])
        self.assertNotEqual(self.verify([leaf, inter]), 0)
        for digital, eku in [(False, "server"), (True, "client")]:
            leaf = self.make("bad leaf usage", self.leaf_key, self.root, self.root_key, names=["example.test"], digital=digital, eku=eku)
            self.assertNotEqual(self.verify([leaf]), 0)

    def test_path_length_constraints_are_enforced(self):
        root = self.make("zero path CA", self.root_key, None, self.root_key, ca=True, pathlen=0)
        inter = self.make("inter", self.intermediate_key, root, self.root_key, ca=True, pathlen=0)
        leaf = self.make("leaf", self.leaf_key, inter, self.intermediate_key, names=["example.test"])
        self.assertNotEqual(self.verify([leaf, inter], anchors=[root]), 0)
        direct = self.make("direct", self.leaf_key, root, self.root_key, names=["example.test"])
        self.assertEqual(self.verify([direct], anchors=[root]), 0)

    def test_unknown_ca_bad_signature_and_wrong_issuer_fail(self):
        other_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        other = self.make("unrelated", other_key, None, other_key, ca=True)
        self.assertNotEqual(self.verify([self.leaf, self.intermediate], anchors=[other]), 0)
        bad = bytearray(self.leaf.public_bytes(serialization.Encoding.DER))
        bad[-7] ^= 1
        self.assertNotEqual(self.verify([bytes(bad), self.intermediate]), 0)
        self.assertNotEqual(self.verify([self.leaf, self.root]), 0)

    def test_unsupported_critical_extensions_fail_closed(self):
        for extra in [{"critical_unknown": True}, {"name_constraints": True}]:
            leaf = self.make("critical", self.leaf_key, self.root, self.root_key, names=["example.test"], **extra)
            self.assertNotEqual(self.parse(leaf)[0], 0)
            self.assertNotEqual(self.verify([leaf]), 0)

    def test_anchor_own_sha384_signature_is_not_required(self):
        root = self.make("SHA384 anchor", self.root_key, None, self.root_key, ca=True, signature=hashes.SHA384())
        leaf = self.make("leaf", self.leaf_key, root, self.root_key, names=["example.test"])
        self.assertEqual(self.parse(root)[0], 0)
        self.assertEqual(self.verify([leaf], anchors=[root]), 0)
        self.assertEqual(self.verify([leaf, root], anchors=[root]), 0)
        unsupported_leaf = self.make("leaf", self.leaf_key, root, self.root_key, names=["example.test"], signature=hashes.SHA384())
        self.assertNotEqual(self.verify([unsupported_leaf], anchors=[root]), 0)

    def test_cross_signed_sha384_wrapper_matches_trusted_subject_and_key(self):
        old_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        old_root = self.make("old signing root", old_key, None, old_key, ca=True)
        cross = self.make("test root", self.root_key, old_root, old_key, ca=True, pathlen=2, signature=hashes.SHA384())
        self.assertNotEqual(cross.public_bytes(serialization.Encoding.DER), self.root.public_bytes(serialization.Encoding.DER))
        self.assertEqual(self.verify([self.leaf, self.intermediate, cross], anchors=[self.root]), 0)
        self.assertNotEqual(self.verify([self.leaf, self.intermediate, cross], "wrong.test", anchors=[self.root]), 0)
        bad = bytearray(self.leaf.public_bytes(serialization.Encoding.DER))
        bad[-1] ^= 1
        self.assertNotEqual(self.verify([bytes(bad), self.intermediate, cross], anchors=[self.root]), 0)
        expired = self.make("test root", self.root_key, old_root, old_key, ca=True, pathlen=2, signature=hashes.SHA384(), before=self.now-timedelta(days=3), after=self.now-timedelta(days=1))
        self.assertNotEqual(self.verify([self.leaf, self.intermediate, expired], anchors=[self.root]), 0)

    def test_matching_anchor_name_with_different_key_never_establishes_trust(self):
        fake_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        old_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        old_root = self.make("old signing root", old_key, None, old_key, ca=True)
        fake = self.make("test root", fake_key, old_root, old_key, ca=True, pathlen=2, signature=hashes.SHA384())
        fake_leaf = self.make("leaf", self.leaf_key, fake, fake_key, names=["example.test"])
        self.assertEqual(fake.subject, self.root.subject)
        self.assertNotEqual(self.verify([fake_leaf, fake], anchors=[self.root]), 0)

    def test_unsupported_ec_anchors_are_skipped_in_mixed_pem(self):
        ec_key = ec.generate_private_key(ec.SECP256R1())
        ec_root = self.make("EC anchor", ec_key, None, ec_key, ca=True)
        self.assertNotEqual(self.parse(ec_root)[0], 0)
        self.assertEqual(self.verify([self.leaf, self.intermediate], anchors=[ec_root, self.root]), 0)

    def test_truncated_nonminimal_and_trailing_der_is_rejected(self):
        der = self.leaf.public_bytes(serialization.Encoding.DER)
        for length in [0, 1, 2, 3, 4, 7, 16, 32, len(der)-1]:
            self.assertNotEqual(self.parse(der[:length])[0], 0)
        self.assertNotEqual(self.parse(der + b"\x00")[0], 0)
        self.assertNotEqual(self.parse(b"\x30\x80\x00\x00")[0], 0)
        self.assertNotEqual(self.parse(b"\x30\x81\x01\x00")[0], 0)
        bad = bytearray(der)
        bad[0] = 0x31
        self.assertNotEqual(self.parse(bytes(bad))[0], 0)
        # Every truncation must be bounded; no fault or malformed success.
        for length in range(len(der)):
            self.assertNotEqual(self.parse(der[:length])[0], 0, length)

    def test_signed_certificate_mutations_never_verify(self):
        der = self.leaf.public_bytes(serialization.Encoding.DER)
        rng = random.Random(5280)
        for index in rng.sample(range(len(der)), 32):
            bad = bytearray(der)
            bad[index] ^= 1
            self.assertNotEqual(self.verify([bytes(bad), self.intermediate]), 0, index)

    def test_empty_unknown_and_malformed_ca_bundle_fails(self):
        for pem in [b"", b"not a certificate", b"-----BEGIN CERTIFICATE-----\n!!!!\n-----END CERTIFICATE-----\n"]:
            self.assertNotEqual(self.verify([self.leaf, self.intermediate], anchors=[pem]), 0)

    def test_bounded_chain_and_no_linked_runtime(self):
        self.assertNotEqual(self.lib.x509_verify_chain(None, 0, b"example.test", None), 0)
        rec = C.create_string_buffer(SIZE * 9)
        self.assertNotEqual(self.lib.x509_verify_chain(rec, 9, b"example.test", None), 0)
        dynamic = subprocess.check_output(["readelf", "-d", str(self.library)], text=True)
        self.assertNotIn("(NEEDED)", dynamic)


if __name__ == "__main__":
    unittest.main()
