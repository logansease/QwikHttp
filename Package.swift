// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "QwikHttp",
    platforms: [
        .macOS(.v10_14), .iOS(.v13), .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "QwikHttp",
            targets: ["QwikHttp"])
    ],
    dependencies: [
        .package(url: "https://github.com/logansease/QwikJson", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "QwikHttp",
            dependencies: [.product(name: "QwikJson", package: "QwikJson")],
            path: "QwikHttp/Classes"
        )
    ]
)
