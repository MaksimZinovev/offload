// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Offload",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/MaksimZinovev/PhotosExport", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Offload",
            dependencies: [
                .product(name: "PhotosExportCore", package: "PhotosExport")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)