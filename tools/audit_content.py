"""Read-only curriculum/audio audit; --write produces review documents only.

No dictionary is downloaded and no recording is judged phonetically correct.
Optional --espeak queries engine text metadata, NOT the contents of the WAVs.
Use --strict for a release gate: known blockers then cause exit status 2.
"""
from array import array
import argparse
from collections import Counter
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import re
import statistics
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
REPORT = Path('docs/audio-content-audit.md')
REVIEW = Path('docs/experts/audio-review.csv')
REVIEW_FIELDS = ('review_status', 'waveform_listening_status', 'reviewer', 'reviewed_at', 'reference',
                 'legal_status', 'notes')
CONTENT_REVIEW_FIELDS = ('text', 'declared_ipa', 'espeak_input', 'skills',
                         'composed_ipa', 'phoneme_count', 'example_or_meaning',
                         'hint', 'runtime_audio_ref')
FIELDS = ('kind', 'id', 'text', 'declared_ipa', 'espeak_input', 'engine_ipa',
          'skills', 'composed_ipa', 'phoneme_count', 'example_or_meaning',
          'hint', 'audio_path', 'runtime_audio_ref', 'sha256', 'duration_ms',
          'active_ms', 'active_rms_dbfs', 'peak_dbfs', 'clipped_samples',
          'source_status', 'machine_flags', 'expert_checks', *REVIEW_FIELDS)
CONTINUANTS = {'m', 'n', 'ŋ', 'l', 'ɹ', 'f', 'v', 's', 'z', 'ʃ', 'θ', 'ð',
               'h', 'w', 'j'}
# A crosswalk of the DECLARED eSpeak notation, not a pronunciation oracle.
ESPEAK_IPA = dict(zip(
    ('s a t p I n m d g A: k E V b h f l r dZ v w j z ks kw S tS T D N '
     'st sp bl pl nd nt eI aI oU ju: i:').split(),
    's æ t p ɪ n m d ɡ ɑ k ɛ ʌ b h f l ɹ dʒ v w j z ks kw ʃ tʃ θ ð ŋ '
    'st sp bl pl nd nt eɪ aɪ oʊ ju i'.split()))
INFLECTIONS = {
    'sat': 'sit の不規則過去形', 'got': 'get の不規則過去形',
    'dug': 'dig の不規則過去形', 'fed': 'feed の不規則過去形',
    'lit': 'light の不規則過去形・分詞', 'sang': 'sing の不規則過去形',
    'rang': 'ring の不規則過去形', 'made': 'make の不規則過去形・分詞',
    'paid': 'pay の不規則過去形・分詞', 'seen': 'see の過去分詞',
    'feet': 'foot の不規則複数形',
}


def phoneme_units(ipa):
    """Inventory-level units: affricates/diphthongs count once, /ks kw ju/ twice."""
    return re.findall(r'tʃ|dʒ|eɪ|aɪ|oʊ|[^ˈˌːˑ\s]', ipa)


def canonical_engine_ipa(ipa):
    # The course uses broad US transcription without length marks. Preserve
    # meaningful vowel differences (ɑ/ɔ, æ/ɐ); do not 'correct' them away.
    return re.sub(r'[ˈˌːˑ\s\u0361\u035c]', '', ipa).replace('g', 'ɡ')


def inspect_wav(path):
    """Measure encoded PCM only: not voicing, accent, or phoneme identity."""
    with wave.open(str(path), 'rb') as wav:
        channels, width, rate = (wav.getnchannels(), wav.getsampwidth(),
                                 wav.getframerate())
        frames = wav.getnframes()
        if (channels, width) != (1, 2):
            raise ValueError('Expected mono 16-bit PCM')
        samples = array('h', wav.readframes(frames))
        if sys.byteorder != 'little':
            samples.byteswap()
    if not samples or len(samples) != frames:
        raise ValueError('Empty or truncated PCM')
    peak = max(abs(sample) for sample in samples)
    size = max(1, round(rate * .010))
    blocks = [samples[i:i + size] for i in range(0, len(samples), size)]
    energies = [(sum(x * x for x in block), len(block)) for block in blocks]
    highest = max(energy / count for energy, count in energies)
    active = [(energy, count) for energy, count in energies
              if energy > 0 and energy / count >= highest * .001]
    active_frames = sum(count for _, count in active)
    rms = (math.sqrt(sum(energy for energy, _ in active) / active_frames)
           if active_frames else 0)
    return dict(rate=rate, channels=channels, sample_width=width,
                frames=frames, duration_ms=1000 * frames / rate,
                active_ms=1000 * active_frames / rate,
                active_rms_dbfs=20 * math.log10(rms / 32768) if rms else None,
                peak_dbfs=20 * math.log10(peak / 32768) if peak else None,
                clipped_samples=sum(x in (-32768, 32767) for x in samples),
                silent=peak == 0)


