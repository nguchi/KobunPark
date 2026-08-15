//
//  TextInputAssistance.swift
//  KobunPark
//

import SwiftUI

struct InputAssistanceSnippet: Equatable, Identifiable {
    let id: String
    let label: String
    let prefix: String
    let placeholder: String
    let suffix: String
    let help: String

    init(id: String, label: String, insertion: String, help: String) {
        self.init(
            id: id,
            label: label,
            prefix: insertion,
            placeholder: "",
            suffix: "",
            help: help
        )
    }

    init(
        id: String,
        label: String,
        prefix: String,
        placeholder: String,
        suffix: String,
        help: String
    ) {
        self.id = id
        self.label = label
        self.prefix = prefix
        self.placeholder = placeholder
        self.suffix = suffix
        self.help = help
    }
}

@MainActor
enum TextInputAssistance {
    static func insert(
        _ snippet: InputAssistanceSnippet,
        into text: inout String,
        selection: inout TextSelection?
    ) {
        let replacementRange = primaryRange(from: selection) ?? text.endIndex..<text.endIndex
        let startOffset = text.distance(from: text.startIndex, to: replacementRange.lowerBound)
        let selectedText = String(text[replacementRange])
        let usesPlaceholder = selectedText.isEmpty && !snippet.placeholder.isEmpty
        let body = usesPlaceholder ? snippet.placeholder : selectedText
        let replacement = snippet.prefix + body + snippet.suffix

        text.replaceSubrange(replacementRange, with: replacement)

        let bodyStart = text.index(
            text.startIndex,
            offsetBy: startOffset + snippet.prefix.count
        )
        if usesPlaceholder {
            let bodyEnd = text.index(bodyStart, offsetBy: body.count)
            selection = TextSelection(range: bodyStart..<bodyEnd)
        } else {
            let insertionOffset = startOffset + replacement.count
            let insertionPoint = text.index(text.startIndex, offsetBy: insertionOffset)
            selection = TextSelection(insertionPoint: insertionPoint)
        }
    }

    private static func primaryRange(from selection: TextSelection?) -> Range<String.Index>? {
        guard let selection else {
            return nil
        }

        switch selection.indices {
        case .selection(let range):
            return range
        case .multiSelection(let ranges):
            return ranges.ranges.first
        @unknown default:
            return nil
        }
    }
}

struct InputAssistanceBar: View {
    let snippets: [InputAssistanceSnippet]
    let insertAction: (InputAssistanceSnippet) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label("入力補助", systemImage: "keyboard")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(snippets) { snippet in
                        Button(snippet.label) {
                            insertAction(snippet)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(snippet.help)
                        .accessibilityLabel(snippet.help)
                        .accessibilityIdentifier("input-assist-\(snippet.id)")
                    }
                }
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("input-assistance")
    }
}

extension InputAssistanceSnippet {
    static let csv: [Self] = [
        Self(
            id: "csv-table",
            label: "表の例",
            prefix: "名前,値\n",
            placeholder: "KobunPark,1",
            suffix: "",
            help: "ヘッダーと1行のCSV例を挿入"
        ),
        Self(
            id: "csv-quoted",
            label: "引用セル",
            prefix: "\"",
            placeholder: "カンマ,改行を含む値",
            suffix: "\"",
            help: "引用符で囲んだCSVセルを挿入"
        ),
        Self(id: "csv-comma", label: ",", insertion: ",", help: "カンマを挿入"),
        Self(id: "csv-newline", label: "改行", insertion: "\n", help: "改行を挿入"),
    ]

    static let json: [Self] = [
        Self(
            id: "json-object",
            label: "{ }",
            prefix: "{\n  \"",
            placeholder: "key",
            suffix: "\": \"value\"\n}",
            help: "JSONオブジェクトを挿入"
        ),
        Self(
            id: "json-array",
            label: "[ ]",
            prefix: "[\n  ",
            placeholder: "value",
            suffix: "\n]",
            help: "JSON配列を挿入"
        ),
        Self(
            id: "json-property",
            label: "key: value",
            prefix: "\"",
            placeholder: "key",
            suffix: "\": \"value\"",
            help: "JSONプロパティを挿入"
        ),
        Self(id: "json-true", label: "true", insertion: "true", help: "trueを挿入"),
        Self(id: "json-false", label: "false", insertion: "false", help: "falseを挿入"),
        Self(id: "json-null", label: "null", insertion: "null", help: "nullを挿入"),
    ]

