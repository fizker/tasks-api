import Fluent
import Vapor

class UserController {
	func registerUser(req: Request) async throws -> HTTPResponseStatus {
		let dto = try req.content.decode(RegisterUserDTO.self)

		try await req.db.transaction { db in
			try await self.registerUser(dto, on: db)
		}

		return .created
	}

	func registerUser(_ dto: RegisterUserDTO, on db: Database) async throws {
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
