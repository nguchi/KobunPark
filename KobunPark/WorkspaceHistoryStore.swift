//
//  WorkspaceHistoryStore.swift
//  KobunPark
//

import Combine
import Foundation

@MainActor
final class WorkspaceHistoryStore: ObservableObject {
    @Published private(set) var jsonWorkspace = JSONWorkspace()
    @Published private(set) var urlWorkspace = URLCodecWorkspace()
    @Published private(set) var csvWorkspace = CSVWorkspace()
    @Published private(set) var latexWorkspace = LaTeXWorkspace()
    @Published private(set) var regularExpressionWorkspace = RegularExpressionWorkspace()
    @Published private(set) var isRegularExpressionProcessing = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var undoActionName: String?
    @Published private(set) var redoActionName: String?

    private struct Snapshot: Equatable {
        let jsonWorkspace: JSONWorkspace
        let urlWorkspace: URLCodecWorkspace
        let csvWorkspace: CSVWorkspace
        let latexWorkspace: LaTeXWorkspace
        let regularExpressionWorkspace: RegularExpressionWorkspace
    }

    private struct HistoryEntry {
        let snapshot: Snapshot
        let actionName: String
    }

    private let capacity: Int
    private let coalescingInterval: TimeInterval
    private var undoStack: [HistoryEntry] = []
    private var redoStack: [HistoryEntry] = []
    private var lastCoalescingKey: String?
    private var lastChangeTime: TimeInterval?

    init(capacity: Int = 100, coalescingInterval: TimeInterval = 0.8) {
        self.capacity = max(1, capacity)
        self.coalescingInterval = max(0, coalescingInterval)
    }

    var undoCommandTitle: String {
        undoActionName.map { "取り消す：\($0)" } ?? "取り消す"
    }

    var redoCommandTitle: String {
        redoActionName.map { "やり直す：\($0)" } ?? "やり直す"
    }

    func replaceJSONWorkspace(_ nextWorkspace: JSONWorkspace) {
        guard nextWorkspace != jsonWorkspace else {
            return
        }

        let inputOnlyChange = nextWorkspace.input != jsonWorkspace.input &&
            nextWorkspace.outputMode == jsonWorkspace.outputMode &&
            nextWorkspace.indentation == jsonWorkspace.indentation &&
            nextWorkspace.output == jsonWorkspace.output &&
            nextWorkspace.status == jsonWorkspace.status

        let settingChange = nextWorkspace.outputMode != jsonWorkspace.outputMode ||
            nextWorkspace.indentation != jsonWorkspace.indentation

        commit(
            snapshot(jsonWorkspace: nextWorkspace),
            actionName: inputOnlyChange ? "JSON入力" : (settingChange ? "JSON設定" : "JSON編集"),
            coalescingKey: inputOnlyChange ? "json-input" : nil
        )
    }

    func replaceURLWorkspace(_ proposedWorkspace: URLCodecWorkspace) {
        guard proposedWorkspace != urlWorkspace else {
            return
        }

        let inputOnlyChange = proposedWorkspace.input != urlWorkspace.input &&
            proposedWorkspace.kind == urlWorkspace.kind &&
            proposedWorkspace.mode == urlWorkspace.mode &&
            proposedWorkspace.output == urlWorkspace.output &&
            proposedWorkspace.status == urlWorkspace.status

        let settingChange = proposedWorkspace.kind != urlWorkspace.kind ||
            proposedWorkspace.mode != urlWorkspace.mode
        let toolName = proposedWorkspace.kind == .url ? "URL" : "文字列"
        var nextWorkspace = proposedWorkspace
        if proposedWorkspace.input != urlWorkspace.input || settingChange {
            nextWorkspace.invalidateResult()
        }

        commit(
            snapshot(urlWorkspace: nextWorkspace),
            actionName: inputOnlyChange ? "\(toolName)入力" : (settingChange ? "\(toolName)設定" : "\(toolName)編集"),
            coalescingKey: inputOnlyChange ? "url-input" : nil
        )
    }

    func replaceCSVWorkspace(_ proposedWorkspace: CSVWorkspace) {
        guard proposedWorkspace != csvWorkspace else {
            return
        }

        let inputOnlyChange = proposedWorkspace.input != csvWorkspace.input &&
            proposedWorkspace.outputFormat == csvWorkspace.outputFormat &&
            proposedWorkspace.output == csvWorkspace.output &&
            proposedWorkspace.status == csvWorkspace.status
        let settingChange = proposedWorkspace.outputFormat != csvWorkspace.outputFormat
        var nextWorkspace = proposedWorkspace
        if proposedWorkspace.input != csvWorkspace.input || settingChange {
            nextWorkspace.invalidateResult()
        }

        commit(
            snapshot(csvWorkspace: nextWorkspace),
            actionName: inputOnlyChange ? "CSV入力" : (settingChange ? "CSV設定" : "CSV編集"),
            coalescingKey: inputOnlyChange ? "csv-input" : nil
        )
    }

