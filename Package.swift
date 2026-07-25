// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOptimizationTool",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // UI 비의존 로직. 삭제 안전 규칙·해시·번역·업데이트 검증이 여기 있고, 테스트 대상이다.
        .target(
            name: "MacOptimizationCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // SwiftUI 앱 본체.
        .executableTarget(
            name: "MacOptimizationTool",
            dependencies: ["MacOptimizationCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MacOptimizationCoreTests",
            dependencies: ["MacOptimizationCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
