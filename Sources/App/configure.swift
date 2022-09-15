import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Vapor

enum ConfigurationError: Error {
	case invalidDatabaseURL(String)
}

// configures your application
public func configure(_ app: Application) throws {
	// uncomment to serve files from /Public folder
	// app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.middleware.use(CORSMiddleware())
	app.middleware.use(FLoCMiddleware())
	app.middleware.use(OAuthErrorMiddleware())

	if app.environment == .testing {
		app.databases.use(.sqlite(.memory), as: .sqlite)
	} else {
		var tlsConfiguration: TLSConfiguration?

		if Environment.get("DATABASE_ENFORCE_SSL") == "true" {
			tlsConfiguration = TLSConfiguration.makeClientConfiguration()
			tlsConfiguration?.certificateVerification = .none
		}

		if let url = Environment.get("DATABASE_URL") {
			guard var conf = PostgresConfiguration(url: url)
			else { throw ConfigurationError.invalidDatabaseURL(url) }
			if let tlsConfiguration {
				conf.tlsConfiguration = tlsConfiguration
			}

			app.databases.use(.postgres(configuration: conf), as: .psql)
		} else {
			app.databases.use(.postgres(
				hostname: Environment.get("DATABASE_HOST") ?? "localhost",
				port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
				username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
				password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
				database: Environment.get("DATABASE_NAME") ?? "vapor_database",
				tlsConfiguration: tlsConfiguration
			), as: .psql)
		}
	}

	for migration in migrations {
		app.migrations.add(migration())
	}

	try app.autoMigrate().wait()

	// register routes
	try routes(app)
}
