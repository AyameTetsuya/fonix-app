# Fire・Google Play・iOS 展開と商品化計画

監査日: 2026-11-11。対象: 現行 Flutter / Dart と Android ネイティブ実装。**推奨は、まず Fire 2 機種で録音・聴き比べを含む同梱教材の品質を確立し、広告なし・買い切り・購入後の主要学習はオフラインという商品を作ること。** この文書は計画であり、ストア公開、課金実装、Apple Developer 登録、有料 CI 契約は行っていない。

## 現状監査

| 重大度 | 確認した事実 | 対応 |
| --- | --- | --- |
| 高: iOS 対応の阻害 | `ios/` がなく、起動時に常に `AndroidDevice()` を生成。`jp.fonix/device` のネイティブ受け口は Android Java のみ | iOS プロジェクトと同等の Device 実装が必要。Flutter のプロジェクト生成だけでは完成しない |
| 高: 公開品質 | 同梱音声は eSpeak NG による仮の合成教材。専門家の音声学的な承認は確認できない | 音声・IPA・口図・語彙の監査と商用権利確認を公開前の条件にする。自動整合性試験と専門家承認を区別 |
| 高: 商品説明 | 自動発音評価はアプリ未接続。サーバーの審査済み対象は空 | 録音練習版として正確に説明。評価を売りにする場合は別途検証・承認 |
| 中: 販売機能 | `pubspec.yaml` は Flutter SDK のみを依存。購入・復元 SDK や課金権利データモデルはない | 有料ダウンロードならアプリ内購入を不要にできる。無料体験 + 全解放ならストアごとの実装と復元が必要 |
| 中: プラットフォーム保証 | Android の `minSdk = 28`、`targetSdk = 35`。Fire 2 機種の継続的実機試験記録は別途必要 | 第 11 世代 API 28 / 第 13 世代 API 30 の実機を試験。現在のストア target API 条件は提出時に再確認 |
| 中: データ保全 | Android は学習状態/PIN をアプリ専用 SharedPreferences、保存録音を専用 files、仮録音を cache に置く。バックアップは無効 | 更新時の履歴・設定保持を試験。再インストール/端末故障時の復元は保証しない。iOS に同等の音声保護を設計 |

Android release manifest は `RECORD_AUDIO`、任意のマイク機能、バックアップ無効、平文通信禁止を宣言し、`INTERNET` 権限はない。debug 用ネットワーク権限は Flutter デバッグ用。コード監査上、現行アプリに児童音声のアップロード処理は見当たらない。ただし、出荷する release artifact と将来追加する SDK も同じ条件かはリリースごとに検査する。

現在の Android 音声処理は Android の標準 MediaPlayer / AudioRecord 等を使い、Google Play services や Google 音声認識 API を依存にしていない。これは Fire に適した構成であるが、Fire のマイク・イヤホン・OS 権限動作が同一であることは実機で確認する。

## 再利用する部分と実装が必要な部分

教材 JSON、10 島 70 レッスン、11 匹の動物、Flutter の UI・学習ロジック、音声/イラスト/フォント資産は原則共用する。学習履歴と保護者設定の既存シリアライズを保持し、変更が必要なら旧データを使う移行試験を先に用意する。

| 機能 | 現行 Android | iOS の必要工程・受け入れ条件 |
| --- | --- | --- |
| 起動・端末選択 | `AndroidDevice` 既定 | `Device` 契約を実装し、プラットフォームに応じて生成。未対応機能で履歴を初期化しない |
| 履歴・設定・PIN | SharedPreferences、ハッシュ化 PIN | 状態の永続化と原子的保存、PIN/秘密情報の保管方式を設計。Keychain 等の適否と依存を比較する。旧状態の decode 互換性を維持 |
| 教材再生 | WAV / MediaPlayer、速度・音量指定 | AVAudioPlayer 等で bundled asset、速度・音量、連続タップ時の排他、停止を実装。音高変化・歪みを含め試験 |
| 録音・再生 | 16 kHz / mono / PCM16、最大 10 秒 | AVAudioSession と録音処理、権限を実装。機器の実サンプルレートを確認し、必要なら変換後 WAV のヘッダ/品質を検査。API の指定だけで 16 kHz と決めつけない |
| 権限 | 最初の録音で要求、拒否時は残りの学習継続 | `NSMicrophoneUsageDescription` に日本語の目的を記載。拒否・後から取り消し・再起動を試験。サーバーや Apple の Speech 認識は使わないので、そのための権限を一律に要求しない |
| 一時・保存録音 | cache / files、明示保存、最大 20 件 | 保存先、上限、クラッシュ後の一時録音削除、保存/削除の失敗を実装。保存録音を iCloud/端末バックアップ対象から除外する方針を実装・試験 |
| 中断 | pause 時に再生停止・録音破棄を試みる | 電話/Siri/他アプリ・イヤホン切断・画面ロック・バックグラウンド化で録音/再生を安全に終了。端末音声が意図せず録音に重ならない |
| 保護者ゲート | アプリ内 PIN | 同じ保護者設定を保護。購入・外部リンク前のゲートと OS ストアの購入認証を両方検証。PIN は外部音声送信の同意を代替しない |
| 横向き・画面 | Flutter と Android activity で横向き | iPhone/iPad の safe area、横向き、分割表示の扱い、文字拡大・VoiceOver・スイッチ操作を確認。Android の画面指定をそのまま iOS 対応済みとしない |

