import Foundation
import Logger

public protocol AuthManager: Sendable {
    var jwt: String? { get async }

    func setJWT(_ jwt: String) async
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
