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

struct SortTasks: AsyncMigration {
	func prepare(on database: Database) async throws {
		return try await database.transaction { (database) async throws in
			try await database.schema(Task.schema)
				.field("sort_order", .int)
				.update()

			var updatedAny = false
			var sortOrder = 1
			for task in try await database.query(SortableTask.self).all() {
				updatedAny = true

				task.sortOrder = sortOrder
				sortOrder += 1
				try await task.save(on: database)
			}

			guard updatedAny
			else { return }

			guard let database = database as? PostgresDatabase
			else { throw MigrationError.notPostgres }

			_ = try await database.query("""
			ALTER TABLE \(Task.schema)
			ALTER COLUMN sort_order SET NOT NULL
			""").get()
		}
	}

	func revert(on database: Database) async throws {
		try await database.schema(TodoSettings.schema)
			.deleteField("sort_order")
			.update()
	}
}
