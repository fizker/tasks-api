import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Vapor

/// Middleware telling the google pervasive-tracking to fuck off
class FLoCMiddleware: AsyncMiddleware {
	static let flocHeader = "Permissions-Policy"
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let response = try await next.respond(to: request)

		response.headers.replaceOrAdd(name: Self.flocHeader, value: "interest-cohort=()")
		return response
	}
}

// configures your application
public func configure(_ app: Application) throws {
	// uncomment to serve files from /Public folder
	// app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.middleware.use(CORSMiddleware())
	app.middleware.use(FLoCMiddleware())

	if app.environment == .testing {
		app.databases.use(.sqlite(.memory), as: .sqlite)
	} else {
		app.databases.use(.postgres(
			hostname: Environment.get("DATABASE_HOST") ?? "localhost",
			port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
			username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
			password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
			database: Environment.get("DATABASE_NAME") ?? "vapor_database"
		), as: .psql)
	}

	for migration in migrations {
		app.migrations.add(migration())
	}

	try app.autoMigrate().wait()

	// register routes
	try routes(app)
}
