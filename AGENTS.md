# AI作業ルール

- Windows Unity 2022.3.22f1、Built-in Render Pipelineを前提にする。
- 仕様と完了条件を決め、ソース・テストを小さく編集し、tools/unity.ps1 -Task Checkで確認する。
- 検証中は同じプロジェクトのEditorを閉じ、Unityプロセスを並列実行しない。
- artifacts/harness/latest.json → directory/summary.json → 失敗stepのログ・XMLの順で読む。
- 起動成功とテスト成功を区別する。未実行の確認を「通過」と記載しない。
- AI側の修正反復は1タスク最大3回を目安とし、未解決なら根拠を添えてユーザーに戻す。
- シーン・Prefab・設定の変更はEditor APIを優先し、既存アセットのGUIDと.metaを維持する。
- Library/Temp/UserSettings/artifacts、認証情報、個人のEditorパスをコミットしない。
- packages-lock.jsonとUnityが生成したProjectSettings・シーン・.metaは内容を確認してからコミット候補にする。
- ロックやLibraryを自動削除しない。他のUnityプロセスを一括終了しない。
- パッケージ追加、Unityのバージョン変更は必要性を説明し、今回の目的に関係しない改修を混ぜない。
- コミット・push・ブランチ作成・PR作成・マージ・外部への書き込みはユーザーの承認後に行う。
- 最終報告には変更内容、実施した検証、未検証の範囲、Windows上での再現手順を含める。
