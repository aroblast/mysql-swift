// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "MySQLSwift",
    products: [
        .library(
            name: "MySQLSwift",
            targets: ["MySQLSwift"]
				)
    ],
    targets: [
        .target(
            name: "MySQLSwift",
            dependencies: []
				)
    ]
)
