import Auth
import Combine
import Logger
import Web

extension Logger {
    static let tee = Logger(category: "TEE")
}

@MainActor
public final class CrossmintTEE: ObservableObject {
    public private(set) static var shared: CrossmintTEE?

    public enum Error: Swift.Error, Equatable {
        case handshakeFailed
        case timeout
        case handshakeRequired
        case jwtRequired
        case generic(String)
        case authMissing
        case urlNotAvailable
        case userCancelled
        case invalidSignature
    }
    public let webProxy: WebViewCommunicationProxy

    private let url: URL
    private var isHandshakeCompleted = false
    private let auth: AuthManager
    private let apiKey: String
    public var email: String?

    private var otpContinuation: CheckedContinuation<String, Swift.Error>?
    @Published public var isOTPRequired = false

    init(
        auth: AuthManager,
        webProxy: WebViewCommunicationProxy,
        apiKey: String,
        isProductionEnvironment: Bool
    ) {
        self.webProxy = webProxy
        // swiftlint:disable:next force_unwrapping
        self.url = isProductionEnvironment ? URL(string: "https://signers.crossmint.com")! : URL(string: "https://staging.signers.crossmint.com")!
        self.auth = auth
        self.apiKey = apiKey
    }

    public func signTransaction(
        transaction: String,
        keyType: String,
        encoding: String
    ) async throws(Error) -> String {
        guard isHandshakeCompleted else { throw Error.handshakeRequired }

        guard let jwt = await auth.jwt else {
            Logger.auth.warn("JWT is missing")
            throw .jwtRequired
        }

        let response = try await self.getStatusResponse(jwt: jwt)
        switch response.status {
        case .success:
            guard let signerStatus = response.signerStatus else {
                Logger.tee.debug("Frame returned successful status response without signer: \(response)")
                throw .generic("Signer status missing from response")
            }
            switch signerStatus {
            case .newDevice:
                let onboardingResponse = try await startOnboarding(
                    jwt: jwt,
                    authId: try getAuthId()
                )

                guard onboardingResponse.status == .success else {
                    Logger.tee.error("Received onboarding response error: \(onboardingResponse.errorMessage ?? "")")
                    throw .generic("Invalid NCS status")
                }

                let otpCode: String = try await waitForOTP()
                _ = try await validate(otpCode: otpCode, jwt: jwt)

                return try await sign(
                    .init(
                        jwt: jwt,
                        apiKey: apiKey,
                        messageBytes: transaction,
                        keyType: keyType,
                        encoding: encoding)
                ).stringValue
            case .ready:
                Logger.tee.info("Is ready, and this is the repsonse: \(response)")
                return try await sign(
                    .init(
                        jwt: jwt,
                        apiKey: apiKey,
                        messageBytes: transaction,
                        keyType: keyType,
                        encoding: encoding)
                ).stringValue
            }
        case .error:
            throw .generic(response.errorMessage ?? "Unknown error")
        }
    }

    public func resetState() {
        isHandshakeCompleted = false
        webProxy.resetLoadedContent()
    }

    public func load() async throws(Error) {
        do {
            try await webProxy.loadURL(url)
        } catch {
            throw .urlNotAvailable
        }

        try await tryHandshake(maxAttempts: 3)
    }

    private func tryHandshake(maxAttempts: Int) async throws(Error) {
        for _ in 0..<maxAttempts {
            do {
                try await performHandshake(timeout: 2.0)
                return
            } catch CrossmintTEE.Error.timeout {
                continue
            } catch {
                throw error
            }
        }
        throw Error.handshakeFailed
    }

    private func performHandshake(timeout: TimeInterval = 5.0) async throws(Error) {
        guard !isHandshakeCompleted else { return }

        let randomVerificationId = randomString(length: 10)

        do {
            try await webProxy.sendMessage(
                HandshakeRequest(requestVerificationId: randomVerificationId)
            )

            let handshakeResponse = try await webProxy.waitForMessage(
                ofType: HandshakeResponse.self,
                timeout: timeout
            )

            try await webProxy.sendMessage(
                HandshakeComplete(requestVerificationId: handshakeResponse.data.requestVerificationId)
            )

            isHandshakeCompleted = true
        } catch WebViewError.timeout {
            throw Error.timeout
        } catch {
            throw Error.handshakeFailed
        }
    }

