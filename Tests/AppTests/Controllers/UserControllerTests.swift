import XCTest
import XCTVapor
@testable import App

final class UserControllerTests: XCTestCase {
	var app: Application!
	let controller = UserController()

	func test__registerUser__noMatchingInvitation__throwsNotFound() async throws {
		let request = RegisterUserDTO(token: UUID(), name: "John Doe", username: "foo", password: "bar")

		await XCTAssertThrowsAbortError(.notFound, try await controller.register(request, on: app.db))
	}

	func test__registerUser__matchingInvite_inviteIsNotExpired__userIsCreated() async throws {
		let inviteID = UUID()
		let request = RegisterUserDTO(token: inviteID, name: "John Doe", username: "foo", password: "bar")

		let invite = UserInvitationModel(id: inviteID, validUntil: Date(timeIntervalSinceNow: 60))
		try await invite.create(on: app.db)

		try await controller.register(request, on: app.db)

		let users = try await UserModel.query(on: app.db)
			.all()

		XCTAssertEqual(1, users.count)

		guard let user = users.first
		else { return }

		XCTAssertEqual(user.name, "John Doe")
		XCTAssertEqual(user.username, "foo")
		XCTAssertTrue(try Bcrypt.verify("bar", created: user.passwordHash))
	}

	func test__registerUser__matchingInvite_inviteIsExpired__throwsNotFound() async throws {
		let inviteID = UUID()
		let request = RegisterUserDTO(token: inviteID, name: "John Doe", username: "foo", password: "bar")

		let invite = UserInvitationModel(id: inviteID, validUntil: Date(timeIntervalSinceNow: -5))
		try await invite.create(on: app.db)

		await XCTAssertThrowsAbortError(.notFound, try await controller.register(request, on: app.db))
	}

	override func setUp() async throws {
		app = Application(.testing)
		try configure(app)
	}

	override func tearDown() async throws {
		app.shutdown()
		app = nil
	}
}