iOS 用 Flutter テンプレートにはアプリ/フレームワークの plist と Xcode プロジェクトがあるが、本アプリ用の録音理由やネイティブ機能を自動で追加しない。新しいプラグインを使う場合も、機能・オフライン性・プライバシー・ライセンスを比較してから選ぶ。

## Windows 中心の開発から iPhone/iPad へ

1. **Windows**: Flutter/Dart の共用実装、教材整合性、単体/ウィジェット試験、Fire 実機の Android デバッグを進める。Android release APK/AAB と署名は、家庭向けデバッグ版と販売版を区別する。公開用秘密鍵をリポジトリへ置かない。
2. **Mac の確保**: 所有/借用の Mac と Xcode を第一案にする。有料 Mac CI は代替案として料金、署名鍵の管理、実機確認方法を比較して承認を得る。Windows 単独では iOS をビルドできない。公式 Flutter ツール実装も macOS 以外を拒否する。
3. **iOS 基盤**: 専用の作業で iOS プロジェクトを生成・レビューし、Bundle ID、表示名、対応 OS、iPhone/iPad、横向き、アイコン、マイク説明を設定。Device 実装、オーディオセッション、保存・削除・中断動作を接続する。
4. **Mac の検査**: `flutter doctor -v` で Xcode、必要なビルド連携ツール、署名環境を確認。取得済み Flutter 公式手順は Xcode の導入、コマンドラインツール選択、Xcode ライセンス確認、iOS プラットフォーム/シミュレーター追加、ネイティブプラグイン用 CocoaPods の準備を案内している。採用する Flutter の版とプラグイン構成に合わせる。Xcode の要求版や提出用 SDK の期限を固定の古い値で決めず、提出時の Apple 公式要件で記録する。
5. **署名と実機**: Mac へ USB 接続し、端末でコンピューターを信頼し、必要な Developer Mode を有効にする。`flutter devices` と `flutter run -d <device_id>` で開発実行する。適切な開発チーム、証明書、プロビジョニングを Xcode の Runner 設定で確認する。シミュレーターで表示/操作を確認し、実機で録音・音声・性能を試す。取得済み Flutter 公式手順は個人の無料アカウントでの実機試験と有料プログラムによる公開を区別している。App Store 配信には Developer Program / App Store Connect の準備が必要になる。登録料・契約・税務・有料アプリ契約の最新条件を所有者が確認する。
6. **配布候補の検証**: Bundle ID と App Store Connect のアプリ情報を用意し、Mac の `flutter build ipa` で署名付き `.xcarchive` と `.ipa` を生成する工程を用意する。取得済み Flutter 公式手順は `build/ios/archive/`、`build/ios/ipa/` の出力と Xcode/Transporter 等での App Store Connect への送信を案内している。公開候補ごとにビルド番号を更新する。TestFlight で iPhone/iPad と保護者の操作を確認し、外部テスト審査の要否・配布条件を提出時に確認する。この監査でビルド、署名、アップロードはしていない。
7. **公開**: 年齢/対象層、プライバシー説明、権利書類、音声の品質、画面画像、サポート先、購入/復元を揃え、審査に「録音は端末内、既定は一時保存、採点なし」等の実挙動を説明する。実装完成・検証後に公開の承認を得る。

## 買い切り方式の比較

