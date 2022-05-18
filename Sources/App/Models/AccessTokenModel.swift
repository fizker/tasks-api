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

	init() {}

	init(id: UUID? = nil, code: String, createdOn: Date = .init(), expiresIn expiration: TokenExpiration) {
		self.id = id
		self.code = code
		self.createdOn = createdOn
		self.expiresOn = createdOn.addingTimeInterval(expiration.asTimeInterval)
	}
}

extension AccessTokenResponse {
	init(_ model: AccessTokenModel) {
		self.init(
			accessToken: model.code,
			type: .bearer,
			expiresIn: TokenExpiration(date: model.expiresOn),
			refreshToken: nil
		)
	}
}
