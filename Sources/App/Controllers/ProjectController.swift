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

	func loadSingle(id: UUID, on db: Database) async throws -> ProjectDTO {
		let future = loadSingle(id: id, on: db) as EventLoopFuture<ProjectDTO>
		return try await future.get()
	}

	func get(req: Request, id: UUID) -> EventLoopFuture<ProjectDTO> {
		loadSingle(id: id, on: req.db)
	}

	func update(req: Request, id: UUID) async throws -> ProjectDTO {
		let dto = try req.content.decode(ProjectDTO.self)
		return try await update(id: id, dto: dto, db: req.db)
	}

	func update(id: UUID, dto: ProjectDTO, db: Database) async throws -> ProjectDTO {
		var dto = dto
		dto.id = id

		guard let project = try await Project.find(id, on: db)
		else { throw Abort(.notFound) }

		dto.copy(onto: project)
		try await project.update(on: db)
		return try await self.loadSingle(id: id, on: db)
	}

	func delete(req: Request, id: UUID) -> EventLoopFuture<HTTPStatus> {
		return Project.find(id, on: req.db)
			.unwrap(or: Abort(.notFound))
			.flatMap { $0.delete(on: req.db) }
			.transform(to: .noContent)
	}
}
