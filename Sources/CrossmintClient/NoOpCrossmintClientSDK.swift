import CrossmintService
import Foundation
import Http
import Wallet

public class NoOpCrossmintClientSDK: ClientSDK {
    public var authManager: any Auth.AuthManager {
        NoOpAuthManager()
    }

    public func crossmintWallets() -> any CrossmintWallets {
        NoOpCrossmintWallets()
    }

    public var crossmintService: CrossmintService {
        NoOpCrossmintService()
    }
}

struct NoOpCrossmintService: CrossmintService {
    private let noOpError = CrossmintServiceError.invalidApiKey(
        "Non-operational CrossmintService used. Review the provided API key."
    )

    public func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> T where T: Decodable, E: ServiceError {
        throw E.fromServiceError(noOpError)
    }

    public func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) where E: ServiceError {
        throw E.fromServiceError(noOpError)
    }

    public func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> Data where E: ServiceError {
        throw E.fromServiceError(noOpError)
    }

    public func getApiBaseURL() throws(CrossmintServiceError) -> URL {
        guard let url = URL(string: "https://example.com") else {
            throw .unknown
        }
        return url
    }

    public var isProductionEnvironment: Bool {
        false
    }
}

struct NoOpAuthManager: AuthManager {
    var authenticationStatus: AuthenticationStatus {
        .nonAuthenticated
    }

    var jwt: String? { nil }
    var email: String? { nil }

    private let invalidAuthManagerError = AuthManagerError.unknown(
        "Non-operational auth manager used. Review the provided API key."
    )

    func otpAuthentication(
        email: String,
        code: String?,
        forceRefresh: Bool
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        throw invalidAuthManagerError
    }

    func setJWT(_ jwt: String) async {}

    func logout() async throws(AuthManagerError) -> OTPAuthenticationStatus {
        throw invalidAuthManagerError
    }

    func reset() async -> OTPAuthenticationStatus {
        .authenticationStatus(.nonAuthenticated)
    }

    #if DEBUG
        func oneTimeSecretAuthentication(
            oneTimeSecret: String
        ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
            throw invalidAuthManagerError
        }
    #endif
}
