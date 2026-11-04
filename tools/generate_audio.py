"""Generate replaceable FORMANT-synthesized draft audio using eSpeak NG.

Uses standard en-us/ja, never MBROLA or third-party sampled voices.
Install espeak-ng separately; its executable is NOT distributed with the app.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from audio_levels import normalize_file

ROOT=Path(__file__).resolve().parents[1]
NARRATION={
    'listen':'おとをきいて、こたえをえらぼう。',
    'read':'このことばの、おとをえらぼう。',
    'case':'おなじもじを、えらぼう。',
    'build':'おとをきいて、もじをならべてみよう。',
    'mic':'おてほんをきいて、まねしてみよう。',
    'welcome':'おとのぼうけんへ、ようこそ。おうちのひとと、じゅんびしよう。',
}


def phoneme_text(phoneme):
    # Bare voiced stops/affricates ([[b]], [[d]], [[g]], [[dZ]]) are SILENT
    # in eSpeak NG 1.52. Give them an explicit following pause so their actual
    # release is rendered, without adding a schwa or a letter name.
    # English [[r]] is also omitted in isolation. r- is eSpeak's linking /ɹ/,
    # not the trilled R or a replacement vowel. Keep all clips reviewable drafts.
    return f'[[{"r-" if phoneme == "r" else phoneme}_]]'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--espeak',default='espeak-ng')
    args=parser.parse_args()
    curriculum=json.loads((ROOT/'assets/data/curriculum.json').read_text())
    target=ROOT/'assets/audio';target.mkdir(parents=True,exist_ok=True)
    entries=[]
    jobs=[(f'sound_{s["id"]}',phoneme_text(s['espeak']),'en-us') for s in curriculum['sounds']]
    jobs += [(f'word_{w["text"]}',w['text'],'en-us') for w in curriculum['words']]
    jobs += [(f'name_{letter}',letter.upper(),'en-us') for letter in 'abcdefghijklmnopqrstuvwxyz']
    jobs += [(f'guide_{key}',text,'ja') for key,text in NARRATION.items()]
    for name,text,voice in jobs:
        path=target/f'{name}.wav'
        subprocess.run([args.espeak,'-D','-v',voice,'-s','135','-p','52','-w',str(path),text],check=True,capture_output=True)
        processing = normalize_file(path)
        entries.append(dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            source='Original text, eSpeak NG 1.52.0 formant synthesis',voice=voice,status='draft-unreviewed',
            embedded_engine=False,commercial_and_redistribution='Generated speech; no engine, voice binaries or sampled recordings included',
            processing=processing))
    (ROOT/'assets/licenses/assets.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
    print(f'Generated {len(entries)} draft WAV files')
if __name__=='__main__':main()
