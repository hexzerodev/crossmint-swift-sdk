import CrossmintClient
import SwiftUI
import CrossmintCommonTypes
import UIKit

struct BalanceDashboardView: View {
    private let sdk: CrossmintSDK = .shared

    let wallet: Wallet

    @Binding var balances: Balances?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let tokens: [SolanaSupportedToken] = [.sol]
    private var tokensAsCryptoCurrency: [CryptoCurrency] {
        tokens.compactMap(\.asCryptoCurrency)
    }

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if balances == nil {
                fetchBalances()
            } else {
                isLoading = false
            }
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
            if let balances {
                if balances.isEmpty {
                    noBalancesView
                } else {
                    ForEach(tokensAsCryptoCurrency, id: \.name) { currency in
                        if let chainBalance = balances[currency] {
                            WalletBalanceEntryView(currency: currency, balance: chainBalance)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
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
                let fetchedBalances = try await wallet.balance(
                    of: tokens.compactMap({ $0.asCryptoCurrency })
                )

                await MainActor.run {
                    balances = fetchedBalances.nonZeroBalances()
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
