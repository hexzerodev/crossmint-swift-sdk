import SwiftUI
import CrossmintClient
import Wallet

struct DashboardView: View {
    private let sdk: CrossmintSDK = .shared

    @StateObject private var alertViewModel = AlertViewModel()

    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var selectedTab: Tab = .balance
    @State private var delegatedSignerAddress: String = ""
    @State private var opacity: Double = 0
    @State private var isLoading: Bool = false
    @State private var creatingWallet: Bool = false
    @State private var wallet: Wallet?
    @State private var balance: Balance?
    @State private var isShaking: Bool = false
    private let hapticFeedback = UINotificationFeedbackGenerator()

    private var authManager: AuthManager {
        sdk.authManager
    }

    enum Tab {
        case balance, transfer, nft
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if isLoading {
                Spacer()
                ProgressView("Checking wallet status...")
                    .padding()
                Spacer()
            } else if creatingWallet {
                Spacer()
                ProgressView("Creating wallet...")
                    .padding()
                Spacer()
            } else if let wallet = wallet {
                walletView(wallet)
                    .padding(.bottom, 24)

                HStack(spacing: 0) {
                    TabButton(title: "Balance", isSelected: selectedTab == .balance) {
                        withAnimation(AnimationConstants.easeInOut(duration: AnimationConstants.shortDuration)) {
                            selectedTab = .balance
                        }
                    }

                    TabButton(title: "Transfer", isSelected: selectedTab == .transfer) {
                        withAnimation(AnimationConstants.easeInOut(duration: AnimationConstants.shortDuration)) {
                            selectedTab = .transfer
                        }
                    }

                    TabButton(title: "NFTs", isSelected: selectedTab == .nft) {
                        withAnimation(AnimationConstants.easeInOut(duration: AnimationConstants.shortDuration)) {
                            selectedTab = .nft
                        }
                    }
                }
                .background(Color.white)

                tabContent(for: wallet)
            } else {
                noWalletView
            }

            CrossmintPoweredView()
                .padding(.bottom, 16)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(AnimationConstants.easeIn()) {
                opacity = 1
            }

            checkWalletStatus()
        }
        .alert(alertViewModel.title, isPresented: alertViewModel.isPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertViewModel.message)
        }
        .environmentObject(alertViewModel)
    }

    @ViewBuilder
    private func tabContent(for wallet: Wallet) -> some View {
        ZStack {
            if let evmWallet = try? EVMWallet.from(wallet: wallet) {
                BalanceDashboardView(wallet: evmWallet, balance: $balance)
                    .opacity(selectedTab == .balance ? 1.0 : 0.0)
            }
            TransferDashboardView(wallet: wallet, balances: $balance)
                .opacity(selectedTab == .transfer ? 1.0 : 0.0)
            NFTDashboardView(wallet: wallet)
                .opacity(selectedTab == .nft ? 1.0 : 0.0)
        }
        .background(Color.white)
        .cornerRadius(20, corners: UIRectCorner([.bottomLeft, .bottomRight]))
        .shadow(color: Color(UIColor(red: 16/255, green: 24/255, blue: 40/255, alpha: 0.1)), radius: 3, x: 0, y: 1)
        .shadow(color: Color(UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)), radius: 2, x: 0, y: 1)
        .padding(.bottom)
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image("crossmint-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            Spacer()

            SecondaryButton(
                text: "Logout",
                icon: "arrow.right.square",
                action: logout
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func walletView(_ wallet: Wallet) -> some View {
        VStack(spacing: 8) {
            Text("Your wallet")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack {
                MiddleEllipsisText(
                    text: wallet.address,
                    maxLength: 12
                )
                .font(.headline)
                .fontWeight(.bold)
                .modifier(ShakeEffect(animatableData: isShaking ? 1 : 0))

                Button(action: copyWalletAddress) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .modifier(ShakeEffect(animatableData: isShaking ? 1 : 0))
                }
            }
            .animation(.default, value: isShaking)
        }
    }

    @ViewBuilder
    private var noWalletView: some View {
        Spacer()

        VStack(spacing: 24) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding(.bottom, 16)

            Text("No Wallet Available")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create a wallet to start managing your assets")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PrimaryButton(
                text: "Create Wallet",
                action: { obtainWallet(updateLoadingStatus: true) },
                isLoading: false
            )
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)

        Spacer()
    }

    private func checkWalletStatus() {
        guard wallet == nil else { return }

        isLoading = true

        Task {
            await obtainOrCreateWallet()

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func copyWalletAddress() {
        guard let wallet = wallet else { return }
        UIPasteboard.general.string = wallet.address

        hapticFeedback.prepare()
        hapticFeedback.notificationOccurred(.success)

        withAnimation(.default) {
            isShaking = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.default) {
                isShaking = false
            }
        }
    }

    private func obtainWallet(updateLoadingStatus: Bool = false) {
        if updateLoadingStatus {
            creatingWallet = true
        }
        Task {
            await obtainOrCreateWallet(updateLoadingStatus)
        }
    }

    private func obtainOrCreateWallet(_ updateLoadingStatus: Bool = false) async {
        guard let email = await crossmintAuthManager.email else {
            await MainActor.run {
                if updateLoadingStatus {
                    creatingWallet = false
                }
                showAlert(with: "There was a problem creating the wallet.\nLogout and try again.")
            }
            return
        }

        do {
            let wallet = try await sdk.crossmintWallets.getOrCreateWallet(
                chain: .baseSepolia,
                signer: .email(email)
            )

            await MainActor.run {
                if updateLoadingStatus {
                    creatingWallet = false
                }
                self.wallet = wallet
            }
        } catch {
            await MainActor.run {
                if updateLoadingStatus {
                    creatingWallet = false
                }
                switch error {
                case .walletCreationCancelled:
                    break
                default:
                    showAlert(with: error.errorMessage)
                }
            }
        }
    }

    private func logout() {
        Task {
            try? await crossmintAuthManager.logout()
        }

        withAnimation(AnimationConstants.easeInOut()) {
            opacity = 0
        }

        Task {
            do {
                _ = try await sdk.logout()
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.duration) {
                    withAnimation(AnimationConstants.easeInOut()) {
                        authenticationStatus = .nonAuthenticated
                    }
                }
            } catch {
                withAnimation {
                    opacity = 1
                }
                showAlert(with: "Error logging out: \(error.localizedDescription)")
            }
        }
    }

    private func showAlert(with message: String) {
        alertViewModel.show(title: "Dashboard", message: message)
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let shake = sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: shake, y: 0))
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .black : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .green : .clear)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView(
        authenticationStatus: .constant(.authenticated(email: "some", jwt: "some", secret: "some"))
    )
}
