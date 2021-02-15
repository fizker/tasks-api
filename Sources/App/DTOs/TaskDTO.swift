import Foundation

struct TaskDTO: Codable {
	enum CodingKeys: String, CodingKey {
		case id, name, descr = "description", status, project
	}

	enum Status: String, Codable {
		case notStarted, done
	}

	var id: UUID?
	var name: String
	var descr: String
	var status: Status? = nil
	var project: UUID? = nil
}
