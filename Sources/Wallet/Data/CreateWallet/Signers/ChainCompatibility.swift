import Foundation

public protocol EVMCompatibleSigner: Sendable {}
public protocol SolanaCompatibleSigner: Sendable {}

public enum EVMSigners: Sendable {
    case email(String)
    case apiKey
    case passkey(name: String, host: String)

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            EVMApiKeySigner()
        case let .email(email):
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .passkey(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}

public enum SolanaSigners: Sendable {
    case email(String)
    case apiKey

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            SolanaApiKeySigner()
        case let .email(email):
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        }
    }
}
