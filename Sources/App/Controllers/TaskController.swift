import Fluent
import Vapor

class TaskController {
	func all(req: Request, projectID: UUID) -> EventLoopFuture<[TaskDTO]> {
		return Task.query(on: req.db)
			.filter(\.$project.$id == projectID)
			.sort(\.$sortOrder, .ascending)
			.all()
			.map { $0.map(TaskDTO.init) }
	}

	func create(req: Request, projectID: UUID) throws -> EventLoopFuture<TaskDTO> {
		var dto = try req.content.decode(TaskDTO.self)
		dto.project = projectID

		let nextSort: EventLoopFuture<Int>
		let database = req.db
		if let sortOrder = dto.sortOrder {
			nextSort = updateSortOrder(database: database, projectID: projectID, sortUpdate: .insertNew(new: sortOrder))
				.transform(to: sortOrder)
		} else {
			nextSort = self.nextSort(database: database, projectID: projectID)
		}
		return nextSort
			.flatMap {
				dto.sortOrder = $0
				let task = dto.taskValue
				return task.save(on: req.db)
					.map { TaskDTO(task) }
			}
	}

	func get(req: Request, projectID: UUID, id: UUID) -> EventLoopFuture<TaskDTO> {
		return Task.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMapThrowing { task throws -> TaskDTO in
				guard task.$project.id == projectID
				else { throw Abort(.notFound) }
				return TaskDTO(task)
			}
	}

	func update(req: Request, projectID: UUID, id: UUID) throws -> EventLoopFuture<TaskDTO> {
		var dto = try req.content.decode(TaskDTO.self)
		dto.id = id
		dto.project = projectID

		return req.db.transaction { database in
		return Task.find(id, on: database)
			.unwrap(or: Abort(.notFound))
			.flatMap { task in
				let nextSort: EventLoopFuture<Void>

				if let sortOrder = dto.sortOrder {
					nextSort = self.updateSortOrder(database: database, projectID: projectID, sortUpdate: .moveExisting(old: task.sortOrder, new: sortOrder))
				} else {
					nextSort = self.nextSort(database: database, projectID: projectID)
						.map {
							dto.sortOrder = $0
						}
				}

				return nextSort.transform(to: task)
			}
			.flatMap { (task: Task) in
				dto.copy(onto: task)
				return task.save(on: database)
					.transform(to: TaskDTO(task))
			}
		}
	}

	func delete(req: Request, projectID: UUID, id: UUID) -> EventLoopFuture<HTTPStatus> {
		return Task.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMapThrowing { task throws -> EventLoopFuture<Void> in
				guard task.$project.id == projectID
				else { throw Abort(.notFound) }
				return task.delete(on: req.db)
					.and(self.updateSortOrder(database: req.db, projectID: projectID, sortUpdate: .deleteExisting(old: task.sortOrder)))
					.transform(to: ())
			}
			.transform(to: .noContent)
	}

	private func nextSort(database: Database, projectID: UUID) -> EventLoopFuture<Int> {
		return Task.query(on: database)
			.filter(\.$project.$id == projectID)
			.max(\.$sortOrder)
			.unwrap(orReplace: 0)
			.map { $0 + 1 }
	}

	private enum SortUpdate {
		case insertNew(new: Int)
		case moveExisting(old: Int, new: Int)
		case deleteExisting(old: Int)
	}

	private func updateSortOrder(database: Database, projectID: UUID, oldSort: Int?, newSort: Int) -> EventLoopFuture<Void> {
		let sortUpdate: SortUpdate = oldSort.map { .moveExisting(old: $0, new: newSort) } ?? .insertNew(new: newSort)
		return updateSortOrder(database: database, projectID: projectID, sortUpdate: sortUpdate)
	}

	private func updateSortOrder(database: Database, projectID: UUID, sortUpdate: SortUpdate) -> EventLoopFuture<Void> {
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

		return query
			.all()
			.flatMap {
				let updates = $0.map { task -> EventLoopFuture<Void> in
					task.sortOrder += direction
					return task.save(on: database)
				}
				return EventLoopFuture.andAllSucceed(updates, on: database.eventLoop.next())
					.map { _ in }
			}
	}
}
