//
//  RegularExpressionTester.swift
//  KobunPark
//

import Foundation

nonisolated struct RegularExpressionOptions: OptionSet, Equatable, Sendable {
    let rawValue: Int

    static let caseInsensitive = Self(rawValue: 1 << 0)
    static let anchorsMatchLines = Self(rawValue: 1 << 1)
    static let dotMatchesLineSeparators = Self(rawValue: 1 << 2)

    fileprivate var foundationOptions: NSRegularExpression.Options {
        var result: NSRegularExpression.Options = []
        if contains(.caseInsensitive) {
            result.insert(.caseInsensitive)
        }
        if contains(.anchorsMatchLines) {
            result.insert(.anchorsMatchLines)
        }
        if contains(.dotMatchesLineSeparators) {
            result.insert(.dotMatchesLineSeparators)
        }
        return result
    }
}

nonisolated struct RegularExpressionRequest: Equatable, Sendable {
    let pattern: String
    let target: String
    let replacement: String
    let replacementEnabled: Bool
    let options: RegularExpressionOptions
}

nonisolated struct RegularExpressionMatch: Equatable, Sendable {
    let range: NSRange
    let text: String
    let captures: [String?]
}

nonisolated struct RegularExpressionTestResult: Equatable, Sendable {
    let matches: [RegularExpressionMatch]
    let replacementPreview: String?
}

nonisolated enum RegularExpressionTestError: Error, Equatable, Sendable {
    case emptyPattern
    case invalidPattern
}

nonisolated enum RegularExpressionOutcome: Equatable, Sendable {
    case success(RegularExpressionTestResult)
    case failure(RegularExpressionTestError)
}

nonisolated struct RegularExpressionTester: Sendable {
    func evaluate(_ request: RegularExpressionRequest) -> RegularExpressionOutcome {
        guard !request.pattern.isEmpty else {
            return .failure(.emptyPattern)
        }

        let expression: NSRegularExpression
        do {
            expression = try NSRegularExpression(
                pattern: request.pattern,
                options: request.options.foundationOptions
            )
        } catch {
            return .failure(.invalidPattern)
        }

        let fullRange = NSRange(
            request.target.startIndex..<request.target.endIndex,
            in: request.target
        )
        let matches = expression.matches(in: request.target, range: fullRange).map { match in
            RegularExpressionMatch(
                range: match.range,
                text: substring(in: request.target, range: match.range) ?? "",
                captures: (1..<match.numberOfRanges).map { index in
                    substring(in: request.target, range: match.range(at: index))
                }
            )
        }

        let replacementPreview: String?
        if request.replacementEnabled {
            replacementPreview = expression.stringByReplacingMatches(
                in: request.target,
                range: fullRange,
                withTemplate: request.replacement
            )
        } else {
            replacementPreview = nil
        }

        return .success(
            RegularExpressionTestResult(
                matches: matches,
                replacementPreview: replacementPreview
            )
        )
    }

    private func substring(in text: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let stringRange = Range(range, in: text) else {
            return nil
        }
        return String(text[stringRange])
    }
}
