import Foundation
import Fluent
import Vapor

final class Project: Model {
	typealias Status = ProjectDTO.Status

	static let schema = "projects"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "name")
	var name: String

	@Field(key: "description")
	var descr: String

	@Field(key: "status")
	var status: Status

	@Children(for: \.$project)
	var tasks: [Task]

	init() {}

	init(id: UUID? = nil, name: String, status: Status = .active, description: String) {
		self.id = id
		self.name = name
		self.descr = description
		self.status = status
	}
}

extension ProjectDTO: Content {
}

extension ProjectDTO {
	init(_ project: Project) {
		self.id = project.id
		self.name = project.name
		self.descr = project.descr
		self.status = project.status
		self.tasks = project.$tasks.value?.map(TaskDTO.init(_:))
	}

	func copy(onto project: Project) {
		project.id = id
		project.name = name
		project.descr = descr
		project.status = status ?? .active
		project.$tasks.value = tasks?.map(\.taskValue)
	}

	var projectValue: Project {
		let p = Project()
		copy(onto: p)
		return p
	}
}
