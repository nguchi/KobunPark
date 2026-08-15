//
//  RegularExpressionTesterTests.swift
//  KobunParkTests
//

import Foundation
import Testing
@testable import KobunPark

struct RegularExpressionTesterTests {
    private let tester = RegularExpressionTester()

    @Test func findsMatchesAndCaptureGroups() throws {
        let result = try successfulResult(
            pattern: #"([A-Za-z]+)-(\d+)"#,
            target: "item-12 and test-34"
        )

        #expect(result.matches.count == 2)
        #expect(result.matches[0].range == NSRange(location: 0, length: 7))
        #expect(result.matches[0].text == "item-12")
        #expect(result.matches[0].captures == ["item", "12"])
        #expect(result.matches[1].text == "test-34")
    }

    @Test func reportsEmptyAndMalformedPatterns() {
        #expect(evaluate(pattern: "", target: "text") == .failure(.emptyPattern))
        #expect(evaluate(pattern: "[", target: "text") == .failure(.invalidPattern))
    }

    @Test func supportsJapaneseAndUnicodeRanges() throws {
        let result = try successfulResult(pattern: "日本.", target: "abc日本語😀日本庭")

        #expect(result.matches.map(\.text) == ["日本語", "日本庭"])
        #expect(result.matches[0].range == NSRange(location: 3, length: 3))
    }

    @Test func appliesFoundationOptionsIndependently() throws {
        let caseInsensitive = try successfulResult(
            pattern: "kobun",
            target: "KOBUN",
            options: .caseInsensitive
        )
        #expect(caseInsensitive.matches.count == 1)

        let multiline = try successfulResult(
            pattern: "^second$",
            target: "first\nsecond\nthird",
            options: .anchorsMatchLines
        )
        #expect(multiline.matches.map(\.text) == ["second"])

        let dotAll = try successfulResult(
            pattern: "first.*third",
            target: "first\nsecond\nthird",
            options: .dotMatchesLineSeparators
        )
        #expect(dotAll.matches.count == 1)
    }

    @Test func previewsReplacementWithoutChangingTarget() throws {
        let target = "Noguchi, Shingo / Yamada, Taro"
        let result = try successfulResult(
            pattern: #"([A-Za-z]+), ([A-Za-z]+)"#,
            target: target,
            replacement: "$2 $1",
            replacementEnabled: true
        )

        #expect(result.replacementPreview == "Shingo Noguchi / Taro Yamada")
        #expect(target == "Noguchi, Shingo / Yamada, Taro")
    }

    @Test func omitsReplacementPreviewWhenDisabled() throws {
        let result = try successfulResult(
            pattern: "a",
            target: "banana",
            replacement: "A",
            replacementEnabled: false
        )

        #expect(result.replacementPreview == nil)
    }

    @Test func representsUnmatchedCapturesAndZeroLengthMatches() throws {
        let captures = try successfulResult(pattern: #"(a)?(b)"#, target: "b")
        #expect(captures.matches[0].captures == [nil, "b"])

        let zeroLength = try successfulResult(
            pattern: "^",
            target: "一行目\n二行目",
            options: .anchorsMatchLines
        )
        #expect(zeroLength.matches.count == 2)
        #expect(zeroLength.matches.allSatisfy { $0.range.length == 0 })
    }

    @Test func handlesEmptyAndLargerTargets() throws {
        let emptyTarget = try successfulResult(pattern: "x", target: "")
        #expect(emptyTarget.matches.isEmpty)

        let target = String(repeating: "a", count: 10_000) + "終"
        let boundary = try successfulResult(pattern: "終$", target: target)
        #expect(boundary.matches.count == 1)
        #expect(boundary.matches[0].range.location == 10_000)
    }

    private func successfulResult(
        pattern: String,
        target: String,
        replacement: String = "",
        replacementEnabled: Bool = false,
        options: RegularExpressionOptions = []
    ) throws -> RegularExpressionTestResult {
        let outcome = evaluate(
            pattern: pattern,
            target: target,
            replacement: replacement,
            replacementEnabled: replacementEnabled,
            options: options
        )
        guard case .success(let result) = outcome else {
            throw TestFailure.expectedSuccess
        }
        return result
    }

    private func evaluate(
        pattern: String,
        target: String,
        replacement: String = "",
        replacementEnabled: Bool = false,
        options: RegularExpressionOptions = []
    ) -> RegularExpressionOutcome {
        tester.evaluate(
            RegularExpressionRequest(
                pattern: pattern,
                target: target,
                replacement: replacement,
                replacementEnabled: replacementEnabled,
                options: options
            )
        )
    }
}

private enum TestFailure: Error {
    case expectedSuccess
}
