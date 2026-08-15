//
//  TextInputAssistanceTests.swift
//  KobunParkTests
//

import SwiftUI
import Testing
@testable import KobunPark

@MainActor
struct TextInputAssistanceTests {
    @Test func insertsAtTheCurrentInsertionPoint() {
        var text = "ab"
        let insertionPoint = text.index(after: text.startIndex)
        var selection: TextSelection? = TextSelection(insertionPoint: insertionPoint)
        let snippet = InputAssistanceSnippet(
            id: "test",
            label: "X",
            insertion: "X",
            help: "test"
        )

        TextInputAssistance.insert(snippet, into: &text, selection: &selection)

        #expect(text == "aXb")
        #expect(selection?.isInsertion == true)
    }

    @Test func selectsPlaceholderForImmediateReplacement() throws {
        var text = ""
        var selection: TextSelection?
        let snippet = try #require(InputAssistanceSnippet.json.first)

        TextInputAssistance.insert(snippet, into: &text, selection: &selection)

        #expect(text == "{\n  \"key\": \"value\"\n}")
        #expect(selectedText(in: text, selection: selection) == "key")
    }

    @Test func wrapsSelectedUnicodeText() throws {
        var text = "前数式後"
        let range = try #require(text.range(of: "数式"))
        var selection: TextSelection? = TextSelection(range: range)
        let snippet = try #require(
            InputAssistanceSnippet.latex.first { $0.id == "latex-root" }
        )

        TextInputAssistance.insert(snippet, into: &text, selection: &selection)

        #expect(text == #"前\sqrt{数式}後"#)
        #expect(selection?.isInsertion == true)
    }

    @Test func modeSpecificURLButtonsUseRawAndPercentEncodedInputs() {
        let encodeInsertions = InputAssistanceSnippet.url(for: .encode).map(\.prefix)
        let decodeInsertions = InputAssistanceSnippet.url(for: .decode).map(\.prefix)

        #expect(encodeInsertions.contains(" "))
        #expect(decodeInsertions.contains("%20"))
        #expect(!decodeInsertions.contains(" "))
    }

    @Test func snippetIdentifiersAreUniqueWithinEachTool() {
        let groups = [
            InputAssistanceSnippet.csv,
            InputAssistanceSnippet.json,
            InputAssistanceSnippet.latex,
            InputAssistanceSnippet.regularExpression,
            InputAssistanceSnippet.url(for: .encode),
            InputAssistanceSnippet.url(for: .decode),
            InputAssistanceSnippet.stringCodec(for: .base64, mode: .encode),
            InputAssistanceSnippet.stringCodec(for: .base64, mode: .decode),
            InputAssistanceSnippet.stringCodec(for: .html, mode: .encode),
            InputAssistanceSnippet.stringCodec(for: .html, mode: .decode),
            InputAssistanceSnippet.stringCodec(for: .json, mode: .encode),
            InputAssistanceSnippet.stringCodec(for: .json, mode: .decode),
        ]

        for snippets in groups {
            #expect(Set(snippets.map(\.id)).count == snippets.count)
        }
    }

    @Test func allRegularExpressionSnippetsCompile() {
        let tester = RegularExpressionTester()

        for snippet in InputAssistanceSnippet.regularExpression {
            let pattern = snippet.prefix + snippet.placeholder + snippet.suffix
            let outcome = tester.evaluate(
                RegularExpressionRequest(
                    pattern: pattern,
                    target: "abc123漢字",
                    replacement: "",
                    replacementEnabled: false,
                    options: []
                )
            )
            if case .failure = outcome {
                Issue.record("入力補助「\(snippet.label)」の正規表現が無効です。")
            }
        }
    }

    private func selectedText(in text: String, selection: TextSelection?) -> String? {
        guard let selection else {
            return nil
        }
        switch selection.indices {
        case .selection(let range):
            return String(text[range])
        case .multiSelection:
            return nil
        @unknown default:
            return nil
        }
    }
}
