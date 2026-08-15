//
//  CSVToolView.swift
//  KobunPark
//

import SwiftUI

struct CSVToolView: View {
    @Binding var workspace: CSVWorkspace
    let processAction: () -> Void
    let clearAction: () -> Void
    @State private var didCopyResult = false
    @State private var inputSelection: TextSelection?
    @FocusState private var isInputFocused: Bool

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
            Text("CSV変換")
                .font(.title2.bold())
            Text("先頭行をヘッダーとし、Markdown表、HTML表、XMLへローカル変換します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("変換先", selection: $workspace.outputFormat) {
                Text("Markdown表").tag(CSVOutputFormat.markdown)
                Text("HTML表").tag(CSVOutputFormat.html)
                Text("XML").tag(CSVOutputFormat.xml)
            }
            .pickerStyle(.segmented)
            .frame(width: 330)
            .accessibilityIdentifier("csv-output-format")

            Spacer()

            Button("全クリア", role: .destructive, action: clearAll)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .accessibilityIdentifier("csv-clear-all")

            Button("変換", action: process)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier("csv-run")
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
                    snippets: InputAssistanceSnippet.csv,
                    insertAction: insertSnippet
                )

                TextEditor(text: $workspace.input, selection: $inputSelection)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .accessibilityLabel("CSV入力")
                    .accessibilityIdentifier("csv-input")

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 24)
            }
        } label: {
            Text("CSV入力")
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
                        .accessibilityIdentifier("csv-output")
                }

                HStack {
                    if didCopyResult {
                        Label("コピーしました", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button("結果をコピー") {
                        didCopyResult = UserClipboard.write(workspace.output)
                    }
                    .disabled(workspace.output.isEmpty)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .accessibilityIdentifier("csv-copy-result")
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
                .accessibilityIdentifier("csv-success")
        case .failure(let error):
            Label(error.localizedMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("csv-error")
        }
    }

    private func process() {
        didCopyResult = false
        processAction()
    }

    private func clearAll() {
        didCopyResult = false
        clearAction()
        isInputFocused = true
    }

    private func insertSnippet(_ snippet: InputAssistanceSnippet) {
        TextInputAssistance.insert(
            snippet,
            into: &workspace.input,
            selection: &inputSelection
        )
        didCopyResult = false
        isInputFocused = true
    }
}

private extension CSVConversionError {
    var localizedMessage: String {
        switch self {
        case .emptyInput:
            return "CSVを入力してください。"
        case .unclosedQuotedField(let row, let column):
            return "\(row)行\(column)列の引用符が閉じられていません。"
        case .quoteInUnquotedField(let row, let column):
            return "\(row)行\(column)列の引用符の位置が正しくありません。"
        case .unexpectedCharacterAfterQuote(let row, let column):
            return "\(row)行\(column)列の閉じ引用符の後ろに予期しない文字があります。"
        case .inconsistentColumnCount(let row, let expected, let actual):
            return "\(row)行目は\(actual)列です。ヘッダーの\(expected)列に合わせてください。"
        }
    }
}
