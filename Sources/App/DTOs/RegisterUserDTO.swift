import Foundation

struct RegisterUserDTO: Codable {
	var token: UUID
	var name: String
	var username: String
	var password: String
}
