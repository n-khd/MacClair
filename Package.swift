// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacClair",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacClair", targets: ["MacClair"])],
    targets: [.executableTarget(name: "MacClair", path: "Sources/MacClair")]
)
