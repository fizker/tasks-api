import Fluent
import Vapor

class TaskController {
	func all(req: Request, projectID: UUID) -> EventLoopFuture<[TaskDTO]> {
		return Task.query(on: req.db).all().map { $0.map(TaskDTO.init) }
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

	func update(req: Request, projectID: UUID, id: UUID) -> Response {
		notImplemented()
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
