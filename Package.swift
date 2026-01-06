// swift-tools-version: 6.0

import PackageDescription

let basePlugins: [PackageDescription.Target.PluginUsage] = [
    .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
]

let baseDependencies: [PackageDescription.Target.Dependency] = [
    "Logger",
    "Utils"
]

let package = Package(
    name: "CrossmintSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CrossmintClientSDK",
            targets: [
                "CrossmintClient"
//                "PaymentsUI"
            ]
        ),
        .library(
            name: "CrossmintCheckout",
            targets: [
                "Checkout"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.18.0"),
        .package(url: "https://github.com/airbnb/lottie-spm", from: "4.5.1"),
//        .package(url: "https://github.com/checkout/checkout-ios-components", exact: "1.2.6"),
        .package(url: "https://github.com/bitflying/SwiftKeccak", exact: "0.1.2"),
        .package(url: "https://github.com/attaswift/BigInt", from: "5.4.0"),
        .package(url: "https://github.com/ekscrypto/SwiftEmailValidator", exact: "1.0.4"),
        .package(url: "https://github.com/valpackett/SwiftCBOR", exact: "0.5.0"),
        // Plugins
        // If the Swiftlint version is updated, update the binary in the Makefile.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.59.1")
    ],
    targets: [
        .target(
            name: "CrossmintClient",
            dependencies: baseDependencies + [
                "CrossmintService",
                "Wallet",
                "CrossmintAuth",
                "CrossmintCommonTypes",
//                "Payments",
                "SecureStorage"
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            plugins: basePlugins
        ),
        .target(
            name: "CrossmintCommonTypes",
            dependencies: baseDependencies,
            plugins: basePlugins
        ),
        .target(
            name: "CrossmintService",
            dependencies: baseDependencies + ["Http"],
            plugins: basePlugins
        ),
        .target(
            name: "Http",
            dependencies: baseDependencies,
            plugins: basePlugins
        ),
        .target(
            name: "Logger",
            dependencies: [
                "Utils"
            ],
            plugins: basePlugins
        ),
        .target(
            name: "Wallet",
            dependencies: baseDependencies + [
                "Http",
                "CrossmintService",
                "CrossmintAuth",
                "CrossmintCommonTypes",
                "SecureStorage",
                "Passkeys",
                .product(name: "secp256k1", package: "swift-secp256k1"),
                .product(name: "SwiftKeccak", package: "SwiftKeccak"),
                .product(name: "BigInt", package: "BigInt"),
                "Web"
            ],
            plugins: basePlugins
        ),
        .target(
            name: "Utils",
            dependencies: [
                .product(name: "SwiftEmailValidator", package: "SwiftEmailValidator"),
                .product(name: "BigInt", package: "BigInt")
            ],
            plugins: basePlugins
        ),
        .target(
            name: "CrossmintAuth",
            dependencies: baseDependencies + ["CrossmintService", "SecureStorage"],
            path: "Sources/CrossmintAuth",
            plugins: basePlugins
        ),
        .target(
            name: "SecureStorage",
            dependencies: baseDependencies,
            plugins: basePlugins
        ),
//        .target(
//            name: "Payments",
//            dependencies: baseDependencies + [
//                "Wallet",
//                .product(name: "CheckoutComponents", package: "checkout-ios-components")
//            ],
//            plugins: basePlugins
//        ),
//        .target(
//            name: "PaymentsUI",
//            dependencies: baseDependencies + [
//                "Payments",
//                "CrossmintService",
//                .product(name: "Lottie", package: "lottie-spm"),
//                .product(name: "CheckoutComponents", package: "checkout-ios-components")
//            ],
//            resources: [
//                .process("Resources")
//            ],
//            plugins: basePlugins
//        ),
        .target(
            name: "Passkeys",
            dependencies: baseDependencies + [
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
                .product(name: "BigInt", package: "BigInt")
            ],
            plugins: basePlugins
        ),
        .target(
            name: "Web",
            dependencies: baseDependencies + ["CrossmintAuth"],
            plugins: basePlugins
        ),
        .target(
            name: "Checkout",
            dependencies: baseDependencies,
            plugins: basePlugins
        ),
        //
        // MARK: - Tests
        //
        .testTarget(
            name: "CrossmintCommonTypesTests",
            dependencies: [
                "CrossmintCommonTypes",
                "TestsUtils"
            ],
            plugins: basePlugins
        ),
        .testTarget(
            name: "CrossmintServiceTests",
            dependencies: [
                "CrossmintService"
            ],
            plugins: basePlugins
        ),
        .testTarget(
            name: "WalletTests",
            dependencies: [
                "Wallet",
                "TestsUtils"
            ],
            resources: [
                .process("Resources/Config/SmartWalletConfigResponseEOA.json"),
                .process("Resources/Config/SmartWalletConfigResponsePasskeys.json"),
                .process("Resources/WalletPasskey.json"),
                .process("Resources/WalletEVMKeypair.json"),
                .process("Resources/WalletSolanaFireblocks.json"),
                .process("Resources/WalletSolanaKeypair.json"),
                .process("Resources/Transaction/CreateTransactionAwaitingApproval.json"),
                .process("Resources/Transaction/SignTransactionResponse.json"),
                .process("Resources/Transaction/FailedTransactionResponse.json"),
                .process("Resources/Transaction/CreateSolanaTransactionResponse.json"),
                .process("Resources/Signature/CreateSignatureAwaitingApproval.json"),
                .process("Resources/WalletEVMApiKey.json"),
                .process("Resources/WalletEVMEmail.json"),
                .process("Resources/WalletSolanaEmail.json"),
                .process("Resources/WalletEVMPhone.json")
            ],
            plugins: basePlugins
        ),
//        .testTarget(
//            name: "PaymentTests",
//            dependencies: [
//                "Payments",
//                "TestsUtils"
//            ],
//            resources: [
//                .process("Order/Resources/GetLineItemDeliveryToken.json"),
//                .process("Order/Resources/SolanaLineItemDeliveryTokenOut.json")
//            ],
//            plugins: basePlugins
//        ),
        .testTarget(
            name: "UtilsTests",
            dependencies: [
                "TestsUtils"
            ],
            plugins: basePlugins
        ),
        .testTarget(
            name: "WebTests",
            dependencies: [
                "Web",
                "TestsUtils",
                "CrossmintAuth"
            ],
            plugins: basePlugins
        ),
        .target(
            name: "TestsUtils",
            dependencies: [
                "CrossmintService",
                "Http"
            ]
        )
    ]
)
