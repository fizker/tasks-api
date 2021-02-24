import Foundation
import Fluent
import Vapor

final class Task: Model {
	typealias Status = TaskDTO.Status

	static let schema = "tasks"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "name")
	var name: String

	@Field(key: "description")
	var descr: String

	@Field(key: "status")
	var status: Status

	@Field(key: "sort_order")
	var sortOrder: Int

	@Parent(key: "project")
	var project: Project

	init() {}

	init(id: UUID? = nil, project: Project, name: String, status: Status = .notStarted, description: String, sortOrder: Int) throws {
		self.id = id
		self.name = name
		self.descr = description
		self.status = status
		self.$project.id = try project.requireID()
		self.sortOrder = sortOrder
	}
}

extension TaskDTO: Content {
}

extension TaskDTO {
	init(_ task: Task) {
		self.id = task.id
		self.name = task.name
		self.descr = task.descr
		self.status = task.status
		self.project = task.$project.id
		self.sortOrder = task.sortOrder
	}

	func copy(onto task: Task) {
		task.id = id
		task.name = name
		task.descr = descr
		task.status = status ?? .notStarted
		if let project = project {
			task.$project.id = project
		}
		if let sortOrder = sortOrder {
			task.sortOrder = sortOrder
		}
	}

	var taskValue: Task {
		let t = Task()
		copy(onto: t)
		return t
	}
}
