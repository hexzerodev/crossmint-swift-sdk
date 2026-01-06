//
//  DataDogLoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
import Utils
#if canImport(UIKit)
import UIKit
#endif

actor DataDogLoggerProvider: LoggerProvider {
    // MARK: - Constants
    private let batchSize = 10
    private let batchTimeoutSeconds: TimeInterval = 5.0

    // MARK: - Configuration
    private let service: String
    private let environment: String
    private let intakeUrl: String

    // MARK: - State
    private var batchQueue: [LogEntry] = []
    private var batchTask: Task<Void, Never>?
    private let sessionId: String
    private let deviceInfo: DeviceInfoCache

    // MARK: - Date Formatter (reused for performance)
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let serviceName = "crossmint-ios-sdk"

    // MARK: - Initialization
    init(service: String, clientToken: String, environment: String) {
        self.service = service
        self.environment = environment
        self.sessionId = Self.generateSessionId()
        self.deviceInfo = DeviceInfoCache.capture()

        let datadogUrl = "https://http-intake.logs.datadoghq.com/v1/input/\(clientToken)"
        let encodedUrl = datadogUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? datadogUrl
        self.intakeUrl = "https://telemetry.crossmint.com/dd?ddforward=\(encodedUrl)"

        Self.setupLifecycleObservers(provider: self)
    }

    // MARK: - LoggerProvider Protocol
    nonisolated func debug(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .debug, message: message, attributes: attrs.value)
        }
    }

    nonisolated func error(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .error, message: message, attributes: attrs.value)
        }
    }

    nonisolated func info(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .info, message: message, attributes: attrs.value)
        }
    }

    nonisolated func warn(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .warn, message: message, attributes: attrs.value)
        }
    }

    // MARK: - Core Logic (actor-isolated)
    private func write(level: LogLevel, message: String, attributes: [String: Encodable]?) {
        let entry = LogEntry(
            level: level,
            message: formatMessage(message, attributes: attributes),
            timestamp: Self.iso8601Formatter.string(from: Date()),
            context: attributes ?? [:]
        )

        batchQueue.append(entry)

        // Flush if batch is full
        if batchQueue.count >= batchSize {
            flush()
        } else {
            // Schedule timeout flush if not already scheduled
            scheduleBatchTimeout()
        }
    }

    private func scheduleBatchTimeout() {
        // Cancel existing task
        batchTask?.cancel()

        // Schedule new flush
        let timeout = batchTimeoutSeconds
        batchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    func flush() {
        // Cancel pending timeout
        batchTask?.cancel()
        batchTask = nil

        guard !batchQueue.isEmpty else { return }

        // Take current batch
        let batch = batchQueue
        batchQueue.removeAll()

        // Send asynchronously (don't await to avoid blocking)
        Task {
            await sendBatch(batch)
        }
    }

    private func sendBatch(_ batch: [LogEntry]) async {
        // Format logs for DataDog
        let logs = batch.map { entry in
            formatLogForDataDog(entry)
        }

        do {
            guard let url = URL(string: intakeUrl) else {
                print("[SDK Logger] Invalid intake URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: logs)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                print("[SDK Logger] DataDog proxy returned error: \(httpResponse.statusCode)")
            }
        } catch {
            // Don't let logging errors break the app
            print("[SDK Logger] Error sending logs to DataDog: \(error)")
        }
    }

    // MARK: - Formatting
    private func formatMessage(_ message: String, attributes: [String: Encodable]?) -> String {
        guard let attributes = attributes, !attributes.isEmpty else {
            return message
        }

        let attributeStrings = attributes.map { key, value in
            "\(key)=\(value)"
        }.sorted().joined(separator: " ")

        return "\(message) \(attributeStrings)"
    }

    private func formatLogForDataDog(_ entry: LogEntry) -> [String: Any] {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"

        var attributes: [String: Any] = [
            "date": entry.timestamp,
            "os": [
                "build": deviceInfo.osBuild,
                "name": deviceInfo.osName,
                "version": deviceInfo.osVersion
            ],
            "build_version": deviceInfo.appBuild,
            "service": serviceName,
            "logger": [
                "thread_name": Self.getThreadName(),
                "name": service,
                "version": SDKVersion.version
            ],
            "version": deviceInfo.appVersion,
            "platform": "ios",
            "_dd": [
                "device": [
                    "name": deviceInfo.deviceName,
                    "model": deviceInfo.model,
                    "brand": "Apple",
                    "architecture": deviceInfo.architecture
                ]
            ],
            "status": mapLevelToStatus(entry.level)
        ]

        var networkInfo: [String: Any] = [
            "client": [
                "type": deviceInfo.networkConnectionType
            ]
        ]

        if let cellularTech = deviceInfo.cellularTechnology {
            if var client = networkInfo["client"] as? [String: Any] {
                client["cellular_technology"] = cellularTech
                networkInfo["client"] = client
            }
        }

        attributes["network"] = networkInfo

        for (key, value) in entry.context {
            attributes[key] = value
        }

        let log: [String: Any] = [
            "timestamp": entry.timestamp,
            "tags": [
                "env:\(environment)",
                "version:\(deviceInfo.appVersion)",
                "source:ios"
            ],
            "service": serviceName,
            "message": entry.message,
            "hostname": bundleId,
            "dd-session_id": sessionId,
            "attributes": attributes
        ]

        return log
    }

    private static func getThreadName() -> String {
        if Thread.isMainThread {
            return "main"
        }
        if let name = Thread.current.name, !name.isEmpty {
            return name
        }
        return "background"
    }

    private func mapLevelToStatus(_ level: LogLevel) -> String {
        switch level {
        case .debug, .info:
            return "info"
        case .warn:
            return "warn"
        case .error:
            return "error"
        }
    }

    // MARK: - Session ID Generation
    private static func generateSessionId() -> String {
        // Generate 16-character hex string (64-bit trace ID)
        var bytes = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Lifecycle Management
    private static func setupLifecycleObservers(provider: DataDogLoggerProvider) {
        #if canImport(UIKit)
        // Flush when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await provider.flush() }
        }

        // Final flush before termination
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await provider.flush() }
        }
        #endif
    }
}
