"""Guard audible phoneme playback and safe offline asset mastering."""
from array import array
import math
from pathlib import Path
import statistics
import struct
import unittest
import wave

from tools.audio_levels import normalize

ROOT = Path(__file__).resolve().parents[1]


class AudioAssetLevelsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.levels = {}
        # Independently measure the full non-silent span, rather than reusing
        # the generator's gated frame measurement as its own test oracle.
        for path in (ROOT / 'assets/audio').glob('*.wav'):
            with wave.open(str(path)) as wav:
                raw = wav.readframes(wav.getnframes())
                samples = struct.unpack('<' + 'h' * (len(raw) // 2), raw)
            nonzero = [i for i, sample in enumerate(samples) if sample]
            if not nonzero:
                raise AssertionError(f'{path.name} is completely silent')
            audible = samples[nonzero[0]:nonzero[-1] + 1]
            rms = math.sqrt(sum(x * x for x in audible) / len(audible))
            peak = max(abs(x) for x in samples)
            cls.levels[path.stem] = (
                20 * math.log10(rms / 32768),
                20 * math.log10(peak / 32768),
            )

    def test_every_phoneme_is_as_audible_as_the_word_library(self):
        reference = statistics.median(level[0] for key, level in self.levels.items()
                                     if key.startswith('word_'))
        for key, (rms, _) in self.levels.items():
            if key.startswith('sound_'):
                with self.subTest(asset=key):
                    self.assertLess(abs(rms - reference), 2.0)

    def test_all_bundled_speech_has_safe_peaks_and_a_consistent_level(self):
        for key, (rms, peak) in self.levels.items():
            with self.subTest(asset=key):
                self.assertGreater(rms, -24)
                self.assertLess(rms, -19)
                self.assertLessEqual(peak, -1.49)


class AudioMasteringTests(unittest.TestCase):
    def test_gain_preserves_waveform_and_sound_length(self):
        source = array('h', [0] * 800 + [100, 200, -100, -200] * 100
                       + [0] * 800)
        output, _ = normalize(source, 16000)
        audible = output[320:720]
        self.assertEqual(len(output), 320 + 400 + 1920)
        self.assertEqual(audible[0], -audible[2])
        self.assertEqual(audible[1], -audible[3])
        self.assertAlmostEqual(audible[1] / audible[0], 2, places=3)
        self.assertGreater(audible[0], 100)

    def test_peak_headroom_wins_over_loudness_target(self):
        source = array('h', [100, -100] * 1000)
        source[100] = 30000
        output, _ = normalize(source, 16000)
        peak = max(abs(x) for x in output)
        self.assertAlmostEqual(20 * math.log10(peak / 32768), -1.5, places=3)
        self.assertLess(peak, 32767)

    def test_near_silent_edges_are_preserved(self):
        # Threshold trimming would remove these quiet transitions.
        output, _ = normalize(array('h', [0, 1, 20, 200, -200, -20, -1, 0]),
                              16000)
        self.assertGreater(output[320], 0)
        self.assertLess(output[325], 0)
        self.assertEqual(len(output), 320 + 6 + 1920)

    def test_silence_must_be_fixed_at_the_source(self):
        with self.assertRaisesRegex(ValueError, 'silent'):
            normalize(array('h', [0] * 16000), 16000)


if __name__ == '__main__':
    unittest.main()
