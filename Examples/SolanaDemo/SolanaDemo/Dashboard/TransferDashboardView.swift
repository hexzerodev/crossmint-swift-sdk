import BigInt
import CrossmintClient
import SwiftUI

struct TransferDashboardView: View {
    let wallet: Wallet

    private let sdk: CrossmintSDK = .shared
    @EnvironmentObject var alertViewModel: AlertViewModel

    @Binding var balances: Balances?

    @State private var selectedToken: SolanaSupportedToken?
    @State private var amount: String = "0"
    @State private var recipientWallet: String = ""
    @State private var availableTokens: [SolanaSupportedToken] = []
    @State private var showTokenSelectionMenu: Bool = false
    @State private var isSendingTransaction: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transfer funds")
                .font(.title2)
                .fontWeight(.bold)

            Text("Send funds to another wallet")
                .font(.subheadline)
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.headline)

                HStack {
                    CustomTextField(
                        placeholder: "0",
                        text: $amount,
                        keyboardType: .decimalPad
                    )

                    Button {
                        showTokenSelectionMenu.toggle()
                    } label: {
                        HStack {
                            Text((selectedToken?.name ?? "Select Token").uppercased())
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.886, green: 0.91, blue: 0.941), lineWidth: 1)
                                )
                                .shadow(
                                    color: Color(red: 0.063, green: 0.094, blue: 0.157).opacity(0.05),
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                        )
                    }
                    .actionSheet(isPresented: $showTokenSelectionMenu) {
                        ActionSheet(
                            title: Text("Select Token"),
                            buttons: availableTokens.map { token in
                                .default(Text(token.name.uppercased())) {
                                    selectedToken = token
                                }
                            } + [.cancel()]
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recipient wallet")
                    .font(.headline)

                CustomTextField(
                    placeholder: "",
                    text: $recipientWallet
                )
            }

            Spacer()

            PrimaryButton(
                text: "Transfer",
                action: {
                    Task {
                        await triggerTransaction()
                    }
                },
                isLoading: isSendingTransaction,
                isDisabled: amount.isEmpty || recipientWallet.isEmpty || selectedToken == nil
            )
        }
        .padding(.top, 16)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onChange(of: balances, { _, newValue in
            if let newValue {
                availableTokens = newValue.tokens.compactMap(SolanaSupportedToken.toSolanaSupportedToken(_:))
                selectedToken = availableTokens.first
            }
        })
    }

    private func triggerTransaction() async {
        defer {
            isSendingTransaction = false
        }

        guard let selectedToken = selectedToken?.name else {
            await showError("No token selected")
            return
        }

        guard let amount = Double(amount) else {
            await showError("Invalid amount. Has to be a numeric value")
            return
        }

        await MainActor.run {
            isSendingTransaction = true
        }

        do {
            let summary = try await wallet.send(
                recipientWallet,
                "solana:\(selectedToken)",
                amount
            )

            await MainActor.run {
                self.amount = "0"
                self.recipientWallet = ""
                alertViewModel.show(
                    title: "Transaction Summary",
                    message: "ID: \(summary.transactionID)\nLink: \(summary.explorerLink)"
                )
            }
        } catch {
            switch error {
            case .userCancelled:
                await MainActor.run {
                    alertViewModel.show(
                        title: "Transaction created but not signed",
                        message: "The signing operation was cancelled"
                    )
                }
            default:
                await MainActor.run {
                    alertViewModel.show(title: "Transaction Failed", message: "Error: \(error.errorMessage)")
                }
            }
        }
    }

    private func showError(_ message: String) async {
        await MainActor.run {
            alertViewModel.show(title: "Transaction Failed", message: "Error: \(message)")
        }
    }
}