    static let latex: [Self] = [
        Self(
            id: "latex-fraction",
            label: "分数",
            prefix: #"\frac{"#,
            placeholder: "分子",
            suffix: "}{分母}",
            help: "LaTeXの分数を挿入"
        ),
        Self(
            id: "latex-root",
            label: "√",
            prefix: #"\sqrt{"#,
            placeholder: "x",
            suffix: "}",
            help: "LaTeXの平方根を挿入"
        ),
        Self(
            id: "latex-superscript",
            label: "xⁿ",
            prefix: "^{",
            placeholder: "n",
            suffix: "}",
            help: "LaTeXの上付き文字を挿入"
        ),
        Self(
            id: "latex-subscript",
            label: "xᵢ",
            prefix: "_{",
            placeholder: "i",
            suffix: "}",
            help: "LaTeXの下付き文字を挿入"
        ),
        Self(
            id: "latex-parentheses",
            label: "( )",
            prefix: #"\left("#,
            placeholder: "x",
            suffix: #"\right)"#,
            help: "大きさが自動調整される括弧を挿入"
        ),
        Self(id: "latex-sum", label: "Σ", insertion: #"\sum_{i=1}^{n} "#, help: "LaTeXの総和を挿入"),
        Self(id: "latex-integral", label: "∫", insertion: #"\int_{a}^{b} "#, help: "LaTeXの定積分を挿入"),
        Self(id: "latex-alpha", label: "α", insertion: #"\alpha"#, help: "LaTeXのαを挿入"),
        Self(id: "latex-beta", label: "β", insertion: #"\beta"#, help: "LaTeXのβを挿入"),
        Self(id: "latex-pi", label: "π", insertion: #"\pi"#, help: "LaTeXのπを挿入"),
        Self(
            id: "latex-matrix",
            label: "行列",
            insertion: "\\begin{matrix}\na & b \\\\\nc & d\n\\end{matrix}",
            help: "2行2列のLaTeX行列を挿入"
        ),
    ]

    static let regularExpression: [Self] = [
        Self(id: "regex-digit", label: #"\d+"#, insertion: #"\d+"#, help: "1文字以上の数字を挿入"),
        Self(id: "regex-word", label: #"\w+"#, insertion: #"\w+"#, help: "1文字以上の単語構成文字を挿入"),
        Self(id: "regex-letters", label: "A–Z", insertion: "[A-Za-z]+", help: "1文字以上の英字を挿入"),
        Self(
            id: "regex-group",
            label: "( )",
            prefix: "(",
            placeholder: "pattern",
            suffix: ")",
            help: "キャプチャグループを挿入"
        ),
        Self(
            id: "regex-noncapturing",
            label: "(?: )",
            prefix: "(?:",
            placeholder: "pattern",
            suffix: ")",
            help: "非キャプチャグループを挿入"
        ),
        Self(
            id: "regex-anchored",
            label: "^ $",
            prefix: "^",
            placeholder: "pattern",
            suffix: "$",
            help: "文字列全体に一致するパターンを挿入"
        ),
        Self(id: "regex-lazy-any", label: ".*?", insertion: ".*?", help: "改行以外の最短一致を挿入"),
        Self(id: "regex-han", label: "漢字", insertion: #"\p{Han}+"#, help: "1文字以上の漢字を挿入"),
    ]

    static func url(for mode: URLCodecMode) -> [Self] {
        switch mode {
        case .encode:
            return [
                Self(id: "url-address", label: "https://", insertion: "https://example.com/", help: "URLの例を挿入"),
                Self(id: "url-query", label: "?key=value", insertion: "?key=value", help: "クエリを挿入"),
                Self(id: "url-parameter", label: "&key=value", insertion: "&key=value", help: "追加クエリパラメーターを挿入"),
                Self(id: "url-fragment", label: "#section", insertion: "#section", help: "フラグメントを挿入"),
                Self(id: "url-space", label: "空白", insertion: " ", help: "空白を挿入"),
            ]
        case .decode:
            return [
                Self(id: "url-percent-space", label: "%20", insertion: "%20", help: "空白のパーセント表記を挿入"),
                Self(id: "url-percent-slash", label: "%2F", insertion: "%2F", help: "スラッシュのパーセント表記を挿入"),
                Self(id: "url-percent-question", label: "%3F", insertion: "%3F", help: "疑問符のパーセント表記を挿入"),
                Self(id: "url-percent-ampersand", label: "%26", insertion: "%26", help: "アンパサンドのパーセント表記を挿入"),
                Self(id: "url-percent-equals", label: "%3D", insertion: "%3D", help: "等号のパーセント表記を挿入"),
            ]
        }
    }

    static func stringCodec(for kind: StringCodecKind, mode: URLCodecMode) -> [Self] {
        switch kind {
        case .url:
            return url(for: mode)
        case .base64:
            if mode == .encode {
                return [
                    Self(id: "base64-text", label: "文字列の例", insertion: "KobunPark 日本語", help: "Base64化する文字列の例を挿入"),
                ]
            }
            return [
                Self(id: "base64-value", label: "Base64の例", insertion: "S29idW5QYXJr", help: "KobunParkのBase64表記を挿入"),
            ]
        case .html:
            if mode == .encode {
                return [
                    Self(id: "html-tag", label: "<p>", insertion: "<p>KobunPark & tools</p>", help: "HTMLエスケープ用の例を挿入"),
                    Self(id: "html-quotes", label: "引用符", insertion: "\"single'\"", help: "引用符の例を挿入"),
                ]
            }
            return [
                Self(id: "html-entities", label: "HTML参照の例", insertion: "&lt;p&gt;KobunPark &amp; tools&lt;/p&gt;", help: "HTML文字参照の例を挿入"),
            ]
        case .json:
            if mode == .encode {
                return [
                    Self(id: "json-string-raw", label: "JSON文字列の例", insertion: "\"日本語\"\nKobunPark", help: "JSONエスケープ用の文字列を挿入"),
                ]
            }
            return [
                Self(id: "json-string-escaped", label: "エスケープの例", insertion: #"\"日本語\"\nKobunPark"#, help: "JSONエスケープ済み文字列を挿入"),
            ]
        }
    }
}
