import Fluent
import Vapor

extension TodoDTO: Content {
}

class TodoController {
	func next(req: Request) -> EventLoopFuture<TodoDTO> {
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
}
