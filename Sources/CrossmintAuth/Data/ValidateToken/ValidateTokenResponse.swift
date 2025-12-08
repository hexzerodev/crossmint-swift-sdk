public struct ValidateTokenResponse: Codable, Sendable {
    let callbackUrl: String
    let oneTimeSecret: String
}
