import Foundation
import Fluent
import Vapor

final class Project: Model, Content {
	enum Status: String, Codable {
		case active, onHold
	}

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
