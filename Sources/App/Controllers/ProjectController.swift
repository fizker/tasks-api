import Fluent
import Vapor

class ProjectController {
	func all(req: Request) -> EventLoopFuture<[Project]> {
		return Project.query(on: req.db).all()
	}

	func create(req: Request) throws -> EventLoopFuture<Project> {
		let project = try req.content.decode(Project.self)

		return project.save(on: req.db).map { project }
	}

	func get(req: Request, id: UUID) -> EventLoopFuture<Project> {
		return Project.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
	}

	func update(req: Request, id: UUID) throws -> EventLoopFuture<Project> {
		let project = try req.content.decode(Project.self)
		project.id = id
		return project.update(on: req.db)
			.map { project }
	}

	func delete(req: Request, id: UUID) -> EventLoopFuture<HTTPStatus> {
		return Project.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMap { $0.delete(on: req.db) }
			.transform(to: .ok)
	}
}
