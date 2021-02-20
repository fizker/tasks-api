import Foundation
import Fluent

final class TodoSettings: Model {
	static let schema = "todo_settings"

	@ID(key: .id)
	var id: UUID?

	@OptionalParent(key: "current_project")
	var currentProject: Project?

	init() {}

	init(id: UUID? = nil, currentProject: Project?) throws {
		self.id = id
		self.$currentProject.id = try currentProject?.requireID()
	}
}
