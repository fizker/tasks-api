import Fluent
import Foundation

final class RefreshTokenModel: Model {
	static let schema = "refresh_tokens"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "token")
	var token: String

	@Field(key: "created_on")
	var createdOn: Date

	@Parent(key: "refreshes_token")
	var refreshes: AccessTokenModel

	@OptionalParent(key: "succeeded_by_token")
	var succeededBy: AccessTokenModel?

	init() {}

	init(id: UUID? = nil, token: String, createdOn: Date = Date(), refreshes accessTokenID: UUID) {
		self.id = id
		self.token = token
		self.createdOn = createdOn
		self.$refreshes.id = accessTokenID
	}

	convenience init(id: UUID? = nil, token: String, createdOn: Date = Date(), refreshes accessToken: AccessTokenModel) throws {
		self.init(id: id, token: token, createdOn: createdOn, refreshes: try accessToken.requireID())
		$refreshes.value = accessToken
	}
}
