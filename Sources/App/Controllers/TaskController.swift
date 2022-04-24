import Fluent
import Vapor

class TaskController {
	func all(req: Request, projectID: UUID) async throws -> [TaskDTO] {
		return try await all(db: req.db, projectID: projectID)
	}

	func all(db: Database, projectID: UUID) async throws -> [TaskDTO] {
		let tasks = try await Task.query(on: db)
			.filter(\.$project.$id == projectID)
			.sort(\.$sortOrder, .ascending)
			.all()
		return tasks.map(TaskDTO.init)
	}

	func create(req: Request, projectID: UUID) async throws -> TaskDTO {
		let dto = try req.content.decode(TaskDTO.self)
		return try await create(db: req.db, dto: dto, projectID: projectID)
	}
	func create(db: Database, dto: TaskDTO, projectID: UUID) async throws -> TaskDTO {
		var dto = dto
		dto.project = projectID

		if let sortOrder = dto.sortOrder {
			try await updateSortOrder(database: db, projectID: projectID, sortUpdate: .insertNew(new: sortOrder))
		} else {
			dto.sortOrder = try await self.nextSort(database: db, projectID: projectID)
		}

		let task = dto.taskValue
		try await task.save(on: db)
		return TaskDTO(task)
	}

	func get(req: Request, projectID: UUID, id: UUID) async throws -> TaskDTO {
		guard let task = try await Task.find(id, on: req.db), task.$project.id == projectID
		else { throw Abort(.notFound) }

		return TaskDTO(task)
	}

	func update(req: Request, projectID: UUID, id: UUID) async throws -> TaskDTO {
		let dto = try req.content.decode(TaskDTO.self)
		return try await update(db: req.db, dto: dto, projectID: projectID, id: id)
	}
	func update(db: Database, dto: TaskDTO, projectID: UUID, id: UUID) async throws -> TaskDTO {
		return try await db.transaction { database in
			var dto = dto
			dto.id = id
			dto.project = projectID

			guard let task = try await Task.find(id, on: database)
			else { throw Abort(.notFound) }

			if let sortOrder = dto.sortOrder {
				try await self.updateSortOrder(database: database, projectID: projectID, sortUpdate: .moveExisting(old: task.sortOrder, new: sortOrder))
			} else {
				dto.sortOrder = try await self.nextSort(database: database, projectID: projectID)
			}

			dto.copy(onto: task)
			try await task.save(on: database)
			return TaskDTO(task)
		}
	}

	func delete(req: Request, projectID: UUID, id: UUID) async throws -> HTTPStatus {
		try await delete(db: req.db, projectID: projectID, id: id)
		return .noContent
	}

	func delete(db: Database, projectID: UUID, id: UUID) async throws {
		guard let task = try await Task.find(id, on: db), task.$project.id == projectID
		else { throw Abort(.notFound) }

		try await task.delete(on: db)
		try await updateSortOrder(database: db, projectID: projectID, sortUpdate: .deleteExisting(old: task.sortOrder))
	}

	private func nextSort(database: Database, projectID: UUID) async throws -> Int {
		let sortOrder = try await Task.query(on: database)
			.filter(\.$project.$id == projectID)
			.max(\.$sortOrder)

		return (sortOrder ?? 0) + 1
	}

	private enum SortUpdate {
		case insertNew(new: Int)
		case moveExisting(old: Int, new: Int)
		case deleteExisting(old: Int)
	}

	private func updateSortOrder(database: Database, projectID: UUID, oldSort: Int?, newSort: Int) async throws {
		let sortUpdate: SortUpdate = oldSort.map { .moveExisting(old: $0, new: newSort) } ?? .insertNew(new: newSort)
		return try await updateSortOrder(database: database, projectID: projectID, sortUpdate: sortUpdate)
	}

	private func updateSortOrder(database: Database, projectID: UUID, sortUpdate: SortUpdate) async throws {
		var query = Task.query(on: database)
			.filter(\.$project.$id == projectID)

		let direction: Int

		switch sortUpdate {
		case let .moveExisting(old: oldSort, new: newSort):
			if oldSort < newSort {
				// ordered later. move all between down
				direction = -1
				query = query.group(.and) { $0
					.filter(\.$sortOrder > oldSort)
					.filter(\.$sortOrder <= newSort)
				}
			} else {
				// ordered earlier. move all between up
				direction = 1
				query = query.group(.and) { $0
					.filter(\.$sortOrder >= newSort)
					.filter(\.$sortOrder < oldSort)
				}
			}
		case let .insertNew(new: newSort):
			// push everything up
			query = query
				.filter(\.$sortOrder >= newSort)
			direction = 1
		case let .deleteExisting(old: oldSort):
			// push everything down
			query = query
				.filter(\.$sortOrder > oldSort)
			direction = -1
		}

		let tasks = try await query.all()

		for task in tasks {
			task.sortOrder += direction
			try await task.save(on: database)
		}
	}
}
