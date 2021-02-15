import Fluent

struct CreateTask: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Task.schema)
			.id()
			.field("name", .string, .required)
			.field("project", .uuid, .required, .references(Project.schema, "id"))
			.field("description", .string, .required)
			.field("status", .string, .required)
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Task.schema).delete()
	}
}
