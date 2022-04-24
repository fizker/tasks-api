import Fluent

struct CreateTodoSettings: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(TodoSettings.schema)
			.id()
			.field("current_project", .uuid, .references(Project.schema, "id"))
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema(TodoSettings.schema)
			.delete()
	}
}
