import Fluent
import Vapor

extension TodoDTO: Content {
}

class TodoController {
	func currentItem(req: Request) async throws -> TodoDTO {
		let projects = try await Project.query(on: req.db).all()
		let settings = try await TodoSettings.query(on: req.db).first()

		guard let project = projects.first(where: { $0.id == settings?.$currentProject.id }) ?? projects.first
		else { throw Abort(.notFound) }

		let task = try await Task.query(on: req.db)
			.filter(\.$project.$id == project.id!)
			.filter(\.$status != .done)
			.sort(\.$sortOrder, .ascending)
			.first()

		return TodoDTO(project: ProjectDTO(project), task: task.map(TaskDTO.init))
	}

	func moveToNextItem(req: Request) async throws -> TodoDTO {
		let dto = try req.content.decode(UpdateTodoDTO.self)

		let settings = try await TodoSettings.query(on: req.db).first()
			?? TodoSettings()
		let projects = try await Project.query(on: req.db).all()

		guard !projects.isEmpty
		else { throw Abort(.notFound) }

		guard settings.$currentProject.id == nil || settings.$currentProject.id == dto.project
		else { try notImplemented() }

		guard let index = projects.firstIndex(where: { $0.id == dto.project })
		else { try notImplemented() }

		let nextIndex = index + 1

		let project = nextIndex < projects.count
			? projects[nextIndex]
			: projects[0]

		settings.$currentProject.id = project.id
		try await settings.save(on: req.db)

		if let update = dto.task {
			guard let task = try await Task.find(update.id, on: req.db)
			else { throw Abort(.notFound) }

			if task.status != update.status {
				task.status = update.status
				try await task.save(on: req.db)
			}
		}

		return try await self.currentItem(req: req)
	}
}
