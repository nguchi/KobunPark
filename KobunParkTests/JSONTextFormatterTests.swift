//
//  JSONTextFormatterTests.swift
//  KobunParkTests
//

import Foundation
import Testing
@testable import KobunPark

@MainActor
struct JSONTextFormatterTests {
    private let formatter = JSONTextFormatter()

    @Test func formatsObjectWithTwoSpaces() throws {
        let input = #"{"name":"えぬぐち","enabled":true,"items":[1,2]}"#

        let output = try formatter.format(input)

        #expect(output.contains(#"  "name" : "えぬぐち""#))
        #expect(output.contains(#"  "enabled" : true"#))
        #expect(output.contains("    1"))
        try expectEquivalentJSON(input, output)
    }

    @Test func supportsAllJSONRootValueKinds() throws {
        let inputs = [
            #"{"value":null}"#,
            #"[1,2,3]"#,
            #""文字列""#,
            "42",
            "true",
            "null",
        ]

        for input in inputs {
            let output = try formatter.format(input)
            try expectEquivalentJSON(input, output)
        }
    }

    @Test func preservesJapaneseEmojiAndEscapedUnicode() throws {
        let input = #"{"日本語":"こんにちは","emoji":"😀","escaped":"\u3042"}"#

        let output = try formatter.format(input)

        #expect(output.contains("日本語"))
        #expect(output.contains("こんにちは"))
        #expect(output.contains("😀"))
        #expect(output.contains("あ"))
        try expectEquivalentJSON(input, output)
    }

    @Test func formatsWithFourSpaces() throws {
        let output = try formatter.format(
            #"{"outer":{"inner":1}}"#,
            indentation: .fourSpaces
        )

        #expect(output.contains(#"    "outer" : {"#))
        #expect(output.contains(#"        "inner" : 1"#))
    }

    @Test func compactsJSON() throws {
        let input = """
        {
          "name": "KobunPark",
          "items": [1, 2]
        }
        """

        let output = try formatter.format(input, mode: .compact)

        #expect(!output.contains("\n"))
        try expectEquivalentJSON(input, output)
    }

    @Test func reportsEmptyInput() {
        #expect(throws: JSONFormattingError.emptyInput) {
            try formatter.format("  \n\t")
        }
    }

    @Test func reportsMalformedJSONWithoutProducingOutput() {
        var workspace = JSONWorkspace()
        workspace.input = """
        {
          "name": "KobunPark",
        }
        """

        workspace.process(using: formatter)

        #expect(workspace.output.isEmpty)
        guard case .invalid(.invalidJSON(_, let line, let column)) = workspace.status else {
            Issue.record("不正なJSONとして扱われませんでした")
            return
        }
        #expect(line != nil)
        #expect(column != nil)
    }

    @Test func rejectsNonstandardJSONAcceptedByPermissiveParsers() {
        let invalidInputs = [
            #"{"value":1,}"#,
            #"[1,2,]"#,
            #"{"value":01}"#,
            #"{"value":1.}"#,
        ]

        for input in invalidInputs {
            #expect(throws: JSONFormattingError.self) {
                try formatter.format(input)
            }
        }
    }

    @Test func keepsInputAndRemovesStaleOutputAfterFailure() {
        var workspace = JSONWorkspace()
        workspace.input = #"{"valid":true}"#
        workspace.process(using: formatter)
        #expect(!workspace.output.isEmpty)

        let malformedInput = #"{"valid":}"#
        workspace.input = malformedInput
        workspace.process(using: formatter)

        #expect(workspace.input == malformedInput)
        #expect(workspace.output.isEmpty)
        guard case .invalid = workspace.status else {
            Issue.record("失敗状態が保持されていません")
            return
        }
    }

    @Test func clearAllRemovesContentAndStatusButKeepsFormattingOptions() {
        var workspace = JSONWorkspace()
        workspace.outputMode = .compact
        workspace.indentation = .fourSpaces
        workspace.input = #"{"value":1}"#
        workspace.process(using: formatter)

        workspace.clearAll()

        #expect(workspace.input.isEmpty)
        #expect(workspace.output.isEmpty)
        #expect(workspace.status == .idle)
        #expect(workspace.outputMode == .compact)
        #expect(workspace.indentation == .fourSpaces)
    }

    @Test func handlesLargeArray() throws {
        let input = "[" + Array(repeating: "123", count: 10_000).joined(separator: ",") + "]"

        let output = try formatter.format(input, mode: .compact)

        try expectEquivalentJSON(input, output)
    }

    private func expectEquivalentJSON(
        _ original: String,
        _ formatted: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let originalValue = try JSONSerialization.jsonObject(
            with: Data(original.utf8),
            options: [.fragmentsAllowed]
        )
        let formattedValue = try JSONSerialization.jsonObject(
            with: Data(formatted.utf8),
            options: [.fragmentsAllowed]
        )

        #expect(
            JSONSerialization.isValidJSONObject([originalValue, formattedValue]),
            sourceLocation: sourceLocation
        )
        #expect(
            (originalValue as AnyObject).isEqual(formattedValue),
            sourceLocation: sourceLocation
        )
    }
}
