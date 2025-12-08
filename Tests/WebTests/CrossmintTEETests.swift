import CrossmintAuth
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE Tests")
@MainActor
// swiftlint:disable:next type_body_length
struct CrossmintTEETests {
    @MainActor
    struct TestFixture {
        let authManager = MockAuthManager()
        let webProxy = MockWebViewCommunicationProxy()
        let apiKey = "test-api-key"
        let tee: CrossmintTEE

        init(isProductionEnvironment: Bool = true) {
            self.tee = CrossmintTEE(
                auth: authManager,
                webProxy: webProxy,
                apiKey: apiKey,
                isProductionEnvironment: isProductionEnvironment
            )
        }

        func setupAuthentication(
            jwt: String? = nil,
            email: String? = nil
        ) async {
            await authManager.setJWT(jwt ?? CrossmintTEETestHelpers.createTestJWT())
            tee.email = email ?? "test@example.com"
        }

        func setupHandshake(verificationId: String = "test123") async throws {
            let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: verificationId)
            webProxy.configureResponse(for: HandshakeResponse.self, response: handshakeResponse)
            try await tee.load()
        }

        func configureReadyDevice() {
            let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
                status: .success,
                signerStatus: .ready
            )
            webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
        }

        func configureNewDevice() {
            let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
                status: .success,
                signerStatus: .newDevice
            )
            webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
        }

        func configureOnboardingFlow() {
            let startOnboardingResponse = CrossmintTEETestHelpers.createStartOnboardingResponse()
            webProxy.configureResponse(for: StartOnboardingResponse.self, response: startOnboardingResponse)

            let completeOnboardingResponse = CrossmintTEETestHelpers.createCompleteOnboardingResponse()
            webProxy.configureResponse(for: CompleteOnboardingResponse.self, response: completeOnboardingResponse)
        }

        func configureSignResponse(signature: String) {
            let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
                signature: signature
            )
            webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)
        }

        func configureErrorResponse(errorMessage: String) {
            let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
                status: .error,
                signerStatus: nil,
                errorMessage: errorMessage
            )
            webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
        }

        func verifyHandshakeCompleted(verificationId: String) {
            let sentHandshakeRequest = webProxy.lastSentMessage(ofType: HandshakeRequest.self)
            #expect(sentHandshakeRequest != nil)

            let sentHandshakeComplete = webProxy.lastSentMessage(ofType: HandshakeComplete.self)
            #expect(sentHandshakeComplete != nil)
            #expect(sentHandshakeComplete?.data.requestVerificationId == verificationId)
        }

        func verifySignRequest(expectedTransaction: String) {
            let statusRequest = webProxy.lastSentMessage(ofType: GetStatusRequest.self)
            #expect(statusRequest != nil)
            #expect(statusRequest?.data.authData.jwt == CrossmintTEETestHelpers.createTestJWT())

            let signRequest = webProxy.lastSentMessage(ofType: NonCustodialSignRequest.self)
            #expect(signRequest != nil)
            #expect(signRequest?.data.data.bytes == expectedTransaction)
        }

        func verifyOnboardingRequests(email: String, otp: String) {
            let startOnboardingRequest = webProxy.lastSentMessage(ofType: StartOnboardingRequest.self)
            #expect(startOnboardingRequest != nil)
            #expect(startOnboardingRequest?.data.data.authId == "email:\(email)")

            let completeOnboardingRequest = webProxy.lastSentMessage(ofType: CompleteOnboardingRequest.self)
            #expect(completeOnboardingRequest != nil)
            #expect(completeOnboardingRequest?.data.data.onboardingAuthentication.encryptedOtp == otp)
        }
    }

    @Test("Successfully completes handshake on first attempt")
    func testSuccessfulHandshakeFirstAttempt() async throws {
        let fixture = TestFixture()
        try await fixture.setupHandshake(verificationId: "test123")

        fixture.verifyHandshakeCompleted(verificationId: "test123")

        #expect(fixture.webProxy.loadedURLs.count == 1)
        #expect(fixture.webProxy.loadedURLs.first?.absoluteString.contains("signers.crossmint.com") == true)
    }

    @Test("Retries handshake on timeout up to 3 times")
    func testHandshakeRetryOnTimeout() async throws {
        let fixture = TestFixture()

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            try await fixture.tee.load()
        }

        let handshakeRequests = fixture.webProxy.sentMessages(ofType: HandshakeRequest.self)
        #expect(handshakeRequests.count == 3)
    }

    @Test("Resets state correctly")
    func testResetState() async throws {
        let fixture = TestFixture()
        try await fixture.setupHandshake()

        fixture.tee.resetState()
        fixture.webProxy.clearResponse(for: HandshakeResponse.self)

        #expect(fixture.webProxy.resetCount == 1)

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            _ = try await fixture.tee.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Load fails when URL is not available")
    func testLoadFailsWhenURLNotAvailable() async throws {
        let fixture = TestFixture()

        fixture.webProxy.shouldThrowOnLoad = true
        fixture.webProxy.loadError = WebViewError.webViewNotAvailable

        await #expect(throws: CrossmintTEE.Error.urlNotAvailable) {
            try await fixture.tee.load()
        }
    }

    @Test("Signs transaction when device is ready")
    func testSignTransactionWhenDeviceReady() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature123")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let signature = try await fixture.tee.signTransaction(
            transaction: transaction,
            keyType: "keyType",
            encoding: "encoding"
        )

        #expect(signature == "0xsignature123")
        fixture.verifySignRequest(expectedTransaction: transaction)
    }

    @Test("Completes full onboarding flow for new device")
    func testFullOnboardingFlowForNewDevice() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature456")

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(fixture.tee.isOTPRequired == true)

        fixture.tee.provideOTP("123456")

        let signature = try await signTask.value
        #expect(signature == "0xsignature456")
        #expect(fixture.tee.isOTPRequired == false)

        fixture.verifyOnboardingRequests(email: "test@example.com", otp: "123456")
    }

    @Test("Signing fails without handshake")
    func testSigningFailsWithoutHandshake() async throws {
        let fixture = TestFixture()

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            _ = try await fixture.tee.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Signing fails without JWT")
    func testSigningFailsWithoutJWT() async throws {
        let fixture = TestFixture()
        try await fixture.setupHandshake()

        await #expect(throws: CrossmintTEE.Error.jwtRequired) {
            _ = try await fixture.tee.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Handles server error response")
    func testHandlesServerErrorResponse() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureErrorResponse(errorMessage: "Server error occurred")

        await #expect(throws: CrossmintTEE.Error.generic("Server error occurred")) {
            _ = try await fixture.tee.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Handles invalid signature response")
    func testHandlesInvalidSignatureResponse() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()

        let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
            signature: "",
            status: .success
        )
        fixture.webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)

        await #expect(throws: CrossmintTEE.Error.invalidSignature) {
            _ = try await fixture.tee.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("OTP cancellation handled correctly")
    func testOTPCancellation() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(fixture.tee.isOTPRequired == true)

        fixture.tee.cancelOTP()

        await #expect(throws: CrossmintTEE.Error.userCancelled) {
            _ = try await signTask.value
        }

        #expect(fixture.tee.isOTPRequired == false)
    }

    @Test("isOTPRequired property updates correctly")
    func testIsOTPRequiredPropertyUpdates() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        #expect(fixture.tee.isOTPRequired == false)

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature789")

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(fixture.tee.isOTPRequired == true)

        fixture.tee.provideOTP("123456")

        _ = try await signTask.value

        #expect(fixture.tee.isOTPRequired == false)
    }

    @Test("Cancelling second duplicate request does not affect first")
    func testCancellingSecondDuplicateRequestDoesNotAffectFirst() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.configureResponseWithDelay(
            for: HandshakeResponse.self,
            response: handshakeResponse,
            delay: 0.3
        )
        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature_first")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()

        let task1 = Task {
            try await fixture.tee.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        let task2 = Task {
            try await fixture.tee.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        task2.cancel()

        let result1 = await task1.result
        let result2 = await task2.result

        switch result1 {
        case .success(let signature):
            #expect(signature == "0xsignature_first")
        case .failure(let error):
            Issue.record("First task should succeed but failed with: \(error)")
        }

        switch result2 {
        case .success:
            Issue.record("Second task should have been cancelled")
        case .failure:
            break
        }
    }

    @Test("Multiple identical requests process independently")
    func testMultipleIdenticalRequestsProcessIndependently() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.configureResponseWithDelay(
            for: HandshakeResponse.self,
            response: handshakeResponse,
            delay: 0.2
        )
        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature_all")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()

        let task1 = Task {
            try await fixture.tee.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        let task2 = Task {
            try await fixture.tee.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        let task3 = Task {
            try await fixture.tee.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        let results = await [task1.result, task2.result, task3.result]

        var successCount = 0
        for result in results {
            switch result {
            case .success(let signature):
                #expect(signature == "0xsignature_all")
                successCount += 1
            case .failure(let error):
                Issue.record("Task failed unexpectedly: \(error)")
            }
        }

        #expect(successCount == 3)
    }
}
