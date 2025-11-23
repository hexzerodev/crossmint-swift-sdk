import SwiftUI
import CrossmintClient

struct OTPValidatorView: View {
    private let sdk: CrossmintSDK = .shared
    
    @State private var verificationCode: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var opacity: Double = 0

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
                isDisabled: verificationCode.isEmpty
            )

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
        sdk.submit(otp: verificationCode)
    }

    private func dismiss() {
        withAnimation(AnimationConstants.easeOut()) {
            opacity = 0
        }
        sdk.cancelTransaction()
    }

    private func showAlert(with message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    OTPValidatorView()
}
