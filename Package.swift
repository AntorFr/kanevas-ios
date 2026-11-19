// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KanevasCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "KanevasCore", targets: ["KanevasCore"])],
    targets: [
        .target(name: "KanevasCore", path: "Sources/KanevasCore"),
    ]
)
