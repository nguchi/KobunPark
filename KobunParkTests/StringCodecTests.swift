//
//  StringCodecTests.swift
//  KobunParkTests
//

import Testing
@testable import KobunPark

@MainActor
struct StringCodecTests {
    private let codec = StringCodec()

    @Test func transformsURLComponentsUsingExistingRules() throws {
        #expect(try codec.transform("a b+", kind: .url, mode: .encode) == "a%20b%2B")
        #expect(try codec.transform("a%20b+", kind: .url, mode: .decode) == "a b+")
    }

    @Test func base64RoundTripsUnicodeAndReportsInvalidData() throws {
        #expect(try codec.transform("KobunPark", kind: .base64, mode: .encode) == "S29idW5QYXJr")
        let input = "日本語😀\nKobunPark"
        let encoded = try codec.transform(input, kind: .base64, mode: .encode)
        #expect(try codec.transform(encoded, kind: .base64, mode: .decode) == input)
        #expect(throws: StringCodecError.invalidBase64) {
            try codec.transform("not base64!", kind: .base64, mode: .decode)
        }
        #expect(throws: StringCodecError.invalidUTF8) {
            try codec.transform("/w==", kind: .base64, mode: .decode)
        }
    }

    @Test func htmlEscapesAndUnescapesNamedAndNumericEntities() throws {
        let input = #"<p class="a">Tom & 'Jerry'</p>"#
        let escaped = try codec.transform(input, kind: .html, mode: .encode)
        #expect(escaped == "&lt;p class=&quot;a&quot;&gt;Tom &amp; &#39;Jerry&#39;&lt;/p&gt;")
        #expect(try codec.transform(escaped, kind: .html, mode: .decode) == input)
        #expect(try codec.transform("&#26085;&#x672C;", kind: .html, mode: .decode) == "日本")
        #expect(throws: StringCodecError.invalidHTMLEntity(position: 1)) {
            try codec.transform("&unknown;", kind: .html, mode: .decode)
        }
        #expect(throws: StringCodecError.invalidHTMLEntity(position: 3)) {
            try codec.transform("A &amp", kind: .html, mode: .decode)
        }
    }

    @Test func jsonEscapesAndUnescapesControlCharactersAndUnicode() throws {
        let input = "\"日本語😀\"\n\t\\\u{0001}"
        let escaped = try codec.transform(input, kind: .json, mode: .encode)
        #expect(escaped == #"\"日本語😀\"\n\t\\\u0001"#)
        #expect(try codec.transform(escaped, kind: .json, mode: .decode) == input)
        #expect(try codec.transform(#"\u65E5\u672C"#, kind: .json, mode: .decode) == "日本")
        #expect(throws: StringCodecError.invalidJSONEscape) {
            try codec.transform(#"\q"#, kind: .json, mode: .decode)
        }
    }

    @Test func rejectsEmptyInputForEveryKindAndMode() {
        for kind in StringCodecKind.allCases {
            for mode in URLCodecMode.allCases {
                #expect(throws: StringCodecError.emptyInput) {
                    try codec.transform("", kind: kind, mode: mode)
                }
            }
        }
    }

    @Test func workspaceClearsStaleOutputAfterFailureAndKeepsSettings() {
        var workspace = URLCodecWorkspace()
        workspace.kind = .base64
        workspace.input = "KobunPark"
        workspace.process()
        #expect(workspace.output == "S29idW5QYXJr")

        workspace.mode = .decode
        workspace.input = "invalid!"
        workspace.process()
        #expect(workspace.input == "invalid!")
        #expect(workspace.output.isEmpty)
        #expect(workspace.status == .failure(.invalidBase64))

        workspace.clearAll()
        #expect(workspace.kind == .base64)
        #expect(workspace.mode == .decode)
        #expect(workspace.status == .idle)
    }
}
