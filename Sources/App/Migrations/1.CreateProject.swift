import Fluent

struct CreateProject: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Project.schema)
			.id()
			.field("name", .string, .required)
			.field("description", .string, .required)
			.field("status", .string, .required)
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Project.schema).delete()
	}
}
