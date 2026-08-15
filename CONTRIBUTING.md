# Contributing to KobunPark

KobunParkはmacOSを優先するローカルファーストのSwiftUIユーティリティです。変更は小さく保ち、入力データを送信・保存しない設計を維持してください。

現在はVersion 0の開発中です。Contributionを提出する場合は、その内容を提供する権利があり、KobunParkのMIT Licenseで公開されることを確認してください。不具合報告では実データを使用せず、再現可能な架空データだけを提示してください。

## Development

1. Xcodeで`KobunPark.xcodeproj`を開きます。
2. `KobunPark`スキームとmacOSデスティネーションを選択します。
3. 変換ロジックはViewから分離し、正常系、空入力、不正入力、Unicode、境界値のテストを追加します。
4. 変更前に関連テスト、変更後に全単体テストとmacOSビルドを実行します。

```sh
xcodebuild -project KobunPark.xcodeproj -scheme KobunPark \
  -destination 'platform=macOS' \
  -only-testing:KobunParkTests test

xcodebuild -project KobunPark.xcodeproj -scheme KobunPark \
  -destination 'platform=macOS' build
```

## Pull requests

- 目的と変更範囲を説明してください。
- 実行したテストと未確認事項を記載してください。
- UI変更では、可能なら画面またはアクセシビリティ識別子の変更を説明してください。
- クリップボード内容、トークン、実データ、署名資料をコミットしないでください。

## Dependencies

本番依存の追加時は、目的、保守リスク、ライセンス、Apple標準の代替案をPull Requestに記載してください。
