import CrossmintCommonTypes
import Foundation
import Logger

public final class SolanaWallet: Wallet, WalletOnChain, @unchecked Sendable {
    public typealias SpecificChain = SolanaChain

    public static func from(wallet: Wallet) throws(WalletError) -> SolanaWallet {
        guard let SolanaWallet = wallet as? SolanaWallet else {
            throw .walletInvalidType("Cannot create an Solana with the provided wallet")
        }
        return SolanaWallet
    }

    internal init(
        smartWalletService: SmartWalletService,
        signer: any Signer,
        baseModel: WalletApiModel,
        solanaChain: SolanaChain,
        onTransactionStart: (() -> Void)? = nil
    ) throws(WalletError) {
        var effectiveSigner = signer

        switch baseModel.config.adminSigner.type {
        case .apiKey:
            effectiveSigner = SolanaApiKeySigner()
        default:
            break
        }

        do {
            try super.init(
                smartWalletService: smartWalletService,
                signer: effectiveSigner,
                baseModel: baseModel,
                chain: solanaChain.chain,
                address: .solana(SolanaAddress(address: baseModel.address)),
                onTransactionStart: onTransactionStart
            )
        } catch {
            throw .walletInvalidType("The address \(baseModel.address) is not compatible with Solana")
        }
    }

    @available(*, deprecated, renamed: "sendTransaction(transaction:)", message: "Use the new sendTransaction method. This one will be removed.")
    public func sendTransaction(
        transaction: String
    ) async throws(TransactionError) -> Transaction {
        guard let transaction = try await super.sendTransaction(
            CreateSolanaTransactionRequest(transaction: transaction)
        ) else { throw .transactionGeneric("Unknown error") }

        return transaction
    }

    public func sendTransaction(
        transaction: String
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.info(LogEvents.solanaSendTransactionStart)

        guard let tx = try await super.sendTransaction(
            CreateSolanaTransactionRequest(transaction: transaction)
        ) else { throw .transactionGeneric("Unknown error") }

        Logger.smartWallet.info(LogEvents.solanaSendTransactionPrepared, attributes: [
            "transactionId": tx.id
        ])

        guard let completedTransaction = tx.toCompleted() else {
            throw .transactionGeneric("Unknown error")
        }

        Logger.smartWallet.info(LogEvents.solanaSendTransactionSuccess, attributes: [
            "transactionId": completedTransaction.id,
            "hash": completedTransaction.onChain.txId
        ])

        return completedTransaction.summary
    }
}
