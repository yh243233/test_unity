# 検証記録

対象: yh243233/test_unity の初回追加候補。2026-10-30時点。

## 既存構成の確認

GitHub接続経由のリポジトリメタデータと、cloneしたローカルコピーを確認しました。
GitHub上はsize=0、既定ブランチ名main、ローカルはNo commits yetで、既存のAssets、Packages、ProjectSettings、AGENTS.mdはありませんでした。
既存コードへの上書きはありません。既存の別プロジェクトや過去のZIPは取り込んでいません。

## この環境で確認した内容

Linux、PowerShell 7.4.6、Python 3.12で、実際のtools/unity.ps1を別プロセスとして実行するテストを実施しました。
Unity Editorの代役は引数を記録し、ログ・マーカー・NUnit形式のXMLを生成します。

- Check成功時のCompile → EditMode → PlayModeの順序
- 空白・日本語を含むプロジェクトパスの受け渡し
- Compileにのみ-quitと-nographicsを付けること
- Unity異常終了・コンパイル完了マーカー欠落の失敗判定
- XMLの欠落・破損・0件・Failedの失敗判定
- タイムアウト時の失敗判定
- UnityLockfileがある場合の起動拒否
- ハーネス同時実行の拒否と、実行中のlatestポインターの保護
- 過去の成功XMLを次回判定に使い回さないこと
- DoctorがUnityを起動しないこと、LogsがEditorなしでも使えること
- Editorが見つからない場合、以前の成功ではなく今回の失敗を最新結果にすること
- Openの結果がpassedではなくlaunchedになること

上記を9個のテストメソッド（異常系には複数のサブケース）で確認しました。
JSON・asmdefの構文、.metaの対応・GUID重複、不要ファイルの除外も静的に確認しました。

## 未検証と実機での受入手順

この環境にはUnity EditorとWindowsがないため、以下は未検証です。

- UnityでのC#コンパイル、Package Manager解決、初回設定生成
- 本物のEditMode/PlayModeテストの成功
- GUI表示、Windows PowerShell 5.1、Windowsのtaskkillによる子プロセス停止
- GPU・ライセンス・ネットワークに依存する挙動

Windows受入手順:

1. HubでUnity 2022.3.22f1を有効化する。
2. READMEのDoctorを実行し、Editorパスを確認する。
3. Editorを閉じてCheckを実行する。
4. summary.jsonのstatus=passed、3stepすべてpassed、両XMLで1件以上Passedを確認する。
5. Openで生成済みHarnessDemo.unityを開き、Playで球が床の上に落ちることを確認する。
6. 自動生成された設定と.metaの差分をレビューする。

Unity公式資料でEditor CLIとTest Framework CLIを確認し、テストには-quitを付けずに結果を待つ構成にしました。

## 外部への反映

GitHubへのファイル追加、コミット、ブランチ作成、push、PR作成、マージはいずれも未実施です。
リポジトリが空なので、反映する場合はmainへの初回コミットが必要です。ユーザーの承認後に行います。
