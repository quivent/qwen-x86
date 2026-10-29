"""Native on-disk management, no commands/hooks or model invocations."""
import ctypes as C,json,os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
RAW=b'---\nname: reviewer\ndescription: Review code\ntools: [read_file, search_files]\ncolor: blue\nunknownKey: keep me\n---\n\nReview changes carefully.\n'
class ManagementTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.build=tempfile.TemporaryDirectory();base=pathlib.Path(cls.build.name)
  for name in ['ui_management','json','plugins','http','net']:
   subprocess.run(['as','--64','-I',str(ROOT/'src'),str(ROOT/f'src/{name}.s'),'-o',str(base/f'{name}.o')],check=True)
  stub=base/'tls_fixture.s';stub.write_text('.intel_syntax noprefix\n.text\n.global tls_connect,tls_read,tls_write,tls_close,tls_pending,tls_after_fork\ntls_connect:\ntls_read:\ntls_write:\n mov rax,-95\n ret\ntls_close:\ntls_pending:\ntls_after_fork:\n xor eax,eax\n ret\n.section .note.GNU-stack,"",@progbits\n');subprocess.run(['as','--64',str(stub),'-o',str(base/'tls_fixture.o')],check=True)
  subprocess.run(['ld','-shared','-Bsymbolic',*[str(base/(n+'.o')) for n in ['ui_management','json','plugins','http','net','tls_fixture']],'-o' ,str(base/'management.so')],check=True)
  cls.lib=C.CDLL(str(base/'management.so'))
  apis={'ui_management_config':([C.c_char_p,C.c_char_p,C.c_int],C.c_int64),'ui_agent_catalog':([C.c_void_p,C.c_size_t],C.c_int64),'ui_extension_catalog':([C.c_void_p,C.c_size_t],C.c_int64),'ui_management_item_scope':([C.c_size_t],C.c_int64),'ui_agent_read':([C.c_char_p,C.c_void_p,C.c_size_t],C.c_int64),'ui_agent_save':([C.c_char_p,C.c_void_p,C.c_size_t,C.c_int],C.c_int64),'ui_agent_delete':([C.c_char_p],C.c_int64),'ui_extension_read':([C.c_char_p,C.c_void_p,C.c_size_t],C.c_int64),'ui_extension_enabled':([C.c_char_p],C.c_int64),'ui_extension_set_enabled':([C.c_char_p,C.c_int],C.c_int64),'ui_extension_uninstall':([C.c_char_p],C.c_int64),'ui_agent_definition_read':([C.c_char_p,C.c_void_p,C.c_size_t],C.c_int64),'ui_agent_definition_path':([],C.c_void_p),'ui_agent_prompt':([C.c_char_p,C.c_void_p,C.c_size_t],C.c_int64),'ui_extension_discover':([C.c_char_p,C.c_void_p,C.c_size_t,C.c_void_p],C.c_int64),'ui_extension_discover_item_read':([C.c_size_t,C.c_void_p,C.c_size_t],C.c_int64),'ui_extension_install':([C.c_char_p,C.c_char_p,C.c_int,C.c_void_p],C.c_int64),'ui_extension_update':([C.c_char_p,C.c_void_p],C.c_int64),'ui_management_set_cancel':([C.c_void_p],C.c_int64),'ui_management_last_error':([],C.c_void_p),'ui_extension_source_catalog':([C.c_void_p,C.c_size_t],C.c_int64),'ui_extension_source_add':([C.c_char_p,C.c_char_p],C.c_int64),'ui_extension_source_remove':([C.c_char_p],C.c_int64),'ui_extension_sources_read':([C.c_void_p,C.c_size_t],C.c_int64),'ui_extension_favorite':([C.c_char_p,C.c_int],C.c_int64),'ui_extension_is_favorite':([C.c_char_p],C.c_int64),'plugins_init':([C.c_char_p,C.c_char_p],C.c_int64),'plugins_expand':([C.c_char_p,C.c_void_p,C.c_size_t],C.c_int64)}
  for name,(args,result) in apis.items():fn=getattr(cls.lib,name);fn.argtypes=args;fn.restype=result
 @classmethod
 def tearDownClass(cls):cls.build.cleanup()
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.base=pathlib.Path(self.tmp.name);self.home=self.base/'home';self.cwd=self.base/'project';self.home.mkdir();self.cwd.mkdir();self.configure();self.lib.ui_management_set_cancel(None)
 def configure(self,save=1):self.assertEqual(self.lib.ui_management_config(os.fsencode(self.home),os.fsencode(self.cwd),save),0)
 def catalog(self,extensions=False,cap=64):
  items=(C.c_void_p*192)();n=(self.lib.ui_extension_catalog if extensions else self.lib.ui_agent_catalog)(items,cap);self.assertGreaterEqual(n,0)
  return [tuple(C.string_at(items[i*3+j]).decode() for j in range(3)) for i in range(n)]
 def save(self,name='reviewer',raw=RAW,scope=1):return self.lib.ui_agent_save(name.encode(),raw,len(raw),scope)
 def test_agent_create_catalog_read_edit_delete_real_scopes(self):
  self.assertEqual(self.save(scope=0),0);self.assertEqual(self.save(scope=1),0)
  rows=self.catalog();self.assertEqual([r[1] for r in rows],['Project','User']);self.assertEqual([r[0] for r in rows],['reviewer','reviewer']);self.assertEqual(self.lib.ui_management_item_scope(0),1);self.assertEqual(self.lib.ui_management_item_scope(1),0)
  target=self.cwd/'.qwen/agents/reviewer.md';self.assertEqual(rows[0][2],str(target));self.assertEqual(target.read_bytes(),RAW);self.assertEqual(target.stat().st_mode&0o777,0o600)
  out=C.create_string_buffer(65537);self.assertEqual(self.lib.ui_agent_read(os.fsencode(target),out,len(out)),len(RAW));self.assertEqual(out.value,RAW)
  edited=RAW.replace(b'Review changes',b'Inspect changes');self.assertEqual(self.save(raw=edited),0);self.assertEqual(target.read_bytes(),edited);self.assertIn(b'unknownKey: keep me',out.value)
  self.assertEqual(self.lib.ui_agent_delete(os.fsencode(target)),0);self.assertFalse(target.exists());self.assertEqual(len(self.catalog()),1)
 def test_invalid_names_payload_and_no_save_do_not_mutate(self):
  for name in ['../escape','bad/name','', 'a'*64]:self.assertLess(self.save(name=name),0)
  for raw in [b'no yaml',b'---\nname: nope\n',RAW+b'\x00bad',RAW+b'\xff',RAW*1000]:self.assertLess(self.save(raw=raw),0)
  self.assertFalse((self.cwd/'.qwen').exists());self.configure(0);self.assertEqual(self.save(),-13);self.assertFalse((self.cwd/'.qwen').exists())
 def test_no_follow_owner_regular_and_outside_confinement(self):
  self.assertEqual(self.save(),0);agent=self.cwd/'.qwen/agents/reviewer.md';outside=self.base/'outside.md';outside.write_bytes(RAW)
  link=agent.parent/'linked.md';link.symlink_to(outside);os.mkfifo(agent.parent/'fifo.md');(agent.parent/'malformed.md').write_text('not an agent')
  rows=self.catalog();self.assertEqual([r[0] for r in rows],['reviewer'])
  out=C.create_string_buffer(65537)
  for p in [outside,link,agent.parent/'fifo.md',agent.parent/'../escape.md']:
   self.assertLess(self.lib.ui_agent_read(os.fsencode(p),out,len(out)),0);self.assertLess(self.lib.ui_agent_delete(os.fsencode(p)),0)
  self.assertTrue(outside.exists());self.assertTrue(link.is_symlink())
  # Atomic update replaces the symlink itself, leaving its target untouched.
  self.assertEqual(self.save(name='linked'),0);self.assertFalse(link.is_symlink());self.assertEqual(outside.read_bytes(),RAW)
 def test_catalog_bounded_and_fd_cleanup(self):
  for i in range(70):self.assertEqual(self.save(name=f'agent-{i}'),0)
  self.assertEqual(len(self.catalog(cap=3)),3);before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for _ in range(10):self.assertEqual(len(self.catalog()),64)
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before);self.assertFalse(list((self.cwd/'.qwen/agents').glob('.qwen-tmp-*')))
 def test_extension_catalog_reads_only_real_strict_manifests(self):
  for base,label in [(self.home,'User'),(self.cwd,'Project')]:
   d=base/'.qwen/extensions/example';d.mkdir(parents=True);(d/'qwen-extension.json').write_text(json.dumps({'name':'example','version':'1.0','description':'local plugin','mcpServers':{'danger':{'command':'must-not-execute'}}}))
  broken=self.cwd/'.qwen/extensions/broken';broken.mkdir();(broken/'qwen-extension.json').write_text('[broken')
  linked=self.cwd/'.qwen/extensions/linked';linked.symlink_to(self.home/'.qwen/extensions/example',target_is_directory=True)
  rows=self.catalog(True);self.assertEqual([r[1] for r in rows],['Project · enabled','User · enabled']);self.assertEqual([r[0] for r in rows],['example','example']);self.assertTrue(all(r[2].endswith('/example/qwen-extension.json') for r in rows))

 def test_extension_enable_disable_and_recursive_uninstall_no_follow(self):
  d=self.cwd/'.qwen/extensions/example';d.mkdir(parents=True);manifest=d/'qwen-extension.json';payload={'name':'example','version':'1','mcpServers':{'evil':{'command':'must-not-run'}}};manifest.write_text(json.dumps(payload));path=os.fsencode(manifest)
  out=C.create_string_buffer(65537);self.assertGreater(self.lib.ui_extension_read(path,out,len(out)),0);self.assertEqual(json.loads(out.value),payload)
  self.assertEqual(self.lib.ui_extension_is_favorite(path),0);self.assertEqual(self.lib.ui_extension_favorite(path,1),0);self.assertEqual(self.lib.ui_extension_is_favorite(path),1);self.assertEqual(self.lib.ui_extension_favorite(path,0),0);self.assertEqual(self.lib.ui_extension_is_favorite(path),0)
  self.assertEqual(self.lib.ui_extension_enabled(path),1);self.assertEqual(self.lib.ui_extension_set_enabled(path,0),0);self.assertEqual(self.lib.ui_extension_enabled(path),0);self.assertIn('disabled',self.catalog(True)[0][1]);marker=d/'.qwen-x86-disabled';self.assertEqual(marker.stat().st_mode&0o777,0o600)
  self.configure(0);self.assertEqual(self.lib.ui_extension_set_enabled(path,1),-13);self.assertEqual(self.lib.ui_extension_uninstall(path),-13);self.assertTrue(manifest.exists());self.configure()
  self.assertEqual(self.lib.ui_extension_set_enabled(path,1),0);self.assertEqual(self.lib.ui_extension_enabled(path),1);self.assertFalse(marker.exists())
  outside=self.base/'outside';outside.mkdir();(outside/'keep.txt').write_text('keep');(d/'link').symlink_to(outside,target_is_directory=True);nested=d/'nested dir/other';nested.mkdir(parents=True);(nested/'λ.txt').write_text('local');os.mkfifo(d/'fifo')
  self.assertEqual(self.lib.ui_extension_uninstall(path),0);self.assertFalse(d.exists());self.assertEqual((outside/'keep.txt').read_text(),'keep');self.assertEqual(self.catalog(True),[])
 def test_extension_actions_reject_unconfigured_and_linked_paths_no_fd_leak(self):
  d=self.cwd/'.qwen/extensions/example';d.mkdir(parents=True);manifest=d/'qwen-extension.json';manifest.write_text('{"name":"example","version":"1"}');outside=self.base/'qwen-extension.json';outside.write_text('{}');linked=d.parent/'linked';linked.symlink_to(d,target_is_directory=True)
  for p in [outside,linked/'qwen-extension.json',d/'../example/qwen-extension.json']:
   self.assertLess(self.lib.ui_extension_set_enabled(os.fsencode(p),0),0);self.assertLess(self.lib.ui_extension_uninstall(os.fsencode(p)),0)
  before=len(list(pathlib.Path('/proc/self/fd').iterdir()))
  for i in range(10):self.assertEqual(self.lib.ui_extension_set_enabled(os.fsencode(manifest),i%2),0);self.assertIn(self.lib.ui_extension_enabled(os.fsencode(manifest)),[0,1])
  self.assertEqual(len(list(pathlib.Path('/proc/self/fd').iterdir())),before)

 def test_disabled_extension_is_not_registered_by_actual_native_loader(self):
  d=self.cwd/'.qwen/extensions/native-demo';d.mkdir(parents=True);manifest=d/'qwen-extension.json';manifest.write_text('{"name":"native-demo","version":"1","description":"real prompt plugin"}');(d/'commands').mkdir();(d/'commands/review.md').write_text('Review $ARGUMENTS carefully.')
  out=C.create_string_buffer(65536)
  self.assertEqual(self.lib.plugins_init(os.fsencode(self.cwd),os.fsencode(self.home)),0);self.assertGreater(self.lib.plugins_expand(b'/native-demo:review changes',out,len(out)),0);self.assertEqual(out.value,b'Review changes carefully.')
  self.assertEqual(self.lib.ui_extension_set_enabled(os.fsencode(manifest),0),0);self.assertEqual(self.lib.plugins_init(os.fsencode(self.cwd),os.fsencode(self.home)),0);self.assertLess(self.lib.plugins_expand(b'/native-demo:review changes',out,len(out)),0)
  self.assertEqual(self.lib.ui_extension_set_enabled(os.fsencode(manifest),1),0);self.assertEqual(self.lib.plugins_init(os.fsencode(self.cwd),os.fsencode(self.home)),0);self.assertGreater(self.lib.plugins_expand(b'/native-demo:review changes',out,len(out)),0)
  self.assertEqual(self.lib.ui_extension_uninstall(os.fsencode(manifest)),0);self.assertEqual(self.lib.plugins_init(os.fsencode(self.cwd),os.fsencode(self.home)),0);self.assertLess(self.lib.plugins_expand(b'/native-demo:review changes',out,len(out)),0)

 def test_real_source_registry_add_replace_remove_preserves_unknown_fields(self):
  directory=self.home/'.qwen/extensions';directory.mkdir(parents=True);registry=directory/'marketplaces.json';original=[{'name':'one','source':'https://example.org/one','unknown':{'keep':[1,2]}},{'name':'two','source':'/local/path'}];registry.write_text(json.dumps(original))
  items=(C.c_void_p*192)();self.assertEqual(self.lib.ui_extension_source_catalog(items,64),2);self.assertEqual(C.string_at(items[0]),b'one');self.assertEqual(C.string_at(items[1]),b'https://example.org/one')
  self.assertEqual(self.lib.ui_extension_source_add(b'three','/path with spaces/λ'.encode()),0);new=json.loads(registry.read_text());self.assertEqual(new[:2],original);self.assertEqual(new[2],{'name':'three','source':'/path with spaces/λ'});self.assertEqual(registry.stat().st_mode&0o777,0o600)
  self.assertEqual(self.lib.ui_extension_source_add(b'renamed',b'/local/path'),0);new=json.loads(registry.read_text());self.assertEqual([row['name'] for row in new],['one','three','renamed']);self.assertEqual(new[0],original[0])
  self.assertEqual(self.lib.ui_extension_source_remove(b'three'),0);self.assertEqual([row['name'] for row in json.loads(registry.read_text())],['one','renamed'])
  out=C.create_string_buffer(65537);self.assertGreater(self.lib.ui_extension_sources_read(out,len(out)),0);self.assertEqual(json.loads(out.value),json.loads(registry.read_text()))
  self.configure(0);before=registry.read_bytes();self.assertEqual(self.lib.ui_extension_source_add(b'blocked',b'/blocked'),-13);self.assertEqual(self.lib.ui_extension_source_remove(b'one'),-13);self.assertEqual(registry.read_bytes(),before)
 def test_source_registry_corruption_not_overwritten_and_missing_empty(self):
  out=C.create_string_buffer(65537);self.assertEqual(self.lib.ui_extension_sources_read(out,len(out)),2);self.assertEqual(out.value,b'[]')
  directory=self.home/'.qwen/extensions';directory.mkdir(parents=True);registry=directory/'marketplaces.json';registry.write_text('[corrupt')
  self.assertLess(self.lib.ui_extension_source_add(b'new',b'/new'),0);self.assertEqual(registry.read_text(),'[corrupt')

 def repository(self,name='real-plugin',valid=True):
  repo=self.base/'source repository λ';repo.mkdir();subprocess.run(['git','init','-q',str(repo)],check=True)
  (repo/'qwen-extension.json').write_text(json.dumps({'name':name,'version':'1'}) if valid else '[broken');(repo/'commands').mkdir();(repo/'commands/real.md').write_text('real installed prompt $ARGUMENTS')
  self.commit(repo);return repo
 def commit(self,repo):
  subprocess.run(['git','-C',str(repo),'add','.'],check=True);subprocess.run(['git','-C',str(repo),'-c','user.name=Fixture','-c','user.email=fixture@example.test','commit','-qm','fixture'],check=True)
 def environment(self):
  env=[os.fsencode(k+'='+v) for k,v in os.environ.items()];return (C.c_char_p*(len(env)+1))(*env,None)
 def test_real_git_install_atomic_update_preserves_state_and_refreshes_prompts(self):
  repo=self.repository();env=self.environment();self.assertEqual(self.lib.ui_extension_install(os.fsencode(repo),b'real-plugin',1,env),0,C.string_at(self.lib.ui_management_last_error()))
  target=self.cwd/'.qwen/extensions/real-plugin';manifest=target/'qwen-extension.json';self.assertTrue(manifest.exists());self.assertEqual(json.loads((target/'.qwen-x86-source.json').read_text()),str(repo));self.assertEqual(self.lib.ui_extension_set_enabled(os.fsencode(manifest),0),0);self.assertEqual(self.lib.ui_extension_favorite(os.fsencode(manifest),1),0)
  (repo/'commands/real.md').write_text('updated installed prompt $ARGUMENTS');self.commit(repo)
  self.assertEqual(self.lib.ui_extension_update(os.fsencode(manifest),env),0,C.string_at(self.lib.ui_management_last_error()));self.assertEqual((target/'commands/real.md').read_text(),'updated installed prompt $ARGUMENTS');self.assertEqual(self.lib.ui_extension_enabled(os.fsencode(manifest)),0);self.assertEqual(self.lib.ui_extension_is_favorite(os.fsencode(manifest)),1)
  self.assertFalse(list(target.parent.glob('.install-*')))
  # Explicit enable and actual native loader see the updated artifact.
  self.assertEqual(self.lib.ui_extension_set_enabled(os.fsencode(manifest),1),0);self.assertEqual(self.lib.plugins_init(os.fsencode(self.cwd),os.fsencode(self.home)),0);out=C.create_string_buffer(65536);self.assertGreater(self.lib.plugins_expand(b'/real-plugin:real now',out,len(out)),0);self.assertEqual(out.value,b'updated installed prompt now')
 def test_install_rejects_mismatch_invalid_manifest_no_save_and_option_injection(self):
  repo=self.repository(valid=False);env=self.environment()
  self.assertLess(self.lib.ui_extension_install(os.fsencode(repo),b'real-plugin',1,env),0);self.assertFalse((self.cwd/'.qwen/extensions/real-plugin').exists());self.assertFalse(list((self.cwd/'.qwen/extensions').glob('.install-*')))
  for source in [b'--upload-pack=evil',b'ext::touch /tmp/must-not-run',b'https://example.invalid/\nattack']:
   self.assertEqual(self.lib.ui_extension_install(source,b'real-plugin',1,env),-22)
  self.configure(0);self.assertEqual(self.lib.ui_extension_install(os.fsencode(repo),b'real-plugin',1,env),-13)
 def test_existing_install_never_overwritten_and_failed_update_preserves_original(self):
  repo=self.repository();env=self.environment();self.assertEqual(self.lib.ui_extension_install(os.fsencode(repo),b'real-plugin',0,env),0);target=self.home/'.qwen/extensions/real-plugin';manifest=target/'qwen-extension.json';original=(target/'commands/real.md').read_bytes()
  self.assertLess(self.lib.ui_extension_install(os.fsencode(repo),b'real-plugin',0,env),0);self.assertEqual((target/'commands/real.md').read_bytes(),original)
  (repo/'qwen-extension.json').write_text('{"name":"wrong-name","version":"2"}');self.commit(repo);self.assertLess(self.lib.ui_extension_update(os.fsencode(manifest),env),0);self.assertEqual((target/'commands/real.md').read_bytes(),original);self.assertEqual(json.loads(manifest.read_text())['name'],'real-plugin');self.assertFalse(list(target.parent.glob('.install-*')))
 def test_explicit_cancel_git_child_does_not_commit_or_leak_staging(self):
  repo=self.repository();env=self.environment();callback_type=C.CFUNCTYPE(C.c_int64)
  @callback_type
  def cancel():return -125
  self.lib.ui_management_set_cancel(cancel)
  self.assertEqual(self.lib.ui_extension_install(os.fsencode(repo),b'real-plugin',1,env),-125);self.lib.ui_management_set_cancel(None);self.assertFalse((self.cwd/'.qwen/extensions/real-plugin').exists());self.assertFalse(list((self.cwd/'.qwen/extensions').glob('.install-*')))

 def discover(self,source):
  items=(C.c_void_p*192)();n=self.lib.ui_extension_discover(os.fsencode(source),items,64,self.environment())
  self.assertGreaterEqual(n,0);return [tuple(C.string_at(items[i*3+j]).decode() for j in range(3)) for i in range(n)]
 def test_local_marketplace_discovery_and_real_metadata_are_read_only(self):
  source=self.base/'marketplace';(source/'.claude-plugin').mkdir(parents=True);metadata={'name':'fixture','plugins':[{'name':'local-plugin','description':'Useful λ metadata','source':'./plugins/local-plugin','version':'2','author':{'name':'Author'},'skills':['./skills/a']},{'name':'external','description':'Remote','source':{'source':'github','repo':'owner/repo'}},{'name':'escape','source':'../outside'}]};manifest=source/'.claude-plugin/marketplace.json';manifest.write_text(json.dumps(metadata));before=(manifest.read_bytes(),manifest.stat().st_mtime_ns)
  rows=self.discover(source);self.assertEqual(rows,[('local-plugin','Useful λ metadata',str(source/'plugins/local-plugin')),('external','Remote','https://github.com/owner/repo')]);out=C.create_string_buffer(65537);self.assertGreater(self.lib.ui_extension_discover_item_read(0,out,len(out)),0);self.assertEqual(json.loads(out.value),metadata['plugins'][0]);self.assertEqual((manifest.read_bytes(),manifest.stat().st_mtime_ns),before)
  self.assertFalse((self.home/'.qwen').exists());self.assertEqual(self.discover(manifest),[('local-plugin','Useful λ metadata',str(source/'.claude-plugin/plugins/local-plugin')),('external','Remote','https://github.com/owner/repo')])
 def test_native_http_get_marketplace_discovery_has_no_model_authorization(self):
  import http.server,threading
  requests=[];payload=json.dumps({'plugins':[{'name':'remote','description':'actual metadata','source':{'source':'url','url':'https://example.test/repo.git'}},{'name':'unsafe-local','source':'./local'},{'name':'nul','source':'https://safe.test/\u0000hidden'}]}).encode()
  class Handler(http.server.BaseHTTPRequestHandler):
   def do_GET(self):
    requests.append((self.path,dict(self.headers)));self.send_response(200);self.send_header('Content-Length',str(len(payload)));self.end_headers()
    for i in range(0,len(payload),3):self.wfile.write(payload[i:i+3]);self.wfile.flush()
   def log_message(self,*a):pass
  server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  try:
   self.assertEqual(self.discover(f'http://127.0.0.1:{server.server_port}/marketplace.json'),[('remote','actual metadata','https://example.test/repo.git')]);self.assertEqual(requests[0][0],'/marketplace.json');self.assertNotIn('Authorization',requests[0][1])
  finally:server.shutdown();server.server_close();thread.join()

 def test_named_agent_runtime_prompt_uses_real_project_then_user_body(self):
  self.assertEqual(self.save(scope=0),0);self.assertEqual(self.save(raw=RAW.replace(b'Review changes',b'Project review'),scope=1),0);out=C.create_string_buffer(65537)
  n=self.lib.ui_agent_prompt(b'reviewer',out,len(out));self.assertGreater(n,0);self.assertEqual(out.raw[:n],b'Project review carefully.\n');self.assertEqual(C.string_at(self.lib.ui_agent_definition_path()).decode(),str(self.cwd/'.qwen/agents/reviewer.md'))
  self.assertEqual(self.lib.ui_agent_delete(os.fsencode(self.cwd/'.qwen/agents/reviewer.md')),0);n=self.lib.ui_agent_prompt(b'reviewer',out,len(out));self.assertEqual(out.raw[:n],b'Review changes carefully.\n')
  advanced=RAW.replace(b'color: blue',b'executor: {kind: codex, command: codex}')
  self.assertEqual(self.save(raw=advanced),0);self.assertEqual(self.lib.ui_agent_prompt(b'reviewer',out,len(out)),-95)
  self.assertEqual(self.lib.ui_agent_prompt(b'../outside',out,len(out)),-22)

 def test_discovery_concatenation_and_registry_append_capacity_fail_safely(self):
  source=self.base/'marketplace';(source/'.claude-plugin').mkdir(parents=True);manifest=source/'.claude-plugin/marketplace.json';manifest.write_text(json.dumps({'plugins':[{'name':'too-long','source':'./'+('x'*4070)},{'name':'too-long-github','source':{'source':'github','repo':'x'*4090}},{'name':'safe','source':'./safe'}]}))
  rows=self.discover(source);self.assertEqual(rows,[('safe','',str(source/'safe'))])
  directory=self.home/'.qwen/extensions';directory.mkdir(parents=True);registry=directory/'marketplaces.json';entry={'name':'large','source':'https://example.test','unknown':'x'*65400};registry.write_text(json.dumps([entry],separators=(',',':')));before=registry.read_bytes()
  self.assertLess(self.lib.ui_extension_source_add(b'new',b'https://other.test'),0);self.assertEqual(registry.read_bytes(),before)
