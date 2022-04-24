import Fluent

struct CreateProject: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(Project.schema)
			.id()
			.field("name", .string, .required)
			.field("description", .string, .required)
			.field("status", .string, .required)
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema(Project.schema).delete()
	}
}
