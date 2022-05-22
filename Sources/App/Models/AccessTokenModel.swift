import Foundation
import Fluent
import OAuth2Models

final class AccessTokenModel: Model {
	static let schema = "access_tokens"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "code")
	var code: String

	@Field(key: "created_on")
	var createdOn: Date

	@Field(key: "expires_on")
	var expiresOn: Date

	@OptionalChild(for: \.$refreshes)
	var refreshedBy: RefreshTokenModel?

	@OptionalChild(for: \.$succeededBy)
	var succeeds: RefreshTokenModel?

	init() {}

	init(id: UUID? = nil, code: String, createdOn: Date = .init(), expiresIn expiration: TokenExpiration) {
		self.id = id
		self.code = code
		self.createdOn = createdOn
		self.expiresOn = createdOn.addingTimeInterval(expiration.asTimeInterval)
	}
}

extension AccessTokenResponse {
	init(_ model: AccessTokenModel, on db: Database) async throws {
		self.init(
			accessToken: model.code,
			type: .bearer,
			expiresIn: TokenExpiration(date: model.expiresOn),
			refreshToken: try await model.$refreshedBy.get(on: db)?.token
		)
	}
}
