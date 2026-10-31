import importlib.machinery
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
import urllib.request

BIN=Path(__file__).resolve().parents[1]/'src/raynet-guix/users/orka/files/.local/bin'

def module(name,path):
    loader=importlib.machinery.SourceFileLoader(name,str(path))
    spec=importlib.util.spec_from_loader(name,loader)
    value=importlib.util.module_from_spec(spec);loader.exec_module(value)
    return value

b=module('pi_meclaw_shared',BIN/'pi-microclaw')
p=module('pi_meclaw_launcher',BIN/'pi-meclaw')

class PiMeclawTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name)

    def test_profile_is_meclaw_and_does_not_modify_existing_pi_auth(self):
        auth=self.home/'.pi/agent/auth.json';auth.parent.mkdir(parents=True)
        auth.write_text('{"existing":"keep"}')
        profile=b.setup_profile(self.home,backend='meclaw',provider=p.PROVIDER)
        b.setup_profile(self.home,backend='meclaw',provider=p.PROVIDER)
        config=json.loads((profile/'models.json').read_text())
        self.assertEqual(profile,self.home/'.local/state/pi-meclaw/agent')
        self.assertEqual(config['providers']['meclaw-local']['models'][0]['id'],'meclaw')
        self.assertFalse((profile/'auth.json').exists())
        self.assertEqual(auth.read_text(),'{"existing":"keep"}')

    def test_channel_is_stable_and_separates_projects_and_sessions(self):
        a=p.channel(self.home/'project','default')
        self.assertEqual(a,p.channel(self.home/'project','default'))
        self.assertNotEqual(a,p.channel(self.home/'other','default'))
        self.assertNotEqual(a,p.channel(self.home/'project','issue-1'))

    def test_meclaw_usage_is_translated_without_another_model(self):
        result=p.parse_result('{"text":"ready","usage":{"input_tokens":17,"output_tokens":3}}')
        self.assertEqual(result['text'],'ready')
        self.assertEqual(result['usage'],{'prompt_tokens':17,'completion_tokens':3,'total_tokens':20})
        self.assertIsNone(result['approval'])

    def test_invoke_passes_private_json_over_stdin(self):
        script='import sys,json; p=json.load(sys.stdin); print(json.dumps({"text":p["prompt"],"usage":{}}))'
        result=b.invoke([sys.executable,'-c',script],lambda:False,2,
                        input_text=json.dumps({'prompt':'stdin-only fixture'}),parse_result=p.parse_result,label='MeClaw')
        self.assertEqual(result['text'],'stdin-only fixture')

    def test_bridge_accepts_meclaw_model_and_reports_it_in_json_and_sse(self):
        calls=[]
        def run(prompt,cancel,emit):
            calls.append(prompt);emit({'event':'thinking'})
            return p.parse_result('{"text":"MeClaw backend ready","usage":{}}')
        app=b.App('fixture-token',run,model='meclaw',label='MeClaw')
        server=b.Server(('127.0.0.1',0),app)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        self.addCleanup(server.server_close);self.addCleanup(server.shutdown)
        body={'model':'meclaw','stream':True,'messages':[{'role':'user','content':'hello'}]}
        req=urllib.request.Request('http://127.0.0.1:'+str(server.server_port)+'/v1/chat/completions',
            data=json.dumps(body).encode(),headers={'Authorization':'Bearer fixture-token','Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=3) as response: text=response.read().decode()
        chunks=[json.loads(line[6:]) for line in text.splitlines() if line.startswith('data: {')]
        self.assertTrue(all(c['model']=='meclaw' for c in chunks))
        self.assertIn('[MeClaw]',''.join(c['choices'][0]['delta'].get('content','') for c in chunks))
        self.assertIn('MeClaw backend ready',text)
        self.assertEqual(calls,['hello'])

    def test_unsupported_inputs_and_invalid_backend_output_fail(self):
        with self.assertRaises(ValueError):
            b.extract_prompt({'model':'meclaw','tools':[{}],'messages':[{'role':'user','content':'x'}]},'meclaw')
        with self.assertRaises(ValueError): p.parse_result('{"error":"not successful"}')

if __name__=='__main__': unittest.main()
