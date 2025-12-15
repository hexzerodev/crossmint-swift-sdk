@_exported @preconcurrency import OSLog
import Utils

public struct Logger: Sendable {

    private let providers: [LoggerProvider]
    public nonisolated(unsafe) static var level: LogLevel = .error

    private let osLogger: OSLog
    private let subsystem: String

    public init(category: String) {
        self.subsystem = "CrossmintSDK"
        self.osLogger = OSLog(subsystem: subsystem, category: category)

        providers = [
            OSLoggerProvider(category: category),
            DataDogLoggerProvider(
                service: category,
                clientToken: DataDogConfig.clientToken,
                environment: DataDogConfig.environment
            )
        ]
    }

    public func debug(_ message: String, attributes: [String: Encodable]? = nil) {
        guard Logger.level.rawValue <= LogLevel.debug.rawValue else { return }
        for provider in providers {
            provider.debug(message, attributes: attributes)
        }
    }

    public func error(_ message: String, attributes: [String: Encodable]? = nil) {
        guard Logger.level.rawValue <= LogLevel.error.rawValue else { return }
        for provider in providers {
            provider.error(message, attributes: attributes)
        }
    }

    public func info(_ message: String, attributes: [String: Encodable]? = nil) {
        guard Logger.level.rawValue <= LogLevel.info.rawValue else { return }
        for provider in providers {
            provider.info(message, attributes: attributes)
        }
    }

    public func warn(_ message: String, attributes: [String: Encodable]? = nil) {
        guard Logger.level.rawValue <= LogLevel.warn.rawValue else { return }
        for provider in providers {
            provider.warn(message, attributes: attributes)
        }
    }
}
