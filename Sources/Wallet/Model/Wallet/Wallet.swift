import CrossmintCommonTypes
import Foundation
import Logger

open class Wallet: @unchecked Sendable {
    public var address: String {
        blockchainAddress.description
    }

    internal let smartWalletService: SmartWalletService
    internal let config: WalletConfig
    internal let blockchainAddress: Address
    internal let signer: any Signer
    internal let chain: Chain

    private let owner: Owner?
    private let createdAt: Date

    private var locator: WalletLocator {
        .address(blockchainAddress)
    }

    private var onTransactionStart: (() -> Void)?

    internal init(
        smartWalletService: SmartWalletService,
        signer: any Signer,
        baseModel: WalletApiModel,
        chain: Chain,
        address: Address,
        onTransactionStart: (() -> Void)?
    ) throws(WalletError) {
        self.smartWalletService = smartWalletService
        self.owner = baseModel.owner
        self.blockchainAddress = address
        self.createdAt = baseModel.createdAt
        self.config = baseModel.config.toDomain
        self.signer = signer
        self.chain = chain
        self.onTransactionStart = onTransactionStart
    }

    public func nfts(page: Int, nftsPerPage: Int) async throws(WalletError) -> [NFT] {
        try await smartWalletService.getNFTs(
            .init(walletLocator: .address(blockchainAddress), chain: chain, page: page, perPage: nftsPerPage)
        )
    }

    /// Fetches the transfer history for this wallet.
    ///
    /// Returns a list of incoming and outgoing transfers for the specified tokens.
    /// Use this method to display transaction history in your application.
    ///
    /// - Parameter tokens: The cryptocurrency tokens to fetch transfers for.
    ///   Common values include `.eth`, `.usdc`, `.sol`, etc.
    ///
    /// - Returns: A ``TransferListResult`` containing the transfer events sorted
    ///   by timestamp (most recent first).
    ///
    /// - Throws: ``WalletError`` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fetch ETH and USDC transfers
    /// let result = try await wallet.listTransfers(tokens: [.eth, .usdc])
    ///
    /// for transfer in result.transfers {
    ///     switch transfer.type {
    ///     case .outgoing:
    ///         print("Sent \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
    ///     case .incoming:
    ///         print("Received \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
    ///     case .unknown:
    ///         break
    ///     }
    /// }
    /// ```
    public func listTransfers(
        tokens: [CryptoCurrency]
    ) async throws(WalletError) -> TransferListResult {
        try await smartWalletService.listTransfers(
            ListTransfersQueryParams(
                walletLocator: .address(blockchainAddress),
                chain: chain,
                tokens: tokens
            )
        )
    }

