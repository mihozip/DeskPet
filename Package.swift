// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeskPet", targets: ["DeskPet"])
    ],
    targets: [
        .executableTarget(
            name: "DeskPet",
            path: "Sources/DeskPet",
            exclude: ["Resources"]
        )
    ]
)
