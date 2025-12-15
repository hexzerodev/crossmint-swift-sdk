//
//  DataDogLoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
import DatadogCore
import DatadogLogs
import Utils

final class DataDogLoggerProvider: LoggerProvider {
    private nonisolated(unsafe) static var isDataDogInitialized: Bool = false

    private let logger: LoggerProtocol
    private let service: String

    init(service: String, clientToken: String, environment: String) {
        self.service = service

        Self.setupDataDogIfNeeded(clientToken: clientToken, environment: environment)

        logger = DatadogLogs.Logger.create(
            with: .init(
                name: service,
                networkInfoEnabled: true,
                bundleWithRumEnabled: false,
                remoteSampleRate: 100
            )
        )
    }

    func debug(_ message: String, attributes: [String: any Encodable]?) {
        logger.debug(formatMessage(message, attributes: attributes), attributes: buildBaseAttributes())
    }

    func error(_ message: String, attributes: [String: any Encodable]?) {
        logger.error(formatMessage(message, attributes: attributes), attributes: buildBaseAttributes())
    }

    func info(_ message: String, attributes: [String: any Encodable]?) {
        logger.info(formatMessage(message, attributes: attributes), attributes: buildBaseAttributes())
    }

    func warn(_ message: String, attributes: [String: any Encodable]?) {
        logger.warn(formatMessage(message, attributes: attributes), attributes: buildBaseAttributes())
    }

    private func formatMessage(_ message: String, attributes: [String: any Encodable]?) -> String {
        guard let attributes = attributes, !attributes.isEmpty else {
            return message
        }

        let attributeStrings = attributes.map { key, value in
            "\(key)=\(value)"
        }.sorted().joined(separator: " ")

        return "\(message) \(attributeStrings)"
    }

    private func buildBaseAttributes() -> [String: Encodable] {
        [
            "service": service,
            "platform": "ios",
            "sdk_version": SDKVersion.version
        ]
    }

    private static func setupDataDogIfNeeded(clientToken: String, environment: String) {
        guard !isDataDogInitialized else { return }

        Datadog.initialize(
            with: Datadog.Configuration(
                clientToken: clientToken,
                env: environment,
                service: "crossmint-ios-sdk"
            ),
            trackingConsent: .granted
        )

        Logs.enable()

        isDataDogInitialized = true
    }
}
