import Auth
@_exported import AuthUI
@_exported import CrossmintCommonTypes
@_exported import CrossmintService
import Logger
import SwiftUI
import Utils
@_exported import Wallet
import Web

@MainActor
final public class CrossmintSDK: ObservableObject {
    nonisolated(unsafe) private static var _shared: CrossmintSDK?

    public static var shared: CrossmintSDK {
        guard let shared = _shared else {
            let newInstance = CrossmintSDK()
            _shared = newInstance
            return newInstance
        }
        return shared
    }

    public static func shared(apiKey: String, logLevel: OSLogType = .default) -> CrossmintSDK {
        Logger.level = logLevel
        let newInstance = CrossmintSDK(apiKey: apiKey)
        _shared = newInstance
        return newInstance
    }

    private let sdk: ClientSDK

    public let crossmintWallets: CrossmintWallets
    public let authManager: AuthManager
    public let crossmintService: CrossmintService

    let crossmintTEE: CrossmintTEE

    public var isProductionEnvironment: Bool {
        crossmintService.isProductionEnvironment
    }

    private convenience init() {
        #if DEBUG
            if let apiKey = ProcessInfo.processInfo.environment["CROSSMINT_API_KEY"] {
                Logger.client.info("Using API key from the environment variable.")
                self.init(apiKey: apiKey)
                return
            }
            Logger.client.error("Starting non operational SDK because no API key was provided.")
        #endif
        self.init()
    }

    private init(apiKey: String? = nil) {
        if let apiKey {
            sdk = CrossmintClient.sdk(key: apiKey)
        } else {
            sdk = NoOpCrossmintClientSDK()
        }
        let authManager = sdk.authManager
        self.crossmintWallets = sdk.crossmintWallets()
        self.authManager = authManager
        self.crossmintService = sdk.crossmintService
        self.crossmintTEE = CrossmintTEE.start(
            auth: authManager,
            webProxy: DefaultWebViewCommunicationProxy(),
            apiKey: apiKey ?? "",
            isProductionEnvironment: sdk.crossmintService.isProductionEnvironment
        )
    }

    public func logout() async throws {
        _ = try await authManager.logout()
        crossmintTEE.resetState()
    }
}
