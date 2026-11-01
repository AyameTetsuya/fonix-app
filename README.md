# わくわくフォニックス

Fire HD 10で、動物と冒険しながら文字と音を学ぶFlutterアプリの開発版です。
6歳・9歳、1回3〜5分、家庭での利用を最初の対象としています。

## 実装した内容

- 10島・70レッスンのコース、開始地点を提案する12問のお試しクイズ。
- アルファベット26文字の名前・大小文字、基本の音、CVC、sh/ch/th、子音連結、サイレントe、ai/ee/oaなど。
- 聞き分け、文字から音を選ぶ問題、文字の組み立て、穴埋め、未練習語の確認。
- 冒頭最大2問の復習、独力での初回解答・学習時間・進行の端末内保存。
- 動物11匹、同行相手の選択、ごはん・なでるお世話。未利用期間によるペナルティなし。
- IPAと口の図が見られる音の図鑑。
- 同梱音声の再生、速度変更、マイク録音、聴き比べ、明示保存、保存上限20件、削除。
- 保護者PIN、音量・マイク・IPA・開始地点の設定、履歴、初期化。
- 外部評価用のバックエンドの基盤。認証・明示同意・評価対象の検証・利用上限・二重送信防止。

教材は381語（確認用69語を含む）と473ファイルの同梱音声です。
音声はeSpeak NGによる合成の仮音声、説明と図は監修前です。
文字数・音源の存在と、発音の教育的な正確さの確認は別に扱っています。

**発音の正誤を自動評価する機能は、まだ有効ではありません。** 録音品質の確認を発音採点とは扱いません。
オンライン評価はアプリに接続しておらず、製品用Androidマニフェストにネットワーク権限はありません。
モデル・児童音声での評価・利用条件の確認が済むまでは、録音と聴き比べを利用する開発版です。

クラウド作業環境ではFlutter SDKの公式配布先が通信制限で遮断されていますが、GitHub ActionsではFlutterの解析とアプリのテストが通過しました。
APKの生成とArtifactsへの保存も成功しました。Fire実機での動作確認はこれからです。
検証済み範囲と残作業は [実装状況](docs/implementation-status.md) を参照してください。

## 作成済みAPKをFireに入れる

