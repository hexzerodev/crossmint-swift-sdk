import CrossmintService
import Http
import Logger

public final class DefaultAuthService: AuthService {
    private let crossmintService: CrossmintService
    public let jsonCoder: JSONCoder

    public init(
        crossmintService: CrossmintService,
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        self.crossmintService = crossmintService
        self.jsonCoder = jsonCoder
    }

    public func validateEmail(
        _ validateEmailRequest: ValidateEmailRequest
    ) async throws(AuthError) -> ValidateEmailResponse {
        return try await crossmintService.executeRequest(
            Endpoint(
                path: "/2024-09-26/session/sdk/auth/otps/send",
                method: .post,
                body: try jsonCoder.encodeRequest(
                    validateEmailRequest,
                    errorType: AuthError.self
                )
            ),
            errorType: AuthError.self
        )
    }

    public func validateToken(
        _ validateTokenRequest: ValidateTokenRequest
    ) async throws(AuthError) -> ValidateTokenResponse {
        guard let otpCallbackURL = otpCallbackURL else {
            throw .generic("Invalid OTP callback URL")
        }

        return try await crossmintService.executeRequest(
            Endpoint(
                path: "/2024-09-26/session/sdk/auth/authenticate",
                method: .post,
                queryItems: [
                    .init(name: "signinAuthenticationMethod", value: "email"),
                    .init(name: "email", value: validateTokenRequest.email),
                    .init(name: "token", value: validateTokenRequest.token),
                    .init(name: "state", value: validateTokenRequest.emailID),
                    .init(name: "callbackUrl", value: otpCallbackURL)
                ]
            ),
            errorType: AuthError.self
        )
    }

    public func refreshJWT(
        _ refreshJWTRequest: RefreshJWTRequest
    ) async throws(AuthError) -> RefreshJWTResponse {
        return try await crossmintService.executeRequest(
            Endpoint(
                path: "/2024-09-26/session/sdk/auth/refresh",
                method: .post,
                body: try jsonCoder.encodeRequest(
                    refreshJWTRequest,
                    errorType: AuthError.self
                )
            ),
            errorType: AuthError.self
        )
    }

    public func logout(_ logoutRequest: LogoutRequest) async throws(AuthError) {
        try await crossmintService.executeRequest(
            Endpoint(
                path: "/2024-09-26/session/sdk/auth/logout",
                method: .post,
                body: try jsonCoder.encodeRequest(
                    logoutRequest,
                    errorType: AuthError.self
                )
            ),
            errorType: AuthError.self
        )
    }

    private var otpCallbackURL: String? {
        try? crossmintService.getApiBaseURL()
            .appendingPathComponent(
                "/2024-09-26/session/sdk/auth/authenticate/callback"
            )
            .absoluteString
    }
}
