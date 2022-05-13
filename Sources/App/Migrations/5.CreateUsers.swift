import Fluent

struct CreateUsers: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(UserModel.schema)
			.id()
			.field("name", .string, .required)
			.field("username", .string, .required)
			.field("password_hash", .string, .required)
			.unique(on: "username")
			.create()

		try await database.schema(UserInvitationModel.schema)
			.id()
			.field("valid_until", .datetime)
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema(UserInvitationModel.schema).delete()
		try await database.schema(UserModel.schema).delete()
	}
}
