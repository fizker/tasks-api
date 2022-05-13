import Foundation

struct UserDTO: Codable, Equatable {
	var id: UUID
	var name: String
	var username: String
	var password: String?
}
