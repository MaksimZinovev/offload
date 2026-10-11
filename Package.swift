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
            ],
            // The app bundle's Info.plist (see scripts/make-app.sh);
            // SwiftPM must not treat it as a resource (same as PhotosExport).
            exclude: ["Info.plist"]
        )
    ],
    swiftLanguageModes: [.v5]
)