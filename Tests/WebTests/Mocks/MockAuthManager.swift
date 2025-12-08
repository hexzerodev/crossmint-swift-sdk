import Foundation
import CrossmintAuth

actor MockAuthManager: AuthManager {
    private var _jwt: String?

    var jwt: String? {
        get async { _jwt }
    }

    func setJWT(_ jwt: String) async {
        _jwt = jwt
    }
}
