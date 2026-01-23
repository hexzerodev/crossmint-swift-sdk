//
//  Transfer.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import Foundation
import Logger

/// The direction of a transfer relative to the wallet.
public enum TransferType: String, Sendable, Hashable {
    /// The transfer was sent from the wallet.
    case outgoing = "wallets.transfer.out"
    /// The transfer was received by the wallet.
    case incoming = "wallets.transfer.in"
}

/// Represents a token transfer event in the wallet's transaction history.
///
/// Use this model to display transaction history in your application. Each transfer
/// contains information about the sender, recipient, token, amount, and timestamp.
///
/// ## Example
///
/// ```swift
/// let result = try await wallet.listTransfers(tokens: [.eth, .usdc])
/// for transfer in result.transfers {
///     print("\(transfer.type): \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
/// }
/// ```
///
public struct Transfer: Sendable, Hashable, Equatable, Identifiable {
    /// Unique identifier for the transfer.
    ///
    /// This is the same as ``transactionHash`` and can be used to look up
    /// the transaction on a blockchain explorer.
    public var id: String {
        transactionHash
    }

    /// The direction of the transfer relative to the wallet.
    public let type: TransferType

    /// The blockchain address that sent the transfer.
    public let fromAddress: String

    /// The blockchain address that received the transfer.
    public let toAddress: String

    /// The unique hash identifying this transaction on the blockchain.
    ///
    /// This can be used to look up the transaction on a blockchain explorer.
    public let transactionHash: String

    /// The symbol of the token involved in the transfer.
    ///
    /// For example: `"ETH"`, `"USDC"`, `"SOL"`. May be `nil` for some transfer types.
    public let tokenSymbol: String?

    /// The human-readable amount of tokens transferred.
    ///
    /// This value has already been adjusted for the token's decimals.
    /// For example, if 1.5 USDC was transferred, this will be `1.5`.
    public let amount: Decimal

    /// The raw amount string as returned by the API.
    ///
    /// Use this if you need the exact string representation for display or further processing.
    public let rawAmount: String

    /// The date and time when the transfer occurred.
    public let timestamp: Date

    /// The mint hash for NFT transfers.
    ///
    /// This identifies the specific NFT that was transferred. Will be `nil` for
    /// fungible token transfers.
    public let mintHash: String?

    public init(
        type: TransferType,
        fromAddress: String,
        toAddress: String,
        transactionHash: String,
        tokenSymbol: String?,
        amount: Decimal,
        rawAmount: String,
        timestamp: Date,
        mintHash: String?
    ) {
        self.type = type
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.transactionHash = transactionHash
        self.tokenSymbol = tokenSymbol
        self.amount = amount
        self.rawAmount = rawAmount
        self.timestamp = timestamp
        self.mintHash = mintHash
    }

}

// MARK: - Mapping

extension Transfer {
    static func map(_ apiModel: TransferApiModel) -> Transfer? {
        let timestamp = Self.parseDate(apiModel.completedAt) ?? Date()
        guard let type = TransferType(rawValue: apiModel.type) else {
            Logger.smartWallet.warn("Unrecognized transfer type", attributes: [
                "type": apiModel.type
            ])
            return nil
        }

        return Transfer(
            type: type,
            fromAddress: apiModel.sender.address,
            toAddress: apiModel.recipient.address,
            transactionHash: apiModel.onChain?.txId ?? "",
            tokenSymbol: apiModel.token.symbol,
            guard let amount = Decimal(string: apiModel.token.amount) else { return nil }
            return Transfer(
                ...
                amount: amount,
            rawAmount: apiModel.token.amount,
            timestamp: timestamp,
            mintHash: nil
        )
    }

    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
