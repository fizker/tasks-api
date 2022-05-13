import XCTest
import XCTVapor
@testable import App

final class UserControllerTests: XCTestCase {
	var app: Application!
	let controller = UserController()

	func test__register_post__noMatchingInvitation__throwsNotFound() async throws {
		let request = RegisterUserDTO(token: UUID(), name: "John Doe", username: "foo", password: "bar")

		try app.test(.POST, "/users/register", beforeRequest: { req in
			try req.content.encode(request)
		}) { res in
			XCTAssertEqual(res.status, .notFound)
		}
	}

	func test__register_post__matchingInvite_inviteIsNotExpired__userIsCreated_returns204() async throws {
		let inviteID = UUID()
		let request = RegisterUserDTO(token: inviteID, name: "John Doe", username: "foo", password: "bar")

		let invite = UserInvitationModel(id: inviteID, validUntil: Date(timeIntervalSinceNow: 60))
		try await invite.create(on: app.db)

		try await app.test(.POST, "/users/register", beforeRequest: { req in
			try req.content.encode(request)
		}) { res in
			XCTAssertEqual(res.status, .created)

			let users = try await UserModel.query(on: app.db)
				.all()

			XCTAssertEqual(1, users.count)

			guard let user = users.first
			else { return }

			XCTAssertEqual(user.name, "John Doe")
			XCTAssertEqual(user.username, "foo")
			XCTAssertTrue(try Bcrypt.verify("bar", created: user.passwordHash))
		}
	}

	func test__register_post__notLoggedIn_matchingInvite_inviteIsExpired__throwsNotFound() async throws {
		let inviteID = UUID()
		let request = RegisterUserDTO(token: inviteID, name: "John Doe", username: "foo", password: "bar")

		let invite = UserInvitationModel(id: inviteID, validUntil: Date(timeIntervalSinceNow: -5))
		try await invite.create(on: app.db)

		try app.test(.POST, "/users/register", beforeRequest: { req in
			try req.content.encode(request)
		}) { res in
			XCTAssertEqual(res.status, .notFound)
		}
	}

	func test__self_get__notLoggedIn__throwsNotAuthorized() async throws {
		let headers = HTTPHeaders()

		try app.test(.GET, "/users/self", headers: headers) { res in
			XCTAssertEqual(res.status, .unauthorized)
		}
	}

	func test__self_get__loggedIn_userDoesNotExist__throwsNotAuthorized() async throws {
		var headers = HTTPHeaders()
		headers.basicAuthorization = .init(username: "foo", password: "bar")

		try app.test(.GET, "/users/self", headers: headers) { res in
			XCTAssertEqual(res.status, .unauthorized)
		}
	}

	func test__self_get__loggedIn_invalidCredentials__throwsNotAuthorized() async throws {
		let user = UserModel(name: "John Doe", username: "foo", passwordHash: try Bcrypt.hash("bar"))
		try await user.save(on: app.db)

		var headers = HTTPHeaders()
		headers.basicAuthorization = .init(username: "foo", password: "baz")

		try app.test(.GET, "/users/self", headers: headers) { res in
			XCTAssertEqual(res.status, .unauthorized)
		}
	}

	func test__self_get__loggedIn__returnsUserDTO() async throws {
		let user = UserModel(name: "John Doe", username: "foo", passwordHash: try Bcrypt.hash("bar"))
		try await user.save(on: app.db)

		var headers = HTTPHeaders()
		headers.basicAuthorization = .init(username: "foo", password: "bar")

		let expected = try UserDTO(user)

		try app.test(.GET, "/users/self", headers: headers) { res in
			XCTAssertEqual(res.status, .ok)
			XCTAssertEqual(try res.content.decode(UserDTO.self), expected)
		}
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
