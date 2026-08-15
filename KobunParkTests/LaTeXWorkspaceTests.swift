//
//  LaTeXWorkspaceTests.swift
//  KobunParkTests
//

import Foundation
import Testing
import WebKit
@testable import KobunPark

@MainActor
struct LaTeXWorkspaceTests {
    @Test func rejectsEmptyAndWhitespaceOnlyInput() {
        var empty = LaTeXWorkspace()
        empty.requestPreview()
        #expect(empty.previewRequest == nil)
        #expect(empty.status == .failure(.emptyInput))

        var whitespace = LaTeXWorkspace()
        whitespace.input = " \n\t"
        whitespace.requestPreview()
        #expect(whitespace.previewRequest == nil)
        #expect(whitespace.status == .failure(.emptyInput))
    }

    @Test func createsVersionedRequestsWithoutChangingInput() throws {
        var workspace = LaTeXWorkspace()
        workspace.input = #"\frac{1}{2}"#
        workspace.displayMode = .inline

        workspace.requestPreview()
        let first = try #require(workspace.previewRequest)
        #expect(first.source == #"\frac{1}{2}"#)
        #expect(first.displayMode == .inline)
        #expect(first.revision == 1)
        #expect(workspace.status == .rendering)

        workspace.requestPreview()
        #expect(workspace.previewRequest?.revision == 2)
        #expect(workspace.input == #"\frac{1}{2}"#)
    }

    @Test func acceptsOnlyTheCurrentPreviewCompletion() throws {
        var workspace = LaTeXWorkspace()
        workspace.input = "x^2"
        workspace.requestPreview()
        let firstRevision = try #require(workspace.previewRequest?.revision)
        workspace.requestPreview()
        let currentRevision = try #require(workspace.previewRequest?.revision)

        workspace.completePreview(.success, revision: firstRevision)
        #expect(workspace.status == .rendering)

        workspace.completePreview(.success, revision: currentRevision)
        #expect(workspace.status == .success)
    }

    @Test func retainsInputAndRenderErrorDetails() throws {
        var workspace = LaTeXWorkspace()
        workspace.input = #"\frac{"#
        workspace.requestPreview()
        let revision = try #require(workspace.previewRequest?.revision)

        workspace.completePreview(
            .failure(.rendering(message: "Expected '}'", position: 6)),
            revision: revision
        )

        #expect(workspace.input == #"\frac{"#)
        #expect(
            workspace.status == .failure(
                .rendering(message: "Expected '}'", position: 6)
            )
        )
    }

    @Test func clearRemovesContentAndStatusButKeepsDisplayMode() {
        var workspace = LaTeXWorkspace()
        workspace.displayMode = .inline
        workspace.input = "x"
        workspace.requestPreview()
        workspace.clearAll()

        #expect(workspace.input.isEmpty)
        #expect(workspace.previewRequest == nil)
        #expect(workspace.status == .idle)
        #expect(workspace.displayMode == .inline)
    }
}

struct LaTeXResourceTests {
    @Test func bundledPreviewAssetsAreAvailableOffline() throws {
        let expectedResources = [
            ("latex-preview", "html"),
            ("latex-preview", "css"),
            ("latex-preview", "js"),
            ("katex.min", "css"),
            ("katex.min", "js"),
            ("KaTeX_Main-Regular", "woff2"),
            ("KaTeX-LICENSE-v0.18.1", "txt"),
        ]

        for resource in expectedResources {
            #expect(resourceURL(name: resource.0, extension: resource.1) != nil)
        }

        let htmlURL = try #require(resourceURL(name: "latex-preview", extension: "html"))
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("connect-src 'none'"))
        #expect(!html.contains("http://"))
        #expect(!html.contains("https://"))
    }

    private func resourceURL(name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension) ??
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "Resources"
            )
    }
}

@MainActor
struct LaTeXWebPreviewTests {
    @Test func bundledKaTeXRendersValidAndRejectsInvalidInput() async {
        let valid = await render(#"\frac{1}{2} + \sqrt{x}"#)
        #expect(valid == .success)

        let invalid = await render(#"\notARealKaTeXCommand{x}"#)
        guard case .failure(.rendering(let message, _)) = invalid else {
            Issue.record("不正なLaTeXが描画成功として扱われました。")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func allLaTeXInputAssistanceSnippetsRender() async {
        for snippet in InputAssistanceSnippet.latex {
            let source = snippet.prefix + snippet.placeholder + snippet.suffix
            let outcome = await render(source)
            if outcome != .success {
                Issue.record("入力補助「\(snippet.label)」をKaTeXで描画できません。")
            }
        }
    }

    private func render(_ source: String) async -> LaTeXRenderOutcome {
        let receiver = LaTeXOutcomeReceiver()
        let coordinator = LaTeXPreviewCoordinator { outcome, _ in
            receiver.deliver(outcome)
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator

        coordinator.loadPreviewPage(in: webView)
        coordinator.update(
            request: LaTeXRenderRequest(
                source: source,
                displayMode: .display,
                revision: 1
            ),
            in: webView
        )
        return await receiver.value()
    }
}

@MainActor
private final class LaTeXOutcomeReceiver {
    private var outcome: LaTeXRenderOutcome?
    private var continuation: CheckedContinuation<LaTeXRenderOutcome, Never>?

    func deliver(_ outcome: LaTeXRenderOutcome) {
        guard self.outcome == nil else {
            return
        }
        self.outcome = outcome
        continuation?.resume(returning: outcome)
        continuation = nil
    }

    func value() async -> LaTeXRenderOutcome {
        if let outcome {
            return outcome
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