def word_mappings(data):
    sounds = {s['id']: s for s in data['sounds']}
    rows = []
    for word in data['words']:
        missing = [key for key in word['skills'] if key not in sounds]
        composed = ''.join(sounds[key]['ipa'] for key in word['skills']
                           if key in sounds)
        rows.append(dict(text=word['text'], ipa=word['ipa'], composed=composed,
                         missing=missing, matches=not missing and composed == word['ipa']))
    return rows


def engine_probe(data, executable):
    if executable is None:
        return dict(status='not_run', words={}, sounds={}, mismatches=[])
    words, sounds, mismatches = {}, {}, []
    for kind, items in (('word', data['words']), ('sound', data['sounds'])):
        for item in items:
            key = item['text'] if kind == 'word' else item['id']
            text = key if kind == 'word' else (
                '[[r-_]]' if item['espeak'] == 'r' else f'[[{item["espeak"]}_]]')
            result = subprocess.run(
                [executable, '-v', 'en-us', '-q', '--ipa', text],
                capture_output=True, text=True, check=True, timeout=15)
            actual = result.stdout.strip()
            (words if kind == 'word' else sounds)[key] = actual
            if canonical_engine_ipa(actual) != canonical_engine_ipa(item['ipa']):
                mismatches.append(dict(kind=kind, id=key,
                                       declared=item['ipa'], engine=actual))
    return dict(status='engine_metadata_only', words=words, sounds=sounds,
                mismatches=mismatches)


