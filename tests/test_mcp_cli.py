"""Real static ELF -> mock model -> manifest -> same native ELF MCP server.
Only the model endpoint is a Python fixture; application and MCP server are both
production assembly. No TLS stub or alternate application objects are linked.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_cli import Server, answer, tool_events, disable_core

ROOT = Path(__file__).resolve().parents[1]


class MCPNativeCLI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['make', '-s', 'qwen-x86'], cwd=ROOT, check=True)
        cls.binary = ROOT / 'qwen-x86'

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='qwen-x86-mcp-cli-')
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.workspace = self.root / 'workspace'
        self.home.mkdir()
        self.workspace.mkdir()
        self.content = 'Native MCP file contents: café 世界 🎵\n'
        (self.workspace / 'evidence.txt').write_text(self.content)
        plugin = self.workspace / '.qwen-go/plugins/native-workspace'
        plugin.mkdir(parents=True)
        (plugin / 'qwen-extension.json').write_text(json.dumps({
            'name': 'native-workspace', 'version': '1',
            'mcpServers': {'files': {'command': str(self.binary),
                'args': ['--cwd', '${extensionPath}/../../..', '--mcp-serve']}}
        }))
        self.env = dict(os.environ)
        for key in ['OPENAI_API_KEY', 'OPENAI_BASE_URL', 'OPENAI_MODEL',
                    'QWEN_API_KEY', 'QWEN_BASE_URL', 'QWEN_MODEL']:
            self.env.pop(key, None)
        self.env.update(HOME=str(self.home), QWEN_API_KEY='dummy-local-mcp-fixture-key')

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, server, *flags):
        return subprocess.run([str(self.binary), '--cwd', str(self.workspace),
            '--base-url', server.url, '--no-save', '--prompt', 'Use the native workspace MCP to read evidence.txt.',
            *flags], env=self.env, capture_output=True, timeout=10, preexec_fn=disable_core)

    @staticmethod
    def tools(request):
        return {tool['function']['name']: tool['function'] for tool in request['tools']}

    @staticmethod
    def last_tool(request):
        return [message for message in request['messages'] if message['role'] == 'tool'][-1]['content']

    def test_production_elf_discovers_and_calls_native_mcp_read_file(self):
        discovered = []

        def list_servers(request):
            names = self.tools(request)
            self.assertIn('list_mcp_servers', names)
            self.assertIn('connect_mcp_server', names)
            self.assertFalse(any(name.startswith('mcp_') for name in names))
            return tool_events([('list_mcp_servers', {})])

        def connect_server(request):
            self.assertIn('native-workspace:files', self.last_tool(request))
            self.assertIn('disconnected', self.last_tool(request))
            return tool_events([('connect_mcp_server', {'server': 'native-workspace:files'})])

        def call_discovered(request):
            self.assertIn('connected;', self.last_tool(request))
            native = {name: tool for name, tool in self.tools(request).items() if name.startswith('mcp_')}
            self.assertEqual(len(native), 2)
            read_name = next(name for name in native if name.endswith('_read_file'))
            self.assertEqual(native[read_name]['parameters']['required'], ['path'])
            discovered.append(read_name)
            return tool_events([(read_name, {'path': 'evidence.txt'})], fragmented=True)

        def finish(request):
            self.assertEqual(self.last_tool(request), self.content)
            self.assertIn(discovered[0], self.tools(request))
            return answer('Native MCP verified.')

        with Server([list_servers, connect_server, call_discovered, finish]) as server:
            result = self.run_cli(server, '--yes')
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertIn(b'Native MCP verified.', result.stdout)
        self.assertEqual(len(server.requests), 4)
        self.assertEqual((self.workspace / 'evidence.txt').read_text(), self.content)

    def test_headless_connection_requires_explicit_yes(self):
        def connect_server(request):
            return tool_events([('connect_mcp_server', {'server': 'native-workspace:files'})])

        def denied(request):
            self.assertIn('denied', self.last_tool(request))
            self.assertFalse(any(name.startswith('mcp_') for name in self.tools(request)))
            return answer('Approval boundary verified.')

        with Server([connect_server, denied]) as server:
            result = self.run_cli(server)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertIn(b'Approval boundary verified.', result.stdout)


if __name__ == '__main__':
    unittest.main()
