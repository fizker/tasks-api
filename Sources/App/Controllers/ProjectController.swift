import Fluent
import Vapor

class ProjectController {
	func all(req: Request) async throws -> [ProjectDTO] {
		let projects = try await Project.query(on: req.db)
			.with(\.$tasks)
			.all()

		return projects.map(ProjectDTO.init)
	}

	func create(req: Request) async throws -> ProjectDTO {
		let dto = try req.content.decode(ProjectDTO.self)
		let project = dto.projectValue

		try await project.save(on: req.db)

		var updatedDTO = ProjectDTO(project)
		updatedDTO.tasks = []
		return updatedDTO
	}

	func loadSingle(id: UUID, on db: Database) async throws -> ProjectDTO {
		guard let project = try await Project.query(on: db)
			.filter(\.$id == id)
			.with(\.$tasks)
			.first()
		else { throw Abort(.notFound) }

		return ProjectDTO(project)
	}

	func get(req: Request, id: UUID) async throws -> ProjectDTO {
		try await loadSingle(id: id, on: req.db)
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
			} else {
				_ = try await taskController.create(db: db, dto: task, projectID: projectID)
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
