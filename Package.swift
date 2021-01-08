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
	dependencies: [
		.package(name: "Socket", url: "https://github.com/aroblast/socket-swift.git", .branch("master"))
	],
	targets: [
		.target(
			name: "MySQL",
			dependencies: ["Socket"]
		),
		.testTarget(
			name: "MySQLTests",
			dependencies: ["MySQL"]
		)
	]
)
