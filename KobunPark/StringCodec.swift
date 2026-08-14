//
//  StringCodec.swift
//  KobunPark
//

import Foundation

nonisolated enum StringCodecKind: String, CaseIterable, Identifiable, Sendable {
    case url
    case base64
    case html
    case json

    var id: String { rawValue }
}

nonisolated enum StringCodecError: Error, Equatable, Sendable {
    case emptyInput
    case url(URLCodecError)
    case invalidBase64
    case invalidUTF8
    case invalidHTMLEntity(position: Int)
    case invalidJSONEscape
}

nonisolated struct StringCodec: Sendable {
    func transform(
        _ input: String,
        kind: StringCodecKind,
        mode: URLCodecMode
    ) throws -> String {
        guard !input.isEmpty else {
            throw StringCodecError.emptyInput
        }

        switch (kind, mode) {
        case (.url, .encode):
            return try transformURL { try $0.encode(input) }
        case (.url, .decode):
            return try transformURL { try $0.decode(input) }
        case (.base64, .encode):
            return Data(input.utf8).base64EncodedString()
        case (.base64, .decode):
            guard let data = Data(base64Encoded: input) else {
                throw StringCodecError.invalidBase64
            }
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw StringCodecError.invalidUTF8
            }
            return decoded
        case (.html, .encode):
            return htmlEscape(input)
        case (.html, .decode):
            return try htmlUnescape(input)
        case (.json, .encode):
            return jsonEscape(input)
        case (.json, .decode):
            return try jsonUnescape(input)
        }
    }

    private func transformURL(
        _ operation: (URLPercentCodec) throws -> String
    ) throws -> String {
        do {
            return try operation(URLPercentCodec())
        } catch let error as URLCodecError {
            throw StringCodecError.url(error)
        }
    }

    private func htmlEscape(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func htmlUnescape(_ input: String) throws -> String {
        var result = ""
        var index = input.startIndex

        while index < input.endIndex {
            guard input[index] == "&" else {
                result.append(input[index])
                index = input.index(after: index)
                continue
            }

            guard let semicolon = input[index...].firstIndex(of: ";") else {
                throw StringCodecError.invalidHTMLEntity(
                    position: input.distance(from: input.startIndex, to: index) + 1
                )
            }
            let entityStart = input.index(after: index)
            let entity = String(input[entityStart..<semicolon])
            guard let decoded = decodedHTMLEntity(entity) else {
                throw StringCodecError.invalidHTMLEntity(
                    position: input.distance(from: input.startIndex, to: index) + 1
                )
            }
            result.append(decoded)
            index = input.index(after: semicolon)
        }
        return result
    }

    private func decodedHTMLEntity(_ entity: String) -> Character? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos", "#39": return "'"
        default:
            let value: UInt32?
            if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                value = UInt32(entity.dropFirst(2), radix: 16)
            } else if entity.hasPrefix("#") {
                value = UInt32(entity.dropFirst(), radix: 10)
            } else {
                value = nil
            }
            guard let value, let scalar = Unicode.Scalar(value) else {
                return nil
            }
            return Character(String(scalar))
        }
    }

    private func jsonEscape(_ input: String) -> String {
        var result = ""
        for scalar in input.unicodeScalars {
            switch scalar.value {
            case 0x08: result += #"\b"#
            case 0x09: result += #"\t"#
            case 0x0A: result += #"\n"#
            case 0x0C: result += #"\f"#
            case 0x0D: result += #"\r"#
            case 0x22: result += #"\""#
            case 0x5C: result += #"\\"#
            case 0x00...0x1F:
                result += String(format: "\\u%04X", scalar.value)
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func jsonUnescape(_ input: String) throws -> String {
        let wrapped = "\"\(input)\""
        do {
            try StrictJSONValidator().validate(wrapped)
            let value = try JSONSerialization.jsonObject(
                with: Data(wrapped.utf8),
                options: .fragmentsAllowed
            )
            guard let decoded = value as? String else {
                throw StringCodecError.invalidJSONEscape
            }
            return decoded
        } catch {
            throw StringCodecError.invalidJSONEscape
        }
    }
}
