// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Refraem",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Refraem",
            path: "Sources/Refraem",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("Vision"),
            ]
        ),
    ]
)
