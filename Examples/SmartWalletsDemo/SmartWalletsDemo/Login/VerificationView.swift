import SwiftUI
import CrossmintClient

struct VerificationView: View {
    private let sdk: CrossmintSDK = .shared

    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var verificationCode: String = ""
    @State private var isVerifying: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var opacity: Double = 0

    private var authManager: AuthManager {
        sdk.authManager
    }

    let email: String
    let emailId: String

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("OTP Verification")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 20)

            CustomTextField(
                placeholder: "Verification code",
                text: $verificationCode,
                keyboardType: .numberPad,
                multilineTextAlignment: .center
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)

            PrimaryButton(
                text: "Verify",
                action: verifyCode,
                isLoading: isVerifying,
                isDisabled: verificationCode.isEmpty
            )

            SecondaryButton(
                text: "Resend code",
                icon: "arrow.2.circlepath",
                action: resendCode
            )
            .padding(.top, 5)

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color.white)
        .opacity(opacity)
        .onAppear {
            withAnimation(AnimationConstants.easeIn()) {
                opacity = 1
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func verifyCode() {
        guard !verificationCode.isEmpty else { return }

        isVerifying = true
        Task {
            do {
                let status = try await authManager.otpAuthentication(
                    email: email,
                    code: verificationCode,
                    forceRefresh: false
                )

                isVerifying = false

                if case let .authenticationStatus(authStatus) = status {
                    if case .authenticated = authStatus {
                        withAnimation(AnimationConstants.easeOut()) {
                            opacity = 0
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.duration) {
                            authenticationStatus = authStatus
                        }
                    }
                } else {
                    showAlert(with: "Invalid verification code. Please try again.")
                }
            } catch {
                isVerifying = false
                showAlert(with: "Error: \(error.localizedDescription)")
                print("Error verifying code: \(error)")
            }
        }
    }

    private func resendCode() {
        Task {
            do {
                let status = try await authManager.otpAuthentication(
                    email: email,
                    code: nil,
                    forceRefresh: true
                )

                if case .emailSent = status {
                    showAlert(with: "A new verification code has been sent to your email.")
                }
            } catch {
                showAlert(with: "Error sending new code: \(error.localizedDescription)")
                print("Error resending code: \(error)")
            }
        }
    }

    private func dismiss() {
        withAnimation(AnimationConstants.easeOut()) {
            opacity = 0
        }

        Task {
            _ = await authManager.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.duration) {
                authenticationStatus = .nonAuthenticated
            }
        }
    }

    private func showAlert(with message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    VerificationView(
        authenticationStatus: .constant(nil),
        email: "example@email.com",
        emailId: "sample-id"
    )
    .environmentObject(CrossmintSDK.shared)
}