「買い切り」は販売形態と、継続 API 費用を持たない設計の両方で考える。最初の購入・インストール・更新・購入の復元にはストアへの接続が必要になり得るため、「ネット接続なしで購入可能」とは説明しない。通常の学習は購入後・教材同梱後にオフラインで成立させる。

| 方式 | 利点 | 必要な実装・制約 | 推奨 |
| --- | --- | --- | --- |
| 全教材を含む有料ダウンロード | 購入 UI とアプリ内権利管理を減らせる。広告・課金誘導のない冒険画面にしやすい | 無料体験の別案が必要。価格・再ダウンロード・家族共有・返金はストア条件を確認。教材品質が購入判断の前提 | **最初の一般公開の第一候補**。価格とストア設定は未決定 |
| 無料お試し + 1 回の非消費型全解放 | 保護者が音質・操作を試してから購入できる | 各ストアの購入・保留・完了・取消・復元・返金・オフライン権利の設計が必要。学習中に繰り返し購入を促さない | 試用需要が確認された段階の比較候補 |
| 月額や消費型チケット | 継続クラウド費用を回収しやすい | 継続契約と利用制限が増える。今回の買い切り・広告なし原則に合いにくい | 初期案には採用しない |

Flutter 公式 `in_app_purchase` の取得済み README は App Store と Google Play を対象としている。Amazon をサポートすると記載されていないため、同じプラグインを入れれば Fire の課金まで完成するとは見積もらない。Amazon IAP を使うなら専用アダプター/SDK を比較し、ストアごとのビルド構成とテストを追加する。今回は購入 SDK を追加していない。

IAP を採用する場合、永久解放は消費型扱いにしない。購入と復元は保護者画面から入り、ストアが利用できなくても購入済みの学習と履歴閲覧を妨げない設計にする。検証済み権利の保持、再インストール後の復元、返金時の扱い、ストアの整合性確認を設計し、履歴データと分離する。異なるストア間での購入共有や家族共有を、アカウントなしの現行構成で保証しない。

## ストアごとの提出前チェック

以下は**確認すべき項目の計画**である。Apple/Google/Amazon の最新規約本文はこの実行環境のネットワーク制限で取得できなかったため、現行ルール適合が確認済みという意味ではない。

| 配信先 | 技術と審査で確認する項目 |
| --- | --- |
| Fire / Amazon Appstore | Fire 第 11/13 世代の実機、Google 系サービスなし、販売用の署名済みパッケージ、Amazon の現在の受付対象端末/地域/SDK 条件、対象年齢、児童プライバシー、マイク理由、保護者ゲート、価格・返金、IAP 使用時の Amazon 固有購入/復元。Fire Kids 等の別プログラムへの採用は通常公開と別扱い |
| Google Play | release AAB と署名、提出時の target API と新しい端末要件、対象年齢/対象ユーザー/コンテンツ、Families 方針、Data safety とプライバシーポリシー、マイクと全 SDK のデータ取り扱い、オフライン学習、必要なら課金テスト/復元、個人アカウント等のテスト要件。Google のアカウント条件を子ども用アプリのアカウント登録と混同しない |
| Apple App Store | Mac/Xcode/署名と提出 SDK、iPhone/iPad、マイク目的、App Privacy と privacy manifest / 必須理由 API の該当性、第三者 SDK、Kids Category の対象年齢帯・外部リンク/購入ゲートの最新条件、価格/有料契約、必要なら非消費型購入/復元、TestFlight、審査メモ。6 歳と 9 歳を対象にするため、カテゴリの年齢帯と実際の対象範囲を照合 |

保護者向け説明では、端末に残す学習履歴と明示保存録音、既定では保存しない仮録音、削除方法、アンインストールの影響、バックアップ方針を分けて書く。外部送信なしという現在の方針に、課金 SDK、クラッシュ収集、広告/分析を勝手に追加しない。購入処理がある場合はストアによる取引データの扱いも説明対象にする。

## リリース判定のための試験

