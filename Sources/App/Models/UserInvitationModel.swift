import Fluent
import Foundation

final class UserInvitationModel: Model {
	static let schema = "user_invitations"

	@ID(key: .id)
	var id: UUID?

	@Timestamp(key: "valid_until", on: .delete)
	var validUntil: Date?

	init() {}

	init(id: UUID? = nil, validUntil: Date) {
		self.id = id
		self.validUntil = validUntil
	}
}
