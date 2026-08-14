//
//  URLPercentCodec.swift
//  KobunPark
//

import Foundation

nonisolated enum URLCodecMode: String, CaseIterable, Identifiable, Sendable {
    case encode
    case decode

    var id: String { rawValue }
}

nonisolated enum URLCodecError: Error, Equatable, Sendable {
    case emptyInput
    case invalidPercentEscape(position: Int)
    case invalidUTF8
}

/// RFC 3986のunreserved文字だけを残すURLコンポーネント変換。
nonisolated struct URLPercentCodec: Sendable {
    func transform(_ input: String, mode: URLCodecMode) throws -> String {
        switch mode {
        case .encode:
            return try encode(input)
        case .decode:
            return try decode(input)
        }
    }

    func encode(_ input: String) throws -> String {
        guard !input.isEmpty else {
            throw URLCodecError.emptyInput
        }

        let hexadecimal = Array("0123456789ABCDEF".utf8)
        var output: [UInt8] = []
        output.reserveCapacity(input.utf8.count)

        for byte in input.utf8 {
            if isUnreserved(byte) {
                output.append(byte)
            } else {
                output.append(ascii("%"))
                output.append(hexadecimal[Int(byte >> 4)])
                output.append(hexadecimal[Int(byte & 0x0F)])
            }
        }

        return String(decoding: output, as: UTF8.self)
    }

    func decode(_ input: String) throws -> String {
        guard !input.isEmpty else {
            throw URLCodecError.emptyInput
        }

        let source = Array(input.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(source.count)
        var index = 0

        while index < source.count {
            guard source[index] == ascii("%") else {
                output.append(source[index])
                index += 1
                continue
            }

            guard index + 2 < source.count,
                  let high = hexadecimalValue(source[index + 1]),
                  let low = hexadecimalValue(source[index + 2]) else {
                throw URLCodecError.invalidPercentEscape(
                    position: characterPosition(atUTF8Offset: index, in: input)
                )
            }

            output.append((high << 4) | low)
            index += 3
        }

        guard let decoded = String(bytes: output, encoding: .utf8) else {
            throw URLCodecError.invalidUTF8
        }
        return decoded
    }

    private func isUnreserved(_ byte: UInt8) -> Bool {
        (byte >= ascii("A") && byte <= ascii("Z")) ||
            (byte >= ascii("a") && byte <= ascii("z")) ||
            (byte >= ascii("0") && byte <= ascii("9")) ||
            byte == ascii("-") || byte == ascii(".") ||
            byte == ascii("_") || byte == ascii("~")
    }

    private func hexadecimalValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case ascii("0")...ascii("9"):
            return byte - ascii("0")
        case ascii("A")...ascii("F"):
            return byte - ascii("A") + 10
        case ascii("a")...ascii("f"):
            return byte - ascii("a") + 10
        default:
            return nil
        }
    }

    private func characterPosition(atUTF8Offset offset: Int, in input: String) -> Int {
        String(decoding: input.utf8.prefix(offset), as: UTF8.self).count + 1
    }

    private func ascii(_ character: Character) -> UInt8 {
        character.asciiValue ?? 0
    }
}
