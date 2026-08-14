//
//  WorkspaceHistoryStoreTests.swift
//  KobunParkTests
//

import Testing
@testable import KobunPark

@MainActor
struct WorkspaceHistoryStoreTests {
    @Test func undoesAndRedoesCoalescedJSONInput() {
        let history = WorkspaceHistoryStore()

        var workspace = history.jsonWorkspace
        workspace.input = "a"
        history.replaceJSONWorkspace(workspace)
        workspace.input = "ab"
        history.replaceJSONWorkspace(workspace)

        #expect(history.canUndo)
        #expect(history.undoActionName == "JSON入力")
        history.undo()
        #expect(history.jsonWorkspace.input.isEmpty)
        #expect(history.canRedo)

        history.redo()
        #expect(history.jsonWorkspace.input == "ab")
    }

    @Test func undoesProcessingSeparatelyFromInput() {
        let history = WorkspaceHistoryStore()
        var workspace = history.jsonWorkspace
        workspace.input = #"{"value":1}"#
        history.replaceJSONWorkspace(workspace)

        history.processJSON()
        #expect(!history.jsonWorkspace.output.isEmpty)
        #expect(history.undoActionName == "JSON処理")

        history.undo()
        #expect(history.jsonWorkspace.input == #"{"value":1}"#)
        #expect(history.jsonWorkspace.output.isEmpty)
        #expect(history.jsonWorkspace.status == .idle)

        history.undo()
        #expect(history.jsonWorkspace.input.isEmpty)

        history.redo()
        history.redo()
        #expect(!history.jsonWorkspace.output.isEmpty)
        #expect(history.jsonWorkspace.status == .valid)
    }

    @Test func restoresWorkspaceAfterClearAll() {
        let history = WorkspaceHistoryStore()
        var workspace = history.urlWorkspace
        workspace.input = "hello world"
        history.replaceURLWorkspace(workspace)
        history.processURL()

        history.clearURL()
        #expect(history.urlWorkspace.input.isEmpty)
        #expect(history.urlWorkspace.output.isEmpty)
        #expect(history.undoActionName == "URL全クリア")

        history.undo()
        #expect(history.urlWorkspace.input == "hello world")
        #expect(history.urlWorkspace.output == "hello%20world")
        #expect(history.urlWorkspace.status == .success)
    }

    @Test func keepsJSONAndURLStateIndependentAcrossHistory() {
        let history = WorkspaceHistoryStore()

        var jsonWorkspace = history.jsonWorkspace
        jsonWorkspace.input = #"{"json":true}"#
        history.replaceJSONWorkspace(jsonWorkspace)
        history.endCoalescing()

        var urlWorkspace = history.urlWorkspace
        urlWorkspace.input = "日本語"
        history.replaceURLWorkspace(urlWorkspace)

        history.undo()
        #expect(history.jsonWorkspace.input == #"{"json":true}"#)
        #expect(history.urlWorkspace.input.isEmpty)

        history.undo()
        #expect(history.jsonWorkspace.input.isEmpty)
    }

    @Test func newEditAfterUndoDiscardsRedoBranch() {
        let history = WorkspaceHistoryStore()
        var workspace = history.jsonWorkspace
        workspace.input = "first"
        history.replaceJSONWorkspace(workspace)
        history.endCoalescing()
        workspace.input = "second"
        history.replaceJSONWorkspace(workspace)

        history.undo()
        #expect(history.jsonWorkspace.input == "first")
        #expect(history.canRedo)

        workspace = history.jsonWorkspace
        workspace.input = "replacement"
        history.replaceJSONWorkspace(workspace)

        #expect(!history.canRedo)
        #expect(history.redoActionName == nil)
    }

    @Test func undoesAndRedoesModeChanges() {
        let history = WorkspaceHistoryStore()
        var workspace = history.urlWorkspace
        workspace.mode = .decode
        history.replaceURLWorkspace(workspace)

        #expect(history.urlWorkspace.mode == .decode)
        #expect(history.undoActionName == "URL設定")
        history.undo()
        #expect(history.urlWorkspace.mode == .encode)
        history.redo()
        #expect(history.urlWorkspace.mode == .decode)
    }

    @Test func limitsRetainedHistory() {
        let history = WorkspaceHistoryStore(capacity: 2)
        var workspace = history.jsonWorkspace

        workspace.input = "one"
        history.replaceJSONWorkspace(workspace)
        history.endCoalescing()
        workspace.input = "two"
        history.replaceJSONWorkspace(workspace)
        history.endCoalescing()
        workspace.input = "three"
        history.replaceJSONWorkspace(workspace)

        history.undo()
        #expect(history.jsonWorkspace.input == "two")
        history.undo()
        #expect(history.jsonWorkspace.input == "one")
        #expect(!history.canUndo)
    }

    @Test func undoesLaTeXPreviewAndClearAsSeparateActions() {
        let history = WorkspaceHistoryStore()
        var workspace = history.latexWorkspace
        workspace.input = "x^2"
        history.replaceLaTeXWorkspace(workspace)

        history.requestLaTeXPreview()
        #expect(history.latexWorkspace.previewRequest?.source == "x^2")
        #expect(history.undoActionName == "LaTeXプレビュー")

        history.clearLaTeX()
        #expect(history.latexWorkspace.input.isEmpty)
        history.undo()
        #expect(history.latexWorkspace.input == "x^2")
        #expect(history.latexWorkspace.previewRequest != nil)

        history.undo()
        #expect(history.latexWorkspace.input == "x^2")
        #expect(history.latexWorkspace.previewRequest == nil)
    }

