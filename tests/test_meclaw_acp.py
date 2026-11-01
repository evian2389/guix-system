import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SHIM=Path(__file__).resolve().parents[1]/'src/raynet-guix/users/orka/files/.local/bin/meclaw-acp'
FAKE='''#!/usr/bin/env python3
import json,os,sys
cmd=sys.argv[1]
if cmd=='models': print(json.dumps({'models':[{'id':'m1','name':'M1'}],'current':'m1'}))
elif cmd=='history':
    if os.environ.get('FAKE_HISTORY_FAIL'): sys.exit(1)
    print(json.dumps({'messages':json.load(open(os.environ['FAKE_HISTORY']))}))
elif cmd=='jobs':
    value=None
    if '--consume' in sys.argv:
        used=os.environ['FAKE_HISTORY']+'.used'
        if os.environ.get('FAKE_JOBS_CONSUME') and not os.path.exists(used):
            open(used,'w').close(); value=os.environ['FAKE_JOBS_CONSUME']
    else: value=os.environ.get('FAKE_JOBS_ACTIVE')
    print(value or json.dumps({'active':[],'finished':[]}))
elif cmd=='ask':
    sys.stdin.read()
    if os.environ.get('FAKE_SLEEP'):
        import time; time.sleep(float(os.environ['FAKE_SLEEP']))
    print(json.dumps({'event':'result','text':'pong'}))
'''


class ShimTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        t=Path(self.temp.name)
        self.fake=t/'fake-workflow';self.fake.write_text(FAKE);self.fake.chmod(0o755)
        self.history=t/'history.json';self.history.write_text('[]')
        self.root=t/'wf';(self.root/'runtime').mkdir(parents=True)
        (self.root/'runtime/dispatcher.json').write_text(json.dumps({'heartbeat':time.time()+3600,'worker_state':'idle'}))
        self.env=dict(os.environ,MECLAW_WORKFLOW_BIN=str(self.fake),MECLAW_ACP_STATE=str(t/'state'),
                      MECLAW_WORKFLOW_ROOT=str(self.root),FAKE_HISTORY=str(self.history))
        self.env.pop('MECLAW_ACP_SESSION',None);self.env.pop('HERDR_ENV',None)
        self.cwd=t/'proj';self.cwd.mkdir()

    def talk(self,requests,**extra_env):
        """Send requests, keep stdin open until every request id is answered; return (responses, notifications)."""
        process=subprocess.Popen([sys.executable,str(SHIM)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,
                                 env={**self.env,**extra_env})
        wanted={r['id'] for r in requests if 'id' in r}
        responses={};notes=[]
        try:
            for r in requests:
                process.stdin.write(json.dumps({'jsonrpc':'2.0',**r})+'\n');process.stdin.flush()
                # Real clients wait for each reply before the next call; do the same for ordering.
                while r.get('id') in wanted and r['id'] not in responses:
                    line=process.stdout.readline()
                    if not line: raise AssertionError('shim exited early')
                    m=json.loads(line)
                    if 'id' in m: responses[m['id']]=m
                    else: notes.append(m)
        finally:
            process.stdin.close();process.wait(timeout=10)
        for line in process.stdout:
            if line.strip(): notes.append(json.loads(line))
        process.stdout.close()
        return responses,notes

    def new(self,cwd=None,**env):
        responses,_=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
                               {'id':2,'method':'session/new','params':{'cwd':str(cwd or self.cwd),'mcpServers':[]}}],**env)
        return responses[2]['result']['sessionId']

    def test_advertises_load_and_list(self):
        responses,_=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}}])
        caps=responses[1]['result']['agentCapabilities']
        self.assertTrue(caps['loadSession']);self.assertIn('list',caps['sessionCapabilities'])

    def test_same_project_continues_the_same_session_unless_named_or_new(self):
        first=self.new();self.assertEqual(first,self.new())
        other=self.cwd.parent/'other';other.mkdir()
        self.assertNotEqual(first,self.new(other))
        self.assertNotEqual(first,self.new(MECLAW_ACP_SESSION='work'))
        self.assertEqual(self.new(MECLAW_ACP_SESSION='work'),self.new(MECLAW_ACP_SESSION='work'))

    def test_list_uses_first_prompt_as_title_and_puts_this_project_first(self):
        sid=self.new()
        other=self.cwd.parent/'other';other.mkdir();self.new(other)
        responses,_=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/new','params':{'cwd':str(self.cwd),'mcpServers':[]}},
            {'id':3,'method':'session/prompt','params':{'sessionId':sid,'prompt':[{'type':'text','text':'Plan the migration\nplease'}]}}])
        time.sleep(0.5)
        listed,_=self.talk([{'id':9,'method':'session/list','params':{'cwd':str(self.cwd)}}])
        sessions=listed[9]['result']['sessions']
        self.assertEqual(sessions[0]['sessionId'],sid);self.assertEqual(sessions[0]['title'],'Plan the migration')
        self.assertEqual(len(sessions),2)

    def test_load_replays_visible_turns_before_responding(self):
        sid=self.new()
        self.history.write_text(json.dumps([
            {'origin':'user','type':'text','text':'Current project directory (context only): "/x"\n\nhello there'},
            {'origin':'assistant','type':'tool_call','text':'{}'},
            {'origin':'tool','type':'tool_result','text':'secret-ish tool output'},
            {'origin':'assistant','type':'text','text':'hi, how can I help'}]))
        responses,notes=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/load','params':{'sessionId':sid,'cwd':str(self.cwd),'mcpServers':[]}}])
        self.assertIn('result',responses[2])
        replay=[(n['params']['update']['sessionUpdate'],n['params']['update']['content']['text']) for n in notes]
        self.assertEqual(replay,[('user_message_chunk','hello there'),('agent_message_chunk','hi, how can I help')])

    def test_load_survives_history_failure_and_rejects_unknown_ids(self):
        sid=self.new()
        responses,notes=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/load','params':{'sessionId':sid,'cwd':str(self.cwd),'mcpServers':[]}}],FAKE_HISTORY_FAIL='1')
        self.assertIn('result',responses[2]);self.assertTrue(any('could not be loaded' in n['params']['update']['content']['text'] for n in notes))
        responses,_=self.talk([{'id':3,'method':'session/load','params':{'sessionId':'mc-nope','cwd':str(self.cwd),'mcpServers':[]}}])
        self.assertIn('error',responses[3])

    def test_resume_also_replays_for_clients_that_only_call_resume(self):
        sid=self.new()
        self.history.write_text(json.dumps([{'origin':'user','type':'text','text':'old question'},
                                            {'origin':'assistant','type':'text','text':'old answer'}]))
        responses,notes=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/resume','params':{'sessionId':sid,'cwd':str(self.cwd),'mcpServers':[]}},
            {'id':3,'method':'session/prompt','params':{'sessionId':sid,'prompt':[{'type':'text','text':'ping'}]}}])
        texts=[n['params']['update']['content']['text'] for n in notes if n['params']['update']['sessionUpdate']!='tool_call']
        self.assertEqual(texts,['old question','old answer','pong']);self.assertIn('result',responses[2])

    def test_finished_jobs_are_announced_before_the_next_answer(self):
        sid=self.new()
        done=json.dumps({'active':[],'finished':[{'id':'abc123','status':'completed','project':'/p','result':'all green'}]})
        responses,notes=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/resume','params':{'sessionId':sid,'cwd':str(self.cwd),'mcpServers':[]}},
            {'id':3,'method':'session/prompt','params':{'sessionId':sid,'prompt':[{'type':'text','text':'ping'}]}}],FAKE_JOBS_CONSUME=done)
        texts=[n['params']['update']['content']['text'] for n in notes if 'content' in n['params']['update']]
        joined='\n'.join(texts)
        self.assertEqual(joined.count('abc123'),1)  # announced once, not at resume and again at the prompt
        self.assertIn('all green',joined);self.assertIn('pong',texts[-1])

    def test_cancel_says_delegated_work_is_not_stopped(self):
        sid=self.new()
        active=json.dumps({'active':[{'id':'job1','status':'working','project':'/p'},{'id':'job2','status':'queued','project':'/p'}]})
        process=subprocess.Popen([sys.executable,str(SHIM)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,
                                 env={**self.env,'FAKE_SLEEP':'30','FAKE_JOBS_ACTIVE':active})
        def send(r): process.stdin.write(json.dumps({'jsonrpc':'2.0',**r})+'\n');process.stdin.flush()
        def read_until(pred):
            while True:
                m=json.loads(process.stdout.readline())
                if pred(m): return m
        send({'id':1,'method':'initialize','params':{'protocolVersion':1}});read_until(lambda m:m.get('id')==1)
        send({'id':2,'method':'session/new','params':{'cwd':str(self.cwd),'mcpServers':[]}});read_until(lambda m:m.get('id')==2)
        send({'id':3,'method':'session/prompt','params':{'sessionId':sid,'prompt':[{'type':'text','text':'go'}]}})
        time.sleep(1);send({'method':'session/cancel','params':{'sessionId':sid}})
        notes=[]
        end=read_until(lambda m:notes.append(m) or m.get('id')==3)
        process.stdin.close();process.wait(timeout=10)
        self.assertEqual(end['result']['stopReason'],'cancelled')
        text='\n'.join(n['params']['update']['content']['text'] for n in notes if n.get('method')=='session/update' and 'content' in n['params']['update'])
        self.assertIn('job1',text);self.assertIn('job2',text)
        self.assertIn('중단되지 않았',text)

    def test_cancel_without_delegated_jobs_makes_no_claim_about_workers(self):
        sid=self.new()
        responses,notes=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/prompt','params':{'sessionId':sid,'prompt':[{'type':'text','text':'ping'}]}}])
        self.assertNotIn('중단되지 않았','\n'.join(str(n) for n in notes))

    def test_list_shows_every_project_with_the_current_folder_first(self):
        mine=self.new()
        other=self.cwd.parent/'other';other.mkdir();theirs=self.new(other)
        mine_b=self.new(MECLAW_ACP_SESSION='second')
        responses,_=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/list','params':{'cwd':str(self.cwd)}}])
        rows=responses[2]['result']['sessions']
        self.assertEqual({r['sessionId'] for r in rows[:2]},{mine,mine_b})  # this folder first
        self.assertEqual(rows[2]['sessionId'],theirs)
        self.assertTrue(rows[2]['title'].startswith('[other] '))
        self.assertFalse(rows[0]['title'].startswith('['))
        everything,_=self.talk([{'id':3,'method':'session/list','params':{}}])
        self.assertEqual(len(everything[3]['result']['sessions']),3)

    def test_resuming_another_projects_session_keeps_its_context_and_says_so(self):
        other=self.cwd.parent/'other';other.mkdir();theirs=self.new(other)
        self.history.write_text(json.dumps([{'origin':'user','type':'text','text':'old question'},
                                            {'origin':'assistant','type':'text','text':'old answer'}]))
        responses,notes=self.talk([{'id':1,'method':'initialize','params':{'protocolVersion':1}},
            {'id':2,'method':'session/resume','params':{'sessionId':theirs,'cwd':str(self.cwd),'mcpServers':[]}},
            {'id':3,'method':'session/prompt','params':{'sessionId':theirs,'prompt':[{'type':'text','text':'ping'}]}}])
        self.assertIn('result',responses[2])
        texts=[n['params']['update']['content']['text'] for n in notes if 'content' in n['params']['update']]
        self.assertIn(str(other.resolve()),texts[0]);self.assertEqual(texts[1:3],['old question','old answer'])
        registry=json.loads((Path(self.env['MECLAW_ACP_STATE'])/'sessions.json').read_text())
        self.assertEqual(registry[theirs]['cwd'],str(other.resolve()))  # still bound to its own project


if __name__=='__main__': unittest.main()