def audit_repository(root=ROOT, espeak=None):
    data_path = root / 'assets/data/curriculum.json'
    manifest_path = root / 'assets/licenses/assets.json'
    data = json.loads(data_path.read_text())
    manifest = json.loads(manifest_path.read_text())
    sounds = {s['id']: s for s in data['sounds']}
    runtime_path = root / 'lib/domain/curriculum.dart'
    runtime = runtime_path.read_text()
    findings = []

    def finding(code, severity, title, evidence, action):
        findings.append(dict(code=code, severity=severity, title=title,
                             evidence=evidence, action=action))

    paths = [entry['path'] for entry in manifest]
    actual = {str(p.relative_to(root)) for p in (root / 'assets/audio').glob('*.wav')}
    expected = ({s['audio'] for s in data['sounds']}
                | {f'assets/audio/word_{w["text"]}.wav' for w in data['words']}
                | {f'assets/audio/name_{c}.wav' for c in 'abcdefghijklmnopqrstuvwxyz'}
                | {f'assets/audio/guide_{c}.wav' for c in
                   ('listen', 'read', 'case', 'build', 'mic', 'welcome')})
    parity_errors = []
    if len(set(paths)) != len(paths):
        parity_errors.append('duplicate manifest paths')
    parity_errors += [f'not in manifest: {p}' for p in sorted(actual - set(paths))]
    parity_errors += [f'missing WAV: {p}' for p in sorted(set(paths) - actual)]
    parity_errors += [f'missing runtime asset: {p}' for p in sorted(expected - actual)]
    audio = []
    for entry in manifest:
        relative = Path(entry['path'])
        if relative.is_absolute() or '..' in relative.parts or relative.parent != Path('assets/audio'):
            parity_errors.append(f'unsafe path: {entry["path"]}')
            continue
        path = root / relative
        if not path.is_file():
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry['sha256']:
            parity_errors.append(f'SHA256 mismatch: {relative}')
        try:
            metrics = inspect_wav(path)
        except (ValueError, wave.Error, EOFError) as error:
            parity_errors.append(f'invalid WAV: {relative}: {error}')
            continue
        audio.append(dict(path=str(relative), sha256=digest, **metrics))
        if metrics['silent'] or metrics['clipped_samples'] or metrics['duration_ms'] >= 15000:
            parity_errors.append(f'silent/clipped/too long: {relative}')
    if parity_errors:
        finding('AUDIO-001', 'block_release', '音声ファイル・台帳の不整合',
                parity_errors, '参照・ハッシュ・PCM・無音/クリップを修正して再監査する。')

    mappings = word_mappings(data)
    mismatch = [row for row in mappings if not row['matches']]
    if mismatch:
        finding('CONTENT-001', 'block_release', '文字と音の対応が語IPAと一致しない',
                [f'{w["text"]}: 語 /{w["ipa"]}/、skills連結 /{w["composed"]}/'
                 + (f'、未定義 {w["missing"]}' if w['missing'] else '') for w in mismatch],
                'u_e の /ju/ と /u/ を語・文脈別に表現する。音素分割と文字数を混同せず、教材・練習・表示を同じ対応データへ接続する。')
    crosswalk_errors = [s['id'] for s in data['sounds']
                        if ESPEAK_IPA.get(s['espeak']) != s['ipa']]
    if crosswalk_errors:
        finding('CONTENT-002', 'expert_review', 'eSpeak記号宣言の要確認',
                crosswalk_errors, '表記体系の対応を原典と照合し、波形も別に聴いて確認する。')

    lessons = [l for island in data['islands'] for l in island['lessons']]
    unused_blends = [s['id'] for s in data['sounds'] if s['id'] in ('st', 'sp', 'bl', 'pl', 'nd', 'nt')
                     and not any(s['id'] in w['skills'] for w in data['words'])]
    introduced = {l['skill']: i for i, l in enumerate(lessons) if i % 7 != 6}
    opened_blends = [w['text'] for w in data['words'] if not w['heldOut'] and w['blend']
                     and all(introduced.get(s, 999) <= 42 for s in w['skills'])]
    if unused_blends:
        focus_fixed = ('bool focusedOn(Word word)' in runtime
                       and 'word.skills.take(2).join() == lesson.skill' in runtime
                       and 'word.skills.skip(word.skills.length - 2).join() == lesson.skill' in runtime)
        focus_state = (
            '本監査ブランチではCurriculum.examplesのonset/coda連続skills照合を修正済み。skillsに連結IDが0件という事実を、現在も焦点選択が壊れている証拠とはしない。'
            if focus_fixed else
            'onset/coda連続skills照合の修正はこのソースで確認できない。runtime焦点照合を点検する。')
        finding('CONTENT-003', 'fix', '子音連結のデータ表現・導入範囲',
                [f'word.skillsで連結ID使用0件: {", ".join(unused_blends)}。各語は音素の成分列として正当に格納されている。',
                 '基準main 3f447d9ではword.skills.contains(lesson.skill)のみの焦点照合が不具合だった。',
                 focus_state,
                 f'未解決: index42で学習用blend語 {len(opened_blends)} 語が同時に適格化する。',
                 '未解決: 現データの導入時学習用候補はst=1語(stop)、bl=1語(black)等と少ない。'],
                '修正済みのruntime焦点照合と、未解決の一括導入・語数不足を分けて管理する。連結内の音素は分けたまま、連結別の練習量と導入順を教育設計で確認する。')

    unreferenced = sorted(p for p in actual if '/sound_' in p and p not in expected)
    if unreferenced:
        finding('AUDIO-002', 'fix', '軽微・非公開阻害: 未参照の復習用音声コピー',
                unreferenced, '容量/参照の整理であり公開を止める指摘ではない。別名の参照設計を明確にしてから重複同梱を整理する。今回の監査では削除しない。')
    by_path = {a['path']: a for a in audio}
    short = []
    for sound in data['sounds']:
        if sound['id'].startswith('mix') or sound['id'] == 'review':
            continue
        metrics = by_path.get(sound['audio'])
        if metrics and sound['ipa'] in CONTINUANTS and metrics['active_ms'] < 80:
            short.append(f'{sound["id"]} /{sound["ipa"]}/: 有音フレーム {metrics["active_ms"]:.2f} ms')
    if short:
        finding('AUDIO-003', 'expert_review', '短い単独持続音の識別しやすさ', short,
                'm/n/ng/l/r 等を専門家と子どもがFire実機で聴く。80msは振り分け用の便宜的閾値で、誤発音や不合格の判定基準ではない。必要なら収録音声へ差し替える。')
    finding('CONTENT-004', 'expert_review', '米語の採用体系・異音・音声品質の承認が未記録',
            ['教材は draft-unreviewed。参照辞書の名称/版/米語方言・審査者/審査日がデータにない。',
             'IPAは長さ記号なしの広い表記（/i u ɑ/）。eSpeak入力の i: / ju: / A: との記法差だけで誤りとはしない。',
             'dog/fog/log/song の /ɑ ɔ/、tube/tune のyod脱落、単独 r→r- の合成処理を確認する。',
             'p/b,t/d,k/g,f/v,s/z,θ/ð の有声・無声、破裂・摩擦・有声開始、余計な母音、連結・単語末音を聴いて確認する。'],
            '一般米語の対象方言と表記方針を決め、各語の出典・対象音・実音声を人が承認する。波形のRMSやエンジンIPA出力は承認の代用にならない。')
    finding('CONTENT-005', 'expert_review', '二重母音字とsilent-eを一般規則に拡張する前の制約',
            [f'ea=/i/ は現 {sum("ea" in w["skills"] for w in data["words"])} 語、ow=/oʊ/ は現 {sum("ow" in w["skills"] for w in data["words"])} 語に限定。現データ内の対応は一致。',
             'tokenize は ea/ow を常に同じskillへ割当てる。head/bread/great、cow/bow の追加は別読み・語義を指定する必要がある（これらは現収録語ではない）。',
             'silent-e は語尾eと3文字目前の母音で推定するため、将来 have/give/love/come 等を加えると誤分類し得る。',
             'x=/ks/、qu=/kw/、u_e=/ju/ は2音素。sh=/ʃ/、ch=/tʃ/ は1音素。文字数・skills数・音素数は一致しない。'],
            '例外を含む語ごとのgrapheme→phoneme対応を持たせ、未対応語を自動解読可能としない。row は「こぐ」の /roʊ/ と語義を合わせて確認する。')
    finding('CONTENT-006', 'expert_review', '口図・ヒントの教授内容が未監修',
            ['MouthPainterは開口・丸め・閉鎖を中心に4つの外形を描き、舌の断面/歯への接触位置/気流/声帯振動を個別に描かない。',
             '/f v θ ð l ɹ/ 等は同じ基本外形になり、歯・舌の接触を図から区別できない。',
             '文字ヒントは有声/無声の一部を説明するが、音ごとの属性や専門家承認欄を持たない。'],
            '口図を解剖学的に正確と表示しない。/θ ð/の歯間、/f v/の歯唇、/ɹ/の許容される舌形を含め専門家に図と実音声を一緒に確認してもらう。')
    finding('CONTENT-007', 'fix', '語義・語形変化と音素対応の審査記録がない',
            [f'形態レビュー対象 {len(INFLECTIONS)} 語: {", ".join(INFLECTIONS)}',
             '語データは text/ipa/meaning/skills/heldOut/blend のみ。形態素・品詞・語義ID・語根・音素と文字範囲の明示対応がない。',
             '組立は q.answer.split(\'\')、穴埋めは文字中央1字なので、shipのshやcakeのa_eを音素単位で提示しているとはいえない。'],
            '現在は綴りの並べ替えと明示する。音素分解と形態分解を区別し、不規則過去・複数・文脈に依存する意味を点検する。形態素機能の未実装だけを初級フォニックスの誤りとは扱わない。')
    finding('LICENSE-001', 'block_release', '商用配布の権利確認は台帳の宣言だけでは完了しない',
            [f'音声 {len(manifest)} 本が同一の eSpeak NG 1.52.0 formant synthesis 出典・draft-unreviewed。',
             'NOTICE.mdはGPLv3第2節の出力規定を根拠に生成物とプログラムを区別している。これは法的な許諾審査の完了記録ではない。',
             '台帳の commercial_and_redistribution は自己記述。生成に使ったエンジン/voiceデータの版・ハッシュ・原素材の条件と、出力に保護対象が含まれるかの確認が必要。'],
            '公開前に権利担当者がエンジン・voiceデータ・出力の条件を確認する。GPLを使った生成物が自動的にGPLまたは無条件の商用可になるとは断定しない。録音へ差替える場合も実演・録音・再配布・商用利用の許諾を記録する。')
    probe = engine_probe(data, espeak)
    if probe['mismatches']:
        finding('AUDIO-004', 'expert_review', '宣言IPAとeSpeakのテキストIPA出力の差',
                [f'{row["kind"]}:{row["id"]} 宣言 /{row["declared"]}/、エンジン {row["engine"]}'
                 for row in probe['mismatches']],
                'アクセント・強形/弱形・辞書設定を確認して実波形を聴く。短母音iの /ɪ/ と /i/ の差は初級教材の核なので優先確認する。これは生成エンジンのメタデータ照合であり、録音の発音を自動認定した結果ではない。')
    return dict(data=data, manifest=manifest, audio=audio, mappings=mappings,
                findings=findings, probe=probe, parity_errors=parity_errors,
                fingerprints={str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in (data_path, manifest_path, runtime_path,
                                        root / 'tools/generate_audio.py', root / 'tools/audio_levels.py')})


