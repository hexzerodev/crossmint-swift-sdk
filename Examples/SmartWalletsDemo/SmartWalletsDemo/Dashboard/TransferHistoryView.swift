//
//  TransferHistoryView.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import SwiftUI
import Wallet

struct TransferHistoryView: View {
    let wallet: Wallet

    @State private var transfers: [Transfer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let tokens: [CryptoCurrency] = [.eth, .usdc, .usdxm]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity History")
                .font(.title2)
                .fontWeight(.bold)

            Text("Recent activity for this wallet")
                .font(.subheadline)
                .foregroundColor(.gray)

            if isLoading && transfers.isEmpty {
                loadingView
            } else if let errorMessage = errorMessage, transfers.isEmpty {
                errorView(message: errorMessage)
            } else if transfers.isEmpty {
                emptyView
            } else {
                transferListView
            }
        }
        .padding(.top, 16)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if transfers.isEmpty {
                fetchTransfers()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)

            Text("Loading activity history...")
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

            Text("Error loading activity")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button("Retry") {
                fetchTransfers()
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

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            Text("No activity yet")
                .font(.headline)

            Text("Your activity history will appear here once you make or receive transfers.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var transferListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(transfers) { transfer in
                    TransferRowView(transfer: transfer)
                }
            }
            .padding(.bottom, 16)
        }
        .refreshable {
            fetchTransfers(showLoading: false)
        }
    }

    private func fetchTransfers(showLoading: Bool = true) {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        Task {
            do {
                let result = try await wallet.listTransfers(tokens: tokens)

                await MainActor.run {
                    transfers = result.transfers
                    isLoading = false
                }
            } catch let walletError as WalletError {
                await MainActor.run {
                    errorMessage = walletError.errorMessage
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct TransferRowView: View {
    let transfer: Transfer

    private var isOutgoing: Bool {
        transfer.type == .outgoing
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transfer.timestamp)
    }

    private var formattedAmount: String {
        let symbol = transfer.tokenSymbol?.uppercased() ?? "TOKEN"
        return "\(transfer.amount) \(symbol)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Direction icon
            Image(systemName: isOutgoing ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isOutgoing ? .orange : .green)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isOutgoing ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(isOutgoing ? "Sent" : "Received")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(isOutgoing ? "-" : "+")\(formattedAmount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isOutgoing ? .primary : .green)
                }

                HStack {
                    Text(isOutgoing ? "To: " : "From: ")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(truncateAddress(isOutgoing ? transfer.toAddress : transfer.fromAddress))
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    // Activity type badge
                    Text(isOutgoing ? "Outgoing" : "Incoming")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                }

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(.gray)

                // Transaction hash link
                HStack(spacing: 4) {
                    Text("Tx: \(truncateAddress(transfer.transactionHash))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func truncateAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
