import Foundation
import Fluent
import OAuth2Models

final class AccessTokenModel: Model {
	static let schema = "access_tokens"

	@ID(key: .id)
	var id: UUID?

	@Parent(key: "user")
	var user: UserModel

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

	init(id: UUID? = nil, userID: UUID, code: String, createdOn: Date = Date(), expiresIn expiration: TokenExpiration) {
		self.id = id
		self.$user.id = userID
		self.code = code
		self.createdOn = createdOn
		self.expiresOn = createdOn.addingTimeInterval(expiration.asTimeInterval)
	}

	convenience init(id: UUID? = nil, user: UserModel, code: String, createdOn: Date = Date(), expiresIn expiration: TokenExpiration) throws {
		self.init(id: id, userID: try user.requireID(), code: code, createdOn: createdOn, expiresIn: expiration)
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
