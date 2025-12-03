import Auth
@_exported import AuthUI
import Combine
@_exported import CrossmintCommonTypes
@_exported import CrossmintService
import Logger
import SwiftUI
import Utils
@_exported import Wallet
import Web

@MainActor private var sdkInstances = 0

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

    public static func shared(
        apiKey: String,
        authManager: AuthManager? = nil,
        logLevel: OSLogType = .default
    ) -> CrossmintSDK {
        if let existing = _shared {
            return existing
        }

        Logger.level = logLevel
        let newInstance = CrossmintSDK(apiKey: apiKey, authManager: authManager)
        _shared = newInstance
        return newInstance
    }

    private let sdk: ClientSDK

    public let crossmintWallets: CrossmintWallets
    public let authManager: AuthManager
    public let crossmintService: CrossmintService

    let crossmintTEE: CrossmintTEE

    public var isOTPRequred: Published<Bool>.Publisher {
        crossmintTEE.$isOTPRequired
    }
    public func submit(otp: String) {
        crossmintTEE.provideOTP(otp)
    }
    public func cancelTransaction() {
        crossmintTEE.cancelOTP()
    }

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
        #endif
        Logger.client.error("Crossmint SDK requires an API key")
        fatalError("Crossmint SDK requires an API key. Please call CrossmintSDK.shared(apiKey:) before accessing CrossmintSDK.shared")
    }

    private init(apiKey: String, authManager: AuthManager? = nil) {
        sdkInstances += 1
        if sdkInstances > 1 {
            Logger.sdk.error("Multiple SDK instances created, behaviour is undefined")
        }

        do {
            sdk = try CrossmintClient.sdk(key: apiKey, authManager: authManager)
            let authManager = sdk.authManager
            self.crossmintWallets = sdk.crossmintWallets()
            self.authManager = authManager
            self.crossmintService = sdk.crossmintService
            self.crossmintTEE = CrossmintTEE.start(
                auth: authManager,
                webProxy: DefaultWebViewCommunicationProxy(),
                apiKey: apiKey,
                isProductionEnvironment: sdk.crossmintService.isProductionEnvironment
            )
        } catch {
            Logger.client.error("Invalid Crossmint API key provided: \(error)")
            fatalError("Invalid Crossmint API key provided. Please verify your API key is a valid client key.")
        }
    }

    public func logout() async throws {
        crossmintTEE.resetState()
    }

    deinit {
        Task { @MainActor in
            sdkInstances -= 1
        }
    }
}
