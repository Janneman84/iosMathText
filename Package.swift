// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iosMathText",
    platforms: [
        .iOS(.v13), .tvOS(.v13)
    ],
    
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "iosMathText",
            targets: ["iosMathText"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kostub/iosMath.git", from: "2.3.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "iosMathText",
            dependencies: ["iosMath"]
        ),

    ]
//    ,
//    swiftLanguageModes: [.v6]
)
