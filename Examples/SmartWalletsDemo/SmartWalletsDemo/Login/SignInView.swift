import SwiftUI
import CrossmintClient

struct SignInView: View {
    private let sdk: CrossmintSDK = .shared

    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var email: String = ""
    @State private var isSigningIn: Bool = false
    @State private var otpAuthenticationStatus: OTPAuthenticationStatus?
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showOTPVerification: Bool = false
    @State private var emailId: String = ""
    @State private var opacity: Double = 0

    private var authManager: AuthManager {
        sdk.authManager
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Image("SplashIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)

                Text("EVM Quickstart")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("The easiest way to build onchain")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
                .frame(height: 40)

            CustomTextField(
                placeholder: "email@example.com",
                text: $email,
                keyboardType: .emailAddress
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textContentType(.emailAddress)

            PrimaryButton(
                text: "Sign in",
                action: signIn,
                isLoading: isSigningIn,
                isDisabled: email.isEmpty
            )

            Spacer()

            CrossmintPoweredView()
            .padding(.bottom, 20)
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
        .sheet(isPresented: $showOTPVerification) {
            VerificationView(
                authenticationStatus: Binding(get: {
                    authenticationStatus
                }, set: { value, _ in
                    showOTPVerification = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.duration) {
                        withAnimation(AnimationConstants.easeInOut()) {
                            authenticationStatus = value
                        }
                    }
                }),
                email: email,
                emailId: emailId
            )
            .presentationDetents([.medium])
        }
    }

    private func signIn() {
        guard !email.isEmpty else { return }

        isSigningIn = true
        Task {
            do {
                let status = try await authManager.otpAuthentication(
                    email: email,
                    code: nil,
                    forceRefresh: false
                )
                otpAuthenticationStatus = status
                isSigningIn = false

                if case let .emailSent(_, id) = status {
                    self.emailId = id
                    self.showOTPVerification = true
                }
            } catch let authError as AuthManagerError {
                isSigningIn = false
                showAlert(with: "\(authError.errorMessage)")
            }
        }
    }

    private func showAlert(with message: String) {
        alertMessage = message
        showAlert = true
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    SignInView(authenticationStatus: .constant(nil))
        .environmentObject(CrossmintSDK.shared)
}
