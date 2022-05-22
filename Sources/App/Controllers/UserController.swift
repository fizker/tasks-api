import Fluent
import Vapor
import OAuth2Models

class UserController {
	func register(req: Request) async throws -> HTTPResponseStatus {
		let dto = try req.content.decode(RegisterUserDTO.self)

		try await req.db.transaction { db in
			try await self.register(dto, on: db)
		}

		return .created
	}

	func get(req: Request) throws -> UserDTO {
		let user = try req.auth.require(UserModel.self)
		return .init(user)
	}

	func update(req: Request) async throws -> HTTPResponseStatus {
		let user = try req.auth.require(UserModel.self)
		let dto = try req.content.decode(UserDTO.self)
		try dto.copy(onto: user)
		try await user.save(on: req.db)

		return .noContent
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

	func invite(req: Request) async throws -> Response {
		let expiration = TokenExpiration(days: 10)
		let invite = UserInvitationModel(validUntil: expiration.date(in: .theFuture))
		try await invite.create(on: req.db)

		let dto = UserInvitationDTO(token: try invite.requireID())

		return try .init(status: .created, dto: dto)
	}
}

extension UserModel: Authenticatable {
}

extension Response {
	convenience init<DTO: Content>(status: HTTPStatus, dto: DTO) throws {
		self.init(status: status, body: .empty)
		try content.encode(dto)
	}
}
