import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

public final class DefaultSmartWalletService: SmartWalletService {
    private let crossmintService: CrossmintService
    private let authManager: AuthManager
    private let jsonCoder: JSONCoder

    public var isProductionEnvironment: Bool {
        crossmintService.isProductionEnvironment
    }

    public init(
        crossmintService: CrossmintService,
        authManager: AuthManager,
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        self.crossmintService = crossmintService
        self.authManager = authManager
        self.jsonCoder = jsonCoder
    }

    public func getWallet(
        _ request: GetMeWalletRequest
    ) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiGetWalletStart, attributes: [
            "locator": "me:\(request.chainType.rawValue)"
        ])

        do {
            let result: WalletApiModel = try await crossmintService.executeRequest(
                Endpoint(
                    path: "/2025-06-09/wallets/me:\(request.chainType.rawValue)",
                    method: .get,
                    headers: authHeaders
                ),
                errorType: WalletError.self
            )

            Logger.smartWallet.info(LogEvents.apiGetWalletSuccess, attributes: [
                "address": result.address
            ])

            return result
        } catch {
            Logger.smartWallet.warn(LogEvents.apiGetWalletError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    public func createWallet(
        _ request: CreateWalletParams
    ) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiCreateWalletStart, attributes: [
            "chain": request.chainType.rawValue,
            "type": request.type.rawValue
        ])

        do {
            let result: WalletApiModel = try await crossmintService.executeRequest(
                Endpoint(
                    path: "/2025-06-09/wallets/me",
                    method: .post,
                    headers: authHeaders,
                    body: try jsonCoder.encodeRequest(
                        request,
                        errorType: WalletError.self
                    )
                ),
                errorType: WalletError.self
            )

            Logger.smartWallet.info(LogEvents.apiCreateWalletSuccess, attributes: [
                "address": result.address
            ])

            return result
        } catch {
            Logger.smartWallet.error(LogEvents.apiCreateWalletError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    public func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances {
        let tokens: [CryptoCurrency] = params.tokens.isEmpty ? CryptoCurrency.allCases : params.tokens
        var queryItems: [URLQueryItem] = []
        if !tokens.isEmpty {
            queryItems.append(.init(name: "tokens", value: tokens.map(\.name).joined(separator: ",")))
        }

        if !params.chains.isEmpty {
            queryItems.append(.init(name: "chains", value: params.chains.map(\.name).joined(separator: ",")))
        }

        return try await crossmintService.executeRequest(
            Endpoint(
                path: "/2025-06-09/wallets/\(params.walletLocator.value)/balances",
                method: .get,
                headers: authHeaders,
                queryItems: queryItems
            ),
            errorType: WalletError.self
        )
    }

    public func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT] {
        let response: [NFTApiModel] = try await crossmintService.executeRequest(
            Endpoint(
                path: "/2022-06-09/wallets/\(params.chain.name):\(params.walletLocator.value)/nfts",
                method: .get,
                headers: authHeaders,
                queryItems: [
                    .init(name: "page", value: "\(params.page)"),
                    .init(name: "perPage", value: "\(params.perPage)")
                ]
            ),
            errorType: WalletError.self
        )
        return response.map { apiModel in
                .map(apiModel)
        }
    }

    public func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let chainType = request.chainType
        let apiRequest = request.request

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions",
            method: .post,
            headers: await authHeaders,
            body: try jsonCoder.encodeRequest(
                    apiRequest,
                    errorType: TransactionError.self
            )
        )

        return try await executeTransactionRequest(
            endpoint: endpoint,
            mapping: chainType.mappingType
        )
    }

    public func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let chainType = request.chainType
        let transactionId = request.transactionId
        let apiRequest = request.apiRequest

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)/approvals",
            method: .post,
            headers: await authHeaders,
            body: try jsonCoder.encodeRequest(
                apiRequest,
                errorType: TransactionError.self
            )
        )

        return try await executeTransactionRequest(
            endpoint: endpoint,
            mapping: chainType.mappingType
        )
    }

    public func fetchTransaction(
        _ fetchTransactionRequest: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let transactionId = fetchTransactionRequest.transactionId
        let chainType = fetchTransactionRequest.chainType

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)",
            method: .get,
            headers: await authHeaders
        )

        return try await executeTransactionRequest(
            endpoint: endpoint,
            mapping: chainType.mappingType
        )
    }

    public func fund(
        _ request: FundWalletRequest
    ) async throws(WalletError) {
        let address = request.address
        let apiRequest: FundWalletApiRequest = FundWalletApiRequest(
            token: request.token,
            amount: request.amount,
            chain: request.chain
        )
        try await crossmintService.executeRequest(
            Endpoint(
                path: "/v1-alpha2/wallets/\(address)/balances",
                method: .post,
                headers: authHeaders,
                body: try jsonCoder.encodeRequest(
                    apiRequest,
                    errorType: WalletError.self
                )
            ),
            errorType: WalletError.self
        )
    }

    public func transferToken(
        chainType: String,
        tokenLocator: String,
        recipient: String,
        amount: String,
        idempotencyKey: String? = nil
    ) async throws(TransactionError) -> any TransactionApiModel {
        Logger.smartWallet.info(LogEvents.apiSendStart, attributes: [
            "walletLocator": "me:\(chainType)",
            "recipient": recipient,
            "token": tokenLocator,
            "amount": amount
        ])

        struct Body: Encodable {
            let recipient: String
            let amount: String
        }

        do {
            let body = Body(
                recipient: recipient,
                amount: amount
            )
            var headers = await authHeaders
            headers["x-idempotency-key"] = idempotencyKey ?? UUID().uuidString
            let endpoint = Endpoint(
                path: "/2025-06-09/wallets/me:\(chainType)/tokens/\(tokenLocator)/transfers",
                method: .post,
                headers: headers,
                body: try jsonCoder.encodeRequest(
                    body,
                    errorType: TransactionError.self
                )
            )

            let result = try await executeTransactionRequest(
                endpoint: endpoint,
                mapping: ChainType(rawValue: chainType).mappingType
            )

            Logger.smartWallet.info(LogEvents.apiSendSuccess, attributes: [
                "transactionId": "\(result.id)"
            ])

            return result
        } catch {
            Logger.smartWallet.error(LogEvents.apiSendError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    public func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel {
        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(request.chainType.rawValue)/signatures",
            method: .post,
            headers: await authHeaders,
            body: try jsonCoder.encodeRequest(
                request.request,
                errorType: SignatureError.self
            )
        )

        if request.request is SignMessageRequest {
            return try await crossmintService.executeRequest(
                endpoint,
                errorType: SignatureError.self
            ) as MessageSignatureResponse
        } else {
            return try await crossmintService.executeRequest(
                endpoint,
                errorType: SignatureError.self
            ) as TypedDataSignatureResponse
        }
    }

    public func approveSignature(
        _ request: SignRequest
    ) async throws(SignatureError) {
        let id = request.transactionId
        let chainType = request.chainType

        try await crossmintService.executeRequest(
            Endpoint(
                path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(id)/approvals",
                method: .post,
                headers: authHeaders,
                body: try jsonCoder.encodeRequest(
                    request.apiRequest,
                    errorType: SignatureError.self
                )
            ),
            errorType: SignatureError.self
        )
    }

    public func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint(
                path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(signatureId)",
                method: .get,
                headers: await authHeaders
            ),
            errorType: SignatureError.self
        )

        struct TypeWrapper: Decodable {
            let type: String
        }

        let typeInfo: TypeWrapper
        do {
            typeInfo = try jsonCoder.decode(TypeWrapper.self, from: data)
        } catch {
            throw .decodingError
        }

        switch typeInfo.type {
        case "message":
            do {
                return try jsonCoder.decode(MessageSignatureResponse.self, from: data)
            } catch {
                throw .decodingError
            }
        case "typed-data":
            do {
                return try jsonCoder.decode(TypedDataSignatureResponse.self, from: data)
            } catch {
                throw .decodingError
            }
        default:
            throw .unknown
        }
    }

    private func executeTransactionRequest<T: WalletTypeTransactionMapping>(
        endpoint: Endpoint,
        mapping: T.Type
    ) async throws(TransactionError) -> any TransactionApiModel {
        let response: T.APIModel = try await crossmintService.executeRequest(
            endpoint,
            errorType: TransactionError.self
        )
        return response
    }

    public func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        Logger.smartWallet.info(LogEvents.apiListTransfersStart, attributes: [
            "walletLocator": params.walletLocator.value,
            "chain": params.chain.name
        ])

        var queryItems: [URLQueryItem] = [
            .init(name: "chain", value: params.chain.name),
            .init(name: "status", value: "successful")
        ]
        if !params.tokens.isEmpty {
            queryItems.append(.init(name: "tokens", value: params.tokens.map(\.name).joined(separator: ",")))
        }

        let chainType = params.chain.chainType.rawValue

        do {
            let response: TransferListApiModel = try await crossmintService.executeRequest(
                Endpoint(
                    path: "/unstable/wallets/me:\(chainType)/transfers",
                    method: .get,
                    headers: await authHeaders,
                    queryItems: queryItems
                ),
                errorType: WalletError.self
            )

            let result = TransferListResult(
                transfers: response.data.compactMap { Transfer.map($0) }
            )

            Logger.smartWallet.info(LogEvents.apiListTransfersSuccess, attributes: [
                "count": "\(result.transfers.count)"
            ])

            return result
        } catch {
            Logger.smartWallet.warn(LogEvents.apiListTransfersError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    public var authHeaders: [String: String] {
        get async {
            guard let jwt = await authManager.jwt else {
                return [:]
            }

            return [
                "Authorization": "Bearer \(jwt)"
            ]
        }
    }
}