    public func approve(transactionId id: String) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletApproveStart, attributes: [
            "transactionId": id
        ])

        do {
            let transaction = try await self.transaction(withId: id)
            guard let signedTransaction = try await signAndPollWhilePending(transaction) else {
                throw TransactionError.transactionGeneric("Unknown error")
            }

            Logger.smartWallet.info(LogEvents.walletApproveSuccessTransaction, attributes: [
                "transactionId": signedTransaction.id
            ])

            return signedTransaction
        } catch {
            Logger.smartWallet.error(LogEvents.walletApproveError, attributes: [
                "transactionId": id,
                "error": "\(error)"
            ])
            throw error as? TransactionError ?? .transactionGeneric("Unknown error")
        }
    }

    @available(*, deprecated, renamed: "balances", message: "Use the balances(tokens) instead")
    public func balance(
        of tokens: [CryptoCurrency] = []
    ) async throws(WalletError) -> Balances {
        try await smartWalletService.getBalance(
            .init(
                walletLocator: .address(blockchainAddress),
                tokens: tokens,
                chains: [chain]
            )
        )
    }

    public func balances(
        _ tokens: [CryptoCurrency] = [],
        _ chains: [Chain] = []
    ) async throws(WalletError) -> Balance {
        Logger.smartWallet.debug(LogEvents.walletBalancesStart)

        do {
            let nativeToken = getNativeToken(chain)
            let balances = try await smartWalletService.getBalance(
                .init(
                    walletLocator: .address(blockchainAddress),
                    tokens: tokens + [nativeToken, .usdc],
                    chains: [chain] + chains
                )
            )

            Logger.smartWallet.debug(LogEvents.walletBalancesSuccess)

            return BalanceTransformer.transform(
                from: balances,
                nativeToken: nativeToken,
                requestedTokens: tokens
            )
        } catch {
            Logger.smartWallet.error(LogEvents.walletBalancesError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    public func fund(
        token: CryptoCurrency,
        amount: Int
    ) async throws(WalletError) {
        Logger.smartWallet.debug(LogEvents.walletStagingFundStart, attributes: [
            "token": token.name,
            "amount": "\(amount)",
            "chain": chain.name
        ])

        do {
            try await smartWalletService.fund(
                .init(
                    token: token.name,
                    amount: amount,
                    chain: chain.name,
                    address: blockchainAddress
                )
            )

            Logger.smartWallet.debug(LogEvents.walletStagingFundSuccess)
        } catch {
            Logger.smartWallet.error(LogEvents.walletStagingFundError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    @available(*, deprecated, renamed: "send(_:_:_:)", message: "Use the new send method. This one will be removed.")
    public func send(
        token: CryptoCurrency,
        recipient: TransferTokenRecipient,
        amount: String
    ) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.debug(LogEvents.walletSendStart, attributes: [
            "token": token.name,
            "recipient": recipient.description,
            "amount": amount
        ])

        let transferTokenLocator: TransferTokenLocator
        if let evmChain = EVMChain(chain.name) {
            transferTokenLocator = .currency(.evm(evmChain, token))
        } else if let solanaToken = SolanaSupportedToken.toSolanaSupportedToken(token) {
            transferTokenLocator = .currency(.solana(solanaToken))
        } else if let stellarToken = StellarSupportedToken.toStellarSupportedToken(token) {
            transferTokenLocator = .currency(.stellar(stellarToken))
        } else {
            Logger.smartWallet.error(LogEvents.walletSendError, attributes: [
                "error": "Transaction creation failed"
            ])
            throw .transactionCreationFailed
        }

        guard let transaction = try await transferTokenAndPollWhilePending(
            tokenLocator: transferTokenLocator.description,
            recipient: recipient.description,
            amount: amount
        ) else {
            Logger.smartWallet.error(LogEvents.walletSendError, attributes: [
                "error": "Unknown error"
            ])
            throw TransactionError.transactionGeneric("Unknown error")
        }

        Logger.smartWallet.debug(LogEvents.walletSendSuccess, attributes: [
            "transactionId": transaction.id
        ])

        return transaction
    }

    /// Sends tokens to a recipient.
    /// - Parameters:
    ///   - walletLocator: The recipient wallet address
    ///   - tokenLocator: Token identifier in format "{chain}:{token}" (e.g., "base-sepolia:eth", "solana:usdc")
    ///   - amount: The amount to send as a decimal number
    ///   - idempotencyKey: Optional unique key to prevent duplicate transaction creation. If not provided, a random UUID will be generated.
    /// - Returns: A TransactionSummary containing the transaction details
    public func send(
        _ walletLocator: String,
        _ tokenLocator: String,
        _ amount: Double,
        idempotencyKey: String? = nil
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.debug(LogEvents.walletSendStart, attributes: [
            "recipient": walletLocator,
            "tokenLocator": tokenLocator,
            "amount": "\(amount)"
        ])

        guard let transaction = try await transferTokenAndPollWhilePending(
            tokenLocator: tokenLocator,
            recipient: walletLocator,
            amount: String(amount),
            idempotencyKey: idempotencyKey
        )?.toCompleted() else {
            Logger.smartWallet.error(LogEvents.walletSendError, attributes: [
                "error": "Unknown error"
            ])
            throw TransactionError.transactionGeneric("Unknown error")
        }

        Logger.smartWallet.debug(LogEvents.walletSendSuccess, attributes: [
            "transactionId": transaction.id
        ])

        return transaction.summary
    }

    public func transferToken(
        tokenId: String? = nil,
        recipient: TransferTokenRecipient,
        amount: String
    ) async throws(TransactionError) -> Transaction {
        guard let tokenLocator = getTransferTokenLocator(
            fromChain: chain,
            andTokenId: tokenId
        ) else {
            throw .transactionCreationFailed
        }

        guard let transaction = try await transferTokenAndPollWhilePending(
            tokenLocator: tokenLocator.description,
            recipient: recipient.description,
            amount: amount
        ) else { throw TransactionError.transactionGeneric("Unknown error") }

        return transaction
    }

    internal func sendTransaction(
        _ transactionRequest: any TransactionRequest
    ) async throws(TransactionError) -> Transaction? {
        onTransactionStart?()
        let createdTransaction = try await createTransaction(transactionRequest)
        let signedTransaction = try await signTransactionIfRequired(createdTransaction)

        do {
            return try await pollTransactionWhilePending(transaction: signedTransaction)
        } catch {
            switch error {
            case .serviceError(let crossmintServiceError):
                if case .invalidApiKey = crossmintServiceError {
                    Logger.smartWallet.warn(
                        """
Transaction polling skipped due to insufficient API key permissions.
Transaction was submitted successfully but status cannot be verified.
Transaction ID: \(createdTransaction?.id ?? "unknown")
"""
                    )
                    return createdTransaction
                } else {
                    throw error
                }
            default:
                throw error
            }
        }
    }

    internal func transferTokenAndPollWhilePending(
        tokenLocator: String,
        recipient: String,
        amount: String,
        idempotencyKey: String? = nil
    ) async throws(TransactionError) -> Transaction? {
        onTransactionStart?()
        let createdTransaction = try await smartWalletService.transferToken(
            chainType: chain.chainType.rawValue,
            tokenLocator: tokenLocator,
            recipient: recipient,
            amount: amount,
            idempotencyKey: idempotencyKey
        ).toDomain(withService: smartWalletService)

        let signedTransaction = try await signTransactionIfRequired(createdTransaction)
        return try await pollTransactionWhilePending(transaction: signedTransaction)
    }

    internal func signAndPollWhilePending(
        _ transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        let signedTransaction = try await signTransactionIfRequired(transaction)
        return try await pollTransactionWhilePending(transaction: signedTransaction)
    }

    internal func getTransferTokenLocator(
        fromChain chain: AnyChain,
        andTokenId tokenId: String?
    ) -> TransferTokenLocator? {
        if let tokenId {
            switch blockchainAddress {
            case .evm(let evmAddress):
                guard let evmBlockchain = EVMChain(chain.name) else {
                    return nil
                }
                return .tokenId(.evm(evmBlockchain, evmAddress), tokenId: tokenId)
            case .solana(let solanaAddress):
                return .tokenId(.solana(solanaAddress), tokenId: tokenId)
            case .stellar(let stellarAddress):
                return .tokenId(.stellar(stellarAddress), tokenId: tokenId)
            }
        } else {
            switch blockchainAddress {
            case .evm(let evmAddress):
                guard let evmBlockchain = EVMChain(chain.name) else {
                    return nil
                }
                return .address(.evm(evmBlockchain, evmAddress))
            case .solana(let solanaAddress):
                return .address(.solana(solanaAddress))
            case .stellar(let stellarAddress):
                return .address(.stellar(stellarAddress))
            }
        }
    }

    internal func updateSignerIfRequired() async -> any Signer {
        var updatedSigner: any Signer = signer
        if let passkey = config.adminSigner as? PasskeySignerData {
            if let passkeySigner = updatedSigner as? PasskeySigner {
                updatedSigner = await passkeySigner.updateAdminSigner(
                    passkey
                )
            }
        }
        return updatedSigner
    }

    private func transaction(withId id: String) async throws(TransactionError) -> Transaction {
        guard let transaction = try await smartWalletService.fetchTransaction(
                .init(transactionId: id, chainType: chain.chainType),
        ).toDomain(withService: smartWalletService) else {
            throw TransactionError.transactionGeneric("Unknown error")
        }
        return transaction
    }

    private func approveTransaction(
        transactionId: String,
        message: String
    ) async throws(TransactionError) -> Transaction? {
        let request: SignRequestApi
        do {
            let updatedSigner: any Signer = await updateSignerIfRequired()
            try await updatedSigner.initialize(smartWalletService)
            request = SignRequestApi(
                approvals: try await updatedSigner.approvals(
                    withSignature: try await updatedSigner.sign(message: message)
                )
            )
        } catch {
            switch error {
            case .invalidMessage:
                throw .transactionSigningFailedNoMessage
            case .invalidPrivateKey:
                throw .transactionSigningFailedInvalidKey
            case .cancelled:
                throw .userCancelled
            case .passkey(let passkeyError):
                switch passkeyError {
                case .cancelled:
                    throw .userCancelled
                default:
                    throw .transactionSigningFailed(error)
                }
            case .signingFailed,
                    .invalidAddress,
                    .invalidEmail,
                    .invalidSigner,
                    .notStarted:
                throw .transactionSigningFailed(error)
            }
        }

        return try await smartWalletService.signTransaction(
            .init(
                transactionId: transactionId,
                apiRequest: request,
                chainType: chain.chainType
            )
        ).toDomain(withService: smartWalletService)
    }

    private func createTransaction(
        _ transactionRequest: any TransactionRequest
    ) async throws(TransactionError) -> Transaction? {
        try await smartWalletService.createTransaction(
            .init(request: transactionRequest, chainType: chain.chainType)
        ).toDomain(withService: smartWalletService)
    }

    private func signTransactionIfRequired(
        _ transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        if let transaction, let approvals = transaction.approvals {
            let pendingApprovals = approvals.pending
            guard pendingApprovals.count == 1, let pendingApproval = pendingApprovals.first else {
                throw TransactionError.invalidApprovals(expected: 1, actual: pendingApprovals.count)
            }

            return try await approveTransaction(
                transactionId: transaction.id,
                message: pendingApproval.message
            )
        }
        return transaction
    }

    private func pollTransactionWhilePending(
        transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        guard let transaction else { return nil }

        var updatedTransaction = transaction
        while updatedTransaction.status == .pending || updatedTransaction.status == .awaitingApproval {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second in nanoseconds
            } catch {
                // If sleep fails, continue with the loop
            }

            guard let fetchedTransaction = try await smartWalletService.fetchTransaction(
                .init(transactionId: updatedTransaction.id, chainType: chain.chainType),
            ).toDomain(withService: smartWalletService) else {
                throw TransactionError.transactionGeneric("Unknown error")
            }

            updatedTransaction = fetchedTransaction
        }

        return updatedTransaction
    }

    private func getNativeToken(_ chain: AnyChain) -> CryptoCurrency {
        switch chain.name {
        case SolanaChain.solana.name:
            return .sol
        case StellarChain.stellar.name:
            return .xlm
        default:
            return .eth
        }
    }
}
