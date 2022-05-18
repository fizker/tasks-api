import Fluent

struct OAuthAccessToken: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema("access_tokens")
			.id()
			.field("code", .string, .required)
			.field("created_on", .datetime, .required)
			.field("expires_on", .datetime, .required)
			.unique(on: "code")
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema("access_tokens").delete()
	}
}
