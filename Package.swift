// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(
            name: "MySQL",
            targets: ["MySQL"]
				)
    ],
    targets: [
        .target(
            name: "MySQL",
            dependencies: []
				),
				.testTarget(
					name: "MySQLTests",
					dependencies: ["MySQL"]
				)
    ]
)
