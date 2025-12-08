import CrossmintService
import Logger
import CrossmintAuth

public actor CrossmintClient {
    public enum Error: Swift.Error {
        case invalidApiKeyType
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var shared: ClientSDK?

    private let apiKey: String

    private init(apiKey: String) {
        self.apiKey = apiKey
    }

    public static func sdk(key: String, authManager: AuthManager? = nil) throws -> ClientSDK {
        lock.lock()
        defer { lock.unlock() }

        guard let shared else {
            let apiKey: ApiKey
            apiKey = try ApiKey(key: key)

            guard apiKey.type == .client else {
                Logger.sdk.error("API key is not a client key")
                throw Error.invalidApiKeyType
            }

            DataDogConfig.configure(environment: apiKey.environment.rawValue)

            let instance = CrossmintClientSDK(apiKey: apiKey, authManager: authManager)
            shared = instance
            return instance
        }
        return shared
    }
}
