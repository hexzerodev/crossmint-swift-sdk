public enum EmailSignerError: Error {
    case nonAvailable
    case teeNotStarted
    case generic(String)

    var errorDescription: String {
        switch self {
        case .nonAvailable:
            "Non-Custodial signers system is not available."
        case .generic(let message):
            message
        case .teeNotStarted:
            "Non-Custodial signer is not started"
        }
    }
}

protocol EmailSigner: Signer {
    var crossmintTEE: CrossmintTEE? { get }
    var keyType: String { get async }
    var encoding: String { get async }
    var email: String? { get async }

    func load() async throws(EmailSignerError)
    func processMessage(_ message: String) -> String
}

extension EmailSigner {
    @MainActor
    public func sign(message: String) async throws(SignerError) -> String {
        guard let crossmintTEE = crossmintTEE else { throw .notStarted }
        crossmintTEE.email = await email
        do {
            return try await crossmintTEE.signTransaction(
                transaction: processMessage(message),
                keyType: keyType,
                encoding: encoding
            )
        } catch CrossmintTEE.Error.userCancelled {
            throw .cancelled
        } catch {
            throw .signingFailed
        }
    }

    public func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval] {
        [.keypair(signer: await adminSigner.locator, signature: signature)]
    }

    public func load() async throws(EmailSignerError) {
        guard let crossmintTEE = crossmintTEE else { throw .teeNotStarted }
        do {
            try await crossmintTEE.load()
        } catch {
            if error == .urlNotAvailable {
                throw .nonAvailable
            }
            throw .generic(error.localizedDescription)
        }
    }

}
