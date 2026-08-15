# GitHub公開前チェックリスト

## 公開を止める必須確認

- [x] 著作権者を`nguchi`とし、見直し前提の暫定`LICENSE`をルートに追加する
- [ ] 公開先リポジトリでPrivate Vulnerability Reportingを有効化する
- [x] `git diff --check`と全単体テストを成功させる（2026-08-15、73件成功）
- [x] DebugとReleaseのmacOSビルドを確認する（2026-08-15、署名なしビルド）
- [x] `git status --ignored`でユーザー固有データと署名資料が公開対象外であることを確認する
- [x] 最小対応OSとXcodeバージョンがREADMEとプロジェクト設定で一致していることを確認する

## リポジトリ設定

- [x] 説明、トピック、デフォルトブランチを設定する
- [ ] Issue、Pull Request、Securityの運用方針を確認する
- [ ] Branch protectionまたはRulesetで、必要なテストを保護ブランチに要求する
- [x] Version 0の開発中として公開し、安定版タグは付けない
- [ ] App Store提出または公証配布前に、開発用Build末尾`T`をApple公式の数字・ピリオド形式へ変更する

## 内容確認

- [x] READMEの機能一覧と将来計画が現在の実装と一致する
- [x] `THIRD_PARTY_NOTICES.md`とKaTeXライセンスを確認する
- [x] 現時点では画面写真を公開しない
- [x] サンプル入力とテストデータがすべて架空であることを確認する

## 現在の未決事項

- プロジェクト本体の最終ライセンス条件
- 公開時のバージョンとタグ
- GitHub Actionsで使用するmacOS・Xcode環境
- 配布時の`CFBundleVersion`形式
