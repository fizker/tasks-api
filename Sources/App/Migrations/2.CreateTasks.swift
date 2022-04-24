import Fluent

struct CreateTask: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(Task.schema)
			.id()
			.field("name", .string, .required)
			.field("project", .uuid, .required, .references(Project.schema, "id"))
			.field("description", .string, .required)
			.field("status", .string, .required)
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema(Task.schema).delete()
	}
}
