import Foundation

struct TaskDTO: Codable, Equatable {
	enum CodingKeys: String, CodingKey {
		case id, name, descr = "description", status, project
		case sortOrder
	}

	enum Status: String, Codable {
		case notStarted, done
	}

	var id: UUID?
	var name: String
	var descr: String
	var sortOrder: Int?
	var status: Status? = nil
	var project: UUID? = nil
}

extension TaskDTO: Comparable {
	static func < (lhs: TaskDTO, rhs: TaskDTO) -> Bool {
		switch (lhs.sortOrder, rhs.sortOrder) {
		case (nil, nil):
			switch (lhs.id, rhs.id) {
			case (nil, nil): return false
			case (nil, _): return false
			case (_, nil): return true
			case let (lhs?, rhs?): return lhs.uuidString < rhs.uuidString
			}
		case (nil, _): return false
		case (_, nil): return true
		case let (lhs?, rhs?): return lhs < rhs
		}
	}
}