    @Test func ignoresStaleLaTeXCompletion() throws {
        let history = WorkspaceHistoryStore()
        var workspace = history.latexWorkspace
        workspace.input = "x"
        history.replaceLaTeXWorkspace(workspace)
        history.requestLaTeXPreview()
        let revision = try #require(history.latexWorkspace.previewRequest?.revision)

        workspace = history.latexWorkspace
        workspace.input = "y"
        history.replaceLaTeXWorkspace(workspace)
        history.requestLaTeXPreview()
        history.completeLaTeXPreview(.success, revision: revision)

        #expect(history.latexWorkspace.status == .rendering)
    }

    @Test func processesAndRestoresRegularExpressionResult() async {
        let history = WorkspaceHistoryStore()
        var workspace = history.regularExpressionWorkspace
        workspace.pattern = "日本."
        workspace.target = "日本語と日本庭"
        history.replaceRegularExpressionWorkspace(workspace)

        history.processRegularExpression()
        while history.isRegularExpressionProcessing {
            await Task.yield()
        }

        #expect(history.regularExpressionWorkspace.result?.matches.count == 2)
        #expect(history.undoActionName == "正規表現処理")
        history.undo()
        #expect(history.regularExpressionWorkspace.result == nil)
        #expect(history.regularExpressionWorkspace.target == "日本語と日本庭")
        history.redo()
        #expect(history.regularExpressionWorkspace.result?.matches.count == 2)
    }

    @Test func clearRegularExpressionRetainsOptionsAndIsUndoable() {
        let history = WorkspaceHistoryStore()
        var workspace = history.regularExpressionWorkspace
        workspace.pattern = "kobun"
        workspace.target = "KOBUN"
        workspace.options = .caseInsensitive
        history.replaceRegularExpressionWorkspace(workspace)

        history.clearRegularExpression()
        #expect(history.regularExpressionWorkspace.pattern.isEmpty)
        #expect(history.regularExpressionWorkspace.target.isEmpty)
        #expect(history.regularExpressionWorkspace.options == .caseInsensitive)

        history.undo()
        #expect(history.regularExpressionWorkspace.pattern == "kobun")
        #expect(history.regularExpressionWorkspace.options == .caseInsensitive)
    }

    @Test func inputChangesInvalidateDerivedPreviewsAndUndoRestoresThem() async {
        let history = WorkspaceHistoryStore()

        var regex = history.regularExpressionWorkspace
        regex.pattern = "a"
        regex.target = "banana"
        history.replaceRegularExpressionWorkspace(regex)
        history.processRegularExpression()
        while history.isRegularExpressionProcessing {
            await Task.yield()
        }
        #expect(history.regularExpressionWorkspace.result != nil)

        regex = history.regularExpressionWorkspace
        regex.target = "apple"
        history.replaceRegularExpressionWorkspace(regex)
        #expect(history.regularExpressionWorkspace.result == nil)
        #expect(history.regularExpressionWorkspace.status == .idle)
        history.undo()
        #expect(history.regularExpressionWorkspace.result?.matches.count == 3)

        var latex = history.latexWorkspace
        latex.input = "x"
        history.replaceLaTeXWorkspace(latex)
        history.requestLaTeXPreview()
        #expect(history.latexWorkspace.previewRequest != nil)

        latex = history.latexWorkspace
        latex.input = "y"
        history.replaceLaTeXWorkspace(latex)
        #expect(history.latexWorkspace.previewRequest == nil)
        #expect(history.latexWorkspace.status == .idle)
        history.undo()
        #expect(history.latexWorkspace.previewRequest?.source == "x")
    }

    @Test func undoesCSVConversionSettingsAndClear() {
        let history = WorkspaceHistoryStore()
        var workspace = history.csvWorkspace
        workspace.input = "name,value\nKobunPark,1"
        workspace.outputFormat = .html
        history.replaceCSVWorkspace(workspace)
        history.processCSV()
        #expect(history.csvWorkspace.output.contains("<table>"))

        history.clearCSV()
        #expect(history.csvWorkspace.input.isEmpty)
        #expect(history.undoActionName == "CSV全クリア")
        history.undo()
        #expect(history.csvWorkspace.input == "name,value\nKobunPark,1")
        #expect(history.csvWorkspace.output.contains("<table>"))
        #expect(history.csvWorkspace.outputFormat == .html)
    }

    @Test func undoesStringCodecKindChangesAndResults() {
        let history = WorkspaceHistoryStore()
        var workspace = history.urlWorkspace
        workspace.kind = .base64
        history.replaceURLWorkspace(workspace)
        #expect(history.undoActionName == "文字列設定")

        workspace = history.urlWorkspace
        workspace.input = "KobunPark"
        history.replaceURLWorkspace(workspace)
        history.processURL()
        #expect(history.urlWorkspace.output == "S29idW5QYXJr")

        history.undo()
        #expect(history.urlWorkspace.output.isEmpty)
        #expect(history.urlWorkspace.input == "KobunPark")
        history.undo()
        #expect(history.urlWorkspace.input.isEmpty)
        history.undo()
        #expect(history.urlWorkspace.kind == .url)
    }
}
