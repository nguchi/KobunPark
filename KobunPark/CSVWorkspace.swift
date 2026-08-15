//
//  CSVWorkspace.swift
//  KobunPark
//

import Foundation

enum CSVProcessingStatus: Equatable, Sendable {
    case idle
    case success
    case failure(CSVConversionError)
}

struct CSVWorkspace: Equatable {
    var input = ""
    var outputFormat: CSVOutputFormat = .markdown

    private(set) var output = ""
    private(set) var status: CSVProcessingStatus = .idle

    mutating func process(using converter: CSVConverter = CSVConverter()) {
        do {
            output = try converter.convert(input, to: outputFormat)
            status = .success
        } catch let error as CSVConversionError {
            output = ""
            status = .failure(error)
        } catch {
            output = ""
            status = .failure(.emptyInput)
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
