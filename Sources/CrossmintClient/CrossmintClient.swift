import CrossmintService
import Logger
import Auth

public actor CrossmintClient {
    public enum Error: Swift.Error {
        case invalidApiKey(String)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var shared: ClientSDK?

    private let apiKey: String

    private init(apiKey: String) {
        self.apiKey = apiKey
    }

    public static func sdk(key: String, authManager: AuthManager? = nil) -> ClientSDK {
        lock.lock()
        defer { lock.unlock() }

        guard let shared else {
            let apiKey: ApiKey
            do {
                apiKey = try ApiKey(key: key)
            } catch {
                Logger.sdk.error("Invalid API key")
                let instance = NoOpCrossmintClientSDK()
                shared = instance
                return instance
            }

            guard apiKey.type == .client else {
                Logger.sdk.error("API key is not a client key")
                let instance = NoOpCrossmintClientSDK()
                shared = instance
                return instance
            }
            
            let instance: CrossmintClientSDK
            if let authManager {
                instance = CrossmintClientSDK(apiKey: apiKey, authManager: authManager)
            } else {
                instance = CrossmintClientSDK(apiKey: apiKey)
            }
            
            shared = instance
            return instance
        }
        return shared
    }
}
