import Fluent
import Vapor

class TaskController {
	func all(req: Request, projectID: UUID) -> EventLoopFuture<[Task]> {
		return Task.query(on: req.db).all()
	}

	func create(req: Request, projectID: UUID) throws -> EventLoopFuture<Task> {
		let task = try req.content.decode(Task.self)
		task.$project.id = projectID
		return task.save(on: req.db).map { task }
	}

	func get(req: Request, projectID: UUID, id: UUID) -> EventLoopFuture<Task> {
		return Task.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMapThrowing { task throws -> Task in
				guard task.$project.id == projectID
				else { throw Abort(.notFound) }
				return task
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
