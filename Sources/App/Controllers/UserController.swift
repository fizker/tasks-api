import Fluent
import Vapor

class UserController {
	func register(req: Request) async throws -> HTTPResponseStatus {
		let dto = try req.content.decode(RegisterUserDTO.self)

		try await req.db.transaction { db in
			try await self.register(dto, on: db)
		}

		return .created
	}

	func get(req: Request) async throws -> UserDTO {
		let user = try req.auth.require(UserModel.self)
		return try .init(user)
	}

	func update(req: Request) async throws {
		let user = try req.auth.require(UserModel.self)
		let dto = try req.content.decode(UserDTO.self)
		try dto.copy(onto: user)
		try await user.save(on: req.db)
	}

	func register(_ dto: RegisterUserDTO, on db: Database) async throws {
		guard let invite = try await UserInvitationModel.query(on: db)
			.filter(\.$id == dto.token)
			.first()
		else { throw Abort(.notFound) }

		invite.validUntil = Date()
		try await invite.save(on: db)

		let hash = try Bcrypt.hash(dto.password)

		let user = UserModel(name: dto.name, username: dto.username, passwordHash: hash)
		try await user.create(on: db)
	}
}

extension UserModel: ModelAuthenticatable {
	static let usernameKey = \UserModel.$username
	static let passwordHashKey = \UserModel.$passwordHash

	func verify(password: String) throws -> Bool {
		try Bcrypt.verify(password, created: passwordHash)
	}
}
