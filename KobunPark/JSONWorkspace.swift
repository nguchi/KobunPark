//
//  JSONWorkspace.swift
//  KobunPark
//

import Foundation

enum JSONProcessingStatus: Equatable, Sendable {
    case idle
    case valid
    case invalid(JSONFormattingError)
}

struct JSONWorkspace: Equatable {
    var input = ""
    var outputMode: JSONOutputMode = .formatted
    var indentation: JSONIndentation = .twoSpaces

    private(set) var output = ""
    private(set) var status: JSONProcessingStatus = .idle

    mutating func process(using formatter: JSONTextFormatter = JSONTextFormatter()) {
        do {
            output = try formatter.format(
                input,
                mode: outputMode,
                indentation: indentation
            )
            status = .valid
        } catch let error as JSONFormattingError {
            output = ""
            status = .invalid(error)
        } catch {
            output = ""
            status = .invalid(
                .invalidJSON(issue: .invalidSyntax, line: nil, column: nil)
            )
        }
    }

    mutating func clearAll() {
        input = ""
        output = ""
        status = .idle
    }
}
