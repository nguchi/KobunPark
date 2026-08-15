//
//  JSONToolView.swift
//  KobunPark
//

import SwiftUI

struct JSONToolView: View {
    @Binding var workspace: JSONWorkspace
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
            Text("JSON整形・検証")
                .font(.title2.bold())
            Text("入力内容は保存せず、このMac内で処理します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("出力", selection: $workspace.outputMode) {
                Text("整形").tag(JSONOutputMode.formatted)
                Text("圧縮").tag(JSONOutputMode.compact)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .accessibilityIdentifier("json-output-mode")

            Picker("インデント", selection: $workspace.indentation) {
                Text("2スペース").tag(JSONIndentation.twoSpaces)
                Text("4スペース").tag(JSONIndentation.fourSpaces)
            }
            .frame(width: 150)
            .disabled(workspace.outputMode == .compact)
            .accessibilityIdentifier("json-indentation")

            Spacer()

            Button("全クリア", role: .destructive, action: clearAll)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .accessibilityIdentifier("json-clear-all")

            Button("実行", action: processInput)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier("json-run")
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
                    snippets: InputAssistanceSnippet.json,
                    insertAction: insertSnippet
                )

                TextEditor(text: $workspace.input, selection: $inputSelection)
                    .font(.system(.body, design: .monospaced))
                    .focused($focusedField, equals: .input)
                    .accessibilityLabel("JSON入力")
                    .accessibilityIdentifier("json-input")

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 24)
            }
        } label: {
            Text("入力")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView([.horizontal, .vertical]) {
                    Text(workspace.output.isEmpty ? "結果はここに表示されます。" : workspace.output)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(workspace.output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityIdentifier("json-output")
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
                        .accessibilityIdentifier("json-copy-result")
                }
                .frame(minHeight: 24)
            }
        } label: {
            Text("結果")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusView: some View {
        switch workspace.status {
        case .idle:
            Text("⌘↩︎で整形・検証")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .valid:
            Label("有効なJSONです", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .accessibilityIdentifier("json-valid")
        case .invalid(let error):
            Label(error.localizedMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("json-error")
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
}

private extension JSONFormattingError {
    var localizedMessage: String {
        switch self {
        case .emptyInput:
            return "JSONを入力してください。"
        case .invalidJSON(let issue, let line, let column):
            let reason = switch issue {
            case .unexpectedEnd:
                "JSONが途中で終了しています。"
            case .unexpectedCharacter:
                "JSON内に予期しない文字があります。"
            case .invalidEscape:
                "文字列のエスケープが正しくありません。"
            case .invalidNumber:
                "数値の形式が正しくありません。"
            case .invalidSyntax:
                "JSON構文が正しくありません。"
            }

            if let line, let column {
                return "\(reason)（\(line)行、\(column)列）"
            }
            if let line {
                return "\(reason)（\(line)行）"
            }
            return reason
        }
    }
}
