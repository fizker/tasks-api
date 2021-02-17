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
		let settings = TodoSettings.query(on: req.db).first()
			.map { $0 ?? TodoSettings() }
		let projects = Project.query(on: req.db).all()

		return settings.and(projects)
			.flatMap { (settings, projects) in
				let project: Project
				if let id = settings.$currentProject.id {
					let index = projects.firstIndex { $0.id == id } ?? 0

					if index < projects.count {
						project = projects[index]
					} else {
						project = projects[0]
					}
				} else if let p = projects.dropFirst().first {
					project = p
				} else if let p = projects.first {
					project = p
				} else {
					notImplemented()
				}

				settings.currentProject = project

				return settings.save(on: req.db)
			}
			.flatMap { self.currentItem(req: req) }
	}
}
