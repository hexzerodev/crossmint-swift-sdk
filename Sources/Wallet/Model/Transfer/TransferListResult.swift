//
//  TransferListResult.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import Foundation

/// The result of fetching wallet transfer history.
///
/// This struct contains an array of ``Transfer`` events representing the wallet's
/// transaction history. The transfers are sorted by timestamp in descending order
/// (most recent first).
public struct TransferListResult: Sendable {
    /// The array of transfer events.
    ///
    /// Transfers are sorted by timestamp in descending order (most recent first).
    /// This array may be empty if the wallet has no transfer history for the
    /// specified tokens.
    public let transfers: [Transfer]

    public init(transfers: [Transfer]) {
        self.transfers = transfers
    }
}
