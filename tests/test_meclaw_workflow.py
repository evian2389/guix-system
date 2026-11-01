from contextlib import closing
import importlib.machinery
import importlib.util
import json
import time
from pathlib import Path
import tempfile
import threading
import urllib.request
import urllib.error
import unittest
from unittest.mock import patch

SCRIPT=Path(__file__).resolve().parents[1]/'src/raynet-guix/users/orka/files/.local/bin/meclaw-workflow'
loader=importlib.machinery.SourceFileLoader('meclaw_workflow',str(SCRIPT))
spec=importlib.util.spec_from_loader(loader.name,loader)
m=importlib.util.module_from_spec(spec)
loader.exec_module(m)

class MeclawTests(unittest.TestCase):
    def test_native_model_update_is_params_only_with_valid_ubf_system_slot(self):
        m.configure(self.repo,self.home);app=m.App(self.store,self.home)
        with patch.object(m,'request',return_value={'message_id':'test'}) as send,patch.object(app,'current_model',return_value='new-model'):
            app.apply_model('new-model','low')
            body=send.call_args.args[1]['body']
            self.assertIn('system',body)
            self.assertNotIn('messages',body)
            self.assertEqual(body['params']['model'],'new-model')

    def test_catalog_filters_hidden_models_and_keeps_last_good_cache_on_error(self):
        m.configure(self.repo,self.home)
        auth=self.home/'.codex/auth.json';auth.write_text(json.dumps({'tokens':{'access_token':'fixture','account_id':'one'}}))
        app=m.App(self.store,self.home)
        with patch.object(m,'fetch_catalog',return_value={'models':[{'slug':'new-model','visibility':'list'}, {'slug':'hidden','visibility':'hide'}]}):
            self.assertEqual([x['id'] for x in app.models(True)['models']],['new-model'])
        with patch.object(m,'fetch_catalog',side_effect=OSError('offline')):
            self.assertTrue(app.models(True)['stale'])
            with self.assertRaises(ValueError): app.set_model('new-model')
        auth.write_text(json.dumps({'tokens':{'access_token':'fixture','account_id':'two'}}))
        with patch.object(m,'fetch_catalog',side_effect=OSError('offline')):
            with self.assertRaises(ValueError): app.models()

    def test_model_switch_requires_idle_and_verified_native_apply(self):
        m.configure(self.repo,self.home);app=m.App(self.store,self.home)
        catalog={'models':[{'id':'new-model','reasoning_effort':'low'}],'stale':False}
        with patch.object(app,'models',return_value=catalog),patch.object(app,'apply_model') as apply:
            app.lock.acquire()
            try:
                with self.assertRaises(ValueError): app.set_model('new-model')
            finally: app.lock.release()
            with self.assertRaises(ValueError): app.set_model('unknown')
            apply.assert_not_called()
            result=app.set_model('new-model')
            self.assertEqual(result['model'],'new-model')
            apply.assert_called_once_with('new-model','low')
            self.assertEqual(json.loads((self.root/'selected-model.json').read_text())['model'],'new-model')
            evaluator=json.loads((self.root/'colony/main/evaluator/config.json').read_text())
            self.assertEqual(evaluator['params']['model'],'gpt-6.1-terra')

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name)/'home';self.home.mkdir()
        self.repo=self.home/'work/workflow-evolution';(self.repo/'.git').mkdir(parents=True)
        self.root=self.repo/'meclaw'
        self.store=m.Store(self.root)

    def test_seed_preserves_history_and_credentials_stay_out_of_configs(self):
        m.configure(self.repo,self.home)
        marker=self.root/'runtime/keep';marker.write_text('history')
        m.configure(self.repo,self.home)
        self.assertEqual(marker.read_text(),'history')
        link=self.home/'.local/share/meclaw-workflow'
        self.assertEqual(link.resolve(),self.root)
        brain=json.loads((self.root/'colony/main/brain/config.json').read_text())
        self.assertEqual(brain['params']['auth'],'oauth_subscription')
        self.assertEqual(brain['params']['model'],'gpt-6.1-terra')
        self.assertNotIn('api_key',brain['params'])
        evaluator=json.loads((self.root/'colony/main/evaluator/config.json').read_text())
        self.assertEqual(evaluator['cell']['type'],'llm')
        import tomllib
        codex=tomllib.loads((self.home/'.codex/config.toml').read_text())
        self.assertEqual(codex['mcp_servers']['meclaw']['args'],['mcp'])

    def test_wiring_refuses_conflicting_state_link(self):
        link=self.home/'.local/share/meclaw-workflow';link.parent.mkdir(parents=True)
        link.symlink_to(self.home/'elsewhere')
        with self.assertRaises(ValueError): m.configure(self.repo,self.home)

    def test_jobs_are_durable_deduplicated_and_not_replayed_after_crash(self):
        a=self.store.queue('run:tool1','terminal','Read README','/project')
        b=self.store.queue('run:tool1','terminal','Read README','/project')
        self.assertEqual(a['id'],b['id'])
        job=self.store.claim()
        self.assertEqual(job['id'],a['id'])
        self.assertIsNone(self.store.claim())
        self.store.recover()
        self.assertEqual(self.store.job(a['id'])['status'],'unknown')
        self.assertIsNone(self.store.claim())

    def test_telegram_credentials_require_an_allowlist(self):
        path=self.home/'gateway.json'
        path.write_text(json.dumps({'channels':{'telegram':{'accounts':{'main':{'bot_token':'fixture-secret'}}}}}))
        with self.assertRaises(ValueError): m.telegram_settings(path)
        config=json.loads(path.read_text());config['channels']['telegram']['allowed_user_ids']=[123]
        path.write_text(json.dumps(config))
        token,allowed=m.telegram_settings(path)
        self.assertEqual(token,'fixture-secret');self.assertEqual(allowed,{123})

    def test_git_snapshot_excludes_raw_jobs_chats_and_tokens(self):
        self.store.queue('key','telegram:123','secret raw user task token=fixture','/private')
        self.store.save_history('telegram:123',[{'text':'private conversation'}])
        self.store.event('tool','success','read_file verified')
        path=self.store.snapshot()
        text=path.read_text()
        self.assertIn('read_file verified',text)
        self.assertNotIn('private conversation',text)
        self.assertNotIn('secret raw',text)
        self.assertNotIn('fixture',text)

    def test_evaluator_has_no_tools_and_normal_context_reloads_champion(self):
        skill=self.repo/'skills/local-workflow/SKILL.md';skill.parent.mkdir(parents=True)
        skill.write_text('champion one')
        app=m.App(self.store,home=self.home)
        evaluation=app.prepare('check','evaluation','judge instructions',True)
        self.assertNotIn('tools',evaluation['system'])
        self.assertIn('judge instructions',evaluation['system']['instructions']['text'])
        normal=app.prepare('work','terminal')
        self.assertIn('champion one',normal['system']['instructions']['text'])
        schema=json.loads(normal['system']['tools']['workflow_search']['text'])
        self.assertEqual(schema['name'],'workflow_search')
        self.assertNotIn('function',schema)
        skill.write_text('champion two')
        self.assertIn('champion two',app.prepare('work','terminal')['system']['instructions']['text'])

    def test_symlinked_runtime_loads_skills_from_repository(self):
        skill=self.repo/'skills/local-workflow/SKILL.md';skill.parent.mkdir(parents=True)
        skill.write_text('shared champion through symlink')
        alias=self.home/'runtime-link';alias.symlink_to(self.root,target_is_directory=True)
        app=m.App(m.Store(alias),home=self.home)
        self.assertIn('shared champion through symlink',app.prepare('work','terminal')['system']['instructions']['text'])

    def test_tool_result_errors_are_evidence_and_approval_is_unknown(self):
        app=m.App(self.store,home=self.home)
        with patch.object(app,'execute',side_effect=ValueError('fixture error token=private')):
            result=app.tool('workflow_search',{'query':'fixture'},'run:1','terminal')
        self.assertTrue(result['is_error'])
        self.assertNotIn('private',result['text'])

    def test_untrusted_user_cannot_submit_telegram_task(self):
        self.assertFalse(m.allowed_update({'message':{'from':{'id':999},'chat':{'id':123},'text':'run'}},{123}))
        self.assertTrue(m.allowed_update({'message':{'from':{'id':123},'chat':{'id':123},'text':'run'}},{123}))
        self.assertFalse(m.allowed_update({'message':{'from':{'id':123},'chat':{'id':-1},'text':'run'}},{123}))

    def test_history_retains_complete_turns(self):
        history=[{'origin':'user','type':'text','text':'old'}]+[
            {'origin':'tool','type':'tool_result','text':'part'} for _ in range(35)]
        history += [{'origin':'user','type':'text','text':'latest'},
                    {'origin':'assistant','type':'text','text':'answer'}]
        self.store.save_history('terminal',history)
        kept=self.store.history('terminal')
        self.assertEqual(kept[0]['origin'],'user')
        self.assertEqual(kept[0]['text'],'latest')

    def test_restore_observations_without_raw_runtime(self):
        self.store.event('verification','success','restorable')
        self.store.snapshot()
        for suffix in ('','-wal','-shm'):
            self.store.path.with_name(self.store.path.name+suffix).unlink(missing_ok=True)
        m.configure(self.repo,self.home)
        with self.store.db() as db:
            self.assertEqual(db.execute('select summary from events').fetchone()[0],'restorable')
            self.assertEqual(db.execute('select count(*) from jobs').fetchone()[0],0)

    def test_codex_settings_symlink_and_existing_model_are_preserved(self):
        path=self.home/'.codex/config.toml';path.parent.mkdir()
        target=self.home/'settings.toml';target.write_text('model = "keep-my-model"\n')
        path.symlink_to(target)
        m.configure(self.repo,self.home)
        self.assertTrue(path.is_symlink())
        self.assertIn('keep-my-model',target.read_text())
        self.assertIn('[mcp_servers.meclaw]',target.read_text())

    def test_evaluation_cannot_execute_tool_calls(self):
        app=m.App(self.store,home=self.home)
        app.active['fixture']={'body':{'messages':[]},'evaluate':True,'steps':0,
                               'channel':'eval','done':threading.Event()}
        body={'messages':[{'origin':'assistant','type':'tool_call','id':'call1',
                           'text':json.dumps({'name':'delegate_codex','arguments':{'task':'anything'}})}]}
        with patch.object(app,'tool') as call:
            app.result('fixture',body,{})
        call.assert_not_called()
        self.assertTrue(app.active['fixture']['done'].is_set())

    def test_native_tool_loop_keeps_call_ids_and_actual_token_counts(self):
        app=m.App(self.store,home=self.home)
        app.active['fixture']={'body':{'messages':[{'origin':'user','type':'text','text':'search'}]},
             'evaluate':False,'steps':0,'channel':'terminal','done':threading.Event()}
        call={'origin':'assistant','type':'tool_call','id':'native-call-1',
              'text':json.dumps({'name':'workflow_search','arguments':{'query':'Guix'}})}
        with patch.object(app,'tool',return_value={'text':'evidence','is_error':False}):
            answer=app.result('fixture',{'messages':[call]},{'tokens_prompt':17,'tokens_completion':3})
        self.assertEqual(answer['header']['route'],'loop')
        self.assertEqual(answer['messages'][-1]['id'],'native-call-1')
        final=app.result('fixture',{'messages':[{'origin':'assistant','type':'text','text':'done'}]},
                         {'tokens_prompt':20,'tokens_completion':2})
        self.assertEqual(final['header']['route'],'answer')
        self.assertEqual(app.active['fixture']['usage'],{'input_tokens':37,'output_tokens':5})

    def test_malformed_native_call_settles_error_without_running_a_tool(self):
        app=m.App(self.store,home=self.home)
        app.active['fixture']={'body':{'messages':[]},'evaluate':False,'steps':0,
                               'channel':'terminal','done':threading.Event()}
        with patch.object(app,'tool') as call:
            app.result('fixture',{'messages':[{'origin':'assistant','type':'tool_call','id':'x','text':'[]'}]}, {})
        call.assert_not_called()
        self.assertTrue(app.active['fixture']['done'].is_set())
        self.assertIn('error',app.active['fixture'])

    def test_http_auth_blocks_execution(self):
        app=m.App(self.store,home=self.home)
        server=m.Server(('127.0.0.1',0),app,'fixture-token')
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        self.addCleanup(server.server_close);self.addCleanup(server.shutdown)
        req=urllib.request.Request('http://127.0.0.1:'+str(server.server_port)+'/chat',
                data=b'{"prompt":"untrusted"}',headers={'Authorization':'Bearer wrong'})
        with patch.object(app,'run') as run:
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(req,timeout=2)
            self.assertEqual(error.exception.code,401)
        run.assert_not_called()

    def test_native_transport_failure_records_component_evidence_and_unlocks(self):
        app=m.App(self.store,home=self.home)
        with patch.object(m,'request',side_effect=OSError('native unavailable')):
            with patch.object(app,'evidence') as evidence:
                with self.assertRaises(OSError): app.run('private user prompt','terminal')
        evidence.assert_called_once()
        self.assertEqual(evidence.call_args.args[:2],('inference','failure'))
        self.assertNotIn('private user prompt',evidence.call_args.args[2])
        self.assertFalse(app.lock.locked())

    def test_closed_worker_is_not_reported_as_available(self):
        path=self.root/'runtime/dispatcher.json'
        path.write_text(json.dumps({'heartbeat':time.time(),'worker_pane':'closed','worker_state':'unknown'}))
        self.assertFalse(m.App(self.store,home=self.home).execute('herdr_status',{},'key','terminal')['available'])

    def test_enrollment_does_not_reuse_fresh_heartbeat_for_closed_worker(self):
        path=self.root/'runtime/dispatcher.json'
        path.write_text(json.dumps({'heartbeat':time.time(),'worker_pane':'closed','worker_state':'unknown'}))
        with patch.dict(m.os.environ,{'HERDR_ENV':'1'}):
            with patch.object(m,'herdr',return_value={'result':{'agent':{'agent':'codex'}}}):
                with patch.object(m.subprocess,'Popen') as start:
                    start.return_value.pid=123
                    m.enroll(self.root,'replacement')
        start.assert_called_once()
        self.assertIn('replacement',start.call_args.args[0])


class ReadFileTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name)/'home';(self.home/'guix-system').mkdir(parents=True)
        self.repo=self.home/'work/workflow-evolution';(self.repo/'.git').mkdir(parents=True)
        self.store=m.Store(self.repo/'meclaw');self.app=m.App(self.store,self.home)
        self.doc=self.home/'work/notes.md';self.doc.write_text('one\ntwo\nthree\n')

    def read(self,path,channel='acp:x',**args):
        return self.app.execute('read_file',{'path':str(path),**args},'k',channel)

    def test_reads_numbered_window_inside_allowed_roots(self):
        value=self.read(self.doc,offset=2,lines=1)
        self.assertEqual(value['text'],'2\ttwo');self.assertTrue(value['truncated'])
        self.assertEqual(self.read(self.home/'guix-system/../work/notes.md')['lines'],3)

    def test_refuses_outside_roots_relative_and_symlink_escape(self):
        outside=Path(self.temp.name)/'outside.txt';outside.write_text('x')
        for bad in (outside,self.home/'.ssh/config','notes.md'):
            with self.assertRaises(ValueError): self.read(bad)
        link=self.home/'work/link.txt';link.symlink_to(outside)
        with self.assertRaises(ValueError): self.read(link)

    def test_refuses_secrets_git_dir_and_private_runtime(self):
        work=self.home/'work'
        secrets=[work/'.env',work/'.env.local',work/'app/auth.json',work/'id_ed25519',work/'k/server.pem',
                 work/'bridge-token',work/'my_secrets.yaml',work/'proj/.git/config',work/'secrets/a.txt']
        for path in secrets:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text('KEY=1')
            with self.assertRaises(ValueError,msg=str(path)): self.read(path)
        with self.assertRaises(ValueError): self.read(self.store.root/'runtime/host.db')
        (work/'tokenizer.py').write_text('x')  # 'token' inside a word is not a secret name
        self.assertEqual(self.read(work/'tokenizer.py')['lines'],1)

    def test_telegram_channel_cannot_read(self):
        with self.assertRaises(ValueError): self.read(self.doc,channel='telegram:42')

    def test_binary_refused_and_secret_values_masked(self):
        blob=self.home/'work/a.bin';blob.write_bytes(b'ab\0cd')
        with self.assertRaises(ValueError): self.read(blob)
        conf=self.home/'work/conf.txt';conf.write_text('api_key = abc123\nBearer topsecretvalue\nok\n')
        text=self.read(conf)['text']
        self.assertNotIn('abc123',text);self.assertNotIn('topsecretvalue',text);self.assertIn('ok',text)

    def test_directory_listing_hides_secrets(self):
        (self.home/'work/.env').write_text('A=1')
        entries=self.read(self.home/'work')['entries']
        self.assertIn('notes.md',entries);self.assertNotIn('.env',entries)

    def test_delegate_error_explains_why_and_how_to_recover(self):
        with self.assertRaises(ValueError) as caught:
            self.app.execute('delegate_codex',{'task':'t','project':str(self.home/'work')},'k','acp:x')
        self.assertIn('enroll',str(caught.exception))


class WorkerSupervisionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name)/'home';self.home.mkdir()
        self.store=m.Store(self.home/'work/workflow-evolution/meclaw')

    def herdr(self,agents=(),workspaces=(),panes=()):
        calls=[]
        def fake(*args,**kw):
            calls.append(args)
            if args[:2]==('agent','list'): return {'result':{'agents':list(agents)}}
            if args[:2]==('workspace','list'): return {'result':{'workspaces':list(workspaces)}}
            if args[:2]==('pane','list'): return {'result':{'panes':list(panes)}}
            if args[:2]==('workspace','create'): return {'result':{'root_pane':{'pane_id':'w1:p1'}}}
            return {}
        return fake,calls

    def test_worker_policy_is_sandboxed_to_work_without_prompts_inside(self):
        args=m.worker_args(self.home);work=str(self.home/'work')
        self.assertEqual(args[args.index('--sandbox')+1],'workspace-write')
        self.assertEqual(args[args.index('--ask-for-approval')+1],'on-request')
        self.assertEqual(args[args.index('--add-dir')+1],work);self.assertEqual(args[args.index('--cd')+1],work)
        self.assertNotIn('--dangerously-bypass-approvals-and-sandbox',args)

    def test_existing_worker_is_reused_and_dispatcher_started_once(self):
        fake,calls=self.herdr(agents=[{'name':'meclaw-codex','agent':'codex','pane_id':'w1:p9'}])
        state={}
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen') as start:
            start.return_value.poll.return_value=None
            m.supervise_step(self.store,state,self.home);m.supervise_step(self.store,state,self.home)
        self.assertEqual(start.call_count,1);self.assertIn('--supervised',start.call_args.args[0])
        self.assertIn('w1:p9',start.call_args.args[0])
        self.assertFalse([c for c in calls if c[:2] in (('workspace','create'),('agent','start'))])

    def test_missing_worker_is_launched_in_its_own_workspace(self):
        fake,calls=self.herdr()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen'),patch.object(m.time,'sleep'):
            m.supervise_step(self.store,{},self.home)
        started=[c for c in calls if c[:2]==('agent','start')]
        self.assertEqual(len(started),1);self.assertIn('--ask-for-approval',started[0])
        self.assertTrue([c for c in calls if c[:2]==('workspace','create')])

    def test_launch_budget_stops_a_crash_loop(self):
        fake,calls=self.herdr()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen'),patch.object(m.time,'sleep'):
            for _ in range(5): m.supervise_step(self.store,{},self.home)
        self.assertEqual(len([c for c in calls if c[:2]==('agent','start')]),m.SPAWN_LIMIT)

    def test_herdr_down_is_logged_once_not_every_pass(self):
        def down(*a,**k): raise ValueError('Herdr: server not running')
        state={}
        with patch.object(m,'herdr',down):
            for _ in range(3): m.supervise_step(self.store,state,self.home)
        with closing(self.store.db()) as db:
            self.assertEqual(db.execute("select count(*) from events where kind='supervisor'").fetchone()[0],1)

    def telegram_job(self,status,result='done',channel='telegram:42'):
        job=self.store.queue('k-'+status,channel,'task',self.home/'work');self.store.finish(job['id'],status,result,'p');return job['id']

    def test_notifies_telegram_chat_once_per_state_and_skips_history(self):
        old=self.telegram_job('completed','old')
        sent=[];app=m.App(self.store,self.home)
        m.notify_finished_jobs(app,lambda chat,text:sent.append((chat,text)))   # baseline: nothing sent
        self.assertEqual(sent,[])
        self.store.finish(self.store.queue('k2','telegram:42','t2',self.home/'work')['id'],'blocked','needs approval','p')
        m.notify_finished_jobs(app,lambda chat,text:sent.append((chat,text)))
        m.notify_finished_jobs(app,lambda chat,text:sent.append((chat,text)))   # no repeat
        self.assertEqual(len(sent),1);self.assertEqual(sent[0][0],'42');self.assertIn('승인 대기',sent[0][1])

    def test_notification_ignores_other_channels_and_masks_secrets(self):
        app=m.App(self.store,self.home);sent=[]
        m.notify_finished_jobs(app,lambda c,t:sent.append(t))
        self.telegram_job('completed','api_key = leaked123',channel='telegram:7')
        self.telegram_job('completed','x',channel='acp:abc')
        m.notify_finished_jobs(app,lambda c,t:sent.append(t))
        self.assertEqual(len(sent),1);self.assertNotIn('leaked123',sent[0])

if __name__=='__main__': unittest.main()
