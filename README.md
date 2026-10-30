# Windows Unity 3D 自律開発ハーネス

空の `yh243233/test_unity` を起点とした、Unity 2022.3.22f1 / Built-in Render Pipeline向けの最小構成です。
AIエージェントがローカルのソースを編集し、コマンドを実行し、JSON・ログを読んで修正するための実行基盤です。
AIモデルやAPI呼び出し、無制限の自動修正ループは含みません。Windows PC上でファイル編集とPowerShell実行ができるAIエージェントを別途使います。

## 準備

1. Unity Hubで **2022.3.22f1** をインストールし、ライセンスを有効化してください。
2. リポジトリをWindowsにcloneします。Windows PowerShell 5.1またはPowerShell 7を使います。
3. リポジトリ直下で以下を実行します。初回はパッケージ取得にインターネットが必要です。

```powershell
git clone https://github.com/yh243233/test_unity.git
cd test_unity
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\unity.ps1 -Task Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\unity.ps1 -Task Check -TimeoutSeconds 1800
```

`Bypass`はこのプロセスだけに適用されます。管理者権限やシステムの実行ポリシー変更は不要です。
標準外の場所にインストールした場合は、各コマンドに `-UnityPath 'D:\Unity\2022.3.22f1\Editor\Unity.exe'` を渡すか、次を設定します。

```powershell
$env:UNITY_EDITOR_PATH = 'D:\Unity\2022.3.22f1\Editor\Unity.exe'
```

自動検索はProjectVersion.txtと一致するHub標準パスだけを使います。明示指定時は、そのEditorが2022.3.22f1であることを確認してください。Doctorはパスと構成の事前確認で、ライセンス・インポート・コンパイル成功の証明ではありません。

## コマンド

| Task | 動作 |
| --- | --- |
| Doctor | Editorパス、プロジェクト、使用中ロックを確認 |
| Compile | インポート・コンパイル完了をマーカーで確認。初回だけデモシーンを作成 |
| EditMode | シーン構成のテストを実行 |
| PlayMode | Physicsによる落下・床との衝突をテスト |
| Check | Compile → EditMode → PlayModeを直列実行。失敗時に停止 |
| Open | GUIでEditorを起動。成功は「起動要求が通った」意味のみ |
| Logs | 最新のsummary.jsonとログ末尾を表示。Editor不要 |

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\unity.ps1 -Task Open
# Editor上で Assets/Harness/Scenes/HarnessDemo.unity を開き、Playで落下を確認
# Editorを閉じてから自動検証
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\unity.ps1 -Task Check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\unity.ps1 -Task Logs -Tail 80
```

最初にOpenした場合は、メニュー `Harness > Create Demo Scene If Missing` でもシーンを生成できます。
生成済みのシーンは上書きしません。Unityが初回に生成するProjectSettings、packages-lock.json、シーンとその.metaは、差分を確認してからコミット候補に含めてください。

## AIの反復手順

1. [AGENTS.md](AGENTS.md)と対象の仕様を読む。完了条件・今回触る範囲・最大試行回数を決める。
2. C#・テスト・必要なEditorツールを小さく編集する。シーン・Prefab編集はEditor APIで行い、参照関係を保つ。
3. Editorを閉じて `-Task Check` を実行する。同じプロジェクトで複数のUnityを起動しない。
4. 終了コードと `artifacts/harness/latest.json` のdirectoryを読み、その中の `summary.json` を確認する。
5. 失敗したstepの `.log`・`.diagnostics.txt`・テストXMLを読み、原因を絞って修正する。
6. 最大3回を目安に止め、解消しなければ原因・試した修正・残る問題をユーザーへ報告する。
7. テスト通過後、Openして見た目と操作を人が確認する。差分・検証結果を提示し、承認後にコミット／push／PR作成する。

`summary.json`の `status=passed` かつ終了コード0をCheck成功条件とします。Openは `launched` です。
Logs自体の終了コード0は検証成功を意味しません。全体summaryのstatusを読んでください。
各実行は別ディレクトリに記録されるので、前回のXMLを成功判定に使い回しません。
テストXMLが無い・不正・0件・Passedでない場合は失敗します。ログ抽出は調査の補助で、判定の代用ではありません。

## 構成

```text
Assets/Harness/Runtime/        プリミティブの3D検証シーンを構成
Assets/Harness/Editor/         シーン生成・コンパイル完了の入口
Assets/Harness/Tests/EditMode/ 構成テスト
Assets/Harness/Tests/PlayMode/ 物理の動作テスト
Packages/manifest.json         Test FrameworkとPhysicsを明示
ProjectSettings/               Editorバージョン固定
tools/unity.ps1                Windowsの実行入口
tools/tests/                   Unityを使わない実行制御テスト
artifacts/harness/             実行ごとのJSON・ログ・XML（Git対象外）
```

床・球・カメラ・ライトはUnity組み込みのものだけで作成し、外部素材の準備は不要です。
ゲーム本体、Windowsビルド／配布、画面キャプチャ、自動的なGit操作、GitHub ActionsでのUnity実行は今回の最小構成に含みません。
PlayModeはGPUを使うため `-nographics` を付けていません。描画品質・見た目の正しさはテスト対象外です。

## 困った場合

- **Collider / PhysicsModuleが見つからない**：manifest.jsonの `com.unity.modules.physics` を確認し、Unityのパッケージ解決ログを確認します。
- **Editorが見つからない**：インストール済みの正しいバージョンを `-UnityPath` で指定します。
- **UnityLockfileがある**：先にEditorを終了します。起動中か確認せずロックやLibraryを削除しないでください。
- **タイムアウト**：初回インポートは `-TimeoutSeconds 1800` などに増やします。スクリプトが起動したプロセスツリーだけを停止します。
- **ライセンス／Package Manager失敗**：Unity Hubで有効化・ネットワークを確認します。認証情報をリポジトリへ保存しません。
- **Checkの合間にEditorを開いた**：Unity自身のプロジェクトロックで後続処理が失敗する可能性があります。完了まで閉じておきます。

## スクリプト検証

Unityなしの実行制御テストは、Linux + Python 3 + PowerShell 7で実行できます（実行可能な代役スクリプトを使うためPOSIX限定）。

```bash
PWSH=pwsh python3 -m unittest discover -s tools/tests -v
```

これはWindows／Unity Editorの実機検証を代替しません。Windowsでは上のDoctor・Check・Openを実施してください。
実施済み範囲は [docs/VALIDATION.md](docs/VALIDATION.md) を参照してください。

参考： [Unity 2022.3 Editor引数](https://docs.unity3d.com/2022.3/Documentation/Manual/EditorCommandLineArguments.html)、[Test Framework 1.1 CLI](https://docs.unity3d.com/Packages/com.unity.test-framework@1.1/manual/reference-command-line.html)。
