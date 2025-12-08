import Logger
import CrossmintService
import SecureStorage

public actor CrossmintAuthManager: AuthManager {
    enum Errors: Error {
        case noBundleIdFound
    }

    private let authService: AuthService
    private let secureStorage: SecureStorage
    private var otpAuthenticationStatus: OTPAuthenticationStatus = .authenticationStatus(.nonAuthenticated)
    private var _authenticationStatus: AuthenticationStatus?
    private var jwtRefreshTimer: Timer?

    public var jwt: String? {
        guard case let .authenticationStatus(.authenticated(_, jwt, _)) = otpAuthenticationStatus else {
            return nil
        }
        return jwt
    }

    public var email: String? {
        guard case let .authenticationStatus(.authenticated(email, _, _)) = otpAuthenticationStatus else {
            return nil
        }
        return email
    }

    public var authenticationStatus: AuthenticationStatus {
        get async throws(AuthError) {
            guard let authenticationStatus = _authenticationStatus else {
                return try await performJWTRefresh(with: getOneTimeSecret())
            }
            return authenticationStatus
        }
    }

    public init(
        authService: AuthService,
        secureStorage: SecureStorage
    ) {
        self.authService = authService
        self.secureStorage = secureStorage
    }

    public init(apiKey apiKeyString: String) throws {
        let apiKey = try ApiKey(key: apiKeyString)
        guard let bundleId = Bundle.main.bundleIdentifier else {
            throw Errors.noBundleIdFound
        }

        let secureStorage = KeychainSecureStorage(bundleId: bundleId)
        let crossmintService = DefaultCrossmintService(apiKey: apiKey, appIdentifier: bundleId)
        self.init(
            authService: DefaultAuthService(crossmintService: crossmintService),
            secureStorage: secureStorage
        )
    }

#if DEBUG
    public func oneTimeSecretAuthentication(
        oneTimeSecret: String
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        do {
            try await refreshJWT(oneTimeSecret)
            return otpAuthenticationStatus
        } catch {
            throw AuthManagerError.serviceError(error.localizedDescription)
        }
    }
#endif

    public func otpAuthentication(
        email: String,
        code: String? = nil,
        forceRefresh: Bool = false
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if forceRefresh || !otpAuthenticationStatus.isAuthenticating {
                otpAuthenticationStatus = try await startEmailValidation(
                    email: normalizedEmail
                )
            } else {
                switch otpAuthenticationStatus {
                case .authenticationStatus(let authenticationStatus):
                    switch authenticationStatus {
                    case .nonAuthenticated:
                        otpAuthenticationStatus = try await startEmailValidation(email: normalizedEmail)
                        jwtRefreshTimer?.invalidate()
                    case .authenticated(let authenticatedEmail, _, _):
                        if authenticatedEmail != normalizedEmail {
                            // swiftlint:disable:next line_length
                            Logger.auth.debug("Starting authentication again. \(email) is different from \(authenticatedEmail)")
                            otpAuthenticationStatus = try await startEmailValidation(email: normalizedEmail)
                            jwtRefreshTimer?.invalidate()
                        } else {
                            Logger.auth.debug("Already authenticated. Use force refresh to authenticate again")
                        }
                    case .authenticating:
                        break
                    }
                case .emailSent(let verifiedEmail, let emailId):
                    if let code {
                        if verifiedEmail == normalizedEmail {
                            try await refreshJWT(
                                try await authService.validateToken(
                                    ValidateTokenRequest(email: verifiedEmail, token: code, emailID: emailId)
                                ).oneTimeSecret
                            )
                        } else {
                            Logger.auth.debug("Email mismatch. Using \(normalizedEmail) to start authentication again")
                            otpAuthenticationStatus = try await startEmailValidation(email: normalizedEmail)
                        }
                    } else {
                        // swiftlint:disable:next line_length
                        Logger.auth.debug("No code received while expecting it. Authentication won't proceed until a code is provided")
                    }

                }
            }
            return otpAuthenticationStatus
        } catch {
            throw AuthManagerError.serviceError(error.errorMessage)
        }
    }

    public func logout() async throws(AuthManagerError) -> OTPAuthenticationStatus {
        guard case let .authenticationStatus(.authenticated(_, _, secret)) = otpAuthenticationStatus else {
            Logger.auth.debug("User is not authenticated. Nothing to logout")
            return otpAuthenticationStatus
        }

        do {
            if !secret.isEmpty {
                try await authService.logout(LogoutRequest(refresh: secret))
            }
            secureStorage.clear()
            otpAuthenticationStatus = .authenticationStatus(.nonAuthenticated)
            _authenticationStatus = .nonAuthenticated
            return otpAuthenticationStatus
        } catch {
            Logger.auth.error("Error while logging out: \(error.localizedDescription)")
            throw AuthManagerError.serviceError(error.errorMessage)
        }
    }

    public func reset() async -> OTPAuthenticationStatus {
        otpAuthenticationStatus = .authenticationStatus(.nonAuthenticated)
        return otpAuthenticationStatus
    }

    public func setJWT(_ jwt: String) async {
        jwtRefreshTimer?.invalidate()
        let authStatus = AuthenticationStatus.authenticated(
            email: "",
            jwt: jwt,
            secret: ""
        )
        otpAuthenticationStatus = .authenticationStatus(authStatus)
        _authenticationStatus = authStatus
    }

    private func startEmailValidation(email: String) async throws(AuthError) -> OTPAuthenticationStatus {
        return .emailSent(
            email: email,
            emailId: try await authService.validateEmail(.init(email: email)).emailId
        )
    }

    @discardableResult
    private func refreshJWT(
        _ oneTimeSecret: String
    ) async throws(AuthError) -> AuthenticationStatus {
        let jwtResponse = try await authService.refreshJWT(RefreshJWTRequest(refresh: oneTimeSecret))

        let jwtExpirationInSeconds = Date().distance(to: jwtResponse.refresh.expiresAt)
        let nextRefreshInSeconds = jwtExpirationInSeconds * 0.9
        jwtRefreshTimer?.invalidate()
        // swiftlint:disable:next line_length
        Logger.auth.debug("JWT will expire in \(jwtExpirationInSeconds) seconds. Schuduling a refresh 10% earlier (\(nextRefreshInSeconds))")
        jwtRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: nextRefreshInSeconds,
            repeats: false
        ) { [weak self] _ in
            Task {
                // swiftlint:disable:next line_length
                guard case let .authenticationStatus(.authenticated(_, _, oneTimeSecret)) = await self?.otpAuthenticationStatus else {
                    throw AuthError.generic("User is not authenticated")
                }
                _ = try await self?.refreshJWT(oneTimeSecret)
            }
        }

        let authStatus = AuthenticationStatus.authenticated(
            email: jwtResponse.user.email,
            jwt: jwtResponse.jwt,
            secret: jwtResponse.refresh.secret
        )
        otpAuthenticationStatus = .authenticationStatus(authStatus)

        await store(authStatus)
        return authStatus
    }

    private func store(_ authenticationStatus: AuthenticationStatus) async {
        switch authenticationStatus {
        case .nonAuthenticated:
            secureStorage.clear()
        case .authenticated(let email, let jwt, let secret):
            try? await secureStorage.storeJWT(jwt)
            try? await secureStorage.storeOneTimeSecret(secret)
            try? await secureStorage.storeEmail(email)
        case .authenticating:
            break
        }
    }

    private func getOneTimeSecret() async throws(AuthError) -> String {
        do {
            return try await secureStorage.getOneTimeSecret() ?? ""
        } catch {
            _authenticationStatus = nil
            throw AuthError.generic("No one time secret found")
        }
    }

    private func performJWTRefresh(with oneTimeSecret: String) async throws(AuthError) -> AuthenticationStatus {
        guard !oneTimeSecret.isEmpty else {
            _authenticationStatus = .nonAuthenticated
            return .nonAuthenticated
        }

        _authenticationStatus = .authenticating
        do {
            let authStatus = try await refreshJWT(oneTimeSecret)
            _authenticationStatus = authStatus
            return authStatus
        } catch {
            if case .signInRequired = error {
                _authenticationStatus = .nonAuthenticated
            } else {
                _authenticationStatus = nil
            }
            throw error
        }
    }
}
