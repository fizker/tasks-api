import Fluent

struct CreateTodoSettings: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(TodoSettings.schema)
			.id()
			.field("current_project", .uuid, .references(Project.schema, "id"))
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(TodoSettings.schema)
			.delete()
	}
}
