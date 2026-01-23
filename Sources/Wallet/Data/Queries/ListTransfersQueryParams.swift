//
//  ListTransfersQueryParams.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import Foundation

/// Query parameters for listing wallet activity.
public struct ListTransfersQueryParams: Sendable {
    /// The wallet locator to fetch activity for.
    public let walletLocator: WalletLocator

    /// The blockchain to query activity from.
    public let chain: Chain

    /// The tokens to filter activity by.
    public let tokens: [CryptoCurrency]

    public init(
        walletLocator: WalletLocator,
        chain: Chain,
        tokens: [CryptoCurrency]
    ) {
        self.walletLocator = walletLocator
        self.chain = chain
        self.tokens = tokens
    }
}
