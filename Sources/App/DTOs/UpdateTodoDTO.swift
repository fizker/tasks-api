import Foundation

struct UpdateTodoDTO: Codable {
	struct TaskUpdate: Codable {
		var id: UUID
		var status: TaskDTO.Status
	}

	var project: UUID
	var projectStatus: ProjectDTO.Status?

	var task: TaskUpdate?
}
