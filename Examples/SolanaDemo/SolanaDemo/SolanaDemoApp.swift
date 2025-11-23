import SwiftUI
import CrossmintClient

let key = "ck_staging_YOUR_API_KEY"

@main
struct SolanaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintNonCustodialSigner(
                    CrossmintSDK.shared(apiKey: key, logLevel: .debug)
                )
        }
    }
}
