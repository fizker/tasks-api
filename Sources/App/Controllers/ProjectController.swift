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
		return project.save(on: req.db).map {
			var dto = ProjectDTO(project)
			dto.tasks = []
			return dto
		}
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
		return try await update(projectID: id, from: dto, on: req.db)
	}

	func update(projectID: UUID, from dto: ProjectDTO, on db: Database) async throws -> ProjectDTO {
		var dto = dto
		dto.id = projectID

		guard let project = try await Project.find(projectID, on: db)
		else { throw Abort(.notFound) }

		dto.copy(onto: project)
		try await project.update(on: db)

		let taskController = TaskController()
		let currentTasks = try await taskController.all(db: db, projectID: projectID)
			.get()
		let tasksToUpdate = dto.tasks ?? []
		for task in currentTasks {
			guard let taskID = task.id
			else { continue }

			if !tasksToUpdate.contains(where: { $0.id == taskID }) {
				try await taskController.delete(db: db, projectID: projectID, id: taskID)
			}
		}
		for task in tasksToUpdate {
			if let taskID = currentTasks.first(where: { $0.id == task.id })?.id {
				_ = try await taskController.update(db: db, dto: task, projectID: projectID, id: taskID)
					.get()
			} else {
				_ = try await taskController.create(db: db, dto: task, projectID: projectID)
					.get()
			}
		}

		return try await self.loadSingle(id: projectID, on: db)
	}

	func delete(req: Request, id: UUID) async throws -> HTTPStatus {
		try await delete(id: id, on: req.db)
		return .noContent
	}

	func delete(id: UUID, on db: Database) async throws {
		guard let project = try await Project.find(id, on: db)
		else { throw Abort(.notFound) }

		let taskController = TaskController()
		try await project.$tasks.load(on: db)
		try await withThrowingTaskGroup(of: Void.self) { taskGroup in
			for task in project.tasks {
				taskGroup.addTask {
					try await taskController.delete(db: db, projectID: id, id: try task.requireID())
				}
			}

			for try await _ in taskGroup {
			}
		}

		try await project.delete(on: db)
	}
}
