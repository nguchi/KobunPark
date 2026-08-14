//
//  JSONTextFormatter.swift
//  KobunPark
//

import Foundation

nonisolated enum JSONOutputMode: String, CaseIterable, Identifiable, Sendable {
    case formatted
    case compact

    var id: String { rawValue }
}

nonisolated enum JSONIndentation: Int, CaseIterable, Identifiable, Sendable {
    case twoSpaces = 2
    case fourSpaces = 4

    var id: Int { rawValue }
}

nonisolated enum JSONSyntaxIssue: Equatable, Sendable {
    case unexpectedEnd
    case unexpectedCharacter
    case invalidEscape
    case invalidNumber
    case invalidSyntax
}

nonisolated enum JSONFormattingError: Error, Equatable, Sendable {
    case emptyInput
    case invalidJSON(issue: JSONSyntaxIssue, line: Int?, column: Int?)
}

nonisolated struct JSONTextFormatter: Sendable {
    func format(
        _ input: String,
        mode: JSONOutputMode = .formatted,
        indentation: JSONIndentation = .twoSpaces
    ) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JSONFormattingError.emptyInput
        }

        try StrictJSONValidator().validate(input)

        let value: Any
        do {
            value = try JSONSerialization.jsonObject(
                with: Data(input.utf8),
                options: [.fragmentsAllowed]
            )
        } catch {
            throw Self.formattingError(from: error, input: input)
        }

        var writingOptions: JSONSerialization.WritingOptions = [
            .fragmentsAllowed,
            .withoutEscapingSlashes,
        ]
        if mode == .formatted {
            writingOptions.insert(.prettyPrinted)
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: writingOptions)
            guard let output = String(data: data, encoding: .utf8) else {
                throw JSONFormattingError.invalidJSON(
                    issue: .invalidSyntax,
                    line: nil,
                    column: nil
                )
            }

            guard mode == .formatted, indentation == .fourSpaces else {
                return output
            }
            return Self.expandIndentation(in: output)
        } catch let error as JSONFormattingError {
            throw error
        } catch {
            throw JSONFormattingError.invalidJSON(
                issue: .invalidSyntax,
                line: nil,
                column: nil
            )
        }
    }

    private static func expandIndentation(in text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in
                let spaceCount = line.prefix(while: { $0 == " " }).count
                return String(repeating: " ", count: spaceCount * 2) + line.dropFirst(spaceCount)
            }
            .joined(separator: "\n")
    }

    private static func formattingError(
        from error: Error,
        input: String
    ) -> JSONFormattingError {
        let debugDescription = (error as NSError).userInfo["NSDebugDescription"] as? String ?? ""
        let lowercaseDescription = debugDescription.lowercased()
        let issue: JSONSyntaxIssue

        if lowercaseDescription.contains("unexpected end") ||
            lowercaseDescription.contains("end of file") {
            issue = .unexpectedEnd
        } else if lowercaseDescription.contains("unexpected character") {
            issue = .unexpectedCharacter
        } else if lowercaseDescription.contains("escape") {
            issue = .invalidEscape
        } else if lowercaseDescription.contains("number") {
            issue = .invalidNumber
        } else {
            issue = .invalidSyntax
        }

        let location = sourceLocation(from: debugDescription, input: input)
        return .invalidJSON(issue: issue, line: location.line, column: location.column)
    }

    private static func sourceLocation(
        from description: String,
        input: String
    ) -> (line: Int?, column: Int?) {
        if let captures = captures(
            in: description,
            pattern: #"line ([0-9]+), column ([0-9]+)"#
        ), captures.count == 2 {
            return (Int(captures[0]), Int(captures[1]))
        }

        if let captures = captures(
            in: description,
            pattern: #"character ([0-9]+)"#
        ), let offset = captures.first.flatMap(Int.init) {
            return location(atUTF8Offset: offset, in: input)
        }

        return (nil, nil)
    }

    private static func captures(
        in text: String,
        pattern: String
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range) else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private static func location(
        atUTF8Offset offset: Int,
        in input: String
    ) -> (line: Int?, column: Int?) {
        let bytes = Array(input.utf8.prefix(max(0, offset)))
        let line = bytes.reduce(into: 1) { result, byte in
            if byte == 0x0A {
                result += 1
            }
        }
        let lastLineBreak = bytes.lastIndex(of: 0x0A)
        let column = bytes.count - (lastLineBreak ?? -1)
        return (line, max(1, column))
    }
}
