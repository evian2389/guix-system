from contextlib import closing
import importlib.machinery
import importlib.util
import json
import sqlite3
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

    def test_queued_job_cancels_atomically_and_is_never_claimed(self):
        a=self.store.queue('k1','ch','task','/p')
        self.assertEqual(self.store.cancel(a['id'],'ch')['status'],'cancelled')
        self.assertIsNone(self.store.claim())
        self.assertEqual(self.store.job(a['id'])['status'],'cancelled')

    def test_cancel_refuses_started_foreign_or_unknown_jobs(self):
        a=self.store.queue('k2','ch','task','/p');self.store.claim()
        self.store.finish(a['id'],'blocked')
        with self.assertRaises(ValueError) as ctx: self.store.cancel(a['id'],'ch')
        self.assertIn('cannot be stopped',str(ctx.exception))
        self.assertEqual(self.store.job(a['id'])['status'],'blocked')
        b=self.store.queue('k3','ch','task','/p')
        with self.assertRaises(ValueError): self.store.cancel(b['id'],'other')
        self.assertEqual(self.store.job(b['id'])['status'],'queued')
        with self.assertRaises(ValueError): self.store.cancel('nope','ch')

    def test_cancel_and_claim_race_has_exactly_one_winner(self):
        for n in range(30):
            job=self.store.queue('race%d'%n,'ch','task','/p')
            outcome={}
            gate=threading.Barrier(2)
            def cancel():
                gate.wait()
                try: outcome['cancel']=self.store.cancel(job['id'],'ch')['status']
                except ValueError: outcome['cancel']='refused'
            def claim():
                gate.wait();outcome['claim']=self.store.claim()
            threads=[threading.Thread(target=cancel),threading.Thread(target=claim)]
            [t.start() for t in threads];[t.join() for t in threads]
            claimed=outcome['claim'] is not None
            self.assertEqual(claimed,outcome['cancel']=='cancel_requested',outcome)  # never both 'cancelled' and claimed
            self.assertEqual(self.store.job(job['id'])['status'],'working' if claimed else 'cancelled')
            if claimed: self.store.finish(job['id'],'completed')

    def test_running_job_gets_a_cancel_request_not_a_status_change(self):
        a=self.store.queue('r1','ch','task','/p');self.store.claim()
        self.assertFalse(self.store.cancel_requested(a['id']))
        self.assertEqual(self.store.cancel(a['id'],'ch')['status'],'cancel_requested')
        self.assertTrue(self.store.cancel_requested(a['id']))
        with self.assertRaises(ValueError): self.store.cancel(a['id'],'other')

    def test_watch_cancel_sends_esc_then_ctrl_c_only_after_a_request(self):
        a=self.store.queue('r2','ch','task','/p');self.store.claim()
        sent=[];stop=threading.Event()
        def until(condition,seconds=5):
            end=time.monotonic()+seconds
            while time.monotonic()<end and not condition(): time.sleep(0.01)
            return condition()
        thread=threading.Thread(target=m.watch_cancel,args=(self.store,a['id'],'w:p1',stop,lambda p,k:sent.append((p,k)),0.02,0.3))
        thread.start()
        time.sleep(0.2)
        self.assertEqual(sent,[])  # nothing is sent without a request
        self.store.cancel(a['id'],'ch')
        self.assertTrue(until(lambda:('w:p1','esc') in sent))
        self.assertTrue(until(lambda:('w:p1','ctrl+c') in sent))
        stop.set();thread.join()
        self.assertEqual(sent,[('w:p1','esc'),('w:p1','ctrl+c')])

    def test_stop_background_types_stop_and_presses_enter_twice(self):
        sent=[]
        m.stop_background('w:p1',lambda p,k:sent.append(k),lambda p,t:sent.append('text:'+t),0)
        self.assertEqual(sent,['text:/stop','enter','enter'])

    def interrupt_app(self,agents):
        calls=[]
        def fake(*a,**k):
            calls.append(a)
            if a[:2]==('agent','list'): return {'result':{'agents':agents()}}
            return {}
        return m.App(self.store,self.home),fake,calls

    def test_interrupt_sends_only_esc_to_a_working_claude_pane(self):
        state=['working']
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'claude','agent_status':state[0]}])
        with patch.object(m,'herdr',fake),patch.object(m.time,'sleep',lambda s:state.__setitem__(0,'idle')):
            result=app.execute('interrupt_agent',{'pane':'w1:p2'},'k','ch')
        self.assertEqual(result['sent'],'esc');self.assertEqual(result['status_now'],'idle')
        self.assertEqual([c for c in calls if c[0]=='pane'],[('pane','send-keys','w1:p2','esc')])
        self.assertIn('not proof',result['note'])

    def test_interrupt_force_uses_ctrl_c(self):
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'agy','agent_status':'working'}])
        with patch.object(m,'herdr',fake),patch.object(m.time,'sleep'):
            app.execute('interrupt_agent',{'pane':'w1:p2','force':True},'k','ch')
        self.assertIn(('pane','send-keys','w1:p2','ctrl+c'),calls)

    def test_interrupt_applies_to_any_herdr_agent_in_any_state(self):
        for agent,status in (('codex','working'),('claude','blocked'),('agy','idle'),('meclaw','working')):
            app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':agent,'agent_status':status}])
            with patch.object(m,'herdr',fake),patch.object(m.time,'sleep'): result=app.execute('interrupt_agent',{'pane':'w1:p2'},'k','ch')
            self.assertEqual(result['status_before'],status);self.assertIn(('pane','send-keys','w1:p2','esc'),calls)
            self.assertEqual([c for c in calls if c[0]=='pane'],[('pane','send-keys','w1:p2','esc')])  # keys only: no text, no close
        app,fake,calls=self.interrupt_app(lambda:[])
        with patch.object(m,'herdr',fake),self.assertRaises(ValueError): app.execute('interrupt_agent',{'pane':'w9:p9'},'k','ch')
        with self.assertRaises(ValueError): app.execute('interrupt_agent',{'pane':'p; rm -rf /'},'k','ch')

    def test_agent_text_keys_and_close_go_through_herdr_for_any_agent(self):
        for agent in ('claude','agy'):
            app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':agent,'agent_status':'blocked'}])
            with patch.object(m,'herdr',fake):
                app.execute('agent_send',{'pane':'w1:p2','text':'run the tests'},'k','ch')
                app.execute('agent_keys',{'pane':'w1:p2','keys':['1','enter']},'k','ch')
                app.execute('agent_close',{'pane':'w1:p2'},'k','ch')
            self.assertEqual([c for c in calls if c[0]=='pane'],[('pane','send-text','w1:p2','run the tests'),('pane','send-keys','w1:p2','enter'),
                             ('pane','send-keys','w1:p2','1','enter'),('pane','close','w1:p2')])
        with closing(self.store.db()) as db:
            kinds={r[0] for r in db.execute('select kind from events')}
        self.assertTrue({'agent_send','agent_keys','agent_close'}<=kinds)

    def test_agent_keys_translates_hyphenated_modifiers_to_herdr_spelling(self):
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'claude','agent_status':'idle'}])
        with patch.object(m,'herdr',fake): app.execute('agent_keys',{'pane':'w1:p2','keys':['ctrl-c','alt-x','enter']},'k','ch')
        self.assertIn(('pane','send-keys','w1:p2','ctrl+c','alt+x','enter'),calls)

    def test_agent_send_without_submit_only_types(self):
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'claude','agent_status':'idle'}])
        with patch.object(m,'herdr',fake): app.execute('agent_send',{'pane':'w1:p2','text':'draft','submit':False},'k','ch')
        self.assertEqual([c for c in calls if c[0]=='pane'],[('pane','send-text','w1:p2','draft')])

    def test_agent_control_validates_input(self):
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'claude','agent_status':'idle'}])
        with patch.object(m,'herdr',fake):
            for tool,args in (('agent_keys',{'pane':'w1:p2','keys':[]}),('agent_keys',{'pane':'w1:p2','keys':['a b']}),
                              ('agent_keys',{'pane':'w1:p2','keys':['x']*9}),('agent_send',{'pane':'w1:p2','text':'  '}),
                              ('agent_close',{'pane':'w9:p9'}),('agent_read',{'pane':'a;b'})):
                with self.assertRaises(ValueError,msg=tool): app.execute(tool,args,'k','ch')
        self.assertFalse([c for c in calls if c[0]=='pane'])

    def test_agent_read_masks_secrets(self):
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'claude','agent_status':'idle'}])
        done=type('R',(),{'returncode':0,'stdout':'token=abcdef123456 ok','stderr':''})()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'run',return_value=done):
            out=app.execute('agent_read',{'pane':'w1:p2'},'k','ch')
        self.assertNotIn('abcdef123456',out['output']);self.assertEqual(out['agent'],'claude')

    def test_telegram_controls_only_panes_below_work(self):
        work=str(self.home/'work')
        inside={'pane_id':'w1:p2','agent':'claude','agent_status':'blocked','cwd':work+'/proj','foreground_cwd':work+'/proj'}
        outside=dict(inside,cwd=str(self.home/'guix-system'),foreground_cwd=str(self.home/'guix-system'))
        mixed=dict(inside,foreground_cwd='/etc')
        escape=dict(inside,cwd=work+'/../secret')
        for tool,args in (('agent_keys',{'keys':['1']}),('agent_send',{'text':'go'}),('agent_close',{}),('interrupt_agent',{})):
            args=dict(args,pane='w1:p2')
            app,fake,calls=self.interrupt_app(lambda:[inside])
            with patch.object(m,'herdr',fake),patch.object(m.time,'sleep'): app.execute(tool,args,'k','telegram:42')
            self.assertTrue([c for c in calls if c[0]=='pane'],tool)
            for bad in (outside,mixed,escape,dict(inside,cwd=None,foreground_cwd=None)):
                app,fake,calls=self.interrupt_app(lambda:[bad])
                with patch.object(m,'herdr',fake),self.assertRaises(ValueError,msg=tool): app.execute(tool,args,'k','telegram:42')
                self.assertFalse([c for c in calls if c[0]=='pane'])
            # the terminal channel is unrestricted
            app,fake,calls=self.interrupt_app(lambda:[outside])
            with patch.object(m,'herdr',fake),patch.object(m.time,'sleep'): app.execute(tool,args,'k','acp:x:main')
            self.assertTrue([c for c in calls if c[0]=='pane'])

    def test_telegram_may_still_read_any_agent_pane(self):
        outside={'pane_id':'w1:p2','agent':'claude','agent_status':'idle','cwd':'/etc','foreground_cwd':'/etc'}
        app,fake,calls=self.interrupt_app(lambda:[outside])
        done=type('R',(),{'returncode':0,'stdout':'hi','stderr':''})()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'run',return_value=done):
            self.assertEqual(app.execute('agent_read',{'pane':'w1:p2'},'k','telegram:42')['output'],'hi')

    def test_agent_read_falls_back_to_the_visible_screen_for_a_blocked_agent(self):
        app,fake,calls=self.interrupt_app(lambda:[{'pane_id':'w1:p2','agent':'agy','agent_status':'blocked'}])
        seen=[]
        def run(cmd,**k):
            seen.append(cmd[cmd.index('--source')+1])
            if cmd[cmd.index('--source')+1]=='recent-unwrapped':
                return type('R',(),{'returncode':1,'stdout':'','stderr':'cannot read 40 lines while blocked'})()
            return type('R',(),{'returncode':0,'stdout':'Do you trust this folder?','stderr':''})()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'run',side_effect=run):
            out=app.execute('agent_read',{'pane':'w1:p2'},'k','ch')
        self.assertEqual(seen,['recent-unwrapped','visible']);self.assertEqual(out['source'],'visible')
        self.assertIn('trust',out['output'])

    def delegate_app(self):
        app=m.App(self.store,self.home)
        for d in ('work/p','guix-system'): (self.home/d).mkdir(parents=True,exist_ok=True)
        m.atomic(self.store.root/'runtime/supervisor.json',json.dumps({'heartbeat':time.time()}))  # worker may be started on demand
        return app

    def delegate(self,app,permission,prompt,channel='acp:x:main',project='work/p'):
        app.user_prompt=prompt
        return app.execute('delegate_codex',{'task':'t','project':str(self.home/project),'permission':permission},'k'+permission+prompt[:6],channel)

    def test_elevated_permission_needs_the_users_own_phrase(self):
        app=self.delegate_app()
        for level in ('project','all'):
            with self.assertRaises(ValueError,msg=level) as ctx: self.delegate(app,level,'please just do it')
            self.assertIn('Do not choose it yourself',str(ctx.exception))
        self.assertEqual(self.delegate(app,'project','수정해줘. 프로젝트 권한 허용','acp:x:main','guix-system')['permission'],'project')
        self.assertEqual(self.delegate(app,'all','Do it, allow-all','acp:x:main','guix-system')['permission'],'all')
        self.assertEqual(self.delegate(app,'default','anything')['permission'],'default')

    def test_project_phrase_does_not_grant_all_but_all_covers_project(self):
        app=self.delegate_app()
        with self.assertRaises(ValueError): self.delegate(app,'all','allow-project please')
        self.assertEqual(self.delegate(app,'project','권한 전체 허용')['permission'],'project')

    def test_phrase_is_read_from_the_current_request_only_and_cleared_after(self):
        app=self.delegate_app()
        app.user_prompt='allow-all'
        app.user_prompt=''  # what run() does in its finally block
        with self.assertRaises(ValueError): app.execute('delegate_codex',{'task':'t','project':str(self.home/'work/p'),'permission':'all'},'k','acp:x:main')
        with self.assertRaises(ValueError): app.execute('delegate_codex',{'task':'t','project':str(self.home/'work/p'),'permission':'bogus'},'k','acp:x:main')

    def test_telegram_cannot_use_all_and_project_stays_below_work(self):
        app=self.delegate_app()
        with self.assertRaises(ValueError): self.delegate(app,'all','allow-all','telegram:42')
        with self.assertRaises(ValueError): self.delegate(app,'project','allow-project','telegram:42','guix-system')
        self.assertEqual(self.delegate(app,'project','allow-project','telegram:42')['permission'],'project')

    def test_permission_is_stored_and_old_databases_migrate(self):
        job=self.store.queue('perm1','ch','t','/p','project')
        self.assertEqual(self.store.job(job['id'])['permission'],'project')
        self.assertEqual(self.store.job(self.store.queue('perm2','ch','t','/p')['id'])['permission'],'default')
        root=self.home/'old-root';(root/'runtime').mkdir(parents=True)
        with closing(sqlite3.connect(root/'runtime/host.db')) as db:
            db.execute('create table jobs(id text primary key,dedup text unique,channel text,task text,project text,status text,result text,created text,pane text)')
            db.execute("insert into jobs values('old','d','c','t','/p','completed','','2026-01-01','')");db.commit()
        migrated=m.Store(root)
        self.assertEqual(migrated.job('old')['permission'],'default')

    def test_worker_flags_per_permission_level(self):
        work=str(self.home/'work');project=str(self.home/'guix-system')
        default=m.worker_args(self.home)
        self.assertIn('workspace-write',default);self.assertNotIn('danger-full-access',default);self.assertNotIn('never',default)
        scoped=m.worker_args(self.home,'project',project)
        self.assertEqual(scoped[scoped.index('--sandbox')+1],'workspace-write')
        self.assertEqual(scoped[scoped.index('--ask-for-approval')+1],'never')
        self.assertIn(project,[scoped[i+1] for i,x in enumerate(scoped) if x=='--add-dir']);self.assertIn(work,scoped)
        full=m.worker_args(self.home,'all',project)
        self.assertEqual(full[full.index('--sandbox')+1],'danger-full-access')
        self.assertEqual(full[full.index('--ask-for-approval')+1],'never')
        for level in ('default','project','all'):  # the single bypass switch stays unused at every level
            self.assertNotIn('--dangerously-bypass-approvals-and-sandbox',m.worker_args(self.home,level,project))

    def test_brief_matches_the_permission_level(self):
        base={'id':'j1','project':'/home/orka/guix-system','task':'do it'}
        default=m.job_brief(dict(base,permission='default'))
        self.assertTrue(default.startswith('Work only in /home/orka/guix-system'))
        scoped=m.job_brief(dict(base,permission='project'))
        self.assertIn('writable',scoped);self.assertNotIn('Work only in',scoped)
        full=m.job_brief(dict(base,permission='all'))
        self.assertIn('only your starting directory',full);self.assertNotIn('Work only in',full)
        for brief in (default,scoped,full): self.assertIn('Do not answer approval prompts yourself',brief)

    def test_elevated_worker_is_a_dedicated_workspace_in_the_job_project(self):
        job=self.store.queue('el1','ch','t',str(self.home/'guix-system'),'all');self.store.claim();job=self.store.job(job['id'])
        calls=[]
        def fake(*a,**k):
            calls.append(a)
            if a[:2]==('workspace','create'): return {'result':{'workspace':{'workspace_id':'w9'},'root_pane':{'pane_id':'w9:p1'}}}
            return {}
        with patch.object(m,'herdr',fake),patch.object(m.time,'sleep'):
            pane,workspace=m.start_elevated_worker(self.store,job,self.home)
        self.assertEqual((pane,workspace),('w9:p1','w9'))
        create=[c for c in calls if c[:2]==('workspace','create')][0]
        self.assertEqual(create[create.index('--cwd')+1],job['project'])
        start=[c for c in calls if c[:2]==('agent','start')][0]
        self.assertIn('danger-full-access',start);self.assertNotEqual(start[2],m.WORKER_NAME)  # never the standing worker's name
        with closing(self.store.db()) as db:
            self.assertEqual(db.execute("select count(*) from events where kind='worker_launch'").fetchone()[0],1)

    def test_agent_control_tools_are_not_exposed_through_mcp(self):
        tail=open(SCRIPT).read().split("Tool not exposed to MCP")[0].split("if body.get('name') not in")[-1]
        for name in ('agent_read','agent_send','agent_keys','agent_close','interrupt_agent'): self.assertNotIn("'"+name+"'",tail)

    def test_interrupt_tool_is_not_exposed_through_mcp(self):
        self.assertNotIn("'interrupt_agent'",open(SCRIPT).read().split("Tool not exposed to MCP")[0].split("if body.get('name') not in")[-1])

    def test_cancelled_jobs_free_queue_capacity(self):
        ids=[self.store.queue('c%d'%n,'ch','t','/p')['id'] for n in range(4)]
        with self.assertRaises(ValueError): self.store.queue('c9','ch','t','/p')
        self.store.cancel(ids[3],'ch')
        self.store.queue('c9','ch','t','/p')

    def test_cancel_job_tool_reports_honest_state(self):
        app=m.App(self.store,self.home)
        job=self.store.queue('t1','ch','task','/p')
        self.assertEqual(app.execute('cancel_job',{'id':job['id']},'k','ch')['status'],'cancelled')
        job=self.store.queue('t2','ch','task','/p');self.store.claim()
        self.assertEqual(app.execute('cancel_job',{'id':job['id']},'k','ch')['status'],'cancel_requested')
        self.assertEqual(self.store.job(job['id'])['status'],'working')  # only the dispatcher may settle it

    def test_unreported_jobs_are_returned_once_per_state(self):
        a=self.store.queue('u1','acp:x:main','task','/p');self.store.queue('u2','acp:y:main','task','/p')
        self.assertEqual(self.store.unreported('acp:x:main'),[])
        self.store.claim();self.store.finish(a['id'],'completed','done')
        rows=self.store.unreported('acp:x:main')
        self.assertEqual([r['id'] for r in rows],[a['id']])
        self.assertEqual(self.store.unreported('acp:x:main'),[])
        self.assertEqual(self.store.unreported('acp:y:main'),[])

    def test_active_jobs_lists_only_unsettled_jobs_of_the_channel(self):
        a=self.store.queue('v1','ch','task','/p');self.store.queue('v2','other','task','/p')
        self.assertEqual([j['id'] for j in self.store.active_jobs('ch')],[a['id']])
        self.store.claim();self.store.finish(a['id'],'completed')
        self.assertEqual(self.store.active_jobs('ch'),[])

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

    def test_tool_limit_keeps_progress_and_asks_the_user_to_continue(self):
        app=m.App(self.store,home=self.home)
        app.active['fixture']={'body':{'messages':[{'origin':'user','type':'text','text':'read many'}]},
             'evaluate':False,'steps':m.TOOL_STEP_LIMIT,'channel':'terminal','done':threading.Event()}
        call={'origin':'assistant','type':'tool_call','id':'c-over','text':json.dumps({'name':'workflow_search','arguments':{'query':'x'}})}
        with patch.object(app,'tool') as run_tool:
            answer=app.result('fixture',{'messages':[call]},{})
        run_tool.assert_not_called()
        state=app.active['fixture']
        self.assertTrue(state['done'].is_set());self.assertIsNone(state.get('error'))
        self.assertIn('계속',state['text']);self.assertEqual(answer['header']['route'],'answer')
        kinds=[(x['origin'],x['type']) for x in state['body']['messages']]
        self.assertEqual(kinds[-3:],[('assistant','tool_call'),('tool','tool_result'),('assistant','text')])  # no dangling call
        self.assertEqual(state['body']['messages'][-2]['id'],'c-over')

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
        self.assertIn('sandbox_workspace_write.network_access=true',args)

    def test_existing_worker_is_reused_and_dispatcher_started_once(self):
        fake,calls=self.herdr(agents=[{'name':'meclaw-codex','agent':'codex','pane_id':'w1:p9'}])
        state={}
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen') as start:
            start.return_value.poll.return_value=None
            m.supervise_step(self.store,state,self.home);m.supervise_step(self.store,state,self.home)
        self.assertEqual(start.call_count,1);self.assertIn('--supervised',start.call_args.args[0])
        self.assertIn('w1:p9',start.call_args.args[0])
        self.assertFalse([c for c in calls if c[:2] in (('workspace','create'),('agent','start'))])

    def test_closed_worker_stays_closed_until_work_is_waiting(self):
        fake,calls=self.herdr()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen') as start,patch.object(m.time,'sleep'):
            for _ in range(5): m.supervise_step(self.store,{},self.home)
        self.assertFalse([c for c in calls if c[:2] in (('workspace','create'),('agent','start'))])
        self.assertEqual(start.call_count,0)
        self.assertTrue(m.supervisor_alive(self.store.root))

    def test_delegation_is_accepted_while_the_supervisor_can_start_the_worker(self):
        app=m.App(self.store,self.home);(self.home/'work/p').mkdir(parents=True)
        args={'task':'t','project':str(self.home/'work/p')}
        with self.assertRaises(ValueError): app.execute('delegate_codex',args,'k1','ch')
        m.atomic(self.store.root/'runtime/supervisor.json',json.dumps({'heartbeat':time.time()}))
        self.assertEqual(app.execute('delegate_codex',args,'k2','ch')['status'],'queued')

    def test_missing_worker_is_launched_in_its_own_workspace(self):
        self.store.queue('w1','ch','task','/p')
        fake,calls=self.herdr()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen'),patch.object(m.time,'sleep'):
            m.supervise_step(self.store,{},self.home)
        started=[c for c in calls if c[:2]==('agent','start')]
        self.assertEqual(len(started),1);self.assertIn('--ask-for-approval',started[0])
        self.assertTrue([c for c in calls if c[:2]==('workspace','create')])

    def test_launch_budget_stops_a_crash_loop(self):
        self.store.queue('w2','ch','task','/p')
        fake,calls=self.herdr()
        with patch.object(m,'herdr',fake),patch.object(m.subprocess,'Popen'),patch.object(m.time,'sleep'):
            for _ in range(m.SPAWN_LIMIT+3): m.supervise_step(self.store,{},self.home)
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
