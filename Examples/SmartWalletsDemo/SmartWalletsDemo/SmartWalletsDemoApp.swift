import SwiftUI
import CrossmintClient

@main
struct SmartWalletsDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintNonCustodialSigner(
                    CrossmintSDK.shared(apiKey: crossmintApiKey, authManager: crossmintAuthManager)
                )
        }
    }
}
