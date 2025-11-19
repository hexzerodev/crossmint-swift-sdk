import Foundation
import Logger

public protocol AuthManager: Sendable {
    var jwt: String? { get async }
    var email: String? { get async }

    var authenticationStatus: AuthenticationStatus { get async throws(AuthError) }

    func setJWT(_ jwt: String) async

    func otpAuthentication(
        email: String,
        code: String?,
        forceRefresh: Bool
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus

    #if DEBUG
    func oneTimeSecretAuthentication(
        oneTimeSecret: String
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus
    #endif

    // TODO: This method should NOT be invoked by the developer. Review this.
    func logout() async throws(AuthManagerError) -> OTPAuthenticationStatus

    func reset() async -> OTPAuthenticationStatus
}

extension AuthManager {
    public func otpAuthentication(
        email: String,
        code: String?,
        forceRefresh: Bool
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        throw .unknown("otpAuthentication has not been implemented")
    }

    #if DEBUG
    public func oneTimeSecretAuthentication(
        oneTimeSecret: String
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        throw .unknown("oneTimeSecretAuthentication has not been implemented")
    }
    #endif
}

public enum AuthManagerError: Swift.Error {
    case unknown(String)
    case serviceError(String)

    public var errorMessage: String {
        return switch self {
            case .unknown(let message), .serviceError(let message):
                message
        }
    }
}

public enum AuthenticationStatus: Sendable, Equatable {
    case nonAuthenticated
    case authenticating
    case authenticated(email: String, jwt: String, secret: String)

    public var isAuthenticated: Bool {
        guard case .authenticated = self else {
            return false
        }
        return true
    }
}

public enum OTPAuthenticationStatus: Sendable, Equatable {
    case authenticationStatus(AuthenticationStatus)
    case emailSent(email: String, emailId: String)

    var isAuthenticating: Bool {
        switch self {
        case .emailSent:
            true
        default:
            false
        }
    }

    public var isAuthenticated: Bool {
        jwt != nil
    }

    public var email: String? {
        guard case let .authenticationStatus(.authenticated(email, _, _)) = self else {
            return nil
        }
        return email
    }

    var jwt: String? {
        guard case let .authenticationStatus(.authenticated(_, jwt, _)) = self else {
            return nil
        }
        return jwt
    }
}
