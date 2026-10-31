import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import threading
import urllib.request
import urllib.error
import subprocess
import sys
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'src/raynet-guix/users/orka/files/.local/bin/pi-microclaw'
loader=importlib.machinery.SourceFileLoader('bridge',str(SCRIPT))
spec=importlib.util.spec_from_loader(loader.name,loader)
b=importlib.util.module_from_spec(spec)
loader.exec_module(b)

class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)

    def test_setup_preserves_other_provider_and_is_idempotent(self):
        path=self.root/'models.json'
        path.write_text(json.dumps({'providers':{'ollama':{'models':[{'id':'mine'}]}}}))
        b.setup(path)
        b.setup(path)
        config=json.loads(path.read_text())
        self.assertEqual(config['providers']['ollama'],{'models':[{'id':'mine'}]})
        self.assertEqual(config['providers']['microclaw-local']['api'],'openai-completions')
        self.assertNotIn('Bearer',path.read_text())

    def test_setup_refuses_existing_different_provider(self):
        path=self.root/'models.json'
        path.write_text('{"providers":{"microclaw-local":{"baseUrl":"custom"}}}')
        before=path.read_text()
        with self.assertRaises(ValueError): b.setup(path)
        self.assertEqual(path.read_text(),before)

    def test_dedicated_profile_does_not_copy_or_mutate_existing_auth(self):
        home=self.root/'home'
        auth=home/'.pi/agent/auth.json'
        auth.parent.mkdir(parents=True)
        auth.write_text('{"anthropic":{"type":"oauth","refresh":"fixture"}}')
        integration=home/'.pi/agent/extensions/herdr-agent-state.ts'
        integration.parent.mkdir();integration.write_text('// existing integration')
        profile=b.setup_profile(home)
        self.assertFalse((profile/'auth.json').exists())
        self.assertEqual(json.loads(auth.read_text())['anthropic']['refresh'],'fixture')
        self.assertEqual((profile/'extensions/herdr-agent-state.ts').resolve(),integration)

    def test_only_latest_user_prompt_is_forwarded(self):
        body={'model':'microclaw','messages':[{'role':'system','content':'frontend policy'},
              {'role':'user','content':'old'},{'role':'assistant','content':'answer'},
              {'role':'user','content':[{'type':'text','text':'current'}]}]}
        self.assertEqual(b.extract_prompt(body),'current')

    def test_tools_and_images_are_rejected(self):
        for extra in ({'tools':[{'type':'function'}]}, {'messages':[{'role':'user','content':[{'type':'image_url'}]}]}):
            body={'model':'microclaw','messages':[{'role':'user','content':'test'}]}
            body.update(extra)
            with self.assertRaises(ValueError): b.extract_prompt(body)

    def test_project_config_keeps_data_but_maps_tools_to_project(self):
        source=self.root/'gateway.json'
        source.write_text(json.dumps({'llm_provider':'openai-codex','model':'gpt-6.1-terra','data_dir':'/existing/data',
                                      'channels':{'telegram':{'enabled':True}},'high_risk_tool_user_confirmation_required':True}))
        project=self.root/'project'; project.mkdir()
        config=b.project_config(source,self.root/'work',project)
        loaded=json.loads(config.read_text())
        self.assertEqual(loaded['data_dir'],'/existing/data')
        self.assertTrue(loaded['high_risk_tool_user_confirmation_required'])
        self.assertEqual(loaded['working_dir_isolation'],'direct')
        self.assertEqual(Path(loaded['working_dir']),project)
        self.assertFalse(project.is_symlink())
        self.assertFalse(loaded['channels'].get('telegram',{}).get('enabled',False))

    def test_cancel_stops_owned_subprocess(self):
        with self.assertRaises(InterruptedError):
            b.invoke([sys.executable,'-c','import time; time.sleep(20)'],lambda:True,2)

    def test_timeout_is_not_success(self):
        with self.assertRaises(TimeoutError):
            b.invoke([sys.executable,'-c','import time; time.sleep(20)'],lambda:False,0.05)

    def test_colored_runtime_usage_is_preserved(self):
        log='INFO microclaw_engine::agent_engine: Agent iteration completed \x1b[3minput_tokens\x1b[0m=12 \x1b[3moutput_tokens\x1b[0m=3'
        program='print('+repr(log)+'); print(\'{"ok":true,"response":"ok"}\')'
        result=b.invoke([sys.executable,'-c',program],lambda:False,2)
        self.assertEqual(result['usage']['total_tokens'],15)

    def start_server(self):
        calls=[]
        def run(prompt,cancel):
            calls.append(prompt)
            return {'text':'backend '+prompt,'usage':{'prompt_tokens':7,'completion_tokens':2,'total_tokens':9}}
        app=b.App('test-token',run)
        server=b.Server(('127.0.0.1',0),app)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return server,calls

    def request(self,server,body,token='test-token'):
        req=urllib.request.Request('http://127.0.0.1:'+str(server.server_port)+'/v1/chat/completions',
             data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
        return urllib.request.urlopen(req,timeout=3)

    def test_auth_prevents_backend_execution(self):
        server,calls=self.start_server()
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.request(server,{'model':'microclaw','messages':[{'role':'user','content':'x'}]},'wrong')
        self.assertEqual(error.exception.code,401)
        self.assertEqual(calls,[])

    def test_json_sse_and_retry_do_not_repeat_backend(self):
        server,calls=self.start_server()
        body={'model':'microclaw','messages':[{'role':'user','content':'hello'}]}
        with self.request(server,body) as r:
            result=json.load(r)
        self.assertEqual(result['choices'][0]['message']['content'],'backend hello')
        self.assertEqual(result['usage']['total_tokens'],9)
        body['stream']=True
        with self.request(server,body) as r:
            text=r.read().decode()
        self.assertIn('backend hello',text)
        self.assertIn('data: [DONE]',text)
        self.assertEqual(calls,['hello'])

    def test_busy_request_does_not_start_another_backend(self):
        server,calls=self.start_server()
        with server.app.lock:
            with self.assertRaises(urllib.error.HTTPError) as error:
                self.request(server,{'model':'microclaw','messages':[{'role':'user','content':'x'}]})
        self.assertEqual(error.exception.code,409)
        self.assertEqual(calls,[])

if __name__=='__main__': unittest.main()
