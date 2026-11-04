"""Match bundled speech levels without changing pitch, timbre, or dynamics.

Whole-file RMS is unsuitable for isolated phonemes: their trailing silence is
longer than their sound. Measure 10 ms frames within 30 dB of the loudest frame,
then apply one constant gain to the entire clip. There is no compressor,
limiter, resampling, or added vowel. A peak ceiling leaves playback headroom.
This is a level check, not a check of pronunciation accuracy.
"""
from array import array
from dataclasses import dataclass
import math
from pathlib import Path
import sys
import wave

TARGET_ACTIVE_DBFS = -21.5
PEAK_CEILING_DBFS = -1.5
GATE_DB = -30.0
FRAME_SECONDS = 0.010
LEADING_SECONDS = 0.020
TRAILING_SECONDS = 0.120


@dataclass(frozen=True)
class Levels:
    active_dbfs: float
    peak_dbfs: float
    active_seconds: float


def measure(samples, rate):
    """Return gated frame RMS, sample peak, and duration of audible frames."""
    if not samples or not any(samples):
        raise ValueError('Audio is silent')
    frame_size = max(1, round(rate * FRAME_SECONDS))
    frames = []
    for start in range(0, len(samples), frame_size):
        frame = samples[start:start + frame_size]
        frames.append((sum(sample * sample for sample in frame), len(frame)))
    loudest = max(energy / count for energy, count in frames)
    threshold = loudest * 10 ** (GATE_DB / 10)
    active = [(energy, count) for energy, count in frames
              if energy / count >= threshold and energy > 0]
    active_samples = sum(count for _, count in active)
    rms = math.sqrt(sum(energy for energy, _ in active) / active_samples)
    peak = max(abs(sample) for sample in samples)
    return Levels(20 * math.log10(rms / 32768),
                  20 * math.log10(peak / 32768), active_samples / rate)


def read_pcm(path):
    with wave.open(str(path), 'rb') as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2:
            raise ValueError(f'Expected 16-bit mono PCM: {path}')
        samples = array('h', wav.readframes(wav.getnframes()))
        if sys.byteorder != 'little':
            samples.byteswap()
        return samples, wav.getframerate()


def normalize(samples, rate):
    """Trim only exact zeros at the edges, preserve padding, and apply gain."""
    # Do not threshold-trim: quiet fricative onsets and stop releases matter.
    first = next((i for i, sample in enumerate(samples) if sample), None)
    if first is None:
        raise ValueError('Audio is silent; fix synthesis rather than amplify it')
    last = len(samples) - next(i for i, sample in enumerate(reversed(samples))
                              if sample)
    clip = (array('h', [0]) * round(rate * LEADING_SECONDS)
            + array('h', samples[first:last])
            + array('h', [0]) * round(rate * TRAILING_SECONDS))
    before = measure(clip, rate)
    gain_db = min(TARGET_ACTIVE_DBFS - before.active_dbfs,
                  PEAK_CEILING_DBFS - before.peak_dbfs)
    gain = 10 ** (gain_db / 20)
    # The ceiling is enforced by gain selection, never by clipping samples.
    output = array('h', (round(sample * gain) for sample in clip))
    after = measure(output, rate)
    return output, {
        'method': 'active-rms-v1',
        'gain_db': round(gain_db, 2),
        'active_rms_dbfs': round(after.active_dbfs, 2),
        'peak_dbfs': round(after.peak_dbfs, 2),
    }


def normalize_file(path: Path):
    samples, rate = read_pcm(path)
    output, metadata = normalize(samples, rate)
    if sys.byteorder != 'little':
        output.byteswap()
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(output.tobytes())
    return metadata
