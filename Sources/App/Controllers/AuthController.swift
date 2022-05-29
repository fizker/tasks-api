import Fluent
import OAuth2Models
import Vapor

class AuthController {
	func requestToken(req: Request) async throws -> AccessTokenResponse {
		let grantRequest = try req.content.decode(GrantRequest.self)

		switch grantRequest {
		case .authCodeAccessToken(_):
			throw ErrorResponse(code: .unsupportedGrantType, description: nil)
		case .clientCredentialsAccessToken(_):
			throw ErrorResponse(code: .unsupportedGrantType, description: nil)
		case let .passwordAccessToken(request):
			return try await handle(request: request, on: req.db)
		case let .refreshToken(request):
			return try await handle(request: request, on: req.db, logger: req.logger)
		}
	}

	private func handle(request: PasswordAccessTokenRequest, on db: Database) async throws -> AccessTokenResponse {
		guard
			let user = try await UserModel.query(on: db)
				.filter(\.$username == request.username)
				.first(),
			try Bcrypt.verify(request.password, created: user.passwordHash)
		else {
			throw ErrorResponse(code: .invalidGrant, description: nil)
		}

		let accessToken = try AccessTokenModel(user: user, code: UUID().uuidString, expiresIn: .oneHour)
		try await accessToken.create(on: db)

		let refreshToken = try RefreshTokenModel(token: UUID().uuidString, refreshes: accessToken)
		try await refreshToken.create(on: db)

		return try await .init(accessToken, on: db)
	}

	private func handle(request: RefreshTokenRequest, on db: Database, logger: Logger) async throws -> AccessTokenResponse {
		guard let refreshToken = try await RefreshTokenModel.query(on: db)
			.filter(\.$token == request.refreshToken)
			.first()
		else {
			throw ErrorResponse(code: .invalidGrant, description: nil)
		}

		guard refreshToken.$succeededBy.id == nil
		else {
			do {
				try await invalidateTokenTree(refreshToken, on: db)
			} catch {
				logger.report(error: error)
			}
			throw ErrorResponse(code: .invalidGrant, description: nil)
		}

		let oldToken = try await refreshToken.$refreshes.get(on: db)
		oldToken.expiresOn = .now
		try await oldToken.save(on: db)

		let newToken = AccessTokenModel(userID: oldToken.$user.id, code: UUID().uuidString, expiresIn: .oneHour)
		try await newToken.create(on: db)
		refreshToken.$succeededBy.id = try newToken.requireID()
		try await refreshToken.save(on: db)

		let newRefreshToken = try RefreshTokenModel(token: UUID().uuidString, refreshes: newToken)
		try await newRefreshToken.create(on: db)

		return try await .init(newToken, on: db)
	}

	private func invalidateTokenTree(_ refreshToken: RefreshTokenModel, on db: Database) async throws {
		var refreshToken: RefreshTokenModel? = refreshToken

		while true {
			guard
				let id = refreshToken?.$succeededBy.id,
				let accessToken = try await AccessTokenModel.query(on: db)
					.filter(\.$id == id)
					.with(\.$refreshedBy)
					.first()
			else { return }

			accessToken.expiresOn = Date()
			try await accessToken.save(on: db)

			refreshToken = accessToken.refreshedBy
		}
	}
}

extension AccessTokenResponse: Content {
}
