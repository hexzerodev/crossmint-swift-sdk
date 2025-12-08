public protocol AuthService: Sendable {
    func validateEmail(
        _ validateEmailRequest: ValidateEmailRequest
    ) async throws(AuthError) -> ValidateEmailResponse

    func validateToken(
        _ validateTokenRequest: ValidateTokenRequest
    ) async throws(AuthError) -> ValidateTokenResponse

    func refreshJWT(
        _ refreshJWTRequest: RefreshJWTRequest
    ) async throws(AuthError) -> RefreshJWTResponse

    func logout(_ logoutRequest: LogoutRequest) async throws(AuthError)
}
