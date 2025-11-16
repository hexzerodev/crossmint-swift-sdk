import SwiftUI
import CrossmintClient

@main
struct SmartWalletsDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintEnvironmentObject(
                    CrossmintSDK.shared(apiKey: "ck_staging_YOUR_API_KEY")
                )
        }
    }
}
