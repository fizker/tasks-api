import Foundation
import Fluent
import FluentPostgresDriver

private final class SortableTask: Model {
	static let schema = Task.schema

	@ID(key: .id)
	var id: UUID?

	@Field(key: "sort_order")
	var sortOrder: Int?

	init() {}
}

private enum MigrationError: Error {
	case notPostgres
}

struct SortTasks: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		var sortOrder = 1
		return database.transaction { (database) -> EventLoopFuture<Void> in
			return database.schema(Task.schema)
				.field("sort_order", .int)
				.update()
				.flatMap { _ in database.query(SortableTask.self).all() }
				.flatMapEach(on: database.eventLoop.next()) { task -> EventLoopFuture<Void> in
					task.sortOrder = sortOrder
					sortOrder += 1
					return task.save(on: database)
				}
				.map { _ in database as? PostgresDatabase }
				.unwrap(or: MigrationError.notPostgres)
				.flatMap { database in
					database.query("""
						ALTER TABLE \(Task.schema)
						ALTER COLUMN sort_order SET NOT NULL
						""")
				}
				.map { _ in }
		}
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(TodoSettings.schema)
			.deleteField("sort_order")
			.update()
	}
}
