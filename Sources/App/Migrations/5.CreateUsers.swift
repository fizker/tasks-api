import Vapor
import Fluent

struct CreateUsers: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema("users")
			.id()
			.field("name", .string, .required)
			.field("username", .string, .required)
			.field("password_hash", .string, .required)
			.unique(on: "username")
			.create()

		try await database.schema("user_invitations")
			.id()
			.field("valid_until", .datetime)
			.create()

		// Seeding an admin user
		let adminUser = UserModel(name: "Admin", username: "admin", passwordHash: try Bcrypt.hash("admin"))
		try await adminUser.create(on: database)
	}

	func revert(on database: Database) async throws {
		try await database.schema("user_invitations").delete()
		try await database.schema("users").delete()
	}
}
