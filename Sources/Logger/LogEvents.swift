import Foundation

/// Centralized log event names for structured logging
/// All event names follow the pattern: {component}.{operation}.{status}
public enum LogEvents {

    // MARK: - Handshake Events

    /// Handshake operation started
    public static let handshakeStart = "signer.handshake.start"

    /// Handshake completed successfully
    public static let handshakeSuccess = "signer.handshake.success"

    /// Handshake failed
    public static let handshakeError = "signer.handshake.error"

    /// Retrying handshake after failure
    public static let handshakeRetry = "signer.handshake.retry"

    // MARK: - GetStatus Events

    /// Requesting signer status
    public static let getStatusStart = "signer.getStatus.start"

    /// Status retrieved successfully
    public static let getStatusSuccess = "signer.getStatus.success"

    /// Failed to get status
    public static let getStatusError = "signer.getStatus.error"

    /// Retrying status request
    public static let getStatusRetry = "signer.getStatus.retry"

    // MARK: - Onboarding Events

    /// Starting onboarding flow
    public static let onboardingStart = "signer.onboarding.start"

    /// Onboarding started successfully
    public static let onboardingSuccess = "signer.onboarding.success"

    /// Failed to start onboarding
    public static let onboardingError = "signer.onboarding.error"

    /// Starting OTP validation
    public static let onboardingCompleteStart = "signer.onboarding.complete.start"

    /// OTP validated successfully
    public static let onboardingCompleteSuccess = "signer.onboarding.complete.success"

    /// OTP validation failed
    public static let onboardingCompleteError = "signer.onboarding.complete.error"

    // MARK: - Sign Events

    /// Starting signature request
    public static let signStart = "signer.sign.start"

    /// Signature completed successfully
    public static let signSuccess = "signer.sign.success"

    /// Signature failed
    public static let signError = "signer.sign.error"

    // MARK: - Queue Events

    /// Request added to queue
    public static let queueEnqueue = "signer.queue.enqueue"

    /// Request cancelled
    public static let queueCancelled = "signer.queue.cancelled"

    /// Queue error
    public static let queueError = "signer.queue.error"

    /// Processing queued request
    public static let queueProcess = "signer.queue.process"

    /// Request processed successfully
    public static let queueProcessSuccess = "signer.queue.process.success"

    /// Processing failed
    public static let queueProcessError = "signer.queue.process.error"

    /// Failing all queued requests
    public static let queueFailAll = "signer.queue.failAll"

    /// Failed to resume request
    public static let queueResumeError = "signer.queue.resume.error"

    // MARK: - OTP Events

    /// Waiting for user OTP input
    public static let otpWait = "signer.otp.wait"

    /// OTP received from user
    public static let otpReceived = "signer.otp.received"

    /// User provided OTP
    public static let otpProvided = "signer.otp.provided"

    /// User cancelled OTP input
    public static let otpUserCancelled = "signer.otp.userCancelled"

    /// OTP wait cancelled
    public static let otpCancelled = "signer.otp.cancelled"

    /// Newer signature requested
    public static let otpSuperseded = "signer.otp.superseded"

    /// OTP error
    public static let otpError = "signer.otp.error"

    // MARK: - State Management Events

    /// Resetting TEE state
    public static let resetStateStart = "signer.resetState.start"

    /// State reset complete
    public static let resetStateSuccess = "signer.resetState.success"

    /// Error loading TEE
    public static let loadError = "signer.load.error"

    /// Missing email for authId
    public static let getAuthIdError = "signer.getAuthId.error"

    // MARK: - Wallet Factory Events

    /// Getting or creating wallet
    public static let walletGetOrCreateStart = "wallet.getOrCreate.start"

    /// Found existing wallet
    public static let walletGetOrCreateExisting = "wallet.getOrCreate.existing"

    /// Creating new wallet
    public static let walletGetOrCreateCreating = "wallet.getOrCreate.creating"

    /// Getting wallet
    public static let walletGetStart = "wallet.get.start"

    /// Wallet not found
    public static let walletGetNotFound = "wallet.get.notFound"

    /// Wallet retrieved successfully
    public static let walletGetSuccess = "wallet.get.success"

    /// Creating wallet
    public static let walletCreateStart = "wallet.create.start"

    /// Wallet creation failed
    public static let walletCreateError = "wallet.create.error"

    /// Wallet created successfully
    public static let walletCreateSuccess = "wallet.create.success"

    // MARK: - Wallet Operation Events

    /// Starting send transaction
    public static let walletSendStart = "wallet.send.start"

    /// Transaction prepared
    public static let walletSendPrepared = "wallet.send.prepared"

    /// Send completed successfully
    public static let walletSendSuccess = "wallet.send.success"

    /// Send failed
    public static let walletSendError = "wallet.send.error"

    /// Getting wallet balances
    public static let walletBalancesStart = "wallet.balances.start"

    /// Balances retrieved successfully
    public static let walletBalancesSuccess = "wallet.balances.success"

    /// Failed to get balances
    public static let walletBalancesError = "wallet.balances.error"

    /// Starting staging fund
    public static let walletStagingFundStart = "wallet.stagingFund.start"

    /// Staging fund completed
    public static let walletStagingFundSuccess = "wallet.stagingFund.success"

    /// Staging fund failed
    public static let walletStagingFundError = "wallet.stagingFund.error"
}
