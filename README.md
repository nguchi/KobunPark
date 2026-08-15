# KobunPark

> [!WARNING]
> **Version 0 — 開発中**
>
> 現在は仕様・画面・変換結果が変更される可能性がある開発版で、安定版ではありません。重要なデータは必ず原本を保持してください。

KobunParkは、JSON、CSV、URL・文字列、LaTeX、正規表現をローカルで整形・検証・変換・プレビューするmacOS向けSwiftUIアプリです。

## 現在の機能

- JSONの整形と検証
- 2スペース／4スペースのインデント
- JSONの圧縮
- 取得可能な行・列を含む日本語エラー表示
- RFC 3986 URLコンポーネントのエンコード／デコード
- 不正なパーセント表記とUTF-8のエラー表示
- Base64のUTF-8文字列エンコード／デコード
- HTML文字参照とJSON文字列のエスケープ／アンエスケープ
- CSVからMarkdown表、HTML表、XMLへの変換
- 引用セル、埋め込みカンマ・改行、CRLFを扱うCSV解析
- 同梱したKaTeXによるオフラインLaTeXプレビュー
- インライン／ディスプレイ数式の切り替えと構文エラー表示
- 正規表現の一致箇所・件数表示、キャプチャ付き置換プレビュー
- 大文字小文字無視、複数行アンカー、改行を含むドットの正規表現オプション
- JSON／文字列／CSV／LaTeX／正規表現ツールの切り替え
- 各ツールの定型構文をカーソル位置へ挿入する入力補助ボタン
- 選択中の文字列をLaTeX構文や正規表現グループで囲む入力補助
- 入力、設定、処理結果、全クリアのUndo／Redo
- `⌘Z`／`⇧⌘Z`と画面上のUndo／Redoボタン
- 明示操作による結果のコピー
- 入力、結果、エラー状態の全クリア
- 入力と履歴を自動保存しないローカル処理

Undo／Redo履歴は最大100操作をメモリ内だけに保持し、アプリ終了時に消去します。

## 開発環境

- Xcode 26.6で作成されたSwiftUIプロジェクト
- 主要ターゲット：macOS
- 現在の最小対応OS：macOS 26.5
- Bundle ID：`jp.nguchi.KobunPark`
- 開発中のVersion：`0`（利用者が指定した場合だけ変更）
- Build：日本時間の`YYYYMMDDHHMMSST`形式（現在は`20260815090831T`）
- Copyright：`Copyright © 2026 nguchi.`
- LaTeX描画：KaTeX 0.18.1（MIT、アプリに資産とライセンスを同梱）

KaTeXは実行時にCDNや外部サービスへ接続せず、WebKitの非永続データストア内でローカル資産のみを読み込みます。

## プライバシー

- 入力、結果、Undo／Redo履歴を既定で保存しません。
- 変換対象をネットワーク送信しません。
- クリップボードを自動収集せず、書き込みは利用者のコピー操作時だけです。

## 将来計画

主要フローは`貼り付け -> 形式の自動判定 -> 変換方法の選択 -> プレビュー／コピー`とします。自動判定は利用者が上書きできる推奨とします。

- LaTeXからUnicode表現・MathMLへの変換
- JSONからYAML・XMLへの変換
- 入力形式の助言的な自動判定

詳細な範囲は`docs/PROJECT_BRIEF.md`と`docs/REQUIREMENTS.md`に記録しています。

## ビルドとテスト

```sh
xcodebuild -project KobunPark.xcodeproj -scheme KobunPark -destination 'platform=macOS' build
xcodebuild -project KobunPark.xcodeproj -scheme KobunPark -destination 'platform=macOS' test
```

署名と配布方法は未決定です。現在のプロジェクト設定はmacOS 26.5以降を対象としています。

Build番号末尾の`T`は開発中の識別性を優先した運用です。Appleの配布用`CFBundleVersion`仕様では数字とピリオドだけが正式形式のため、App Storeや公証を伴う配布前に形式を再確認します。

## リポジトリ文書

- [貢献ガイド](CONTRIBUTING.md)
- [セキュリティ方針](SECURITY.md)
- [第三者ライセンス](THIRD_PARTY_NOTICES.md)
- [GitHub公開前チェックリスト](docs/PUBLICATION_CHECKLIST.md)

## ライセンス

KobunPark本体は、著作権者`nguchi`による[MIT License](LICENSE)で提供します。著作権表示と許諾表示を残すことを条件に、複製、改変、公開、再配布、サブライセンス、販売を含む商用・非商用利用が可能です。

ソフトウェアは現状有姿で提供され、明示・黙示を問わず保証しません。作者および著作権者は、利用や不具合に関連して生じた請求、損害その他の責任を負いません。正式な条件は英語の[LICENSE](LICENSE)本文を優先します。

第三者コンポーネントのKaTeXにもMITライセンスが適用され、ライセンス本文を別途同梱しています。
