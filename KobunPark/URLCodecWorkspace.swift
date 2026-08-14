//
//  URLCodecWorkspace.swift
//  KobunPark
//

import Foundation

enum URLCodecStatus: Equatable, Sendable {
    case idle
    case success
    case failure(StringCodecError)
}

struct URLCodecWorkspace: Equatable {
    var input = ""
    var kind: StringCodecKind = .url
    var mode: URLCodecMode = .encode

    private(set) var output = ""
    private(set) var status: URLCodecStatus = .idle

    mutating func process(using codec: StringCodec = StringCodec()) {
        do {
            output = try codec.transform(input, kind: kind, mode: mode)
            status = .success
        } catch let error as StringCodecError {
            output = ""
            status = .failure(error)
        } catch {
            output = ""
            status = .failure(.invalidUTF8)
        }
    }

    mutating func invalidateResult() {
        output = ""
        status = .idle
    }

    mutating func clearAll() {
        input = ""
        invalidateResult()
    }
}
