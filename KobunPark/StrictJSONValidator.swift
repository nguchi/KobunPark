//
//  StrictJSONValidator.swift
//  KobunPark
//

import Foundation

/// FoundationのJSONパーサーが受理する拡張構文を、標準JSONとして出力する前に除外する。
nonisolated struct StrictJSONValidator: Sendable {
    func validate(_ input: String) throws {
        var parser = Parser(input: input)
        try parser.validateDocument()
    }
}

private nonisolated struct Parser {
    private let bytes: [UInt8]
    private var index = 0

    init(input: String) {
        bytes = Array(input.utf8)
    }

    mutating func validateDocument() throws {
        skipWhitespace()
        try parseValue()
        skipWhitespace()

        guard isAtEnd else {
            throw syntaxError(.unexpectedCharacter)
        }
    }

    private mutating func parseValue() throws {
        guard let byte = currentByte else {
            throw syntaxError(.unexpectedEnd)
        }

        switch byte {
        case ascii("{"):
            try parseObject()
        case ascii("["):
            try parseArray()
        case ascii("\""):
            try parseString()
        case ascii("t"):
            try parseLiteral("true")
        case ascii("f"):
            try parseLiteral("false")
        case ascii("n"):
            try parseLiteral("null")
        case ascii("-"), ascii("0")...ascii("9"):
            try parseNumber()
        default:
            throw syntaxError(.unexpectedCharacter)
        }
    }

    private mutating func parseObject() throws {
        advance()
        skipWhitespace()
        if consume(ascii("}")) {
            return
        }

        while true {
            guard currentByte == ascii("\"") else {
                throw syntaxError(currentByte == nil ? .unexpectedEnd : .unexpectedCharacter)
            }
            try parseString()
            skipWhitespace()
            try expect(ascii(":"))
            skipWhitespace()
            try parseValue()
            skipWhitespace()

            if consume(ascii("}")) {
                return
            }
            try expect(ascii(","))
            skipWhitespace()

            if currentByte == ascii("}") {
                throw syntaxError(.unexpectedCharacter)
            }
        }
    }

    private mutating func parseArray() throws {
        advance()
        skipWhitespace()
        if consume(ascii("]")) {
            return
        }

        while true {
            try parseValue()
            skipWhitespace()

            if consume(ascii("]")) {
                return
            }
            try expect(ascii(","))
            skipWhitespace()

            if currentByte == ascii("]") {
                throw syntaxError(.unexpectedCharacter)
            }
        }
    }

    private mutating func parseString() throws {
        advance()

        while let byte = currentByte {
            switch byte {
            case ascii("\""):
                advance()
                return
            case ascii("\\"):
                try parseEscapeSequence()
            case 0x00...0x1F:
                throw syntaxError(.unexpectedCharacter)
            default:
                advance()
            }
        }

        throw syntaxError(.unexpectedEnd)
    }

    private mutating func parseEscapeSequence() throws {
        advance()
        guard let escapedByte = currentByte else {
            throw syntaxError(.unexpectedEnd)
        }

        switch escapedByte {
        case ascii("\""), ascii("\\"), ascii("/"), ascii("b"), ascii("f"),
             ascii("n"), ascii("r"), ascii("t"):
            advance()
        case ascii("u"):
            advance()
            for _ in 0..<4 {
                guard let byte = currentByte else {
                    throw syntaxError(.unexpectedEnd)
                }
                guard isHexDigit(byte) else {
                    throw syntaxError(.invalidEscape)
                }
                advance()
            }
        default:
            throw syntaxError(.invalidEscape)
        }
    }

    private mutating func parseLiteral(_ literal: String) throws {
        for expectedByte in literal.utf8 {
            guard let byte = currentByte else {
                throw syntaxError(.unexpectedEnd)
            }
            guard byte == expectedByte else {
                throw syntaxError(.unexpectedCharacter)
            }
            advance()
        }
    }

    private mutating func parseNumber() throws {
        if consume(ascii("-")), currentByte == nil {
            throw syntaxError(.unexpectedEnd)
        }

        if consume(ascii("0")) {
            if let byte = currentByte, isDigit(byte) {
                throw syntaxError(.invalidNumber)
            }
        } else {
            guard let byte = currentByte, byte >= ascii("1"), byte <= ascii("9") else {
                throw syntaxError(.invalidNumber)
            }
            advance()
            consumeDigits()
        }

        if consume(ascii(".")) {
            guard let byte = currentByte, isDigit(byte) else {
                throw syntaxError(currentByte == nil ? .unexpectedEnd : .invalidNumber)
            }
            consumeDigits()
        }

        let hasExponent: Bool
        if consume(ascii("e")) {
            hasExponent = true
        } else {
            hasExponent = consume(ascii("E"))
        }

        if hasExponent {
            if !consume(ascii("+")) {
                _ = consume(ascii("-"))
            }
            guard let byte = currentByte, isDigit(byte) else {
                throw syntaxError(currentByte == nil ? .unexpectedEnd : .invalidNumber)
            }
            consumeDigits()
        }
    }

    private mutating func consumeDigits() {
        while let byte = currentByte, isDigit(byte) {
            advance()
        }
    }

    private mutating func expect(_ byte: UInt8) throws {
        guard let currentByte else {
            throw syntaxError(.unexpectedEnd)
        }
        guard currentByte == byte else {
            throw syntaxError(.unexpectedCharacter)
        }
        advance()
    }

    private mutating func skipWhitespace() {
        while let byte = currentByte,
              byte == ascii(" ") || byte == ascii("\t") ||
              byte == ascii("\n") || byte == ascii("\r") {
            advance()
        }
    }

    private var currentByte: UInt8? {
        isAtEnd ? nil : bytes[index]
    }

    private var isAtEnd: Bool {
        index >= bytes.count
    }

    private mutating func advance() {
        index += 1
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard currentByte == byte else {
            return false
        }
        advance()
        return true
    }

    private func syntaxError(_ issue: JSONSyntaxIssue) -> JSONFormattingError {
        let safeIndex = min(index, bytes.count)
        let prefix = String(decoding: bytes.prefix(safeIndex), as: UTF8.self)
        let lines = prefix.components(separatedBy: "\n")
        return .invalidJSON(
            issue: issue,
            line: lines.count,
            column: (lines.last?.count ?? 0) + 1
        )
    }

    private func ascii(_ character: Character) -> UInt8 {
        character.asciiValue ?? 0
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= ascii("0") && byte <= ascii("9")
    }

    private func isHexDigit(_ byte: UInt8) -> Bool {
        isDigit(byte) ||
            (byte >= ascii("a") && byte <= ascii("f")) ||
            (byte >= ascii("A") && byte <= ascii("F"))
    }
}
