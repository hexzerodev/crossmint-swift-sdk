import SwiftUI
import CrossmintClient

struct SplashScreen: View {
    private enum Error {
        case genericError
        case invalidCredentialsStored

        var errorMessage: String {
            switch self {
            case .genericError:
                "There was an error authenticating the user."
            case .invalidCredentialsStored:
                "The stored credentials are invalid. Sign In again."
            }
        }

        var buttonText: String {
            switch self {
            case .genericError:
                "Try again"
            case .invalidCredentialsStored:
                "Go to sign in"
            }
        }

        var icon: String {
            switch self {
            case .genericError:
                "arrow.trianglehead.2.clockwise.rotate.90"
            case .invalidCredentialsStored:
                "key.horizontal"
            }
        }
    }

    private let sdk: CrossmintSDK = .shared

    @State private var isLoading: Bool = false
    @State private var authenticationStatus: AuthenticationStatus?
    @State private var transitionOpacity: Double = 0
    @State private var error: Error?
    @State private var showOTPView = false

    private var authManager: AuthManager {
        sdk.authManager
    }

    @ViewBuilder
    private var splashContent: some View {
        ZStack {
            VStack {
                Image("SplashIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
            }

            VStack {
                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.bottom, 70)
                }
            }

            if let error {
                VStack {
                    Spacer()

                    Text(error.errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    SecondaryButton(text: error.buttonText, icon: error.icon) {
                        Task {
                            switch error {
                            case .genericError:
                                await authenticate()
                            case .invalidCredentialsStored:
                                authenticationStatus = .nonAuthenticated
                            }
                        }
                    }
                    .padding(.bottom, 70)
                    .padding(.top, 24)
                }.padding(.horizontal, 32)
            }
        }
        .ignoresSafeArea()
    }
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if authenticationStatus == nil {
                splashContent
            }

            ZStack {
                if let authenticationStatus = authenticationStatus {
                    switch authenticationStatus {
                    case .nonAuthenticated:
                        SignInView(authenticationStatus: $authenticationStatus)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            ))
                            .opacity(transitionOpacity)
                    case .authenticating:
                        EmptyView()
                    case .authenticated:
                        DashboardView(authenticationStatus: $authenticationStatus)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                            .opacity(transitionOpacity)
                    }
                }
            }
            .animation(AnimationConstants.easeInOut(), value: authenticationStatus)
            .sheet(isPresented: $showOTPView) {
                OTPValidatorView()
            }
        }
        .task {
            await authenticate()
        }
        .onReceive(sdk.$isOTPRequred) {
            showOTPView = $0
        }
    }

    private func authenticate() async {
        error = nil
        guard authenticationStatus == nil else { return }
        isLoading = true
        do {
            authenticationStatus = try await authManager.authenticationStatus
        } catch {
            if case .signInRequired = error {
                self.error = .invalidCredentialsStored
            } else {
                self.error = .genericError
            }
        }
        isLoading = false
        withAnimation(AnimationConstants.easeIn()) {
            transitionOpacity = 1
        }
    }
}

#Preview {
    SplashScreen().environmentObject(CrossmintSDK.shared)
}
