//
//  RegularExpressionToolView.swift
//  KobunPark
//

import SwiftUI

struct RegularExpressionToolView: View {
    @Binding var workspace: RegularExpressionWorkspace
    let isProcessing: Bool
    let processAction: () -> Void
    let clearAction: () -> Void
    @State private var didCopyResult = false
    @State private var patternSelection: TextSelection?
    @FocusState private var isPatternFocused: Bool

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
            Text("正規表現テスト")
                .font(.title2.bold())
            Text("一致箇所と置換結果を、元の対象文字列を変更せずに確認します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Toggle("大文字・小文字を無視", isOn: optionBinding(.caseInsensitive))
            Toggle("^／$を行単位", isOn: optionBinding(.anchorsMatchLines))
            Toggle(".に改行を含む", isOn: optionBinding(.dotMatchesLineSeparators))

            Spacer()

            Button("全クリア", role: .destructive, action: clearAll)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .accessibilityIdentifier("regex-clear-all")

            Button(action: process) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("実行")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isProcessing)
            .accessibilityIdentifier("regex-run")
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
            VStack(alignment: .leading, spacing: 10) {
                InputAssistanceBar(
                    snippets: InputAssistanceSnippet.regularExpression,
                    insertAction: insertPatternSnippet
                )

                TextField(
                    "例：([A-Za-z]+)",
                    text: $workspace.pattern,
                    selection: $patternSelection
                )
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .focused($isPatternFocused)
                    .accessibilityLabel("正規表現パターン")
                    .accessibilityIdentifier("regex-pattern")

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 22)

                Text("対象文字列")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $workspace.target)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("正規表現の対象文字列")
                    .accessibilityIdentifier("regex-target")

                Toggle("置換結果をプレビュー", isOn: $workspace.replacementEnabled)
                    .accessibilityIdentifier("regex-replacement-enabled")
                TextField("置換文字列（例：$1）", text: $workspace.replacement)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!workspace.replacementEnabled)
                    .accessibilityIdentifier("regex-replacement")
            }
        } label: {
            Text("入力")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let result = workspace.result {
                    Label("一致：\(result.matches.count)件", systemImage: "text.magnifyingglass")
                        .font(.headline)
                        .accessibilityIdentifier("regex-match-count")

                    ScrollView([.horizontal, .vertical]) {
                        highlightedTarget(result: result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)

                    if let replacementPreview = result.replacementPreview {
                        Divider()
                        HStack {
                            Text("置換プレビュー")
                                .font(.headline)
                            Spacer()
                            if didCopyResult {
                                Label("コピーしました", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Button("結果をコピー") {
                                didCopyResult = UserClipboard.write(replacementPreview)
                            }
                            .keyboardShortcut("c", modifiers: [.command, .shift])
                            .accessibilityIdentifier("regex-copy-result")
                        }
                        ScrollView([.horizontal, .vertical]) {
                            Text(replacementPreview)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .accessibilityIdentifier("regex-replacement-preview")
                        }
                        .frame(maxHeight: .infinity)
                    }
                } else {
                    ContentUnavailableView(
                        "結果はここに表示されます",
                        systemImage: "text.magnifyingglass",
                        description: Text("パターンと対象文字列を入力して実行してください。")
                    )
                }
            }
        } label: {
            Text("結果")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusView: some View {
        if isProcessing {
            Label("処理中", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            switch workspace.status {
            case .idle:
                Text("⌘↩︎で一致と置換結果を確認")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .success:
                Label("正規表現を評価しました", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("regex-success")
            case .failure(let error):
                Label(error.localizedMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("regex-error")
            }
        }
    }

    private func optionBinding(_ option: RegularExpressionOptions) -> Binding<Bool> {
        Binding(
            get: { workspace.options.contains(option) },
            set: { isEnabled in
                if isEnabled {
                    workspace.options.insert(option)
                } else {
                    workspace.options.remove(option)
                }
            }
        )
    }

    private func process() {
        didCopyResult = false
        processAction()
    }

    private func clearAll() {
        didCopyResult = false
        clearAction()
        isPatternFocused = true
    }

    private func insertPatternSnippet(_ snippet: InputAssistanceSnippet) {
        TextInputAssistance.insert(
            snippet,
            into: &workspace.pattern,
            selection: &patternSelection
        )
        didCopyResult = false
        isPatternFocused = true
    }

    private func highlightedTarget(result: RegularExpressionTestResult) -> Text {
        let source = workspace.target as NSString
        var rendered = Text("")
        var cursor = 0

        for match in result.matches {
            guard match.range.location >= cursor,
                  NSMaxRange(match.range) <= source.length else {
                continue
            }

            if match.range.location > cursor {
                let unmatched = Text(
                    source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                )
                rendered = Text("\(rendered)\(unmatched)")
            }

            if match.range.length == 0 {
                let marker = Text("▏")
                    .foregroundColor(.accentColor)
                    .bold()
                rendered = Text("\(rendered)\(marker)")
            } else {
                let matched = Text(source.substring(with: match.range))
                    .foregroundColor(.accentColor)
                    .bold()
                rendered = Text("\(rendered)\(matched)")
            }
            cursor = NSMaxRange(match.range)
        }

        if cursor < source.length {
            let remaining = Text(
                source.substring(with: NSRange(location: cursor, length: source.length - cursor))
            )
            rendered = Text("\(rendered)\(remaining)")
        }
        return rendered
    }
}

private extension RegularExpressionTestError {
    var localizedMessage: String {
        switch self {
        case .emptyPattern:
            return "正規表現パターンを入力してください。"
        case .invalidPattern:
            return "正規表現パターンが正しくありません。"
        }
    }
}
