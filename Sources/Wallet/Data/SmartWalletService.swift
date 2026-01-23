import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService

public protocol SmartWalletService: AuthenticatedService, Sendable {
    var isProductionEnvironment: Bool { get }

    func getWallet(
        _ request: GetMeWalletRequest
    ) async throws(WalletError) -> WalletApiModel

    func createWallet(
        _ request: CreateWalletParams
    ) async throws(WalletError) -> WalletApiModel

    func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances

    func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT]

    func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    func fetchTransaction(
        _ fetchTransactionRequest: FetchTransactionRequest,

    ) async throws(TransactionError) -> any TransactionApiModel

    func fund(
        _ request: FundWalletRequest
    ) async throws(WalletError)

    func transferToken(
        chainType: String,
        tokenLocator: String,
        recipient: String,
        amount: String,
        idempotencyKey: String?
    ) async throws(TransactionError) -> any TransactionApiModel

    func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel

    func approveSignature(
        _ request: SignRequest
    ) async throws(SignatureError)

    func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel

    /// Fetches the transfer history for a wallet.
    ///
    /// - Note: This endpoint uses the `/unstable/` API prefix, meaning the API may change
    ///   without notice. Use with caution in production environments.
    /// - Parameter params: Query parameters including wallet locator, chain, tokens, and pagination options.
    /// - Returns: A `TransferListResult` containing the list of transfers and pagination cursors.
    func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult
}
