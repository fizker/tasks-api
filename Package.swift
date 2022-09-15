// swift-tools-version:5.7

import PackageDescription

let package = Package(
	name: "tasks",
	platforms: [
		.macOS(.v12),
	],
	dependencies: [
		.package(url: "https://github.com/fizker/swift-oauth2-models.git", from: "0.2.1"),
		.package(url: "https://github.com/vapor/vapor.git", from: "4.57.1"),
		.package(url: "https://github.com/vapor/fluent.git", from: "4.4.0"),
		.package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.2.6"),
		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.1.0"),
	],
	targets: [
		.target(
			name: "App",
			dependencies: [
				.product(name: "Fluent", package: "fluent"),
				.product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
				.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
				.product(name: "OAuth2Models", package: "swift-oauth2-models"),
				.product(name: "Vapor", package: "vapor"),
			],
			swiftSettings: [
				// Enable better optimizations when building in Release configuration. Despite the use of
				// the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
				// builds. See <https://github.com/swift-server/guides#building-for-production> for details.
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
			]
		),
		.executableTarget(name: "Run", dependencies: [.target(name: "App")]),
		.testTarget(name: "AppTests", dependencies: [
			.target(name: "App"),
			.product(name: "XCTVapor", package: "vapor"),
		])
	]
)
