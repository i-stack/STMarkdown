// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "STMarkdown",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "STMarkdown",
            targets: ["STMarkdown"]
        ),
    ],
    dependencies: [
        // 发布时需依赖包含新版字体 API 的 STBaseProject 2.0 或更高版本：
        // .package(url: "https://github.com/i-stack/STBaseProject.git", from: "2.0.0")
        .package(name: "STBaseProject", path: "../STBaseProject"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
        .package(url: "https://github.com/mgriebling/SwiftMath.git", revision: "48ff188ba118c37d024551238041113560ab09b9")
    ],
    targets: [
        .target(
            name: "STMarkdown",
            dependencies: [
                .product(name: "STBaseProject", package: "STBaseProject"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftMath", package: "SwiftMath", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/STMarkdown",
            resources: [
                .process("Resources")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
