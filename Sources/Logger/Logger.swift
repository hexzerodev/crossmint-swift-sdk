@_exported @preconcurrency import OSLog
import Utils

public struct Logger: Sendable {
    public nonisolated(unsafe) static var level: OSLogType = .debug
    
    private let osLogger: OSLog
    private let subsystem: String

    public init(category: String) {
        self.subsystem = "CrossmintSDK"
        self.osLogger = OSLog(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) {
        if isRunningInPlayground() {
            print("🔍 [\(subsystem)] \(message)")
        }
        
        guard Logger.level == .debug else { return }
        os_log(.debug, log: osLogger, "%{public}@", message)
    }

    public func error(_ message: String) {
        if isRunningInPlayground() {
            print("❌ [\(subsystem)] \(message)")
        }
        
        os_log(.error, log: osLogger, "%{public}@", message)
    }

    public func info(_ message: String) {
        if isRunningInPlayground() {
            print("ℹ️ [\(subsystem)] \(message)")
        }

        guard [.info, .debug].contains(Logger.level) else { return }
        os_log(.info, log: osLogger, "%{public}@", message)
    }

    public func warn(_ message: String) {
        os_log(.default, log: osLogger, "%{public}@", message)

        if isRunningInPlayground() {
            print("⚠️ [\(subsystem)] \(message)")
        }
    }
}