def review_rows(audit):
    data, probe = audit['data'], audit['probe']
    sounds = {s['id']: s for s in data['sounds']}
    words = {w['text']: w for w in data['words']}
    mappings = {w['text']: w for w in audit['mappings']}
    metrics = {a['path']: a for a in audit['audio']}
    for entry in audit['manifest']:
        path = entry['path']
        kind, key = Path(path).stem.split('_', 1)
        row = dict.fromkeys(FIELDS, '')
        row.update(kind=kind, id=key, audio_path=path, runtime_audio_ref=path,
                   sha256=entry['sha256'], source_status=entry.get('status', ''),
                   review_status='pending', waveform_listening_status='not_listened_by_expert',
                   legal_status='pending')
        flags = []
        if kind == 'sound':
            sound = sounds[key]
            row.update(text=sound['label'], declared_ipa=sound['ipa'],
                       espeak_input='[[r-_]]' if sound['espeak'] == 'r' else f'[[{sound["espeak"]}_]]',
                       engine_ipa=probe['sounds'].get(key, ''),
                       phoneme_count=len(phoneme_units(sound['ipa'])),
                       example_or_meaning=sound['example'], hint=sound['hint'],
                       runtime_audio_ref=sound['audio'])
            if sound['audio'] != path:
                flags.append('UNREFERENCED_ALIAS_COPY')
            if sound['ipa'] in CONTINUANTS and metrics.get(path, {}).get('active_ms', 999) < 80:
                flags.append('SHORT_CONTINUANT_REQUIRES_LISTENING')
            if len(phoneme_units(sound['ipa'])) > 1:
                flags.append('MULTIPLE_PHONEMES')
            row['expert_checks'] = ('単独音の同定;余分な母音/文字名なし;有声無声・放出/摩擦;単語例と比較;'
                                    'US方言/IPA一致;口・舌・歯・気流ヒント;Fireスピーカー/ヘッドホン;権利')
        elif kind == 'word':
            word, mapping = words[key], mappings[key]
            row.update(text=key, declared_ipa=word['ipa'], espeak_input=key,
                       engine_ipa=probe['words'].get(key, ''), skills=' '.join(word['skills']),
                       composed_ipa=mapping['composed'], phoneme_count=len(phoneme_units(word['ipa'])),
                       example_or_meaning=word['meaning'])
            if not mapping['matches']:
                flags.append('SKILL_IPA_MISMATCH')
            if key in INFLECTIONS:
                flags.append('INFLECTION_REVIEW:' + INFLECTIONS[key])
            if 'u_e' in word['skills']:
                flags.append('US_U_E_YOD_CONTEXT')
            if 'ea' in word['skills'] or 'ow' in word['skills']:
                flags.append('DIGRAPH_READING_IS_SCOPED')
            row['expert_checks'] = ('語全体の実音声とIPA/語義;US方言/強形弱形;末尾子音/連結;'
                                    '文字範囲と音素の対応;silent-e/二重字の適用範囲;語形/品詞/日本語;'
                                    '子どもの理解と単語の自然さ;Fireスピーカー/ヘッドホン;権利')
        elif kind == 'name':
            row.update(text=key.upper(), espeak_input=key.upper(),
                       expert_checks='英米の対象方言;文字名と文字音を区別;自然さ/明瞭さ;子どもの理解;権利')
        elif kind == 'guide':
            row.update(text=key, expert_checks='日本語の明瞭さ/自然さ;画面の指示と一致;年齢相応の語彙/長さ;音量;権利')
        if (row['engine_ipa'] and canonical_engine_ipa(row['engine_ipa'])
                != canonical_engine_ipa(row['declared_ipa'])):
            flags.append('ENGINE_IPA_METADATA_MISMATCH')
        for key in ('duration_ms', 'active_ms', 'active_rms_dbfs', 'peak_dbfs', 'clipped_samples'):
            value = metrics.get(path, {}).get(key)
            row[key] = '' if value is None else (value if isinstance(value, int) else f'{value:.3f}')
        if metrics.get(path, {}).get('silent'):
            flags.append('SILENT')
        if metrics.get(path, {}).get('clipped_samples'):
            flags.append('CLIPPED')
        row['machine_flags'] = ';'.join(flags)
        yield row


