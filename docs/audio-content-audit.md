# 音声・教材監査

本書は現行の教材と音声を変更せずに検査した結果です。機械的整合性と人による音声学・教育・権利の承認を分けています。公開可否の認定、治療・発音評価、法的助言ではありません。

## 再実行

```bash
python tools/audit_content.py
python tools/audit_content.py --espeak /path/to/espeak-ng --write
python -m unittest tests.test_content_audit -v
```

`--write` はこの報告と専門家レビューCSVだけを書きます。`--json` は全473本の測定値を標準出力へ出します。`--strict` は公開阻害項目がある場合に終了コード2を返します。`--check` は同じオプションで生成文書が最新か検査します。既存CSVの審査者・日付・所見は保持します。音声SHA変更時は教育/権利審査を再待機に戻します。同じWAVでもIPA・意味・ヒント・生成入力・skills等が変われば教育審査/聴き直しを再待機にし、音声権利の承認は独立して保持します。

## 全量検査の範囲

| 項目 | 結果 |
| --- | --- |
| 語 | 381（練習用 312、留保用 69） |
| 音データ | 60 ID、主教材 48、復習別名 12、宣言IPA列 41種類 |
| IPAの構成音素 | 現コースで 33 種。全米語IPAの網羅表とはしない |
| 同梱WAV / 台帳 / CSV | 473 / 473 / 473。CSVは全語・全音・文字名26・案内6を含む |
| 語IPAとskills列の宣言IPA一致 | 376/381（実音声の正しさを意味しない） |
| ファイル参照・台帳SHA・PCMエラー | 0 |
| WAV形式 | 22050 Hz、16-bit、mono |
| 全尺 | 285.011秒、1本 166.893–5446.848 ms |
| 有音RMS | -21.500–-21.500 dBFS |
| 最大サンプルピーク | -2.706 dBFS |
| 完全無音 / 飽和サンプル | 0本 / 0サンプル |
| 音声ソース | 1種類。{'en-us': 467, 'ja': 6} |

RMSは生PCMを10ms区間に分け、最強区間より30dB以上小さい区間を除外して二乗平均を測定しました。無音、長さ、飽和、ハッシュは機械検査できます。有声・無声、正しい舌位置、余計な母音、自然さ、子どもの聴取しやすさは、この値から認定できません。Fireのスピーカー・音量設定・耳との距離による聴感差も未測定です。

## 語・表記体系の確認

全381語を対象に、参照skill、宣言IPA連結、音声参照・SHA・有音レベルを検査しています。辞書の発音・語義の全量照合や全波形の専門家聴取を実施したという意味ではありません。`expert_review` は審査待ち、`fix` は修正/整理の候補（公開阻害かは本文で明示）、`block_release` は解決まで一般公開を止める項目です。

