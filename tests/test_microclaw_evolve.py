import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'src/raynet-guix/users/orka/files/.local/bin/microclaw-evolve'
loader = importlib.machinery.SourceFileLoader('evolve', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
e = importlib.util.module_from_spec(spec)
loader.exec_module(e)

class EvolutionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.w = e.Workflow(Path(self.tmp.name))
        self.w.init()
        (self.w.state / 'suite.json').write_text(json.dumps([
            {'prompt': 'fixture a', 'expected': 'ok'},
            {'prompt': 'fixture b', 'expected': 'ok'}]))

    def candidate(self):
        self.w.record({'event': 'AfterToolCall', 'result': {'is_error': True, 'content': 'build failed token=secret123456'}})
        with patch.object(e, 'llm', return_value='Check Guix dependencies before retrying.'):
            return self.w.propose()

    def test_init_preserves_active(self):
        self.w.active.write_text('custom')
        self.w.init()
        self.assertEqual(self.w.active.read_text(), 'custom')

    def test_meclaw_can_submit_shared_evidence(self):
        self.w.record_experience({'schema_version':1,'agent':'meclaw','kind':'verification',
                                  'outcome':'success','summary':'Native MeClaw inference completed'})
        result=self.w.search('Native MeClaw',agent='meclaw')
        self.assertEqual(result['evidence'][0]['payload']['agent'],'meclaw')

    def test_meclaw_backend_uses_tools_free_evaluation_endpoint(self):
        completed=subprocess.CompletedProcess([],0,'{"text":"evaluated"}','')
        with patch.object(e.subprocess,'run',return_value=completed) as call:
            result=e.llm('evaluation system','fixture prompt',{'model':'gpt-6.1-terra','backend':'meclaw'})
        self.assertEqual(result,'evaluated')
        self.assertIn('meclaw-workflow',call.call_args.args[0][0])
        self.assertEqual(call.call_args.args[0][1],'infer')
        self.assertEqual(json.loads(call.call_args.kwargs['input'])['system'],'evaluation system')

    def test_hook_redacts_and_keeps_error_label(self):
        self.candidate()
        row = self.w.db().execute('select payload,failed from traces').fetchone()
        self.assertNotIn('secret123456', row[0])
        self.assertEqual(row[1], 1)

    def test_approval_pause_does_not_feed_failure_evolution(self):
        self.w.record({'event':'AfterToolCall','tool_name':'bash',
                       'result':{'is_error':True,'error_type':'approval_required','content':'approval card'}})
        row=self.w.db().execute('select payload,failed from traces').fetchone()
        self.assertEqual(row[1],0)
        self.assertEqual(json.loads(row[0])['outcome'],'unknown')
        with self.assertRaisesRegex(ValueError,'no new failed tool evidence'):
            self.w.propose()

    def test_init_reclassifies_legacy_approval_without_deleting_evidence(self):
        payload=json.dumps({'error_type':'approval_required','outcome':'failure','content':'approval card'})
        with self.w.db() as db:
            db.execute('insert into traces(created,failed,payload) values(?,?,?)',('fixture',1,payload))
        self.w.init()
        row=self.w.db().execute('select payload,failed from traces').fetchone()
        self.assertEqual(row[1],0)
        self.assertEqual(json.loads(row[0])['content'],'approval card')

    def test_candidate_does_not_replace_champion(self):
        before = self.w.active.read_text()
        self.candidate()
        self.assertEqual(before, self.w.active.read_text())
        with self.assertRaises(ValueError):
            self.w.propose()

    def test_unverified_promotion_rejected(self):
        with self.assertRaises(ValueError):
            self.w.promote(self.candidate())

    def test_evaluation_promotion_and_rollback(self):
        before = self.w.active.read_text()
        cid = self.candidate()
        with patch.object(e, 'llm', side_effect=['wrong', 'ok', 'ok', 'ok']):
            report = self.w.evaluate(cid)
        self.assertTrue(report['eligible'])
        self.w.promote(cid)
        self.assertNotEqual(before, self.w.active.read_text())
        self.w.rollback()
        self.assertEqual(before, self.w.active.read_text())

    def test_regression_rejected(self):
        cid = self.candidate()
        with patch.object(e, 'llm', side_effect=['ok', 'wrong', 'wrong', 'ok']):
            self.assertFalse(self.w.evaluate(cid)['eligible'])
        with self.assertRaises(ValueError):
            self.w.promote(cid)

    def test_changed_candidate_or_baseline_rejected(self):
        cid = self.candidate()
        with patch.object(e, 'llm', side_effect=['wrong', 'ok', 'ok', 'ok']):
            self.w.evaluate(cid)
        self.w.active.write_text('changed baseline')
        with self.assertRaises(ValueError):
            self.w.promote(cid)

    def test_unsafe_identifier_rejected(self):
        with self.assertRaises(ValueError):
            self.w.evaluate('../outside')

    def test_init_creates_codex_gateway_and_observation_hook(self):
        config = json.loads((self.w.root / 'gateway.json').read_text())
        self.assertEqual(config['llm_provider'], 'openai-codex')
        self.assertEqual(config['web_host'], '127.0.0.1')
        self.assertEqual(config['web_max_inflight_per_session'], 1)
        self.assertNotIn('web_auth_token', config)
        self.assertFalse(config['reflector_enabled'])
        self.assertEqual(config['skill_review_min_tool_calls'], 0)
        hook = self.w.root / 'microclaw/hooks/evolution/HOOK.md'
        self.assertIn('AfterToolCall', hook.read_text())

    def test_microclaw_inference_isolates_calls_and_denies_tools(self):
        observed = []
        def run(argv, **kwargs):
            cfg = json.loads(Path(argv[2]).read_text())
            observed.append(cfg)
            self.assertEqual(cfg['tool_policy']['deny_tools'], ['*'])
            self.assertEqual(Path(cfg['soul_path']).read_text(), 'system instruction')
            return subprocess.CompletedProcess(argv, 0, '{"ok":true,"response":"ok"}', '')
        with patch.object(e.subprocess, 'run', side_effect=run):
            self.assertEqual(e.llm('system instruction', 'task', {'model': 'gpt-6.1-sol'}), 'ok')
        self.assertEqual(len(observed), 1)

    def test_tick_calls_model_at_most_once_per_day_even_after_failure(self):
        self.w.record({'result': {'is_error': True, 'content': 'fixture error'}})
        with patch.object(e, 'llm', side_effect=TimeoutError):
            with self.assertRaises(TimeoutError):
                self.w.tick()
        with patch.object(e, 'llm') as model:
            self.assertEqual(self.w.tick(), 'daily proposal budget exhausted')
            model.assert_not_called()

    def test_password_initialized_once_and_stored_privately(self):
        output = subprocess.CompletedProcess([], 0, 'Generated password: fixture-password\n', '')
        with patch.object(e.subprocess, 'run', return_value=output) as run:
            self.w.secure_web()
            self.w.secure_web()
            self.assertEqual(run.call_count, 1)
        password = self.w.root / 'web-initial-password.txt'
        self.assertEqual(password.read_text(), 'fixture-password\n')
        self.assertEqual(password.stat().st_mode & 0o777, 0o600)

    def test_candidate_keeps_evidence_and_meta_skill(self):
        cid = self.candidate()
        path = self.w.candidate_path(cid)
        self.assertIn('build failed', (path / 'trace.json').read_text())
        self.assertNotIn('secret123456', (path / 'trace.json').read_text())
        self.assertEqual((path / 'meta-skill.md').read_text(), (self.w.state / 'meta-skill.md').read_text())

class RepositoryWiringTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'local-state'
        self.repo = self.base / 'workflow-evolution'
        self.repo.mkdir()
        (self.repo / '.git').mkdir()
        (self.repo / 'README.md').write_text('existing repository')
        self.w = e.Workflow(self.root)

    def test_existing_state_migrates_without_losing_original(self):
        self.w.init()
        self.w.active.write_text('evolved champion')
        self.w.record({'result': {'is_error': True, 'content': 'fixture'}})
        before = self.w.status()
        self.w.wire(self.repo)
        self.assertTrue(self.root.is_symlink())
        self.assertEqual(self.root.resolve(), self.repo)
        self.assertEqual(self.w.status(), before)
        self.assertEqual((self.repo / 'README.md').read_text(), 'existing repository')
        self.assertEqual(len(list(self.base.glob('local-state.pre-wiring-*'))), 1)
        self.w.wire(self.repo)
        self.assertEqual(len(list(self.base.glob('local-state.pre-wiring-*'))), 1)

    def test_conflicting_target_fails_without_changing_source(self):
        self.w.init()
        (self.repo / 'evolution').mkdir()
        with self.assertRaises(ValueError):
            self.w.wire(self.repo)
        self.assertFalse(self.root.is_symlink())
        self.assertTrue(self.w.active.exists())

    def test_wrong_symlink_is_not_replaced(self):
        other = self.base / 'other'
        other.mkdir()
        self.root.symlink_to(other)
        with self.assertRaises(ValueError):
            self.w.wire(self.repo)
        self.assertEqual(self.root.resolve(), other)

    def test_missing_checkout_is_not_silently_initialized(self):
        with self.assertRaises(ValueError):
            self.w.wire(self.base / 'not-cloned')
        self.assertFalse(self.root.exists())

    def test_fresh_checkout_restores_history_before_initialization(self):
        self.w.init()
        self.w.record({'result': {'is_error': True, 'content': 'restore fixture'}})
        self.w.snapshot()
        dump = (self.w.state / 'snapshots/evidence.sql').read_text()
        e.atomic(self.repo / 'evolution/snapshots/evidence.sql', dump)
        fresh = e.Workflow(self.base / 'fresh-state')
        fresh.wire(self.repo)
        fresh.init()
        self.assertEqual(fresh.status()['traces'], 1)
        fresh.record({'result': {'is_error': False}})
        fresh.wire(self.repo)
        self.assertEqual(fresh.status()['traces'], 2)

    def test_snapshot_contains_pending_wal_records_and_restores_cleanly(self):
        self.w.init()
        cid = None
        self.w.record({'result': {'is_error': True, 'content': 'snapshot fixture'}})
        with patch.object(e, 'llm', return_value='Reusable procedure'):
            cid = self.w.propose()
        self.w.snapshot()
        with e.sqlite3.connect(':memory:') as db:
            db.executescript((self.w.state / 'snapshots/evidence.sql').read_text())
            self.assertEqual(db.execute('pragma integrity_check').fetchone(), ('ok',))
            self.assertEqual(db.execute('select id,status from proposals').fetchone(), (cid, 'pending'))
            self.assertEqual(db.execute('select count(*) from traces').fetchone(), (1,))

class SharedWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.w = e.Workflow(self.base / 'state')
        self.w.init()

    def test_champion_is_canonical_and_runtime_links_to_it(self):
        self.assertEqual(self.w.active, self.w.root / 'skills/local-workflow/SKILL.md')
        runtime = self.w.root / 'microclaw/skills/local-workflow'
        self.assertTrue(runtime.is_symlink())
        self.assertEqual(runtime.resolve(), self.w.active.parent.resolve())
        self.w.active.write_text('promoted procedure')
        self.assertEqual((runtime / 'SKILL.md').read_text(), 'promoted procedure')

    def test_legacy_evolved_skill_is_preserved(self):
        legacy = e.Workflow(self.base / 'legacy')
        old = legacy.root / 'microclaw/skills/local-workflow/SKILL.md'
        e.atomic(old, 'previously evolved skill')
        legacy.init()
        self.assertEqual(legacy.active.read_text(), 'previously evolved skill')
        self.assertTrue(old.parent.is_symlink())

    def test_share_is_idempotent_and_preserves_existing_skills(self):
        home = self.base / 'home'
        unrelated = home / '.claude/skills/custom/SKILL.md'
        e.atomic(unrelated, 'existing skill')
        self.w.share_skills(home)
        self.w.share_skills(home)
        for directory in ('.agents/skills', '.claude/skills', '.gemini/antigravity-cli/skills'):
            self.assertEqual((home / directory / 'local-workflow').resolve(), self.w.active.parent.resolve())
        self.assertEqual(unrelated.read_text(), 'existing skill')

    def test_conflict_is_detected_before_creating_consumer_links(self):
        home = self.base / 'home'
        conflict = home / '.claude/skills/local-workflow/SKILL.md'
        e.atomic(conflict, 'unrelated local-workflow')
        with self.assertRaises(ValueError):
            self.w.share_skills(home)
        self.assertFalse((home / '.agents/skills/local-workflow').exists())
        self.assertEqual(conflict.read_text(), 'unrelated local-workflow')

    def test_all_agents_submit_searchable_redacted_experience(self):
        for agent in ('codex', 'claude', 'agy'):
            self.w.record_experience({'schema_version': 1, 'agent': agent, 'kind': 'verification',
                                     'outcome': 'failure', 'project': 'example',
                                     'summary': 'Guix dependency failure token=secret123456'})
            found = self.w.search('Guix', 3, agent)
            self.assertEqual(len(found['evidence']), 1)
            self.assertEqual(found['evidence'][0]['payload']['agent'], agent)
            self.assertNotIn('secret123456', json.dumps(found))

    def test_success_experiences_keep_reusable_summary(self):
        self.w.record_experience({'schema_version': 1, 'agent': 'codex', 'kind': 'verification',
                                 'outcome': 'success', 'summary': 'Guix shell resolved the missing gcc'})
        found = self.w.search('gcc')
        self.assertEqual(len(found['evidence']), 1)
        self.assertFalse(found['evidence'][0]['failed'])
        with self.assertRaises(ValueError):
            self.w.propose()

    def test_bad_schema_or_source_does_not_write(self):
        with self.assertRaises(ValueError):
            self.w.record_experience({'schema_version': 1, 'agent': 'invented', 'summary': 'bad'})
        self.assertEqual(self.w.status()['traces'], 0)

    def test_search_treats_sql_and_wildcards_as_literal_text(self):
        self.w.record_experience({'schema_version': 1, 'agent': 'agy', 'kind': 'tool',
                                 'outcome': 'unknown', 'summary': 'literal 100% problem'})
        self.assertEqual(len(self.w.search('100%')['evidence']), 1)
        self.assertEqual(self.w.search("%' OR 1=1 --")['evidence'], [])

if __name__ == '__main__':
    unittest.main()
