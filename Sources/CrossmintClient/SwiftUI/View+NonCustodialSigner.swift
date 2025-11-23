import AuthUI
import Logger
import SwiftUI
import Wallet

extension View {
    public func crossmintNonCustodialSigner(_ sdk: CrossmintSDK) -> some View {
        self.modifier(CrossmintNonCustodialSignerViewModifier(sdk: sdk))
    }
}

private struct CrossmintNonCustodialSignerViewModifier: ViewModifier {
    private let crossmintTEE: CrossmintTEE

    init(sdk: CrossmintSDK) {
        crossmintTEE = sdk.crossmintTEE
    }

    func body(content: Content) -> some View {
        ZStack {
            HiddenEmailSignersView(crossmintTEE: crossmintTEE)
            content
        }
    }
}

private struct HiddenEmailSignersView: View {
    private var crossmintTEE: CrossmintTEE

    init(crossmintTEE: CrossmintTEE) {
        self.crossmintTEE = crossmintTEE
    }

    var body: some View {
        EmailSignersView(
            webViewCommunicationProxy: crossmintTEE.webProxy
        )
        .frame(width: 20, height: 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await crossmintTEE.load()
        }
    }
}