| sound ID | 表記 | 宣言IPA | eSpeak入力 | 音素数 |
| --- | --- | --- | --- | --- |
| s | s | /s/ | `[[s_]]` | 1 |
| a | a | /æ/ | `[[a_]]` | 1 |
| t | t | /t/ | `[[t_]]` | 1 |
| p | p | /p/ | `[[p_]]` | 1 |
| i | i | /ɪ/ | `[[I_]]` | 1 |
| n | n | /n/ | `[[n_]]` | 1 |
| m | m | /m/ | `[[m_]]` | 1 |
| d | d | /d/ | `[[d_]]` | 1 |
| g | g | /ɡ/ | `[[g_]]` | 1 |
| o | o | /ɑ/ | `[[A:_]]` | 1 |
| c | c | /k/ | `[[k_]]` | 1 |
| k | k | /k/ | `[[k_]]` | 1 |
| e | e | /ɛ/ | `[[E_]]` | 1 |
| u | u | /ʌ/ | `[[V_]]` | 1 |
| b | b | /b/ | `[[b_]]` | 1 |
| h | h | /h/ | `[[h_]]` | 1 |
| f | f | /f/ | `[[f_]]` | 1 |
| l | l | /l/ | `[[l_]]` | 1 |
| r | r | /ɹ/ | `[[r-_]]` | 1 |
| j | j | /dʒ/ | `[[dZ_]]` | 1 |
| v | v | /v/ | `[[v_]]` | 1 |
| w | w | /w/ | `[[w_]]` | 1 |
| y | y | /j/ | `[[j_]]` | 1 |
| z | z | /z/ | `[[z_]]` | 1 |
| x | x | /ks/ | `[[ks_]]` | 2 |
| qu | qu | /kw/ | `[[kw_]]` | 2 |
| sh | sh | /ʃ/ | `[[S_]]` | 1 |
| ch | ch | /tʃ/ | `[[tS_]]` | 1 |
| th | th | /θ/ | `[[T_]]` | 1 |
| thv | th | /ð/ | `[[D_]]` | 1 |
| ng | ng | /ŋ/ | `[[N_]]` | 1 |
| ck | ck | /k/ | `[[k_]]` | 1 |
| st | st | /st/ | `[[st_]]` | 2 |
| sp | sp | /sp/ | `[[sp_]]` | 2 |
| bl | bl | /bl/ | `[[bl_]]` | 2 |
| pl | pl | /pl/ | `[[pl_]]` | 2 |
| nd | nd | /nd/ | `[[nd_]]` | 2 |
| nt | nt | /nt/ | `[[nt_]]` | 2 |
| a_e | a_e | /eɪ/ | `[[eI_]]` | 1 |
| i_e | i_e | /aɪ/ | `[[aI_]]` | 1 |
| o_e | o_e | /oʊ/ | `[[oU_]]` | 1 |
| u_e | u_e | /ju/ | `[[ju:_]]` | 2 |
| ai | ai | /eɪ/ | `[[eI_]]` | 1 |
| ay | ay | /eɪ/ | `[[eI_]]` | 1 |
| ee | ee | /i/ | `[[i:_]]` | 1 |
| ea | ea | /i/ | `[[i:_]]` | 1 |
| oa | oa | /oʊ/ | `[[oU_]]` | 1 |
| ow | ow | /oʊ/ | `[[oU_]]` | 1 |

音素数は本コースの広い分節単位で数え、/tʃ dʒ/ と /eɪ aɪ oʊ/ は各1、/ks kw ju/ と子音連結は2としています。音声波形を分節した数ではありません。文字の名前・grapheme（綴りの単位）・音素・形態素を区別する必要があります。

## 指摘と対応

### CONTENT-001 — block_release: 文字と音の対応が語IPAと一致しない

- tube: 語 /tub/、skills連結 /tjub/
- tune: 語 /tun/、skills連結 /tjun/
- flute: 語 /flut/、skills連結 /fljut/
- rude: 語 /ɹud/、skills連結 /ɹjud/
- rule: 語 /ɹul/、skills連結 /ɹjul/

u_e の /ju/ と /u/ を語・文脈別に表現する。音素分割と文字数を混同せず、教材・練習・表示を同じ対応データへ接続する。

### CONTENT-003 — fix: 子音連結のデータ表現・導入範囲

- word.skillsで連結ID使用0件: st, sp, bl, pl, nd, nt。各語は音素の成分列として正当に格納されている。
- 基準main 3f447d9ではword.skills.contains(lesson.skill)のみの焦点照合が不具合だった。
- 本監査ブランチではCurriculum.examplesのonset/coda連続skills照合を修正済み。skillsに連結IDが0件という事実を、現在も焦点選択が壊れている証拠とはしない。
- 未解決: index42で学習用blend語 40 語が同時に適格化する。
- 未解決: 現データの導入時学習用候補はst=1語(stop)、bl=1語(black)等と少ない。

修正済みのruntime焦点照合と、未解決の一括導入・語数不足を分けて管理する。連結内の音素は分けたまま、連結別の練習量と導入順を教育設計で確認する。

### AUDIO-002 — fix: 軽微・非公開阻害: 未参照の復習用音声コピー

- assets/audio/sound_mix1.wav
- assets/audio/sound_mix10.wav
- assets/audio/sound_mix11.wav
- assets/audio/sound_mix2.wav
- assets/audio/sound_mix3.wav
- assets/audio/sound_mix4.wav
- assets/audio/sound_mix5.wav
- assets/audio/sound_mix6.wav
- assets/audio/sound_mix7.wav
- assets/audio/sound_mix8.wav
- assets/audio/sound_mix9.wav
- assets/audio/sound_review.wav

容量/参照の整理であり公開を止める指摘ではない。別名の参照設計を明確にしてから重複同梱を整理する。今回の監査では削除しない。

