//
//  URLCodecView.swift
//  KobunPark
//

import SwiftUI

struct URLCodecView: View {
    @Binding var workspace: URLCodecWorkspace
    let processAction: () -> Void
    let clearAction: () -> Void
    @State private var didCopyResult = false
    @State private var inputSelection: TextSelection?
    @FocusState private var focusedField: Field?

    private enum Field {
        case input
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            editorArea
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("URL・文字列変換")
                .font(.title2.bold())
            Text("URL、Base64、HTML、JSON文字列をこのMac内で変換します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(helperDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("種類", selection: $workspace.kind) {
                Text("URL").tag(StringCodecKind.url)
                Text("Base64").tag(StringCodecKind.base64)
                Text("HTML").tag(StringCodecKind.html)
                Text("JSON").tag(StringCodecKind.json)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .accessibilityIdentifier("string-codec-kind")

            Picker("処理", selection: $workspace.mode) {
                Text(encodeLabel).tag(URLCodecMode.encode)
                Text(decodeLabel).tag(URLCodecMode.decode)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .accessibilityIdentifier("url-codec-mode")

            Spacer()

            Button("全クリア", role: .destructive, action: clearAll)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .accessibilityIdentifier("url-clear-all")

            Button("実行", action: processInput)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier("url-run")
        }
    }

    private var editorArea: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                inputPanel
                resultPanel
            }
            VStack(alignment: .leading, spacing: 16) {
                inputPanel
                resultPanel
            }
        }
    }

    private var inputPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                InputAssistanceBar(
                    snippets: InputAssistanceSnippet.stringCodec(
                        for: workspace.kind,
                        mode: workspace.mode
                    ),
                    insertAction: insertSnippet
                )

                TextEditor(text: $workspace.input, selection: $inputSelection)
                    .font(.system(.body, design: .monospaced))
                    .focused($focusedField, equals: .input)
                    .accessibilityLabel("文字列変換元")
                    .accessibilityIdentifier("url-input")

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 24)
            }
        } label: {
            Text("変換元")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView([.horizontal, .vertical]) {
                    Text(workspace.output.isEmpty ? "変換結果はここに表示されます。" : workspace.output)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(workspace.output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityIdentifier("url-output")
                }

                HStack {
                    if didCopyResult {
                        Label("コピーしました", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button("結果をコピー", action: copyResult)
                        .disabled(workspace.output.isEmpty)
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        .accessibilityIdentifier("url-copy-result")
                }
                .frame(minHeight: 24)
            }
        } label: {
            Text("変換結果")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusView: some View {
        switch workspace.status {
        case .idle:
            Text("⌘↩︎で変換")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success:
            Label("変換しました", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .accessibilityIdentifier("url-success")
        case .failure(let error):
            Label(error.localizedMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("url-error")
        }
    }

    private func processInput() {
        processAction()
        didCopyResult = false
    }

    private func clearAll() {
        clearAction()
        didCopyResult = false
        focusedField = .input
    }

    private func copyResult() {
        didCopyResult = UserClipboard.write(workspace.output)
    }

    private func insertSnippet(_ snippet: InputAssistanceSnippet) {
        TextInputAssistance.insert(
            snippet,
            into: &workspace.input,
            selection: &inputSelection
        )
        didCopyResult = false
        focusedField = .input
    }

    private var encodeLabel: String {
        switch workspace.kind {
        case .url, .base64: return "エンコード"
        case .html, .json: return "エスケープ"
        }
    }

    private var decodeLabel: String {
        switch workspace.kind {
        case .url, .base64: return "デコード"
        case .html, .json: return "アンエスケープ"
        }
    }

    private var helperDescription: String {
        switch workspace.kind {
        case .url:
            return "RFC 3986のURLコンポーネント用です。「+」は空白に変換しません。"
        case .base64:
            return "UTF-8文字列と標準Base64表記を相互変換します。"
        case .html:
            return "HTMLの特殊文字と文字参照を相互変換します。"
        case .json:
            return "JSON文字列の内容を、外側の引用符を付けずにエスケープします。"
        }
    }
}

private extension StringCodecError {
    var localizedMessage: String {
        switch self {
        case .emptyInput:
            return "変換する文字列を入力してください。"
        case .url(let error):
            return error.localizedMessage
        case .invalidBase64:
            return "Base64表記が正しくありません。"
        case .invalidUTF8:
            return "デコード結果をUTF-8文字列として解釈できません。"
        case .invalidHTMLEntity(let position):
            return "HTML文字参照が正しくありません（\(position)文字目）。"
        case .invalidJSONEscape:
            return "JSON文字列のエスケープが正しくありません。"
        }
    }
}

private extension URLCodecError {
    var localizedMessage: String {
        switch self {
        case .emptyInput:
            return "変換する文字列を入力してください。"
        case .invalidPercentEscape(let position):
            return "パーセントエンコードが正しくありません（\(position)文字目）。"
        case .invalidUTF8:
            return "デコード結果をUTF-8文字列として解釈できません。"
        }
    }
}