1. GitHubにログインし、[成功したビルド #4](https://github.com/AyameTetsuya/fonix-app/actions/runs/41357246782) を開きます。
2. ページ下部のArtifactsから `fonix-family-debug-apk` をダウンロードします。ZIPは約76MBです。
3. WindowsでZIPを展開し、`app-debug.apk` をFireのDownloadフォルダにUSB転送します。
4. FireのファイルアプリでAPKを開き、必要ならそのアプリからのインストールを許可してインストールします。
5. 「わくわくフォニックス」を開き、保護者PINを設定して開始します。

このAPKはコミット `204aad1` のソースから生成した家庭向けデバッグ版です。
以後のアプリ更新時も、最新の成功した実行からAPKを取得してください。

## 開発環境

| ツール | 基準 |
| --- | --- |
| Flutter | 3.47.9 stable（c197ca5199e9ee5661e865596c9c07294dfab51c） |
| Java | JDK 21。Androidソースの言語レベルは17 |
| Android SDK | API 36、Build Tools 36.0.0 |
| Gradle / Android Gradle Plugin / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 |
| アプリ対象 | Android互換API 28以上。Fire第11・13世代は実機検証対象 |

Windowsでは公式のFlutter SDK、Android SDK、JDKを準備し、`flutter doctor -v`で確認してください。
標準のeSpeak NG実行ファイルは音源の再生成時だけ必要で、アプリのビルド・実行には不要です。
Flutter実行時の外部パッケージは追加しておらず、Android機能は専用のMethodChannelで接続しています。

## Windowsで確認・ビルドする

リポジトリのルートでPowerShellから実行します。

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APKは `build/app/outputs/flutter-apk/app-debug.apk` に出力されます。
これは家庭で試すためのデバッグ版です。一般公開用の署名・配布設定は別途必要です。

Fire側で保護者が開発者設定とUSBデバッグを有効にし、USB接続を許可してから導入します。
既存データを保持して更新するコマンドは次のとおりです。

```powershell
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

初回は保護者用PINを設定します。忘れた場合は端末側でアプリデータを消去して再設定します。
この場合、学習履歴と保存録音は失われます。共通の解除PINは用意していません。

## クラウド環境の残りの準備

`storage.googleapis.com` の通信許可を環境設定の下書きへ追加済みです。
下書き保存だけでは実行環境には反映されません。環境設定で確認・保存し、環境を公開して反映してください。
公式配布先への接続が可能になった後、準備済みのSDKで次を実行します。

```bash
export PATH="/workspace/tools/flutter/bin:$PATH"
export ANDROID_HOME=/workspace/tools/android-sdk
flutter --version
flutter config --android-sdk /workspace/tools/android-sdk
cd /workspace/fonix-app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

接続拒否を回避するためにTLS検証やチェックサム検証を無効にしないでください。
`android/local.properties`は各マシンのローカル設定であり、コミット対象ではありません。
`pubspec.lock`は依存解決が初めて成功した時に生成・確認して追加します。未確認のロックファイルは作っていません。

## 独立して実行できるテスト

```bash
python -m unittest discover -s tests -v
mkdir -p /tmp/fonix-native
javac -d /tmp/fonix-native android/app/src/main/java/jp/fonix/AudioData.java android/app/src/main/java/jp/fonix/PinHash.java tests/NativeTests.java
java -cp /tmp/fonix-native NativeTests
```

`javac`起動ファイルがなく、JDKのコンパイラモジュールが存在する環境では、代わりに
`java -m jdk.compiler/com.sun.tools.javac.Main` を使えます。
Pythonテストは標準ライブラリだけで動作し、ローカルHTTP試験以外の通信や有料APIへの接続をしません。
CIも同じ検証とFlutter解析・テスト・APKビルドを行います。失敗時は具体的な診断をActionsの注釈にも表示し、実際の終了コードを維持します。

## 教材と音源を変更する

```bash
python tools/build_curriculum.py
python tools/generate_audio.py --espeak espeak-ng
python -m unittest discover -s tests -v
```

教材データは `assets/data/curriculum.json`、元になる定義は `tools/build_curriculum.py` です。
確認用の単語は通常の問題や説明例に出さず、既習の綴りで読めるものだけ確認に使います。
既存データと生成スクリプトの変更はセットで行います。

音源を人の収録音声などへ差し替える場合、仮音声の生成スクリプトで上書きしないよう運用を切り替え、
素材台帳に出典・利用条件・ハッシュを更新してください。
[素材台帳](assets/licenses/NOTICE.md) の条件を確認してから採用します。

## 発音評価の実装状況

`server/`には、短い単語を対象にしたAzure Speech向けのアダプターと、提供者から独立した受付・予算管理があります。
単独音を1文字の読み上げに置き換える処理はありません。単独音の適切な評価方式は未確定です。

安全な初期状態として `server/reviewed_targets.json` は空です。
提供者の設定だけを入れても、検証済みの対象・助言が登録されるまで発音評価は実行しません。
テストの合成信号や模擬プロバイダーは通信・制御の検証用であり、発音精度を検証したデータではありません。

バックエンド用の設定名は次のとおりです。値やAPIキーをAPK・教材・リポジトリへ記載しないでください。

- `FONIX_DEVICE_TOKENS`：匿名の端末IDと長いランダムな接続用トークンの対応。
- `FONIX_SPEECH_REGION` / `FONIX_SPEECH_KEY`：提供者の設定。
- `FONIX_REVIEWED_TARGETS`：対象・助言・評価根拠の台帳へのパス。
- `FONIX_QUOTA_DB`：録音を含まない利用枠DBへのパス。
- `FONIX_MONTHLY_YEN`：従量課金の利用枠。初期値1000円。
- `FONIX_RESERVATION_YEN`：1要求前に予約する費用。初期値10円は設定の仮値であり、提供者の実料金ではありません。

実料金、固定費、税、為替、失敗時の課金を調べて保守的な予約額・利用枠を設定するまでは、商用APIを有効にしません。
エラーになっても課金された可能性があるため予約を戻さず、同一要求を再度課金しない設計です。

設定を用意した後のローカル起動は `python -m server.main` です。
本番ではTLS、端末登録・失効、保護者同意、提供者の保存・学習利用条件の確認、接続数・タイムアウト制限を満たす必要があります。
バックエンドは公開・デプロイしていません。アプリへの接続と児童音声による検証も残っています。

## 構成

```text
lib/domain/       教材・出題・習熟・復習・進行
lib/platform/     Android端末機能の境界
lib/ui/           冒険・学習・動物・図鑑・保護者画面
android/          マイク・再生・保存・PINのネイティブ実装
assets/           オフライン教材・仮音声・素材台帳
server/           外部発音評価の受付と提供者アダプター
test/             Flutterのロジック・画面テスト
tests/            教材、通信境界、予算、ネイティブ処理のテスト
docs/             要件定義・実装状況
```

iOSビルドにはmacOS・Xcode・署名・実機確認が必要です。
現在はAndroid専用の録音・保存処理を実装しているため、iOS向けアダプターも後続作業になります。
