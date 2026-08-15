//
//  LaTeXToolView.swift
//  KobunPark
//

import SwiftUI

struct LaTeXToolView: View {
    @Binding var workspace: LaTeXWorkspace
    let previewAction: () -> Void
    let clearAction: () -> Void
    let completionAction: (LaTeXRenderOutcome, Int) -> Void
    @State private var didCopySource = false
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
            Text("LaTeXプレビュー")
                .font(.title2.bold())
            Text("KaTeXをアプリに同梱し、ネットワーク接続なしで数式を描画します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("表示", selection: $workspace.displayMode) {
                Text("インライン").tag(LaTeXDisplayMode.inline)
                Text("ディスプレイ").tag(LaTeXDisplayMode.display)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .accessibilityIdentifier("latex-display-mode")

            Spacer()

            Button("全クリア", role: .destructive, action: clearAll)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .accessibilityIdentifier("latex-clear-all")

            Button("プレビュー", action: preview)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier("latex-preview")
        }
    }

    private var editorArea: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                inputPanel
                previewPanel
            }
            VStack(alignment: .leading, spacing: 16) {
                inputPanel
                previewPanel
            }
        }
    }

    private var inputPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                InputAssistanceBar(
                    snippets: InputAssistanceSnippet.latex,
                    insertAction: insertSnippet
                )

                TextEditor(text: $workspace.input, selection: $inputSelection)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .accessibilityLabel("LaTeX入力")
                    .accessibilityIdentifier("latex-input")

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 24)

                HStack {
                    if didCopySource {
                        Label("コピーしました", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button("ソースをコピー") {
                        didCopySource = UserClipboard.write(workspace.input)
                    }
                    .disabled(workspace.input.isEmpty)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .accessibilityIdentifier("latex-copy-source")
                }
            }
        } label: {
            Text("LaTeX入力")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPanel: some View {
        GroupBox {
            ZStack {
                LaTeXPreviewView(
                    request: workspace.previewRequest,
                    onOutcome: completionAction
                )

                if workspace.previewRequest == nil {
                    ContentUnavailableView(
                        "プレビューはここに表示されます",
                        systemImage: "function",
                        description: Text("LaTeXを入力してプレビューを実行してください。")
                    )
                    .allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier("latex-preview-area")
        } label: {
            Text("プレビュー")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusView: some View {
        switch workspace.status {
        case .idle:
            Text("⌘↩︎でプレビュー")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .rendering:
            Label("描画中", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success:
            Label("描画しました", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .accessibilityIdentifier("latex-success")
        case .failure(let error):
            Label(error.localizedMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("latex-error")
        }
    }

    private func preview() {
        didCopySource = false
        previewAction()
    }

    private func clearAll() {
        didCopySource = false
        clearAction()
        isInputFocused = true
    }

    private func insertSnippet(_ snippet: InputAssistanceSnippet) {
        TextInputAssistance.insert(
            snippet,
            into: &workspace.input,
            selection: &inputSelection
        )
        didCopySource = false
        isInputFocused = true
    }
}

private extension LaTeXPreviewError {
    var localizedMessage: String {
        switch self {
        case .emptyInput:
            return "LaTeXを入力してください。"
        case .rendering(let message, let position):
            if let position {
                return "描画できません（\(position)文字目）：\(message)"
            }
            return "描画できません：\(message)"
        case .resourceUnavailable:
            return "ローカルのLaTeX描画資産を読み込めません。"
        }
    }
}
