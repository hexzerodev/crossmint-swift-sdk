@available(*, deprecated, message: "Use EVMSigners or SolanaSigners for type-safe chain compatibility")
public enum Signers: Sendable {
    case solanaEmailSigner(email: String)
    case evmEmailSigner(email: String)
    case solanaFireblocksSigner
    case evmFireblocksSigner
    case passkeySigner(name: String, host: String)

    @MainActor
    public var signer: any Signer {
        switch self {
        case .evmFireblocksSigner:
            EVMApiKeySigner()
        case .solanaFireblocksSigner:
            SolanaApiKeySigner()
        case let .solanaEmailSigner(email):
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .evmEmailSigner(email):
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .passkeySigner(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}
