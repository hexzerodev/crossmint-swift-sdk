import Foundation

public struct RefreshJWTResponse: Codable, Sendable {
    public struct RefreshToken: Codable, Sendable {
        let secret: String
        let expiresAt: Date

        enum CodingKeys: String, CodingKey {
            case secret
            case expiresAt
        }
    }

    public struct User: Codable, Sendable {
        let id: String
        let email: String
    }

    let jwt: String
    let refresh: RefreshToken
    let user: User
}
