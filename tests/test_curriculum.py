import hashlib
import json
from pathlib import Path
import unittest
import wave
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]

class CurriculumTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((ROOT/'assets/data/curriculum.json').read_text())
        cls.sounds={s['id']:s for s in cls.data['sounds']}
        cls.words={w['text']:w for w in cls.data['words']}
    def test_all_seventy_lessons_have_referenced_sound_assets(self):
        self.assertEqual(len(self.data['islands']),10)
        for island in self.data['islands']:
            self.assertEqual(len(island['lessons']),7)
            for lesson in island['lessons']:
                self.assertIn(lesson['skill'],self.sounds)
                self.assertTrue((ROOT/self.sounds[lesson['skill']]['audio']).is_file())
    def test_word_coverage_and_no_duplicate_spellings(self):
        self.assertEqual(len(self.words),len(self.data['words']))
        self.assertGreaterEqual(len(self.words),120)
        self.assertGreaterEqual(sum(w['heldOut'] for w in self.words.values()),30)
        for word in self.words.values():
            self.assertTrue(word['ipa']);self.assertTrue(word['meaning'])
            for skill in word['skills']:self.assertIn(skill,self.sounds,word['text'])
    def test_held_out_words_are_not_sound_examples(self):
        for sound in self.sounds.values():
            self.assertIn(sound['example'],self.words)
            self.assertFalse(self.words[sound['example']]['heldOut'])
    def test_every_audio_asset_matches_the_license_manifest(self):
        manifest=json.loads((ROOT/'assets/licenses/assets.json').read_text())
        paths=set()
        for asset in manifest:
            path=ROOT/asset['path'];paths.add(path.resolve())
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),asset['sha256'],asset['path'])
            with wave.open(str(path)) as wav:
                self.assertEqual(wav.getnchannels(),1)
                self.assertEqual(wav.getsampwidth(),2)
                self.assertGreater(wav.getnframes(),0)
                self.assertLess(wav.getnframes()/wav.getframerate(),15)
        self.assertEqual(paths,{p.resolve() for p in (ROOT/'assets/audio').glob('*.wav')})
    def test_each_word_and_letter_name_has_bundled_audio(self):
        for word in self.words:
            self.assertTrue((ROOT/f'assets/audio/word_{word}.wav').is_file(),word)
        for letter in 'abcdefghijklmnopqrstuvwxyz':
            self.assertTrue((ROOT/f'assets/audio/name_{letter}.wav').is_file())
    def test_production_manifest_does_not_enable_uploads_or_backups(self):
        tree=ET.parse(ROOT/'android/app/src/main/AndroidManifest.xml')
        android='{http://schemas.android.com/apk/res/android}'
        permissions={p.attrib.get(android+'name') for p in tree.getroot().findall('uses-permission')}
        self.assertNotIn('android.permission.INTERNET',permissions)
        app=tree.getroot().find('application')
        self.assertEqual(app.attrib[android+'allowBackup'],'false')
        self.assertEqual(app.attrib[android+'usesCleartextTraffic'],'false')
    def test_gradle_wrapper_is_checksum_pinned(self):
        props=(ROOT/'android/gradle/wrapper/gradle-wrapper.properties').read_text()
        self.assertRegex(props,r'distributionSha256Sum=[0-9a-f]{64}')

if __name__=='__main__':unittest.main()
