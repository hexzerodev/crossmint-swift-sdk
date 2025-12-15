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
        logger.debug(message, attributes: buildAttributes(attributes))
    }

    func error(_ message: String, attributes: [String: any Encodable]?) {
        logger.error(message, attributes: buildAttributes(attributes))
    }

    func info(_ message: String, attributes: [String: any Encodable]?) {
        logger.info(message, attributes: buildAttributes(attributes))
    }

    func warn(_ message: String, attributes: [String: any Encodable]?) {
        logger.warn(message, attributes: buildAttributes(attributes))
    }

    private func buildAttributes(_ attributes: [String: any Encodable]?) -> [String: Encodable] {
        var loggerAttributes: [String: Encodable] = [
            "service": service,
            "platform": "ios",
            "sdk_version": SDKVersion.version
        ]

        if let attributes {
            loggerAttributes.merge(attributes) { _, new in new }
        }

        return loggerAttributes
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
