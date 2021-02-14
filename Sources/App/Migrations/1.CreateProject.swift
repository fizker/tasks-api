import Fluent

struct CreateProject: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Project.schema)
			.id()
			.field("name", .string, .required)
			.field("description", .string, .required)
			.field(
				"status",
				.enum(.init(
					name: "project_status",
					cases: ["active", "onHold"]
				)),
				.required)
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Project.schema).delete()
	}
}
