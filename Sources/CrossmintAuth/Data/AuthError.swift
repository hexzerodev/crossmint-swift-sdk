import CrossmintService
import Http

public enum AuthError: ServiceError {
    case serviceError(CrossmintServiceError)
    case signInRequired
    case generic(String)

    public static func fromServiceError(_ error: CrossmintServiceError)
        -> AuthError {
        .serviceError(error)
    }

    public static func fromNetworkError(_ error: NetworkError) -> AuthError {
        let message = error.serviceErrorMessage ?? error.localizedDescription
        return switch error {
        case .unauthorized:
            .signInRequired
        case .forbidden:
            .serviceError(.invalidApiKey(message))
        default:
            .generic(message)
        }
    }

    public var errorMessage: String {
        switch self {
        case .serviceError(let crossmintServiceError):
            return crossmintServiceError.errorMessage
        case .generic(let message):
            return message
        case .signInRequired:
            return "Sign in is required as the operation was unauthorized"
        }
    }
}
