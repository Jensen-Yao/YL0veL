// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YL0veLPredictionKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "YL0veLPredictionKit", targets: ["YL0veLPredictionKit"])
    ],
    targets: [
        .target(name: "YL0veLPredictionKit", path: "Sources")
    ]
)
