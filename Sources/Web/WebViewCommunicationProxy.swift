import Logger
import WebKit
import Foundation

@MainActor
public protocol WebViewCommunicationProxy: AnyObject, WKNavigationDelegate, WKScriptMessageHandler {
    var name: String { get }
    var webView: WKWebView? { get set }
    var onWebViewMessage: (any WebViewMessage) -> Void { get set }
    var onUnknownMessage: (String, Data) -> Void { get set }

    func loadURL(_ url: URL) async throws
    func resetLoadedContent()
    @discardableResult
    func sendMessage<T: WebViewMessage>(_ message: T) async throws(WebViewError) -> Any?
    func waitForMessage<T: WebViewMessage>(
        ofType type: T.Type,
        matching predicate: @escaping @Sendable (T) -> Bool,
        timeout: TimeInterval
    ) async throws -> T
}

extension WebViewCommunicationProxy {
    public func waitForMessage<T: WebViewMessage>(
        ofType type: T.Type,
        timeout: TimeInterval
    ) async throws -> T {
        try await waitForMessage(ofType: type, matching: { _ in true }, timeout: timeout)
    }
}

public class DefaultWebViewCommunicationProxy: NSObject, ObservableObject, WKScriptMessageHandler, WebViewCommunicationProxy {
    public let name = "crossmintMessageHandler"

    public weak var webView: WKWebView?
    public var onWebViewMessage: (any WebViewMessage) -> Void = { _ in }
    public var onUnknownMessage: (String, Data) -> Void = { _, _ in }

    private var loadedContent: URL?
    private var isPageLoaded = false
    private let messageHandler = WebViewMessageHandler()
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    public override init() {
        super.init()
        Task { @MainActor in
            messageHandler.setDelegate(self)
        }
    }

    public func loadURL(_ url: URL) async throws {
        Logger.web.debug("loadURL() called with URL: \(url)")

        guard let webView = webView else {
            Logger.web.error("loadURL() failed: webView is not available")
            throw WebViewError.webViewNotAvailable
        }

        guard requiresLoading(forUrl: url) else {
            Logger.web.debug("URL \(url) was already loaded, skipping")
            return
        }

        Logger.web.debug("URL requires loading, starting navigation")

        // Cancel any existing navigation continuation
        if navigationContinuation != nil {
            Logger.web.warn("Cancelling existing navigation continuation")
            navigationContinuation?.resume(throwing: CancellationError())
            navigationContinuation = nil
        }

        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            loadContent(url, in: webView)
        }
        Logger.web.debug("URL \(url) loaded successfully")
    }

    public func resetLoadedContent() {
        Logger.web.debug("resetLoadedContent() - Resetting loaded content and message handler")
        loadedContent = nil
        isPageLoaded = false
        Task { @MainActor in
            messageHandler.reset()
        }
    }

    public func loadContent(_ content: URL) {
        guard let webView = webView else {
            Logger.web.warn("Cannot load content: webView is nil")
            return
        }
        loadContent(content, in: webView)
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == name else {
            Logger.web.debug("Received message with unexpected name: \(message.name), expected: \(name)")
            return
        }

        Task { @MainActor in
            messageHandler.processIncomingMessage(message.body)
        }
    }

    @discardableResult
    public func sendMessage<T: WebViewMessage>(_ message: T) async throws(WebViewError) -> Any? {
        guard let webView = webView else {
            Logger.web.error("Error sending message to frame: webView unavailable")
            throw WebViewError.webViewNotAvailable
        }

        let messageData: Data
        do {
            messageData = try JSONEncoder().encode(message)
        } catch {
            Logger.web.error("Error sending message to frame: failed to encode message \(error)")
            throw WebViewError.encodingError
        }

        // If page is not loaded yet, queue the message
        if messageHandler.queueMessage(messageData) {
            Logger.web.debug("Frame not yet loaded, enqueuing message")
            return nil
        }

        do {
            return try await executeJavaScript(messageData, in: webView)
        } catch {
            Logger.web.error("Error sending message: javascript execution failed \(error)")
            throw .javascriptEvaluationError
        }
    }

    // Convenience method for fire-and-forget calls
    public func sendMessage<T: WebViewMessage>(_ message: T) {
        Task {
            do {
                try await sendMessage(message)
            } catch {
                Logger.web.error("Error sending message: \(error)")
            }
        }
    }

    @discardableResult
    public func waitForMessage<T: WebViewMessage>(
        ofType type: T.Type,
        matching predicate: @escaping @Sendable (T) -> Bool = { _ in true },
        timeout: TimeInterval = 2.0
    ) async throws -> T {
        try await messageHandler.waitForMessage(ofType: type, matching: predicate, timeout: timeout)
    }

    @MainActor
    private func executeJavaScript(_ messageData: Data, in webView: WKWebView) async throws -> Any? {
        guard let jsonString = String(data: messageData, encoding: .utf8) else {
            Logger.web.error("Failed to encode message data to UTF-8 string")
            throw WebViewError.encodingError
        }

        let script = "window.onMessageFromNative(\(jsonString));"
        Logger.web.debug("Native >> Web: \(jsonString)")

        return try await webView.evaluateJavaScript(script)
    }

    private func processPendingMessages() {
        guard let webView = webView else {
            Logger.web.warn("Could not process pending messages: webview not available")
            return
        }

        Task { @MainActor in
            let messages = messageHandler.getPendingMessages()
            for messageData in messages {
                do {
                    _ = try await executeJavaScript(messageData, in: webView)
                } catch {
                    Logger.web.error("Error processing pending message: \(error)")
                }
            }
        }
    }

    private func loadContent(_ content: URL, in webView: WKWebView) {
        Logger.web.debug("loadContent() - Loading URL in WebView: \(content)")
        loadedContent = content
        isPageLoaded = false
        Task { @MainActor in
            messageHandler.reset()
        }

        webView.load(URLRequest(url: content))
        Logger.web.debug("URLRequest sent to WebView")
    }

    private func requiresLoading(forUrl url: URL) -> Bool {
        guard let loadedContent else {
            return true
        }

        return loadedContent != url
    }
}

extension DefaultWebViewCommunicationProxy: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.web.debug("Webview finished loading")
        isPageLoaded = true
        Task { @MainActor in
            messageHandler.setReady(true)
        }
        processPendingMessages()

        // Resume any waiting navigation continuation
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.web.error("Webview failed to load: \(error)")
        isPageLoaded = false
        Task { @MainActor in
            messageHandler.setReady(false)
        }

        // Resume any waiting navigation continuation with error
        navigationContinuation?.resume(throwing: WebViewError.navigationFailed(error))
        navigationContinuation = nil
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Logger.web.error("Webview failed provisional navigation: \(error)")
        isPageLoaded = false
        Task { @MainActor in
            messageHandler.setReady(false)
        }

        // Resume any waiting navigation continuation with error
        navigationContinuation?.resume(throwing: WebViewError.navigationFailed(error))
        navigationContinuation = nil
    }
}

extension DefaultWebViewCommunicationProxy: WebViewMessageHandlerDelegate {
    public nonisolated func handleWebViewMessage<T: WebViewMessage>(_ message: T) {
        Task { @MainActor in
            onWebViewMessage(message)
        }
    }

    public nonisolated func handleUnknownMessage(_ messageType: String, data: Data) {
        Task { @MainActor in
            onUnknownMessage(messageType, data)
        }
    }
}
