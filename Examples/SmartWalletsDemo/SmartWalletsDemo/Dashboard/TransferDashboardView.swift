import BigInt
import CrossmintClient
import SwiftUI
import Wallet
import CrossmintCommonTypes

struct TransferDashboardView: View {
    let wallet: Wallet

    private let sdk: CrossmintSDK = .shared
    @EnvironmentObject var alertViewModel: AlertViewModel

    @Binding var balances: Balance?

    @State private var selectedToken: CryptoCurrency?
    @State private var amount: String = "0"
    @State private var recipientWallet: String = ""
    @State private var availableTokens: [CryptoCurrency] = []
    @State private var showTokenSelectionMenu: Bool = false
    @State private var isSendingTransaction: Bool = false

    private let evmBlockchain: EVMChain = .baseSepolia

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
        .onChange(of: balances) { _, newValue in
            if let newValue {
                // Collect all available tokens with balance
                var tokens: [CryptoCurrency] = []

                // Add native token if it has balance
                if newValue.nativeToken.amount != "0" {
                    tokens.append(newValue.nativeToken.token)
                }

                // Add USDC if it has balance
                if newValue.usdc.amount != "0" {
                    tokens.append(newValue.usdc.token)
                }

                // Add other tokens with balance
                for tokenBalance in newValue.tokens {
                    if tokenBalance.amount != "0" {
                        tokens.append(tokenBalance.token)
                    }
                }

                availableTokens = tokens
                selectedToken = availableTokens.first
            }
        }
    }

    private func triggerTransaction() async {
        defer {
            isSendingTransaction = false
        }

        guard let selectedToken = selectedToken else {
            await showError("No token selected")
            return
        }

        guard let evmAddress = try? EVMAddress(address: recipientWallet) else {
            await showError("Invalid EVM address")
            return
        }

        await MainActor.run {
            isSendingTransaction = true
        }

        do {
            _ = try await wallet.send(
                token: selectedToken,
                recipient: .address(.evm(evmBlockchain, evmAddress)),
                amount: amount
            )

            await MainActor.run {
                self.amount = "0"
                self.recipientWallet = ""
                alertViewModel.show(
                    title: "Transaction Successful",
                    message: "Your transfer has been submitted."
                )
            }
        } catch {
            switch error {
            case .userCancelled:
                // As the user cancelled this, there is nothing to do
                break
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
