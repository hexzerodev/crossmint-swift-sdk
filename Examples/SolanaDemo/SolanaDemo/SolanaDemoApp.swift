import SwiftUI
import CrossmintClient

@main
struct SolanaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintEnvironmentObject(
                    CrossmintSDK.shared(apiKey: crossmintApiKey, authManager: crossmintAuthManager, logLevel: .debug)
                ) {
                    OTPValidatorView(nonCustodialSignerCallback: $0)
                }
        }
    }
}
