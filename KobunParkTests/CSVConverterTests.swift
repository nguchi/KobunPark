//
//  CSVConverterTests.swift
//  KobunParkTests
//

import Foundation
import Testing
@testable import KobunPark

@MainActor
struct CSVConverterTests {
    private let parser = CSVParser()
    private let converter = CSVConverter()

    @Test func parsesQuotedCommaNewlineAndEscapedQuote() throws {
        let input = "name,note\r\n\"山田,花子\",\"1行目\r\n2行目\"\r\nquote,\"say \"\"hello\"\"\""
        let table = try parser.parse(input)

        #expect(table.headers == ["name", "note"])
        #expect(table.rows == [["山田,花子", "1行目\r\n2行目"], ["quote", "say \"hello\""]])
    }

    @Test func convertsToExactMarkdownAndEscapesCells() throws {
        let input = "name,note\nKobunPark,\"a|b\nc\""
        let output = try converter.convert(input, to: .markdown)

        #expect(
            output == """
            | name | note |
            | --- | --- |
            | KobunPark | a\\|b<br>c |
            """
        )
    }

    @Test func convertsToHTMLWithEscapedText() throws {
        let output = try converter.convert(
            "name,value\n<script>,A&B",
            to: .html
        )

        #expect(output.contains("<table>"))
        #expect(output.contains("<th>name</th>"))
        #expect(output.contains("<td>&lt;script&gt;</td>"))
        #expect(output.contains("<td>A&amp;B</td>"))
        #expect(!output.contains("<td><script>"))
    }

    @Test func convertsToWellFormedXMLWithoutUsingHeadersAsElementNames() throws {
        let output = try converter.convert(
            "display name,a&b\n山田,\"<value>\"",
            to: .xml
        )

        #expect(output.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(output.contains("name=\"a&amp;b\""))
        #expect(output.contains("山田"))
        #expect(output.contains("&lt;value&gt;"))
        #expect(XMLParser(data: Data(output.utf8)).parse())
    }

    @Test func preservesEmptyFieldsAndTrailingComma() throws {
        let table = try parser.parse("a,b,c\n1,,")
        #expect(table.rows == [["1", "", ""]])
    }

    @Test func reportsEmptyMalformedAndInconsistentInputs() {
        #expect(throws: CSVConversionError.emptyInput) {
            try parser.parse("")
        }
        #expect(throws: CSVConversionError.unclosedQuotedField(row: 2, column: 2)) {
            try parser.parse("a,b\n1,\"open")
        }
        #expect(throws: CSVConversionError.quoteInUnquotedField(row: 2, column: 1)) {
            try parser.parse("a\nbad\"quote")
        }
        #expect(throws: CSVConversionError.unexpectedCharacterAfterQuote(row: 2, column: 1)) {
            try parser.parse("a\n\"value\"x")
        }
        #expect(throws: CSVConversionError.inconsistentColumnCount(row: 2, expected: 2, actual: 1)) {
            try parser.parse("a,b\n1")
        }
    }

    @Test func supportsJapaneseEmojiHeaderOnlyAndLargeInput() throws {
        let headerOnly = try parser.parse("名前,絵文字")
        #expect(headerOnly.headers == ["名前", "絵文字"])
        #expect(headerOnly.rows.isEmpty)

        let rows = (0..<1_000).map { "\($0),日本語😀" }.joined(separator: "\n")
        let large = try parser.parse("id,value\n" + rows)
        #expect(large.rows.count == 1_000)
        #expect(large.rows.last == ["999", "日本語😀"])
    }

    @Test func workspaceKeepsInputOnFailureAndClearKeepsFormat() {
        var workspace = CSVWorkspace()
        workspace.outputFormat = .xml
        workspace.input = "a,b\n1"
        workspace.process()

        #expect(workspace.input == "a,b\n1")
        #expect(workspace.output.isEmpty)
        #expect(workspace.status == .failure(.inconsistentColumnCount(row: 2, expected: 2, actual: 1)))

        workspace.clearAll()
        #expect(workspace.input.isEmpty)
        #expect(workspace.status == .idle)
        #expect(workspace.outputFormat == .xml)
    }
}
