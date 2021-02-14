import Foundation
import Fluent

final class Task: Model {
	enum Status: String, Codable {
		case notStarted, done
	}

	static let schema = "tasks"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "name")
	var name: String

	@Field(key: "description")
	var descr: String

	@Field(key: "status")
	var status: Status

	@Parent(key: "project")
	var project: Project

	init() {}

	init(id: UUID? = nil, project: Project, name: String, status: Status = .notStarted, description: String) throws {
		self.id = id
		self.name = name
		self.descr = description
		self.status = status
		self.$project.id = try project.requireID()
	}
}
