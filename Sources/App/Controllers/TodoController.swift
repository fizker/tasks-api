import Fluent
import Vapor

extension TodoDTO: Content {
}

class TodoController {
	func currentItem(req: Request) -> EventLoopFuture<TodoDTO> {
		let projects = Project.query(on: req.db).all()
		let settings = TodoSettings.query(on: req.db).first()

		return settings.and(projects)
			.map { (settings, projects) -> Project? in
				if
					let id = settings?.$currentProject.id,
					let project = projects.first(where: { $0.id == id })
				{
					return project
				} else {
					return projects.first
				}
			}
			.unwrap(or: Abort(.notFound))
			.flatMap { project in
				Task.query(on: req.db)
					.filter(\.$project.$id == project.id!)
					.filter(\.$status != .done)
					.first()
					.and(value: project)
			}
			.map { (task, project) in
				TodoDTO(project: ProjectDTO(project), task: task.map(TaskDTO.init))
			}
	}

	func moveToNextItem(req: Request) throws -> EventLoopFuture<TodoDTO> {
		let dto = try req.content.decode(UpdateTodoDTO.self)

		let settings = TodoSettings.query(on: req.db).first()
			.map { $0 ?? TodoSettings() }
		let projects = Project.query(on: req.db).all()

		return settings.and(projects)
			.flatMapThrowing { (settings, projects) -> (TodoSettings, Project) in
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

				return (settings, project)
			}
			.flatMap { (settings, project) in
				settings.$currentProject.id = project.id
				return settings.save(on: req.db)
			}
			.flatMap {
				guard let task = dto.task
				else { return req.eventLoop.future() }

				return Task.find(task.id, on: req.db)
					.unwrap(or: Abort(.notFound))
					.flatMap {
						guard $0.status != task.status
						else { return req.eventLoop.future() }

						$0.status = task.status
						return $0.save(on: req.db)
					}
			}
			.flatMap { self.currentItem(req: req) }
	}
}
