//
//  ContentView.swift
//  KobunPark
import SwiftUI

private enum WorkspaceTool: String, CaseIterable, Identifiable {
    case json
    case urlCodec
    case csv
    case latex
    case regularExpression

    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject var history: WorkspaceHistoryStore
    @State private var selectedTool: WorkspaceTool = .json

    var body: some View {
        VStack(spacing: 0) {
            toolPicker
            Divider()

            switch selectedTool {
            case .json:
                JSONToolView(
                    workspace: Binding(
                        get: { history.jsonWorkspace },
                        set: history.replaceJSONWorkspace
                    ),
                    processAction: history.processJSON,
                    clearAction: history.clearJSON
                )
            case .urlCodec:
                URLCodecView(
                    workspace: Binding(
                        get: { history.urlWorkspace },
                        set: history.replaceURLWorkspace
                    ),
                    processAction: history.processURL,
                    clearAction: history.clearURL
                )
            case .csv:
                CSVToolView(
                    workspace: Binding(
                        get: { history.csvWorkspace },
                        set: history.replaceCSVWorkspace
                    ),
                    processAction: history.processCSV,
                    clearAction: history.clearCSV
                )
            case .latex:
                LaTeXToolView(
                    workspace: Binding(
                        get: { history.latexWorkspace },
                        set: history.replaceLaTeXWorkspace
                    ),
                    previewAction: history.requestLaTeXPreview,
                    clearAction: history.clearLaTeX,
                    completionAction: { outcome, revision in
                        history.completeLaTeXPreview(outcome, revision: revision)
                    }
                )
            case .regularExpression:
                RegularExpressionToolView(
                    workspace: Binding(
                        get: { history.regularExpressionWorkspace },
                        set: history.replaceRegularExpressionWorkspace
                    ),
                    isProcessing: history.isRegularExpressionProcessing,
                    processAction: history.processRegularExpression,
                    clearAction: history.clearRegularExpression
                )
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .onChange(of: selectedTool) {
            history.endCoalescing()
        }
    }

    private var toolPicker: some View {
        HStack(spacing: 16) {
            Text("KobunPark")
                .font(.headline)

            Picker("機能", selection: $selectedTool) {
                Text("JSON").tag(WorkspaceTool.json)
                Text("文字列").tag(WorkspaceTool.urlCodec)
                Text("CSV").tag(WorkspaceTool.csv)
                Text("LaTeX").tag(WorkspaceTool.latex)
                Text("正規表現").tag(WorkspaceTool.regularExpression)
            }
            .pickerStyle(.segmented)
            .frame(width: 520)
            .accessibilityIdentifier("tool-picker")

            Spacer()

            Button(action: history.undo) {
                Label("取り消す", systemImage: "arrow.uturn.backward")
            }
            .labelStyle(.iconOnly)
            .disabled(!history.canUndo)
            .help(history.undoCommandTitle)
            .accessibilityIdentifier("undo")

            Button(action: history.redo) {
                Label("やり直す", systemImage: "arrow.uturn.forward")
            }
            .labelStyle(.iconOnly)
            .disabled(!history.canRedo)
            .help(history.redoCommandTitle)
            .accessibilityIdentifier("redo")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    ContentView(history: WorkspaceHistoryStore())
}