- **Fire 第 11/13 世代**: 381 語/音声の対応チェックに加え、実音量・遅延・歪み、短音素の聞こえ、音量ボタン/イヤホン、10 秒録音、連打、保存上限、権限拒否、他アプリ中断、ホームへ戻る、強制終了後の仮録音削除を確認。
- **iPhone/iPad**: ネイティブ機能の同等性、音声セッションと権限、横向き・safe area・文字拡大・読み上げ、古い対象端末の RAM/性能、保存録音のバックアップ除外、機内モードを実機で確認。シミュレーターだけで録音品質を承認しない。
- **オフライン**: 新規インストール後の初回起動から教材/お手本/ゲーム/履歴/録音・比較が動くかを機内モードで試す。ストアでのインストール/復元が必要な工程は分けて説明。追加モデルや CDN からの初回取得が暗黙に発生しないことを確認。
- **更新と保全**: 旧版で履歴・保護者設定・PIN・明示保存録音を作り、同じ application ID / 署名の新版へ上書き更新。値が残ることと、破損データで自動初期化しないことを確認。アンインストールを通常の更新手順にしない。
- **販売と権利**: 素材ごとの出所/許諾/版/加工/再配布範囲、専門家の承認、Privacy/Data safety の実装一致、購入・復元/返金の試験を記録。音声やイラストの見栄えだけで権利や教育品質の承認を代用しない。

## 承認が必要な次の選択

1. 自動評価モデル導入、児童音声のクラウド送信、新しい有料サービスの契約は `pronunciation-evaluation-options.md` の比較と検証条件を満たしてから承認を求める。
2. 教材の全置換や体系の全面変更は、対象・移行・音声/図解/テスト・費用を示して承認を求める。監査で見つけた 1 対 1 対応エラーの修正と区別する。
3. 実装・品質検証が済んだ販売候補を揃えてから、配信先・価格・有料ダウンロードか IAP か・公開を判断する。今の段階でストア登録や契約は実行しない。

## 出典と取得状態

| 出典 | 取得状態と用途 |
| --- | --- |
| ローカル Flutter SDK `packages/flutter_tools/lib/src/commands/build_ios.dart`、`src/ios/mac.dart`、`templates/app/ios.tmpl/` | 2026-11-11 に読解。iOS build の macOS 制限、Xcode 必要性、テンプレートの構成を確認。SDK ソースの読解は Apple の最新審査条件の確認ではない |
| Flutter 公式 website ソース [iOS setup](https://github.com/flutter/website/blob/35ed8c8d5caf1ff8b63a80bfe0f5b1b85e6e8e68/sites/docs/src/content/platform-integration/ios/setup.md) / [iOS deployment](https://github.com/flutter/website/blob/35ed8c8d5caf1ff8b63a80bfe0f5b1b85e6e8e68/sites/docs/src/content/deployment/ios.md) | 2026-11-11 に公式リポジトリの本文取得。取得時の main HEAD をリンクした。Mac/Xcode、信頼/Developer Mode、開発署名、`flutter build ipa`、App Store Connect、TestFlight の工程を確認。Apple の最新ポリシー自体を取得したわけではない |
| [Flutter 公式 in_app_purchase README](https://github.com/flutter/packages/blob/main/packages/in_app_purchase/in_app_purchase/README.md) | 2026-11-11 に本文取得。App Store/Google Play、非消費型、購入更新/完了/復元のフローを確認。更新される main ブランチの資料であり、導入する版は別途固定する |
| 本リポジトリ `lib/main.dart`、`lib/platform/device.dart`、Android Java/manifest/Gradle、`pubspec.yaml`、`assets/licenses/NOTICE.md` | 2026-11-11 に読解。現行構成の確認。今回 iOS ビルド/ストア操作はしていない |
| [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)、[App Privacy](https://developer.apple.com/app-store/app-privacy-details/)、[TestFlight](https://developer.apple.com/testflight/)、[StoreKit](https://developer.apple.com/storekit/) | Apple review ページは 2026-11-11 の取得が CONNECT 403。関連公式リンクは提出前の確認先として提示。Apple 原文での最新条件の照合は未了 |
| [Google Play Billing](https://developer.android.com/google/play/billing)、[Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335)、[Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)、[target API](https://support.google.com/googleplay/android-developer/answer/11926878) | Billing ページは同日の取得が CONNECT 403。関連ページは確認先。最新の対象年齢、申告、提出期限、費用は未確認 |
| [Amazon IAP](https://developer.amazon.com/docs/in-app-purchasing/iap-overview.html)、[Amazon policy overview](https://developer.amazon.com/docs/policy-center/understanding-content-policy.html) | IAP ページは同日の取得が CONNECT 403。現行の配信/児童/決済条件、Amazon 個別 SDK 条件は未確認 |

ネットワーク設定の追加案は親作業で保存されているが、Save/Publish 後の実行環境への反映は未確認。取得不可の資料を読んだことにして規約適合や価格を断定しない。公開前に本文を取得して、このチェック表と実装に対応する条項・確認日を追記する。
