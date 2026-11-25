"""The audit detects content defects; it does not freeze them as correct content."""
from array import array
import csv
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import wave

from tools.audit_content import (FIELDS, ROOT, audit_repository, canonical_engine_ipa,
                                 inspect_wav, phoneme_units, render_csv,
                                 review_rows, word_mappings)


class ContentAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = audit_repository()

    def test_review_covers_every_manifest_asset_and_every_word_including_held_out(self):
        rows = list(review_rows(self.audit))
        self.assertEqual({row['audio_path'] for row in rows},
                         {asset['path'] for asset in self.audit['manifest']})
        self.assertEqual(len(rows), len(self.audit['manifest']))
        words = {word['text'] for word in self.audit['data']['words']}
        self.assertEqual({row['id'] for row in rows if row['kind'] == 'word'}, words)
        for word in self.audit['data']['words']:
            if word['heldOut']:
                self.assertIn('assets/audio/word_' + word['text'] + '.wav',
                              {row['audio_path'] for row in rows})
        self.assertTrue(all(row['review_status'] == 'pending' for row in rows))
        self.assertTrue(all(row['waveform_listening_status'] == 'not_listened_by_expert'
                            for row in rows))

    def test_audio_files_are_checked_against_manifest_and_runtime_references(self):
        self.assertEqual(self.audit['parity_errors'], [])
        self.assertEqual(len(self.audit['audio']), len(self.audit['manifest']))

    def test_u_e_context_mismatch_is_detected_in_a_minimal_fixture(self):
        fixture = {
            'sounds': [{'id': 't', 'ipa': 't'}, {'id': 'u_e', 'ipa': 'ju'},
                       {'id': 'b', 'ipa': 'b'}, {'id': 'c', 'ipa': 'k'}],
            'words': [{'text': 'tube', 'ipa': 'tub', 'skills': ['t', 'u_e', 'b']},
                      {'text': 'cube', 'ipa': 'kjub', 'skills': ['c', 'u_e', 'b']}],
        }
        result = word_mappings(fixture)
        self.assertFalse(result[0]['matches'])
        self.assertEqual(result[0]['composed'], 'tjub')
        self.assertTrue(result[1]['matches'])

    def test_missing_skill_is_never_silently_approved(self):
        fixture = {'sounds': [{'id': 'a', 'ipa': 'æ'}],
                   'words': [{'text': 'a', 'ipa': 'æ', 'skills': ['a', 'unknown']}]}
        result = word_mappings(fixture)[0]
        self.assertFalse(result['matches'])
        self.assertEqual(result['missing'], ['unknown'])

    def test_grapheme_count_is_distinct_from_phoneme_count(self):
        self.assertEqual(phoneme_units('ks'), ['k', 's'])
        self.assertEqual(phoneme_units('kw'), ['k', 'w'])
        self.assertEqual(phoneme_units('ju'), ['j', 'u'])
        self.assertEqual(phoneme_units('dʒ'), ['dʒ'])
        self.assertEqual(phoneme_units('ʃeɪp'), ['ʃ', 'eɪ', 'p'])

    def test_engine_comparison_preserves_meaningful_vowel_differences(self):
        self.assertEqual(canonical_engine_ipa('kˈeɪk'), 'keɪk')
        self.assertEqual(canonical_engine_ipa('sˈiː'), 'si')
        self.assertNotEqual(canonical_engine_ipa('sˈɔŋ'), 'sɑŋ')
        self.assertNotEqual(canonical_engine_ipa('ðˈɐn'), 'ðæn')

    def test_regeneration_preserves_human_review_but_invalidates_changed_audio(self):
        stream = io.StringIO(newline='')
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        first = next(review_rows(self.audit))
        first.update(review_status='approved', waveform_listening_status='listened',
                     reviewer='審査者テスト', notes='人の所見', legal_status='pending')
        writer.writerow(first)
        current = list(csv.DictReader(io.StringIO(render_csv(self.audit, stream.getvalue()))))[0]
        self.assertEqual(current['review_status'], 'approved')
        self.assertEqual(current['notes'], '人の所見')
        changed = stream.getvalue().replace(first['sha256'], 'old-sha')
        updated = list(csv.DictReader(io.StringIO(render_csv(self.audit, changed))))[0]
        self.assertEqual(updated['review_status'], 'pending_changed_audio')
        self.assertEqual(updated['waveform_listening_status'], 'not_listened_changed_audio')
        self.assertEqual(updated['reviewer'], '審査者テスト')
        self.assertEqual(updated['notes'], '人の所見')

    def test_changed_teaching_content_requires_review_even_when_audio_is_unchanged(self):
        for field in ('declared_ipa', 'composed_ipa', 'example_or_meaning', 'hint',
                      'espeak_input', 'skills'):
            with self.subTest(field=field):
                first = next(review_rows(self.audit))
                first.update(review_status='approved', waveform_listening_status='listened',
                             legal_status='approved', reviewer='審査者テスト',
                             reviewed_at='2026-11-11', notes='前回の審査')
                first[field] = '以前の教材内容'
                stream = io.StringIO(newline='')
                writer = csv.DictWriter(stream, fieldnames=FIELDS)
                writer.writeheader()
                writer.writerow(first)
                updated = next(csv.DictReader(io.StringIO(render_csv(self.audit, stream.getvalue()))))
                self.assertEqual(updated['review_status'], 'pending_changed_content')
                self.assertEqual(updated['waveform_listening_status'], 'needs_recheck_changed_content')
                self.assertEqual(updated['legal_status'], 'approved')
                self.assertEqual(updated['reviewer'], '審査者テスト')
                self.assertEqual(updated['notes'], '前回の審査')

    def test_strict_mode_blocks_release_with_open_blocking_findings(self):
        # The evidence-gathering command remains useful even when not ready
        # for release. Only --strict is a release gate.
        result = subprocess.run([sys.executable, 'tools/audit_content.py', '--strict'],
                                cwd=ROOT, capture_output=True, text=True, check=False)
        expected = 2 if any(f['severity'] == 'block_release'
                            for f in self.audit['findings']) else 0
        self.assertEqual(result.returncode, expected, result.stderr)


class WaveAuditTests(unittest.TestCase):
    def write_wav(self, path, samples):
        pcm = array('h', samples)
        if sys.byteorder != 'little':
            pcm.byteswap()
        with wave.open(str(path), 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(16000)
            wav.writeframes(pcm.tobytes())

    def test_silent_and_clipped_audio_are_reported_from_pcm(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.wav'
            self.write_wav(path, [0] * 1600)
            silent = inspect_wav(path)
            self.assertTrue(silent['silent'])
            self.assertIsNone(silent['active_rms_dbfs'])
            self.write_wav(path, [0] * 160 + [32767, -32768] + [0] * 160)
            clipped = inspect_wav(path)
            self.assertFalse(clipped['silent'])
            self.assertEqual(clipped['clipped_samples'], 2)

    def test_active_level_does_not_mistake_padding_for_quiet_speech(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.wav'
            self.write_wav(path, [0] * 1600 + [1000, -1000] * 160 + [0] * 1600)
            measured = inspect_wav(path)
            self.assertAlmostEqual(measured['duration_ms'], 220)
            self.assertAlmostEqual(measured['active_ms'], 20)
            self.assertAlmostEqual(measured['active_rms_dbfs'], -30.309, places=3)


if __name__ == '__main__':
    unittest.main()
