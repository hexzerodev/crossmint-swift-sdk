import AuthUI
import Logger
import SwiftUI
import Wallet

@MainActor var instanceTrackers: [String: [InstanceTracker]] = [:]

final class InstanceTracker: ObservableObject, Sendable {
    let instance: String
    init(name: String) {
        self.instance = name
        Task { @MainActor in
            instanceTrackers[instance, default: []].append(self)
            if instanceTrackers[instance, default: []].count > 1 {
                Logger.sdk.error("More than one instance of \(instance) created at a time. Behaviour is undefined.")
            }
        }
    }

    deinit {
        Task { @MainActor [instance] in
            instanceTrackers[instance]?.popLast()
        }
    }
}

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
                .environmentObject(InstanceTracker(name: "HiddenEmailSignersView"))
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
        .frame(width: 20, height: 20) // 1x1 WebViews may be throttled, so give some margin
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await crossmintTEE.load()
        }
    }
}
