import Foundation

struct ProjectDTO: Codable {
	enum CodingKeys: String, CodingKey {
		case id, name, descr = "description", status, tasks
	}

	enum Status: String, Codable {
		case active, onHold
	}

	var id: UUID? = nil
	var name: String
	var descr: String
	var status: Status? = nil
	var tasks: [TaskDTO]? = nil
}
