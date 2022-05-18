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
			return try await handle(request: request, on: req.db)
		}
	}

	private func handle(request: PasswordAccessTokenRequest, on db: Database) async throws -> AccessTokenResponse {
		guard
			let user = try await UserModel.query(on: db)
				.filter(\.$username == request.username)
				.first(),
			try Bcrypt.verify(request.password, created: user.passwordHash)
		else {
			throw ErrorResponse(code: .accessDenied, description: nil)
		}

		let accessToken = AccessTokenModel(code: UUID().uuidString, expiresIn: .oneHour)
		try await accessToken.create(on: db)

		return .init(accessToken)
	}

	private func handle(request: RefreshTokenRequest, on db: Database) async throws -> AccessTokenResponse {
		throw ErrorResponse(code: .invalidGrant, description: nil)
	}
}
