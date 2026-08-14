//
//  URLPercentCodecTests.swift
//  KobunParkTests
//

import Testing
@testable import KobunPark

@MainActor
struct URLPercentCodecTests {
    private let codec = URLPercentCodec()

    @Test func keepsRFC3986UnreservedCharacters() throws {
        let input = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

        #expect(try codec.encode(input) == input)
    }

    @Test func encodesSpacesAndReservedCharacters() throws {
        #expect(try codec.encode("hello world") == "hello%20world")
        #expect(
            try codec.encode(":/?#[]@!$&'()*+,;=") ==
                "%3A%2F%3F%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D"
        )
    }

    @Test func encodesUTF8UsingUppercaseHexadecimal() throws {
        let output = try codec.encode("日本語😀")

        #expect(output == "%E6%97%A5%E6%9C%AC%E8%AA%9E%F0%9F%98%80")
    }

    @Test func decodesUppercaseAndLowercaseHexadecimal() throws {
        #expect(try codec.decode("%E6%97%A5%e6%9c%ac") == "日本")
    }

    @Test func doesNotTreatPlusAsFormEncodedSpace() throws {
        #expect(try codec.decode("a+b%20c") == "a+b c")
        #expect(try codec.encode("a+b") == "a%2Bb")
    }

    @Test func roundTripsJapaneseEmojiAndLineBreaks() throws {
        let input = "日本語と😀\n2行目"

        let encoded = try codec.encode(input)
        let decoded = try codec.decode(encoded)

        #expect(decoded == input)
    }

    @Test func allowsWhitespaceAsMeaningfulInput() throws {
        #expect(try codec.encode(" \t\n") == "%20%09%0A")
    }

    @Test func reportsEmptyInput() {
        #expect(throws: URLCodecError.emptyInput) {
            try codec.encode("")
        }
        #expect(throws: URLCodecError.emptyInput) {
            try codec.decode("")
        }
    }

    @Test func reportsMalformedPercentEscapesAtCharacterPosition() {
        #expect(throws: URLCodecError.invalidPercentEscape(position: 2)) {
            try codec.decode("日%G0")
        }
        #expect(throws: URLCodecError.invalidPercentEscape(position: 4)) {
            try codec.decode("abc%")
        }
        #expect(throws: URLCodecError.invalidPercentEscape(position: 1)) {
            try codec.decode("%0G")
        }
    }

    @Test func rejectsDecodedBytesThatAreNotUTF8() {
        #expect(throws: URLCodecError.invalidUTF8) {
            try codec.decode("%FF")
        }
    }

    @Test func workspaceKeepsInputAndClearsStaleOutputAfterFailure() {
        var workspace = URLCodecWorkspace()
        workspace.input = "hello world"
        workspace.process()
        #expect(workspace.output == "hello%20world")

        workspace.mode = .decode
        workspace.input = "broken%"
        workspace.process()

        #expect(workspace.input == "broken%")
        #expect(workspace.output.isEmpty)
        #expect(workspace.status == .failure(.url(.invalidPercentEscape(position: 7))))
    }

    @Test func clearAllRemovesContentAndStatusButKeepsMode() {
        var workspace = URLCodecWorkspace()
        workspace.mode = .decode
        workspace.input = "%E6%97%A5"
        workspace.process()

        workspace.clearAll()

        #expect(workspace.input.isEmpty)
        #expect(workspace.output.isEmpty)
        #expect(workspace.status == .idle)
        #expect(workspace.mode == .decode)
    }
}
