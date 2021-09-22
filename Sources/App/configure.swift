import Fluent
import FluentPostgresDriver
import Vapor

/// Middleware telling the google pervasive-tracking to fuck off
class FLoCMiddleware: Middleware {
	static let flocHeader = "Permissions-Policy"
	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		let response = next.respond(to: request)
		return response.map { response in
			response.headers.replaceOrAdd(name: Self.flocHeader, value: "interest-cohort=()")
			return response
		}
	}
}

// configures your application
public func configure(_ app: Application) throws {
	// uncomment to serve files from /Public folder
	// app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.middleware.use(FLoCMiddleware())

	app.databases.use(.postgres(
		hostname: Environment.get("DATABASE_HOST") ?? "localhost",
		port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
		username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
		password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
		database: Environment.get("DATABASE_NAME") ?? "vapor_database"
	), as: .psql)

	for migration in migrations {
		app.migrations.add(migration())
	}

	try app.autoMigrate().wait()

	// register routes
	try routes(app)
}
