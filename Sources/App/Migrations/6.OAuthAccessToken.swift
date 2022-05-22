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

		try await database.schema("refresh_tokens")
			.id()
			.field("token", .string, .required)
			.field("created_on", .datetime, .required)
			.field("refreshes_token", .uuid, .required, .references("access_tokens", .id))
			.field("succeeded_by_token", .uuid, .references("access_tokens", .id))
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema("access_tokens").delete()
	}
}