def render_csv(audit, existing=''):
    previous = {row['audio_path']: row for row in csv.DictReader(io.StringIO(existing))}
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=FIELDS, lineterminator='\n')
    writer.writeheader()
    for row in review_rows(audit):
        old = previous.get(row['audio_path'])
        if old:
            for key in REVIEW_FIELDS:
                row[key] = old.get(key, row[key])
            if old.get('sha256') != row['sha256']:
                row['review_status'] = 'pending_changed_audio'
                row['waveform_listening_status'] = 'not_listened_changed_audio'
                row['legal_status'] = 'pending_changed_audio'
            elif any(old.get(key, '') != str(row.get(key, ''))
                     for key in CONTENT_REVIEW_FIELDS):
                # Same audio does not mean the lesson's interpretation of it
                # is unchanged. Retain the audio-rights record independently.
                row['review_status'] = 'pending_changed_content'
                row['waveform_listening_status'] = 'needs_recheck_changed_content'
        writer.writerow(row)
    return stream.getvalue()


def render_report(audit):
    data, audio = audit['data'], audit['audio']
    sounds = data['sounds']
    primary = [s for s in sounds if s['id'] != 'review' and not s['id'].startswith('mix')]
    units = {unit for sound in primary for unit in phoneme_units(sound['ipa'])}
    mapping_matches = sum(w['matches'] for w in audit['mappings'])
    durations = [a['duration_ms'] for a in audio]
    rms = [a['active_rms_dbfs'] for a in audio if not a['silent']]
    peaks = [a['peak_dbfs'] for a in audio if not a['silent']]
    lines = ['# 音声・教材監査', '',
        '本書は現行の教材と音声を変更せずに検査した結果です。機械的整合性と人による音声学・教育・権利の承認を分けています。公開可否の認定、治療・発音評価、法的助言ではありません。', '',
        '## 再実行', '', '```bash',
        'python tools/audit_content.py',
        'python tools/audit_content.py --espeak /path/to/espeak-ng --write',
        'python -m unittest tests.test_content_audit -v', '```', '',
        '`--write` はこの報告と専門家レビューCSVだけを書きます。`--json` は全473本の測定値を標準出力へ出します。`--strict` は公開阻害項目がある場合に終了コード2を返します。`--check` は同じオプションで生成文書が最新か検査します。既存CSVの審査者・日付・所見は保持します。音声SHA変更時は教育/権利審査を再待機に戻します。同じWAVでもIPA・意味・ヒント・生成入力・skills等が変われば教育審査/聴き直しを再待機にし、音声権利の承認は独立して保持します。', '',
        '## 全量検査の範囲', '',
        '| 項目 | 結果 |', '| --- | --- |',
        f'| 語 | {len(data["words"])}（練習用 {sum(not w["heldOut"] for w in data["words"])}、留保用 {sum(w["heldOut"] for w in data["words"])}） |',
        f'| 音データ | {len(sounds)} ID、主教材 {len(primary)}、復習別名 {len(sounds)-len(primary)}、宣言IPA列 {len({s["ipa"] for s in sounds})}種類 |',
        f'| IPAの構成音素 | 現コースで {len(units)} 種。全米語IPAの網羅表とはしない |',
        f'| 同梱WAV / 台帳 / CSV | {len(audio)} / {len(audit["manifest"])} / {len(list(review_rows(audit)))}。CSVは全語・全音・文字名26・案内6を含む |',
        f'| 語IPAとskills列の宣言IPA一致 | {mapping_matches}/{len(data["words"])}（実音声の正しさを意味しない） |',
        f'| ファイル参照・台帳SHA・PCMエラー | {len(audit["parity_errors"])} |',
        f'| WAV形式 | {", ".join(str(x) for x in sorted({a["rate"] for a in audio}))} Hz、16-bit、mono |',
        f'| 全尺 | {sum(durations)/1000:.3f}秒、1本 {min(durations):.3f}–{max(durations):.3f} ms |',
        f'| 有音RMS | {min(rms):.3f}–{max(rms):.3f} dBFS |',
        f'| 最大サンプルピーク | {max(peaks):.3f} dBFS |',
        f'| 完全無音 / 飽和サンプル | {sum(a["silent"] for a in audio)}本 / {sum(a["clipped_samples"] for a in audio)}サンプル |',
        f'| 音声ソース | {len({e.get("source") for e in audit["manifest"]})}種類。{dict(Counter(e.get("voice") for e in audit["manifest"]))} |', '',
        'RMSは生PCMを10ms区間に分け、最強区間より30dB以上小さい区間を除外して二乗平均を測定しました。無音、長さ、飽和、ハッシュは機械検査できます。有声・無声、正しい舌位置、余計な母音、自然さ、子どもの聴取しやすさは、この値から認定できません。Fireのスピーカー・音量設定・耳との距離による聴感差も未測定です。', '',
        '## 語・表記体系の確認', '',
        '全381語を対象に、参照skill、宣言IPA連結、音声参照・SHA・有音レベルを検査しています。辞書の発音・語義の全量照合や全波形の専門家聴取を実施したという意味ではありません。`expert_review` は審査待ち、`fix` は修正/整理の候補（公開阻害かは本文で明示）、`block_release` は解決まで一般公開を止める項目です。', '',
        '| sound ID | 表記 | 宣言IPA | eSpeak入力 | 音素数 |',
        '| --- | --- | --- | --- | --- |']
    for sound in primary:
        phoneme = 'r-' if sound['espeak'] == 'r' else sound['espeak']
        lines.append(f'| {sound["id"]} | {sound["label"]} | /{sound["ipa"]}/ | `[[{phoneme}_]]` | {len(phoneme_units(sound["ipa"]))} |')
    lines += ['', '音素数は本コースの広い分節単位で数え、/tʃ dʒ/ と /eɪ aɪ oʊ/ は各1、/ks kw ju/ と子音連結は2としています。音声波形を分節した数ではありません。文字の名前・grapheme（綴りの単位）・音素・形態素を区別する必要があります。', '',
              '## 指摘と対応', '']
    for item in audit['findings']:
        lines += [f'### {item["code"]} — {item["severity"]}: {item["title"]}', '']
        lines += [f'- {evidence}' for evidence in item['evidence']]
        lines += ['', item['action'], '']
    lines += ['## 専門家レビューの実施方法', '',
        '[全473本のレビュー表](experts/audio-review.csv)を使い、音声学/米語教育の審査者が各WAVを通常・低速・単語比較で聴いてください。波形を見ただけ、辞書表記が一致しただけで `approved` と記録しないでください。辞書の名称/版/参照URLまたは許諾済み収録指示書、方言、審査者、日付、所見を残します。review_statusとlegal_statusは別々に承認します。', '',
        '1. 主教材48音と復習別名12を聴き、単独音の同定、有声/無声、末尾放出、摩擦、不要な母音、母音の質、/ɹ/と/l/、/θ/と/ð/を確認する。',
        '2. 全381語について、IPA・語義・品詞/語形・読みの条件・音素と文字範囲を確認し、録音との対応を聴く。heldOut69語も対象から外さない。',
        '3. 26文字名を文字音から区別し、日本語案内6本の自然さと指示内容を確認する。',
        '4. Fire HD 10の11世代・13世代の内蔵スピーカーとヘッドホンで、家庭で使う音量で識別できるか試す。音量の数値的均一性を音声学的正確さの合格条件にしない。',
        '5. 権利担当者が生成エンジン・voiceデータ・出力の利用条件と、差し替え録音の商用利用/組込み/再配布権を確認する。未解決の権利や音声品質があれば対象教材を公開しない。', '',
        '## エンジンIPA照合の実施状況', '']
    if audit['probe']['status'] == 'not_run':
        lines += ['この実行では未実施です。`--espeak` を指定すると全381語と全60音IDのエンジンIPA出力を照合します。音声認識や波形の正誤評価は行いません。', '']
    else:
        lines += [f'全381語と全60音IDを実行。広い表記に合わせて強勢・長さ記号を除いた差は {len(audit["probe"]["mismatches"])}件です。/ɑ/と/ɔ/、/æ/と/ɐ/など音価の違いは消していません。結果は各CSVのengine_ipa列に記録しています。', '']
    lines += ['## 出典と限界', '',
        '- 検査対象: `assets/data/curriculum.json`、`tools/build_curriculum.py`、`tools/generate_audio.py`、`tools/audio_levels.py`、`assets/licenses/assets.json`、`assets/licenses/NOTICE.md`、`lib/domain/curriculum.dart`、`lib/domain/learning.dart`、`lib/ui/lesson.dart`、`lib/ui/art.dart`。',
        '- 生成エンジンの公式ソース: https://github.com/espeak-ng/espeak-ng/tree/1.52.0 。エンジンの音素記号は音声学上の承認済み録音資料ではありません。',
        '- GPLv3第2節: https://www.gnu.org/licenses/gpl-3.0.html#section2 （同梱 `assets/licenses/GPL-3.txt`）。出力規定の解釈と個々の素材の商用利用許諾は別途確認が必要です。',
        '- 外部辞書の音声/本文を新規取得・転載していません。専門家の録音聴取、子どもの学習効果測定、権利者からの追加許諾は未実施です。', '',
        '## 検査対象のSHA256', '', '```text']
    lines += [f'{digest}  {path}' for path, digest in audit['fingerprints'].items()]
    lines += ['```', '']
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--espeak', help='Optional eSpeak NG 1.52.0 executable')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    audit = audit_repository(espeak=args.espeak)
    review_path = ROOT / REVIEW
    csv_text = render_csv(audit, review_path.read_text() if review_path.exists() else '')
    artifacts = {ROOT / REPORT: render_report(audit), review_path: csv_text}
    if args.write:
        for path, text in artifacts.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
    if args.json:
        print(json.dumps(audit, ensure_ascii=False, indent=2))
    else:
        print(f'{len(audit["data"]["words"])} words / {len(audit["audio"])} WAVs / '
              f'{len(audit["parity_errors"])} asset errors')
        print('Findings:', dict(Counter(f['severity'] for f in audit['findings'])))
        print('Phonetic correctness and legal clearance: NOT certified')
    if args.check and any(not path.exists() or path.read_text() != text
                          for path, text in artifacts.items()):
        print('Audit documents are stale; rerun with the same --espeak option and --write.',
              file=sys.stderr)
        return 1
    if args.strict and any(f['severity'] == 'block_release' for f in audit['findings']):
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