### AUDIO-003 — expert_review: 短い単独持続音の識別しやすさ

- n /n/: 有音フレーム 29.93 ms
- m /m/: 有音フレーム 29.93 ms
- h /h/: 有音フレーム 79.82 ms
- l /l/: 有音フレーム 59.86 ms
- r /ɹ/: 有音フレーム 29.93 ms
- y /j/: 有音フレーム 79.82 ms
- ng /ŋ/: 有音フレーム 39.91 ms

m/n/ng/l/r 等を専門家と子どもがFire実機で聴く。80msは振り分け用の便宜的閾値で、誤発音や不合格の判定基準ではない。必要なら収録音声へ差し替える。

### CONTENT-004 — expert_review: 米語の採用体系・異音・音声品質の承認が未記録

- 教材は draft-unreviewed。参照辞書の名称/版/米語方言・審査者/審査日がデータにない。
- IPAは長さ記号なしの広い表記（/i u ɑ/）。eSpeak入力の i: / ju: / A: との記法差だけで誤りとはしない。
- dog/fog/log/song の /ɑ ɔ/、tube/tune のyod脱落、単独 r→r- の合成処理を確認する。
- p/b,t/d,k/g,f/v,s/z,θ/ð の有声・無声、破裂・摩擦・有声開始、余計な母音、連結・単語末音を聴いて確認する。

一般米語の対象方言と表記方針を決め、各語の出典・対象音・実音声を人が承認する。波形のRMSやエンジンIPA出力は承認の代用にならない。

### CONTENT-005 — expert_review: 二重母音字とsilent-eを一般規則に拡張する前の制約

- ea=/i/ は現 15 語、ow=/oʊ/ は現 5 語に限定。現データ内の対応は一致。
- tokenize は ea/ow を常に同じskillへ割当てる。head/bread/great、cow/bow の追加は別読み・語義を指定する必要がある（これらは現収録語ではない）。
- silent-e は語尾eと3文字目前の母音で推定するため、将来 have/give/love/come 等を加えると誤分類し得る。
- x=/ks/、qu=/kw/、u_e=/ju/ は2音素。sh=/ʃ/、ch=/tʃ/ は1音素。文字数・skills数・音素数は一致しない。

例外を含む語ごとのgrapheme→phoneme対応を持たせ、未対応語を自動解読可能としない。row は「こぐ」の /roʊ/ と語義を合わせて確認する。

### CONTENT-006 — expert_review: 口図・ヒントの教授内容が未監修

- MouthPainterは開口・丸め・閉鎖を中心に4つの外形を描き、舌の断面/歯への接触位置/気流/声帯振動を個別に描かない。
- /f v θ ð l ɹ/ 等は同じ基本外形になり、歯・舌の接触を図から区別できない。
- 文字ヒントは有声/無声の一部を説明するが、音ごとの属性や専門家承認欄を持たない。

口図を解剖学的に正確と表示しない。/θ ð/の歯間、/f v/の歯唇、/ɹ/の許容される舌形を含め専門家に図と実音声を一緒に確認してもらう。

### CONTENT-007 — fix: 語義・語形変化と音素対応の審査記録がない

- 形態レビュー対象 11 語: sat, got, dug, fed, lit, sang, rang, made, paid, seen, feet
- 語データは text/ipa/meaning/skills/heldOut/blend のみ。形態素・品詞・語義ID・語根・音素と文字範囲の明示対応がない。
- 組立は q.answer.split('')、穴埋めは文字中央1字なので、shipのshやcakeのa_eを音素単位で提示しているとはいえない。

現在は綴りの並べ替えと明示する。音素分解と形態分解を区別し、不規則過去・複数・文脈に依存する意味を点検する。形態素機能の未実装だけを初級フォニックスの誤りとは扱わない。

### LICENSE-001 — block_release: 商用配布の権利確認は台帳の宣言だけでは完了しない

- 音声 473 本が同一の eSpeak NG 1.52.0 formant synthesis 出典・draft-unreviewed。
- NOTICE.mdはGPLv3第2節の出力規定を根拠に生成物とプログラムを区別している。これは法的な許諾審査の完了記録ではない。
- 台帳の commercial_and_redistribution は自己記述。生成に使ったエンジン/voiceデータの版・ハッシュ・原素材の条件と、出力に保護対象が含まれるかの確認が必要。

