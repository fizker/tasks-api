import Foundation
import Fluent

final class UserModel: Model {
	static let schema = "users"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "name")
	var name: String

	@Field(key: "username")
	var username: String

	@Field(key: "password_hash")
	var passwordHash: String

	init() {}

	init(id: UUID? = nil, name: String, username: String, passwordHash: String) {
		self.id = id
		self.name = name
		self.username = username
		self.passwordHash = passwordHash
	}
}