    func replaceLaTeXWorkspace(_ proposedWorkspace: LaTeXWorkspace) {
        guard proposedWorkspace != latexWorkspace else {
            return
        }

        let inputOnlyChange = proposedWorkspace.input != latexWorkspace.input &&
            proposedWorkspace.displayMode == latexWorkspace.displayMode &&
            proposedWorkspace.previewRequest == latexWorkspace.previewRequest &&
            proposedWorkspace.status == latexWorkspace.status
        let settingChange = proposedWorkspace.displayMode != latexWorkspace.displayMode
        var nextWorkspace = proposedWorkspace
        if proposedWorkspace.input != latexWorkspace.input || settingChange {
            nextWorkspace.invalidatePreview()
        }

        commit(
            snapshot(latexWorkspace: nextWorkspace),
            actionName: inputOnlyChange ? "LaTeX入力" : (settingChange ? "LaTeX設定" : "LaTeX編集"),
            coalescingKey: inputOnlyChange ? "latex-input" : nil
        )
    }

    func replaceRegularExpressionWorkspace(_ proposedWorkspace: RegularExpressionWorkspace) {
        guard proposedWorkspace != regularExpressionWorkspace else {
            return
        }

        let inputOnlyChange = (
            proposedWorkspace.pattern != regularExpressionWorkspace.pattern ||
                proposedWorkspace.target != regularExpressionWorkspace.target ||
                proposedWorkspace.replacement != regularExpressionWorkspace.replacement
        ) && proposedWorkspace.replacementEnabled == regularExpressionWorkspace.replacementEnabled &&
            proposedWorkspace.options == regularExpressionWorkspace.options &&
            proposedWorkspace.result == regularExpressionWorkspace.result &&
            proposedWorkspace.status == regularExpressionWorkspace.status
        let settingChange = proposedWorkspace.replacementEnabled != regularExpressionWorkspace.replacementEnabled ||
            proposedWorkspace.options != regularExpressionWorkspace.options
        var nextWorkspace = proposedWorkspace
        if proposedWorkspace.request != regularExpressionWorkspace.request {
            nextWorkspace.invalidateResult()
        }

        commit(
            snapshot(regularExpressionWorkspace: nextWorkspace),
            actionName: inputOnlyChange ? "正規表現入力" : (settingChange ? "正規表現設定" : "正規表現編集"),
            coalescingKey: inputOnlyChange ? "regex-input" : nil
        )
    }

    func processJSON() {
        var nextWorkspace = jsonWorkspace
        nextWorkspace.process()
        commit(
            snapshot(jsonWorkspace: nextWorkspace),
            actionName: "JSON処理"
        )
    }

    func clearJSON() {
        var nextWorkspace = jsonWorkspace
        nextWorkspace.clearAll()
        commit(
            snapshot(jsonWorkspace: nextWorkspace),
            actionName: "JSON全クリア"
        )
    }

    func processURL() {
        var nextWorkspace = urlWorkspace
        nextWorkspace.process()
        commit(
            snapshot(urlWorkspace: nextWorkspace),
            actionName: "URL処理"
        )
    }

    func clearURL() {
        var nextWorkspace = urlWorkspace
        nextWorkspace.clearAll()
        commit(
            snapshot(urlWorkspace: nextWorkspace),
            actionName: "URL全クリア"
        )
    }

    func processCSV() {
        var nextWorkspace = csvWorkspace
        nextWorkspace.process()
        commit(
            snapshot(csvWorkspace: nextWorkspace),
            actionName: "CSV処理"
        )
    }

    func clearCSV() {
        var nextWorkspace = csvWorkspace
        nextWorkspace.clearAll()
        commit(
            snapshot(csvWorkspace: nextWorkspace),
            actionName: "CSV全クリア"
        )
    }

    func requestLaTeXPreview() {
        var nextWorkspace = latexWorkspace
        nextWorkspace.requestPreview()
        commit(
            snapshot(latexWorkspace: nextWorkspace),
            actionName: "LaTeXプレビュー"
        )
    }

