//
//  LaTeXWorkspace.swift
//  KobunPark
//

import Foundation

nonisolated enum LaTeXDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case inline
    case display

    var id: String { rawValue }
}

nonisolated struct LaTeXRenderRequest: Equatable, Sendable {
    let source: String
    let displayMode: LaTeXDisplayMode
    let revision: Int
}

nonisolated enum LaTeXPreviewError: Error, Equatable, Sendable {
    case emptyInput
    case rendering(message: String, position: Int?)
    case resourceUnavailable
}

nonisolated enum LaTeXRenderOutcome: Equatable, Sendable {
    case success
    case failure(LaTeXPreviewError)
}

enum LaTeXPreviewStatus: Equatable, Sendable {
    case idle
    case rendering
    case success
    case failure(LaTeXPreviewError)
}

struct LaTeXWorkspace: Equatable {
    var input = ""
    var displayMode: LaTeXDisplayMode = .display

    private(set) var previewRequest: LaTeXRenderRequest?
    private(set) var status: LaTeXPreviewStatus = .idle
    private var nextRevision = 0

    mutating func requestPreview() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            previewRequest = nil
            status = .failure(.emptyInput)
            return
        }

        nextRevision += 1
        previewRequest = LaTeXRenderRequest(
            source: input,
            displayMode: displayMode,
            revision: nextRevision
        )
        status = .rendering
    }

    mutating func completePreview(
        _ outcome: LaTeXRenderOutcome,
        revision: Int
    ) {
        guard previewRequest?.revision == revision else {
            return
        }

        switch outcome {
        case .success:
            status = .success
        case .failure(let error):
            status = .failure(error)
        }
    }

    mutating func invalidatePreview() {
        previewRequest = nil
        status = .idle
    }

    mutating func clearAll() {
        input = ""
        invalidatePreview()
    }
}
