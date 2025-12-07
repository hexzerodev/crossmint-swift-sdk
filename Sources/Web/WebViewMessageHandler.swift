import Foundation
import Logger

@MainActor
public class WebViewMessageHandler {
    private struct BufferedMessage {
        let message: any WebViewMessage
        let timestamp: Date
    }

    private var messageListeners: [UUID: CheckedContinuation<any WebViewMessage, Error>] = [:]
    private var messagePredicates: [UUID: @Sendable (any WebViewMessage) -> Bool] = [:]
    private var pendingMessages: [Data] = []
    private var isReady = false

    // Message buffer configuration
    private var messageBuffer: [BufferedMessage] = []
    private let bufferTTL: TimeInterval = 30.0 // 30 seconds
    private let maxBufferSize = 100

    private weak var delegate: WebViewMessageHandlerDelegate?

    public init() {
        // Register all known message types
        WebViewMessageRegistry.registerDefaultTypes()
    }

    public func setDelegate(_ delegate: WebViewMessageHandlerDelegate?) {
        self.delegate = delegate
    }

    public func setReady(_ ready: Bool) {
        isReady = ready
        if !ready {
            pendingMessages.removeAll()
        }
    }

    public func reset() {
        isReady = false
        pendingMessages.removeAll()
        messageBuffer.removeAll()
        for (_, continuation) in messageListeners {
            continuation.resume(throwing: WebViewError.webViewNotAvailable)
        }
        messageListeners.removeAll()
        messagePredicates.removeAll()
    }

    public func processIncomingMessage(_ messageBody: Any) {
        guard let messageData = extractMessageData(from: messageBody) else {
            Logger.web.warn("Failed to extract message data from: \(messageBody)")
            return
        }

        guard let messageTypeInfo = extractMessageType(from: messageData) else {
            Logger.web.warn("Failed to extract message type from message data: \(messageBody)")
            return
        }

        if messageTypeInfo.hasPrefix("console.") {
            handleConsoleLog(messageData)
            return
        }

        if let decodedMessage = WebViewMessageRegistry.decode(messageType: messageTypeInfo, data: messageData) {
            Logger.web.debug("Web >> Native: \(String(data: messageData, encoding: .utf8) ?? "Unknown")")

            // Add to message buffer
            addToMessageBuffer(decodedMessage)

            for (id, predicate) in messagePredicates {
                if predicate(decodedMessage) {
                    if let continuation = messageListeners.removeValue(forKey: id) {
                        messagePredicates.removeValue(forKey: id)
                        continuation.resume(returning: decodedMessage)
                    }
                }
            }

            delegate?.handleWebViewMessage(decodedMessage)
        } else {
            // Log unknown message before delegating
            Logger.web.warn("Unknown message type: \(messageTypeInfo), data: \(String(data: messageData, encoding: .utf8) ?? "nil")")
            delegate?.handleUnknownMessage(messageTypeInfo, data: messageData)
        }
    }

    private func extractMessageData(from messageBody: Any) -> Data? {
        if let stringBody = messageBody as? String {
            return stringBody.data(using: .utf8)
        } else if let dictBody = messageBody as? [String: Any] {
            return try? JSONSerialization.data(withJSONObject: dictBody, options: [])
        }
        return nil
    }

    private func extractMessageType(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        return json["type"] as? String ?? json["event"] as? String
    }

    private func handleConsoleLog(_ data: Data) {
        if let consoleMessage = try? JSONDecoder().decode(ConsoleLogMessage.self, from: data) {
            let logMessage = "Console[\(consoleMessage.severity.rawValue)]: \(consoleMessage.message)"

            switch consoleMessage.severity {
            case .error:
                Logger.web.error(logMessage)
            case .warn:
                Logger.web.warn(logMessage)
            case .debug:
                Logger.web.debug(logMessage)
            case .info, .log, .trace:
                Logger.web.info(logMessage)
            }
        }
    }

    public func queueMessage(_ messageData: Data) -> Bool {
        if !isReady {
            pendingMessages.append(messageData)
            return true
        }
        return false
    }

    public func getPendingMessages() -> [Data] {
        let messages = pendingMessages
        pendingMessages.removeAll()
        return messages
    }

    public func waitForMessage<T: WebViewMessage>(
        ofType type: T.Type,
        matching predicate: @escaping @Sendable (T) -> Bool = { _ in true },
        timeout: TimeInterval = 2.0
    ) async throws -> T {
        // First check the message buffer
        cleanupMessageBuffer()
        for (index, bufferedMessage) in messageBuffer.enumerated() {
            if let typedMessage = bufferedMessage.message as? T, predicate(typedMessage) {
                // Remove the message from buffer since it's being consumed
                messageBuffer.remove(at: index)
                return typedMessage
            }
        }

        // If not found in buffer, wait for new messages
        let id = UUID()

        // Create the timeout task first
        let timeoutTask = Task { @MainActor in
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if let continuation = messageListeners[id] {
                messageListeners.removeValue(forKey: id)
                messagePredicates.removeValue(forKey: id)
                Logger.web.error("Timed out waiting for message \(type)")
                continuation.resume(throwing: WebViewError.timeout)
            }
        }

        defer {
            timeoutTask.cancel()
            // Clean up any remaining listeners
            messageListeners.removeValue(forKey: id)
            messagePredicates.removeValue(forKey: id)
        }

        let result = try await withCheckedThrowingContinuation { continuation in
            let typedPredicate: @Sendable (any WebViewMessage) -> Bool = { message in
                guard let typedMessage = message as? T else { return false }
                return predicate(typedMessage)
            }
            registerListener(id: id, predicate: typedPredicate, continuation: continuation)
        }

        guard let typedResult = result as? T else {
            throw WebViewError.decodingError
        }

        return typedResult
    }

    private func registerListener(
        id: UUID,
        predicate: @escaping @Sendable (any WebViewMessage) -> Bool,
        continuation: CheckedContinuation<any WebViewMessage, Error>
    ) {
        messageListeners[id] = continuation
        messagePredicates[id] = predicate
    }

    private func cleanupMessageBuffer() {
        let cutoffDate = Date().addingTimeInterval(-bufferTTL)
        messageBuffer.removeAll { $0.timestamp < cutoffDate }

        // Also enforce max buffer size
        if messageBuffer.count > maxBufferSize {
            messageBuffer.removeFirst(messageBuffer.count - maxBufferSize)
        }
    }

    private func addToMessageBuffer(_ message: any WebViewMessage) {
        cleanupMessageBuffer()
        messageBuffer.append(BufferedMessage(message: message, timestamp: Date()))
    }
}
