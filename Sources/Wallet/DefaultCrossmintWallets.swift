import CrossmintCommonTypes
import CrossmintService
import Logger
import SecureStorage

public final class DefaultCrossmintWallets: CrossmintWallets, Sendable {
    private let smartWalletService: SmartWalletService
    private let secureWalletStorage: SecureWalletStorage

    public init(
        service: SmartWalletService,
        secureWalletStorage: SecureWalletStorage
    ) {
        self.smartWalletService = service
        self.secureWalletStorage = secureWalletStorage

        Logger.smartWallet.info(LogEvents.sdkInitialized)
    }

    public func getOrCreateWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        guard isValid(chain: chain) else {
            let errorMessage = "The chain \(chain.name) is not supported for the current environment"
            Logger.smartWallet.error(LogEvents.walletFactoryGetOrCreateWalletError, attributes: [
                "error": errorMessage
            ])
            throw WalletError.walletCreationFailed(errorMessage)
        }

        Logger.smartWallet.debug(LogEvents.walletGetOrCreateStart, attributes: [
            "chain": chain.name,
            "signerType": signer.signerType.rawValue
        ])

        let walletApiModel: WalletApiModel
        do {
            walletApiModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
            Logger.smartWallet.debug(LogEvents.walletGetOrCreateExisting, attributes: [
                "chain": chain.name,
                "address": walletApiModel.address
            ])
        } catch WalletError.walletNotFound {
            Logger.smartWallet.debug(LogEvents.walletGetOrCreateCreating, attributes: [
                "chain": chain.name
            ])
            walletApiModel = try await createWallet(
                signer: signer,
                chainType: chain.chainType,
                walletType: .smart,
                options: options
            )
        }

        let wallet: Wallet
        switch walletApiModel.chainType {
        case .evm:
            guard let evmChain: EVMChain = EVMChain(chain.name) else {
                throw WalletError.walletInvalidType("The wallet received is not compatible with EVM")
            }

            wallet = try EVMWallet(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: walletApiModel,
                evmChain: evmChain,
                onTransactionStart: options?.experimentalCallbacks.onTransactionStart
            )
        case .solana:
            guard let solanaChain: SolanaChain = SolanaChain(chain.name) else {
                throw WalletError.walletInvalidType("The wallet received is not compatible with Solana")
            }

            wallet = try SolanaWallet(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: walletApiModel,
                solanaChain: solanaChain,
                onTransactionStart: options?.experimentalCallbacks.onTransactionStart
            )
        case .unknown:
            throw .walletGeneric("Unknown wallet chain")
        }

        do {
            try await (signer as? any EmailSigner)?.load()
        } catch {
            Logger.smartWallet.warn(
                """
There was an error initializing the Email signer. \(error.errorDescription)
Review if the .crossmintEnvironmentObject modifier is used as expected.
"""
            )
        }

        return wallet
    }

    private func isValid(chain: AnyChain) -> Bool {
        chain.isValid(isProductionEnvironment: smartWalletService.isProductionEnvironment)
    }

    private func initializeSigner(
        _ effectiveSigner: any Signer
    ) async throws(WalletError) {
        do {
            try await effectiveSigner.initialize(smartWalletService)
        } catch {
            if case let .passkey(passkeyError) = error {
                switch passkeyError {
                case .notSupported:
                    throw .walletCreationFailed("Passkeys not supported")
                case .cancelled:
                    throw .walletCreationCancelled
                case .invalidUser:
                    throw .walletCreationFailed("Invalid user")
                case .timedOut:
                    throw .walletCreationFailed("Timeout")
                case .unknown, .requestFailed, .invalidChallenge, .badConfiguration:
                    throw .walletCreationFailed("Error initializing admin signer.")
                }
            }
            throw .walletCreationFailed("Error initializing admin signer.")
        }
    }

    private func createWallet(
        signer: any Signer,
        chainType: ChainType,
        walletType: WalletType,
        options: WalletOptions?
    ) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.debug(LogEvents.walletCreateStart, attributes: [
            "chainType": chainType.rawValue,
            "signerType": signer.signerType.rawValue
        ])

        try await initializeSigner(signer)

        options?.experimentalCallbacks.onWalletCreationStart()

        do {
            let walletApiModel = try await smartWalletService.createWallet(
                CreateWalletParams(
                    chainType: chainType,
                    type: walletType,
                    config: .init(adminSigner: await signer.adminSigner)
                )
            )

            Logger.smartWallet.debug(LogEvents.walletCreateSuccess, attributes: [
                "chainType": chainType.rawValue,
                "address": walletApiModel.address
            ])

            return walletApiModel
        } catch {
            Logger.smartWallet.error(LogEvents.walletCreateError, attributes: [
                "chainType": chainType.rawValue,
                "error": "\(error)"
            ])
            throw error
        }
    }
}
