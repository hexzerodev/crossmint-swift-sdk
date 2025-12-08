import CrossmintAuth
import CrossmintService
import Wallet

public protocol ClientSDK {
    func crossmintWallets() -> CrossmintWallets
    var authManager: AuthManager { get }
    var crossmintService: CrossmintService { get }
}
