import Foundation

struct UserDTO: Codable, Equatable {
	var name: String
	var username: String
	var password: String?
}