    private func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private func getStatusResponse(jwt: String) async throws(Error) -> GetStatusResponse {
        do {
            try await webProxy.sendMessage(GetStatusRequest(jwt: jwt, apiKey: apiKey))

            let getStatusResponse = try await webProxy.waitForMessage(
                ofType: GetStatusResponse.self,
                timeout: 10.0
            )

            return getStatusResponse
        } catch {
            Logger.tee.error("Failed to get status from frame. Error: \(error)")
            throw .generic("Failed to get status response")
        }
    }

    private func startOnboarding(jwt: String, authId: String) async throws(Error) -> StartOnboardingResponse {
        do {
            try await webProxy.sendMessage(
                StartOnboardingRequest(jwt: jwt, apiKey: apiKey, authId: authId)
            )

            let response = try await webProxy.waitForMessage(
                ofType: StartOnboardingResponse.self,
                timeout: 10.0
            )

            return response
        } catch {
            Logger.tee.error("Failed to onboard: \(error)")
            throw .generic("Failed to start onboarding")
        }
    }

    private func validate(otpCode: String, jwt: String) async throws(Error) -> CompleteOnboardingResponse {
        do {
            try await webProxy.sendMessage(
                CompleteOnboardingRequest(jwt: jwt, apiKey: apiKey, otp: otpCode)
            )
            let response = try await webProxy.waitForMessage(
                ofType: CompleteOnboardingResponse.self,
                timeout: 10.0
            )

            return response
        } catch {
            Logger.tee.info("Failed to validate OTP \(error)")
            throw .generic("Failed to complete onboarding")
        }
    }

    private func getAuthId() throws(Error) -> String {
        guard let email = email else {
            throw .authMissing
        }
        return "email:\(email)"
    }

    private func waitForOTP() async throws(Error) -> String {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                self.otpContinuation = continuation
                self.isOTPRequired = true
            }
        } catch CrossmintTEE.Error.userCancelled {
            throw .userCancelled
        } catch {
            Logger.tee.error("Unknown error waiting for OTP: \(error.localizedDescription)")
            throw .generic("Unknown error happened: \(error.localizedDescription)")
        }
    }

    private func sign(
        _ request: NonCustodialSignRequest
    ) async throws(Error) -> String {
        do {
            _ = try await webProxy.sendMessage(request)
            let response = try await webProxy.waitForMessage(
                ofType: NonCustodialSignResponse.self,
                timeout: 5.0
            )

            guard let bytes = response.signature?.bytes, !bytes.isEmpty else {
                Logger.tee.error("Error signing: frame returned empty signature")
                throw Error.invalidSignature
            }
            return bytes
        } catch {
            Logger.tee.error("Error signing: \(error)")
            if let crossmintError = error as? CrossmintTEE.Error {
                throw crossmintError
            }
            throw .generic("Failed to complete signing")
        }
    }

    public func provideOTP(_ code: String) {
        otpContinuation?.resume(returning: code)
        otpContinuation = nil
        isOTPRequired = false
    }

    public func cancelOTP() {
        otpContinuation?.resume(throwing: CrossmintTEE.Error.userCancelled)
        otpContinuation = nil
        isOTPRequired = false
    }

    @discardableResult
    public static func start(
        auth: AuthManager,
        webProxy: WebViewCommunicationProxy,
        apiKey: String,
        isProductionEnvironment: Bool
    ) -> CrossmintTEE {
        let instance = CrossmintTEE(
            auth: auth,
            webProxy: webProxy,
            apiKey: apiKey,
            isProductionEnvironment: isProductionEnvironment
        )
        CrossmintTEE.shared = instance
        return instance
    }
}
