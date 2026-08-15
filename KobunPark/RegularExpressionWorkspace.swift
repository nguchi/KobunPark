//
//  RegularExpressionWorkspace.swift
//  KobunPark
//

import Foundation

enum RegularExpressionStatus: Equatable, Sendable {
    case idle
    case success
    case failure(RegularExpressionTestError)
}

struct RegularExpressionWorkspace: Equatable {
    var pattern = ""
    var target = ""
    var replacement = ""
    var replacementEnabled = false
    var options: RegularExpressionOptions = []

    private(set) var result: RegularExpressionTestResult?
    private(set) var status: RegularExpressionStatus = .idle

    var request: RegularExpressionRequest {
        RegularExpressionRequest(
            pattern: pattern,
            target: target,
            replacement: replacement,
            replacementEnabled: replacementEnabled,
            options: options
        )
    }

    mutating func apply(_ outcome: RegularExpressionOutcome) {
        switch outcome {
        case .success(let result):
            self.result = result
            status = .success
        case .failure(let error):
            result = nil
            status = .failure(error)
        }
    }

    mutating func invalidateResult() {
        result = nil
        status = .idle
    }

    mutating func clearAll() {
        pattern = ""
        target = ""
        replacement = ""
        invalidateResult()
    }
}
