import Foundation
import Fluent
import Vapor

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

extension UserDTO {
	init(_ user: UserModel) throws {
		id = try user.requireID()
		name = user.name
		username = user.username
	}

	func copy(onto user: UserModel) throws {
		user.name = name
		user.username = username
		if let password = password {
			user.passwordHash = try Bcrypt.hash(password)
		}
	}
}