公開前に権利担当者がエンジン・voiceデータ・出力の条件を確認する。GPLを使った生成物が自動的にGPLまたは無条件の商用可になるとは断定しない。録音へ差替える場合も実演・録音・再配布・商用利用の許諾を記録する。

### AUDIO-004 — expert_review: 宣言IPAとeSpeakのテキストIPA出力の差

- word:log 宣言 /lɑɡ/、エンジン lˈɔɡ
- word:than 宣言 /ðæn/、エンジン ðˈɐn
- word:song 宣言 /sɑŋ/、エンジン sˈɔŋ
- sound:i 宣言 /ɪ/、エンジン ˈi
- sound:mix4 宣言 /ɪ/、エンジン ˈi

アクセント・強形/弱形・辞書設定を確認して実波形を聴く。短母音iの /ɪ/ と /i/ の差は初級教材の核なので優先確認する。これは生成エンジンのメタデータ照合であり、録音の発音を自動認定した結果ではない。

## 専門家レビューの実施方法

[全473本のレビュー表](experts/audio-review.csv)を使い、音声学/米語教育の審査者が各WAVを通常・低速・単語比較で聴いてください。波形を見ただけ、辞書表記が一致しただけで `approved` と記録しないでください。辞書の名称/版/参照URLまたは許諾済み収録指示書、方言、審査者、日付、所見を残します。review_statusとlegal_statusは別々に承認します。

1. 主教材48音と復習別名12を聴き、単独音の同定、有声/無声、末尾放出、摩擦、不要な母音、母音の質、/ɹ/と/l/、/θ/と/ð/を確認する。
2. 全381語について、IPA・語義・品詞/語形・読みの条件・音素と文字範囲を確認し、録音との対応を聴く。heldOut69語も対象から外さない。
3. 26文字名を文字音から区別し、日本語案内6本の自然さと指示内容を確認する。
4. Fire HD 10の11世代・13世代の内蔵スピーカーとヘッドホンで、家庭で使う音量で識別できるか試す。音量の数値的均一性を音声学的正確さの合格条件にしない。
5. 権利担当者が生成エンジン・voiceデータ・出力の利用条件と、差し替え録音の商用利用/組込み/再配布権を確認する。未解決の権利や音声品質があれば対象教材を公開しない。

## エンジンIPA照合の実施状況

全381語と全60音IDを実行。広い表記に合わせて強勢・長さ記号を除いた差は 5件です。/ɑ/と/ɔ/、/æ/と/ɐ/など音価の違いは消していません。結果は各CSVのengine_ipa列に記録しています。

## 出典と限界

- 検査対象: `assets/data/curriculum.json`、`tools/build_curriculum.py`、`tools/generate_audio.py`、`tools/audio_levels.py`、`assets/licenses/assets.json`、`assets/licenses/NOTICE.md`、`lib/domain/curriculum.dart`、`lib/domain/learning.dart`、`lib/ui/lesson.dart`、`lib/ui/art.dart`。
- 生成エンジンの公式ソース: https://github.com/espeak-ng/espeak-ng/tree/1.52.0 。エンジンの音素記号は音声学上の承認済み録音資料ではありません。
- GPLv3第2節: https://www.gnu.org/licenses/gpl-3.0.html#section2 （同梱 `assets/licenses/GPL-3.txt`）。出力規定の解釈と個々の素材の商用利用許諾は別途確認が必要です。
- 外部辞書の音声/本文を新規取得・転載していません。専門家の録音聴取、子どもの学習効果測定、権利者からの追加許諾は未実施です。

## 検査対象のSHA256

```text
27780e77a8e661caf491315a6be1a97114f17ce25b9a203b43b92710dea6d8df  assets/data/curriculum.json
1e11bbe3decdc99cf71a53b006fcdc8f397193d57f4e250733fbf42534073e1c  assets/licenses/assets.json
d3a85b3e86bcfac3a08c1551864308258397dfe47af658e6f0cb0f339832b145  lib/domain/curriculum.dart
c43da180621162afeb426a89dac38507b24960e27c51f5ac7557b28a82b62fc8  tools/generate_audio.py
2ff3833abbc3a836cdcdc9a83937663873f300d3fe2c1be0da789fa48fba5fca  tools/audio_levels.py
```