    func completeLaTeXPreview(_ outcome: LaTeXRenderOutcome, revision: Int) {
        var nextWorkspace = latexWorkspace
        nextWorkspace.completePreview(outcome, revision: revision)
        guard nextWorkspace != latexWorkspace else {
            return
        }

        latexWorkspace = nextWorkspace
    }

    func clearLaTeX() {
        var nextWorkspace = latexWorkspace
        nextWorkspace.clearAll()
        commit(
            snapshot(latexWorkspace: nextWorkspace),
            actionName: "LaTeX全クリア"
        )
    }

    func processRegularExpression() {
        guard !isRegularExpressionProcessing else {
            return
        }

        let request = regularExpressionWorkspace.request
        isRegularExpressionProcessing = true

        Task { [weak self] in
            let outcome = await Task.detached(priority: .userInitiated) {
                RegularExpressionTester().evaluate(request)
            }.value

            guard let self else {
                return
            }
            self.isRegularExpressionProcessing = false
            guard self.regularExpressionWorkspace.request == request else {
                return
            }

            var nextWorkspace = self.regularExpressionWorkspace
            nextWorkspace.apply(outcome)
            self.commit(
                self.snapshot(regularExpressionWorkspace: nextWorkspace),
                actionName: "正規表現処理"
            )
        }
    }

    func clearRegularExpression() {
        var nextWorkspace = regularExpressionWorkspace
        nextWorkspace.clearAll()
        commit(
            snapshot(regularExpressionWorkspace: nextWorkspace),
            actionName: "正規表現全クリア"
        )
    }

    func undo() {
        guard let entry = undoStack.popLast() else {
            return
        }

        redoStack.append(
            HistoryEntry(snapshot: currentSnapshot, actionName: entry.actionName)
        )
        apply(entry.snapshot)
        endCoalescing()
        refreshAvailability()
    }

    func redo() {
        guard let entry = redoStack.popLast() else {
            return
        }

        undoStack.append(
            HistoryEntry(snapshot: currentSnapshot, actionName: entry.actionName)
        )
        trimUndoStackIfNeeded()
        apply(entry.snapshot)
        endCoalescing()
        refreshAvailability()
    }

    func endCoalescing() {
        lastCoalescingKey = nil
        lastChangeTime = nil
    }

    private var currentSnapshot: Snapshot {
        snapshot()
    }

    private func snapshot(
        jsonWorkspace: JSONWorkspace? = nil,
        urlWorkspace: URLCodecWorkspace? = nil,
        csvWorkspace: CSVWorkspace? = nil,
        latexWorkspace: LaTeXWorkspace? = nil,
        regularExpressionWorkspace: RegularExpressionWorkspace? = nil
    ) -> Snapshot {
        Snapshot(
            jsonWorkspace: jsonWorkspace ?? self.jsonWorkspace,
            urlWorkspace: urlWorkspace ?? self.urlWorkspace,
            csvWorkspace: csvWorkspace ?? self.csvWorkspace,
            latexWorkspace: latexWorkspace ?? self.latexWorkspace,
            regularExpressionWorkspace: regularExpressionWorkspace ?? self.regularExpressionWorkspace
        )
    }

    private func commit(
        _ nextSnapshot: Snapshot,
        actionName: String,
        coalescingKey: String? = nil
    ) {
        let currentSnapshot = currentSnapshot
        guard nextSnapshot != currentSnapshot else {
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        let shouldCoalesce = coalescingKey != nil &&
            coalescingKey == lastCoalescingKey &&
            lastChangeTime.map { now - $0 <= coalescingInterval } == true &&
            !undoStack.isEmpty

        if !shouldCoalesce {
            undoStack.append(
                HistoryEntry(snapshot: currentSnapshot, actionName: actionName)
            )
            trimUndoStackIfNeeded()
        }

        redoStack.removeAll()
        apply(nextSnapshot)
        lastCoalescingKey = coalescingKey
        lastChangeTime = coalescingKey == nil ? nil : now
        refreshAvailability()
    }

    private func apply(_ snapshot: Snapshot) {
        jsonWorkspace = snapshot.jsonWorkspace
        urlWorkspace = snapshot.urlWorkspace
        csvWorkspace = snapshot.csvWorkspace
        latexWorkspace = snapshot.latexWorkspace
        regularExpressionWorkspace = snapshot.regularExpressionWorkspace
    }

    private func trimUndoStackIfNeeded() {
        let overflow = undoStack.count - capacity
        if overflow > 0 {
            undoStack.removeFirst(overflow)
        }
    }

    private func refreshAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoActionName = undoStack.last?.actionName
        redoActionName = redoStack.last?.actionName
    }
}
