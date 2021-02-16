import Foundation

struct TodoDTO: Codable {
	var project: ProjectDTO
	var task: TaskDTO?
}
