import CrossmintClient
import SwiftUI
import CrossmintCommonTypes
import UIKit

struct BalanceDashboardView: View {
    private let sdk: CrossmintSDK = .shared

    let wallet: EVMWallet

    @Binding var balance: Balance?
    @State private var isLoading = true
    @State private var creatingSignature = false
    @State private var creatingMessageSignature = false
    @State private var messageToSign: String = ""
    @State private var errorMessage: String?
    @EnvironmentObject var alertViewModel: AlertViewModel

    private let currencies: [CryptoCurrency] = [.eth, .usdc, .usdxm]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Wallet balance")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Text("Check the wallet balance")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)

                        if isLoading {
                            loadingView
                        } else if let errorMessage = errorMessage {
                            errorView(message: errorMessage)
                        } else {
                            balanceListView
                        }

                        // Add space at the bottom for the test token button
                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .refreshable {
                    fetchBalances(false)
                }
            }

            // Test token button fixed at the bottom
            VStack {
                GetTestTokenButton(currency: .usdxm) {
                    await getTestToken(currency: .usdxm)
                    // Let's wait 2.5 seconds to get the balances updated after triggering the funding action.
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    fetchBalances(false)
                }
                .padding(.bottom, 16)

                createSignMessageView

                createSignatureButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(Color(UIColor.systemBackground).opacity(0.95))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if balance == nil {
                fetchBalances()
            } else {
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private var createSignMessageView: some View {
        VStack {
            CustomTextField(
                placeholder: "Message to sign",
                text: $messageToSign,
                keyboardType: .alphabet
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)

            Button(action: {
                Task {
                    do {
                        creatingMessageSignature = true
                        try await wallet.signMessage(messageToSign)
                        await MainActor.run {
                            creatingMessageSignature = false
                            alertViewModel.show(title: "Success", message: "Message created, signed and approved")
                        }
                    } catch {
                        await MainActor.run {
                            creatingMessageSignature = false
                            // swiftlint:disable:next line_length
                            alertViewModel.show(title: "Signature error", message: "There was an error while creating the signature")
                        }
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if creatingMessageSignature {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.green))
                    }

                    Text("Sign message")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.green)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var createSignatureButton: some View {
        Button(action: {
            Task {
                let data = EIP712.Builder()
                    .withDomain(
                        EIP712.Domain(
                            name: "Ether Mail",
                            version: "1",
                            chainId: 1,
                            verifyingContract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
                        )
                    )
                    .defineType("Person") { builder in
                        builder.string("name").address("wallet")
                    }
                    .defineType("Mail") { builder in
                        builder.string("contents")
                    }
                    .withPrimaryType("Mail")
                    .withMessage(
                        [
                            "from": [
                                "name": "Cow",
                                "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
                            ],
                            "to": [
                                "name": "Bob",
                                "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
                            ],
                            "contents": "Hello, Bob!"
                        ]
                    )
                    .build()

                guard let eipData = data else {
                    return
                }

                do {
                    creatingSignature = true
                    try await wallet.signTypedData(eipData)
                    await MainActor.run {
                        creatingSignature = false
                        alertViewModel.show(title: "Success", message: "Signature created and approved")
                    }
                } catch {
                    await MainActor.run {
                        creatingSignature = false
                        // swiftlint:disable:next line_length
                        alertViewModel.show(title: "Signature error", message: "There was an error while creating the signature")
                    }
                }
            }
        }) {
            HStack(spacing: 8) {
                if creatingSignature {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.green))
                }

                Text("Create Signature")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.green)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)

            Text("Loading balances...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .padding(.bottom, 8)

            Text("Error loading balances")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button("Retry") {
                fetchBalances()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var balanceListView: some View {
        LazyVStack(spacing: 16) {
            if let balance {
                let hasBalances = balance.nativeToken.amount != "0" ||
                                 balance.usdc.amount != "0" ||
                                 balance.tokens.contains { $0.amount != "0" }

                if hasBalances {
                    // Show native token if it has balance
                    if balance.nativeToken.amount != "0" {
                        WalletBalanceEntryView(tokenBalance: balance.nativeToken)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                    // Show USDC if it has balance
                    if balance.usdc.amount != "0" {
                        WalletBalanceEntryView(tokenBalance: balance.usdc)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                    // Show other tokens
                    ForEach(balance.tokens.indices, id: \.self) { index in
                        let token = balance.tokens[index]
                        if token.amount != "0" {
                            WalletBalanceEntryView(tokenBalance: token)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                } else {
                    noBalancesView
                }
            } else {
                noBalancesView
            }
        }
    }

    private func fetchBalances(_ showLoading: Bool = true) {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        Task {
            do {
                let fetchedBalance = try await wallet.balances(currencies)

                await MainActor.run {
                    balance = fetchedBalance
                    if showLoading {
                        isLoading = false
                    }
                }
            } catch let walletError as WalletError {
                await MainActor.run {
                    errorMessage = walletError.errorMessage
                    if showLoading {
                        isLoading = false
                    }
                }
            }
        }
    }

    private func getTestToken(currency: CryptoCurrency) async {
        do {
            try await wallet.fund(token: currency, amount: 10)
        } catch {
            await MainActor.run {
                errorMessage = error.errorMessage
            }
        }
    }

    @ViewBuilder
    private var noBalancesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "banknote")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            Text("No balances found")
                .font(.headline)

            Text("Your wallet doesn't have any tokens with balance yet.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
