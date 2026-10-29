"""Native prompt-plugin loader/expander proofs. No external plugin code runs."""
import ctypes as C
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PluginTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.compilation = tempfile.TemporaryDirectory(prefix="qwen-x86-plugin-build-")
        build = Path(cls.compilation.name)
        objects = []
        for name in ["plugins", "json"]:
            obj = build / (name + ".o")
            subprocess.run(["as", "-I", str(ROOT / "src"), "-o", str(obj), str(ROOT / "src" / (name + ".s"))], check=True)
            objects.append(str(obj))
        cls.library = build / "plugins.so"
        subprocess.run(["ld", "-shared", "-Bsymbolic", "-z", "noexecstack", "-o", str(cls.library), *objects], check=True)
        cls.lib = C.CDLL(str(cls.library))
        cls.lib.plugins_init.argtypes = [C.c_char_p, C.c_char_p]
        cls.lib.plugins_init.restype = C.c_long
        cls.lib.plugins_expand.argtypes = [C.c_char_p, C.c_void_p, C.c_size_t]
        cls.lib.plugins_expand.restype = C.c_long
        cls.lib.plugins_list.argtypes = [C.c_void_p, C.c_size_t]
        cls.lib.plugins_list.restype = C.c_long
        cls.lib.plugins_set_mcp_callback.argtypes = [C.c_void_p]
        cls.lib.plugins_set_mcp_callback.restype = C.c_long

    @classmethod
    def tearDownClass(cls):
        cls.compilation.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="qwen-x86-plugin-fixture-")
        self.base = Path(self.temporary.name)
        self.home, self.cwd = self.base / "home", self.base / "workspace"
        self.home.mkdir()
        self.cwd.mkdir()
        self.lib.plugins_set_mcp_callback(None)

    def tearDown(self):
        self.lib.plugins_set_mcp_callback(None)
        self.temporary.cleanup()

    def install(self, name="workspace-tools", *, project=False, commands=None, skills=None, manifest=None, dirname=None):
        parent = self.cwd / ".qwen-go/plugins" if project else self.home / ".config/qwen-go/plugins"
        plugin = parent / (dirname or name)
        plugin.mkdir(parents=True)
        meta = manifest if manifest is not None else {"name": name, "version": "1", "description": "Useful native prompt helpers"}
        (plugin / "qwen-extension.json").write_text(json.dumps(meta) if not isinstance(meta, str) else meta)
        for key, value in (commands or {}).items():
            path = plugin / "commands" / (key + ".md")
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(value.encode() if isinstance(value, str) else value)
        for key, value in (skills or {}).items():
            path = plugin / "skills" / key / "SKILL.md"
            path.parent.mkdir(parents=True)
            path.write_text(value)
        return plugin

    def initialize(self):
        self.assertEqual(self.lib.plugins_init(os.fsencode(self.cwd), os.fsencode(self.home)), 0)

    def expand(self, text, capacity=65536):
        out = C.create_string_buffer(max(1, capacity))
        encoded = text.encode() if isinstance(text, str) else text
        result = self.lib.plugins_expand(encoded, out, capacity)
        if result >= 0:
            self.assertEqual(result, len(out.value))
        return result, out.value

    def catalogue(self, capacity=65536):
        out = C.create_string_buffer(max(1, capacity))
        result = self.lib.plugins_list(out, capacity)
        return result, out.value.decode()

    def test_workspace_tools_format_commands_skills_and_frontmatter(self):
        self.install(commands={"review": "---\ndescription: Check the files\n---\nReview independently. Focus: $ARGUMENTS\n", "test-plan": "Find meaningful tests."},
            skills={"review": "---\nname: evidence-review\ndescription: Evidence first\n---\nReport confirmed findings. $ARGUMENTS"},
            manifest={"name": "workspace-tools", "description": "Read-only review and test planning", "mcpServers": {"git": {"command": "qwen-go", "args": ["mcp-serve"]}}})
        self.initialize()
        result, body = self.expand("/workspace-tools:review recent changes")
        self.assertGreater(result, 0)
        self.assertEqual(body, b"Review independently. Focus: recent changes\n")
        self.assertEqual(self.expand("/skill workspace-tools:evidence-review safety")[1], b"Report confirmed findings. safety")
        result, listing = self.catalogue()
        self.assertGreater(result, 0)
        self.assertIn("/workspace-tools:review", listing)
        self.assertIn("/skill workspace-tools:evidence-review", listing)
        self.assertIn("MCP configured: unsupported", listing)
        self.assertNotIn("description: Evidence", body.decode())

    def test_literal_multiple_argument_substitutions_preserve_utf8(self):
        self.install(commands={"echo": "$ARGUMENTS / $ARGUMENTS", "append": "Instructions only"})
        self.initialize()
        self.assertEqual(self.expand("/workspace-tools:echo café 世界")[1], "café 世界 / café 世界".encode())
        self.assertEqual(self.expand("/workspace-tools:append extra focus")[1], b"Instructions only\n\nArguments: extra focus")
        self.assertEqual(self.expand("/workspace-tools:echo")[1], b" / ")
        self.assertEqual(self.expand("/workspace-tools:append")[1], b"Instructions only")

    def test_qualified_commands_avoid_cross_plugin_collisions(self):
        self.install("one", commands={"review": "First plugin"})
        self.install("two", commands={"review": "Second plugin"})
        self.initialize()
        self.assertEqual(self.expand("/one:review")[1], b"First plugin")
        self.assertEqual(self.expand("/two:review")[1], b"Second plugin")
        self.assertEqual(self.expand("/review")[0], -1)
        self.assertEqual(self.expand("/help")[0], -1)
        self.assertEqual(self.expand("plain user prompt")[0], -1)

    def test_project_plugin_has_precedence_over_same_user_plugin(self):
        self.install("same", commands={"review": "User"})
        self.install("same", project=True, commands={"review": "Project"})
        self.initialize()
        self.assertEqual(self.expand("/same:review")[1], b"Project")
        self.assertEqual(self.catalogue()[1].count("/same:review"), 1)

    def test_invalid_and_oversized_manifests_are_rejected(self):
        fixtures = ["{", "[]", {"name": "../bad"}, {"name": "bad:name"}, {"name": "bad\x00hidden"}, {"name": "bad", "description": []}, {"name": "bad", "description": "x" * 300}, {"name": "bad", "description": "\x1b[2J"}]
        for i, meta in enumerate(fixtures):
            self.install("bad", dirname=f"bad{i}", commands={"run": "Should not load"}, manifest=meta)
        self.install("huge", dirname="too-large", commands={"run": "Should not load"}, manifest='{"name":"huge","padding":"' + "x" * 20000 + '"}')
        self.initialize()
        self.assertEqual(self.expand("/bad:run")[0], -1)
        self.assertEqual(self.expand("/huge:run")[0], -1)
        self.assertIn("skipped", self.catalogue()[1])

    def test_symlink_manifest_commands_skills_and_plugin_directories_are_not_followed(self):
        outside = self.base / "outside"
        outside.mkdir()
        (outside / "payload.md").write_text("EXTERNAL SECRET")
        plugin = self.install(commands={"safe": "Safe"})
        (plugin / "commands/evil.md").symlink_to(outside / "payload.md")
        (plugin / "skills").mkdir()
        (outside / "SKILL.md").write_text("EXTERNAL SECRET")
        (plugin / "skills/evil").symlink_to(outside, target_is_directory=True)
        sibling = plugin.parent / "linked"
        sibling.symlink_to(plugin, target_is_directory=True)
        bad = self.install("bad-manifest")
        (bad / "qwen-extension.json").unlink()
        (outside / "manifest.json").write_text('{"name":"stolen"}')
        (bad / "qwen-extension.json").symlink_to(outside / "manifest.json")
        self.initialize()
        self.assertEqual(self.expand("/workspace-tools:safe")[1], b"Safe")
        self.assertEqual(self.expand("/workspace-tools:evil")[0], -1)
        self.assertEqual(self.expand("/skill workspace-tools:evil")[0], -1)
        self.assertEqual(self.expand("/stolen:anything")[0], -1)

    def test_symlink_root_path_component_is_not_followed(self):
        alternate = self.base / "alternate"
        (alternate / "qwen-go/plugins/hidden/commands").mkdir(parents=True)
        (alternate / "qwen-go/plugins/hidden/qwen-extension.json").write_text('{"name":"hidden"}')
        (alternate / "qwen-go/plugins/hidden/commands/run.md").write_text("Hidden")
        (self.home / ".config").symlink_to(alternate, target_is_directory=True)
        self.initialize()
        self.assertEqual(self.expand("/hidden:run")[0], -1)

    def test_path_traversal_and_qualifier_injection_are_rejected(self):
        self.install(commands={"review": "Safe"})
        self.initialize()
        for text in ["/workspace-tools:../review", "/../workspace-tools:review", "/workspace-tools:review/../evil", "/workspace-tools:review:other", "/skill workspace-tools:../evil"]:
            with self.subTest(text=text):
                self.assertEqual(self.expand(text)[0], -2)

    def test_unterminated_frontmatter_nul_and_bad_skill_name_are_rejected(self):
        self.install(commands={"bad": "---\nno terminator", "nul": b"hello\x00hidden", "good": "---\r\ndescription: test\r\n---\r\nBody\r\n"},
            skills={"bad": "---\nname: ../evil\n---\nBad", "quoted": "---\nname: 'safe-skill'\n---\nSafe skill"})
        self.initialize()
        self.assertEqual(self.expand("/workspace-tools:bad")[0], -1)
        self.assertEqual(self.expand("/workspace-tools:nul")[0], -1)
        self.assertEqual(self.expand("/workspace-tools:good")[1], b"Body\r\n")
        self.assertEqual(self.expand("/skill workspace-tools:safe-skill")[1], b"Safe skill")

    def test_prompt_and_output_bounds_fail_without_truncated_execution(self):
        self.install(commands={"large": "x" * 65536, "echo": "prefix $ARGUMENTS suffix"})
        self.initialize()
        self.assertEqual(self.expand("/workspace-tools:large")[0], -1)
        result, out = self.expand("/workspace-tools:echo " + "y" * 64, capacity=16)
        self.assertEqual(result, -2)
        self.assertEqual(out, b"")
        self.assertEqual(self.expand("/workspace-tools:echo", capacity=0)[0], -2)
        self.assertEqual(self.catalogue(capacity=5), (-2, ""))

    def test_registry_bounds_and_repeat_initialization(self):
        self.install("many", commands={f"cmd{i}": f"Prompt{i}" for i in range(40)})
        for i in range(18):
            self.install(f"plugin{i}")
        self.initialize()
        listing = self.catalogue()[1]
        self.assertLessEqual(sum(line.startswith("  /many:") for line in listing.splitlines()), 32)
        self.assertLessEqual(sum(" — " in line for line in listing.splitlines()), 16)
        shutil.rmtree(self.home / ".config/qwen-go/plugins")
        self.initialize()
        self.assertIn("No prompt or skill plugins loaded", self.catalogue()[1])

    def test_mcp_callback_borrows_raw_json_and_canonical_root_without_starting_code(self):
        marker = self.base / "must-not-exist"
        servers = {"git": {"command": "/bin/sh", "args": ["-c", f"touch {marker}"]}}
        plugin = self.install(manifest={"name": "workspace-tools", "description": "Safe metadata", "mcpServers": servers, "hooks": {"startup": f"touch {marker}"}}, commands={"review": "Review only"})
        seen = []
        callback_type = C.CFUNCTYPE(C.c_long, C.c_char_p, C.c_char_p, C.c_void_p, C.c_size_t)
        def collect(name, root, raw, length):
            seen.append((name.decode(), os.fsdecode(root), json.loads(C.string_at(raw, length))))
            return 0
        callback = callback_type(collect)
        self.lib.plugins_set_mcp_callback(callback)
        self.initialize()
        self.assertEqual(seen, [("workspace-tools", str(plugin.resolve()), servers)])
        self.assertFalse(marker.exists())
        self.assertIn("server startup and tool calls require approval", self.catalogue()[1])
        self.assertEqual(self.expand("/workspace-tools:review")[1], b"Review only")
        reject = callback_type(lambda *_: -1)
        self.lib.plugins_set_mcp_callback(reject)
        self.initialize()
        self.assertIn("configuration rejected or unavailable", self.catalogue()[1])
        self.assertFalse(marker.exists())

    def test_fifo_manifest_and_command_entries_never_block_discovery(self):
        broken = self.install("fifo-manifest")
        (broken / "qwen-extension.json").unlink()
        os.mkfifo(broken / "qwen-extension.json")
        good = self.install("good", commands={"safe": "Safe prompt"})
        os.mkfifo(good / "commands/blocked.md")
        started = time.monotonic()
        self.initialize()
        self.assertLess(time.monotonic() - started, 1)
        self.assertEqual(self.expand("/good:safe")[1], b"Safe prompt")
        self.assertEqual(self.expand("/good:blocked")[0], -1)

    def test_no_linked_runtime(self):
        dynamic = subprocess.check_output(["readelf", "-d", str(self.library)], text=True)
        self.assertNotIn("(NEEDED)", dynamic)


if __name__ == "__main__":
    unittest.main()
