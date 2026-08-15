//
//  LaTeXPreviewView.swift
//  KobunPark
//

import SwiftUI
import WebKit

#if os(macOS)
struct LaTeXPreviewView: NSViewRepresentable {
    let request: LaTeXRenderRequest?
    let onOutcome: (LaTeXRenderOutcome, Int) -> Void

    func makeCoordinator() -> LaTeXPreviewCoordinator {
        LaTeXPreviewCoordinator(onOutcome: onOutcome)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = makePreviewWebView(coordinator: context.coordinator)
        context.coordinator.loadPreviewPage(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOutcome = onOutcome
        context.coordinator.update(request: request, in: webView)
    }
}
#else
struct LaTeXPreviewView: UIViewRepresentable {
    let request: LaTeXRenderRequest?
    let onOutcome: (LaTeXRenderOutcome, Int) -> Void

    func makeCoordinator() -> LaTeXPreviewCoordinator {
        LaTeXPreviewCoordinator(onOutcome: onOutcome)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = makePreviewWebView(coordinator: context.coordinator)
        context.coordinator.loadPreviewPage(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOutcome = onOutcome
        context.coordinator.update(request: request, in: webView)
    }
}
#endif

@MainActor
final class LaTeXPreviewCoordinator: NSObject, WKNavigationDelegate {
    var onOutcome: (LaTeXRenderOutcome, Int) -> Void

    private var pendingRequest: LaTeXRenderRequest?
    private var lastRenderedRevision: Int?
    private var isReady = false
    private var resourceLoadFailed = false

    init(onOutcome: @escaping (LaTeXRenderOutcome, Int) -> Void) {
        self.onOutcome = onOutcome
    }

    func loadPreviewPage(in webView: WKWebView) {
        guard let pageURL = previewPageURL else {
            resourceLoadFailed = true
            reportResourceFailureIfNeeded()
            return
        }

        webView.loadFileURL(
            pageURL,
            allowingReadAccessTo: pageURL.deletingLastPathComponent()
        )
    }

    private var previewPageURL: URL? {
        Bundle.main.url(forResource: "latex-preview", withExtension: "html") ??
            Bundle.main.url(
                forResource: "latex-preview",
                withExtension: "html",
                subdirectory: "Resources"
            )
    }

    func update(request: LaTeXRenderRequest?, in webView: WKWebView) {
        pendingRequest = request

        guard let request else {
            lastRenderedRevision = nil
            if isReady {
                webView.evaluateJavaScript("window.clearLatexPreview();")
            }
            return
        }

        if resourceLoadFailed {
            reportResourceFailureIfNeeded()
            return
        }

        guard isReady, request.revision != lastRenderedRevision else {
            return
        }
        render(request, in: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        if let pendingRequest,
           pendingRequest.revision != lastRenderedRevision {
            render(pendingRequest, in: webView)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        resourceLoadFailed = true
        reportResourceFailureIfNeeded()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        resourceLoadFailed = true
        reportResourceFailureIfNeeded()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if url.isFileURL || url.scheme == "about" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    private func render(_ request: LaTeXRenderRequest, in webView: WKWebView) {
        lastRenderedRevision = request.revision
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else {
                return
            }

            do {
                let value = try await webView.callAsyncJavaScript(
                    "return window.renderLatexPreview(source, displayMode);",
                    arguments: [
                        "source": request.source,
                        "displayMode": request.displayMode == .display,
                    ],
                    in: nil,
                    contentWorld: .page
                )
                self.handle(value, revision: request.revision)
            } catch {
                self.onOutcome(.failure(.resourceUnavailable), request.revision)
            }
        }
    }

    private func handle(_ value: Any?, revision: Int) {
        guard let response = value as? [String: Any],
              let succeeded = response["success"] as? Bool else {
            onOutcome(.failure(.resourceUnavailable), revision)
            return
        }

        if succeeded {
            onOutcome(.success, revision)
        } else {
            let message = sanitizedMessage(response["message"] as? String)
            onOutcome(
                .failure(
                    .rendering(
                        message: message,
                        position: errorPosition(in: message)
                    )
                ),
                revision
            )
        }
    }

    private func reportResourceFailureIfNeeded() {
        guard let revision = pendingRequest?.revision else {
            return
        }
        onOutcome(.failure(.resourceUnavailable), revision)
    }

    private func sanitizedMessage(_ message: String?) -> String {
        let normalized = (message ?? "LaTeX構文を解釈できません。")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(normalized.prefix(240))
    }

    private func errorPosition(in message: String) -> Int? {
        guard let expression = try? NSRegularExpression(
            pattern: #"position\s+([0-9]+)"#,
            options: .caseInsensitive
        ) else {
            return nil
        }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = expression.firstMatch(in: message, range: range),
              let captureRange = Range(match.range(at: 1), in: message) else {
            return nil
        }
        return Int(message[captureRange])
    }
}

@MainActor
private func makePreviewWebView(coordinator: LaTeXPreviewCoordinator) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = coordinator
    webView.allowsBackForwardNavigationGestures = false
#if os(macOS)
    webView.underPageBackgroundColor = .clear
#endif
    return webView
}
