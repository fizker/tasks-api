import Fluent
import Vapor

class ProjectController {
	func all(req: Request) -> EventLoopFuture<[ProjectDTO]> {
		return Project.query(on: req.db)
			.with(\.$tasks)
			.all().map { $0.map(ProjectDTO.init) }
	}

	func create(req: Request) throws -> EventLoopFuture<ProjectDTO> {
		let dto = try req.content.decode(ProjectDTO.self)
		let project = dto.projectValue
		return project.save(on: req.db).map { ProjectDTO(project) }
	}

	private func loadSingle(id: UUID, on db: Database) -> EventLoopFuture<ProjectDTO> {
		return Project.query(on: db)
			.filter(\.$id == id)
			.with(\.$tasks)
			.first()
			.unwrap(or: Abort(.notFound))
			.map(ProjectDTO.init(_:))
	}

	func get(req: Request, id: UUID) -> EventLoopFuture<ProjectDTO> {
		loadSingle(id: id, on: req.db)
	}

	func update(req: Request, id: UUID) throws -> EventLoopFuture<ProjectDTO> {
		var dto = try req.content.decode(ProjectDTO.self)
		dto.id = id
		let project = dto.projectValue
		return project.update(on: req.db)
			.flatMap { self.loadSingle(id: id, on: req.db) }
	}

	func delete(req: Request, id: UUID) -> EventLoopFuture<HTTPStatus> {
		return Project.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMap { $0.delete(on: req.db) }
			.transform(to: .ok)
	}
}
