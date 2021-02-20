import Fluent
import Vapor

class TaskController {
	func all(req: Request, projectID: UUID) -> EventLoopFuture<[TaskDTO]> {
		return Task.query(on: req.db)
			.filter(\.$project.$id == projectID)
			.all()
			.map { $0.map(TaskDTO.init) }
	}

	func create(req: Request, projectID: UUID) throws -> EventLoopFuture<TaskDTO> {
		var dto = try req.content.decode(TaskDTO.self)
		dto.project = projectID
		let task = dto.taskValue
		return task.save(on: req.db).map { TaskDTO(task) }
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

		let nextSort: EventLoopFuture<Int>
		if let sortOrder = dto.sortOrder {
			nextSort = Task.query(on: req.db)
				.filter(\.$sortOrder >= sortOrder)
				.filter(\.$id != id)
				.filter(\.$project.$id == projectID)
				.all()
				.flatMap {
					var sort = sortOrder + 1
					let updates = $0.map { task -> EventLoopFuture<Void> in
						task.sortOrder = sort
						sort += 1
						return task.save(on: req.db)
					}
					return EventLoopFuture.andAllSucceed(updates, on: req.eventLoop.next())
						.transform(to: sortOrder)
				}
		} else {
			nextSort = Task.query(on: req.db)
				.filter(\.$project.$id == projectID)
				.max(\.$sortOrder)
				.unwrap(orReplace: 1)
		}

		return nextSort.flatMap {
			dto.sortOrder = $0
			let task = dto.taskValue
			return task.save(on: req.db)
				.transform(to: TaskDTO(task))
		}
	}

	func delete(req: Request, projectID: UUID, id: UUID) -> EventLoopFuture<HTTPStatus> {
		return Task.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMapThrowing { task throws -> EventLoopFuture<Void> in
				guard task.$project.id == projectID
				else { throw Abort(.notFound) }
				return task.delete(on: req.db)
			}
			.transform(to: .ok)
	}
}
