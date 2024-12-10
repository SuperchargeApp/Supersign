// swift-tools-version:6.0

import PackageDescription

let cSettings: [CSetting] = [
    .define("_GNU_SOURCE", .when(platforms: [.linux])),
]

let package = Package(
    name: "Supersign",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Supersign",
            targets: ["Supersign"]
        ),
        .library(
            name: "SupersignCLISupport",
            targets: ["SupersignCLISupport"]
        ),
        .executable(
            name: "SupersignCLI",
            targets: ["SupersignCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SuperchargeApp/SuperchargeCore", .upToNextMinor(from: "1.2.0")),
        .package(url: "https://github.com/SuperchargeApp/SwiftyMobileDevice", .upToNextMinor(from: "1.3.0")),
        .package(url: "https://github.com/kabiroberai/swiftpack", .upToNextMinor(from: "1.0.1")),
        .package(url: "https://github.com/kabiroberai/zsign", .upToNextMinor(from: "1.3.0")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.15.0"),
        .package(url: "https://github.com/apple/swift-certificates", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.9.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/attaswift/BigInt", from: "5.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.3.0"),

        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
    ],
    targets: [
        .systemLibrary(name: "CSupersette"),
        .target(
            name: "CSupersign",
            dependencies: [
                .product(name: "OpenSSL", package: "SuperchargeCore")
            ],
            cSettings: cSettings
        ),
        .target(
            name: "DeveloperAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            exclude: ["openapi-generator-config.yaml"]
        ),
        .target(
            name: "Supersign",
            dependencies: [
                "DeveloperAPI",
                "CSupersign",
                .byName(name: "CSupersette", condition: .when(platforms: [.linux])),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "SwiftyMobileDevice", package: "SwiftyMobileDevice"),
                .product(name: "Zupersign", package: "zsign"),
                .product(name: "SignerSupport", package: "SuperchargeCore"),
                .product(name: "ProtoCodable", package: "SuperchargeCore"),
                .product(name: "Superutils", package: "SuperchargeCore"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(
                    name: "OpenAPIAsyncHTTPClient",
                    package: "swift-openapi-async-http-client",
                    condition: .when(platforms: [.linux])
                ),
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client",
                    condition: .when(platforms: [.linux])
                ),
                .product(
                    name: "WebSocketKit",
                    package: "websocket-kit",
                    condition: .when(platforms: [.linux])
                ),
            ],
            cSettings: cSettings
        ),
        .testTarget(
            name: "SupersignTests",
            dependencies: [
                "Supersign",
                .product(name: "SuperutilsTestSupport", package: "SuperchargeCore")
            ],
            exclude: [
                "config/config-template.json",
            ],
            resources: [
                .copy("config/config.json"),
                .copy("config/test.app"),
            ]
        ),
        .target(
            name: "SupersignCLISupport",
            dependencies: [
                "SwiftyMobileDevice",
                "Supersign",
                .product(name: "PackLib", package: "swiftpack"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            cSettings: cSettings
        ),
        .executableTarget(
            name: "SupersignCLI",
            dependencies: [
                "SwiftyMobileDevice",
                "Supersign",
                "SupersignCLISupport",
            ],
            cSettings: cSettings
        ),
    ]
)
