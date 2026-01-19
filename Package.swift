// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwagManager",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SwagManager", targets: ["SwagManager"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SwagManager",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                "SwiftSoup",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "SwagManager"
        )
    ]
)
