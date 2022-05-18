import XCTest
import XCTVapor
import Fluent
import OAuth2Models
@testable import App

final class AuthControllerTests: XCTestCase {
	var app: Application!
	let controller = UserController()

	func test__token_post__passwordRequest_credentialsAreValid__newAccessTokenIsReturned() async throws {
		let passwordRequest = PasswordAccessTokenRequest(username: "admin", password: "admin")

		try await app.test(.POST, "/auth/token", beforeRequest: { req in
			try req.content.encode(passwordRequest)
		}) { res in
			XCTAssertEqual(res.status, .ok)

			let response = try res.content.decode(AccessTokenResponse.self)

			guard let tokenModel = try await AccessTokenModel.query(on: app.db)
				.filter(\.$code == response.accessToken)
				.first()
			else {
				XCTFail("Could not find token in database")
				return
			}

			XCTAssertEqual(response.scope, .init())
			XCTAssertNil(response.refreshToken)
			XCTAssertEqual(response.type, .bearer)
			XCTAssertEqual(response.expiration?.asTimeInterval ?? 0, 3600, accuracy: 2)
			XCTAssertEqual(tokenModel.createdOn.timeIntervalSinceNow, 0, accuracy: 2)
			XCTAssertEqual(response.expiration?.date(in: .theFuture).timeIntervalSince(tokenModel.expiresOn) ?? 10, 0, accuracy: 2)
		}
	}

	func test__token_post__passwordRequest_credentialsAreInvalid__returnsInvalidGrantError() async throws {
		let passwordRequest = PasswordAccessTokenRequest(username: "admin", password: "foo")

		try app.test(.POST, "/auth/token",
			beforeRequest: { req in
			try req.content.encode(passwordRequest)
		}) { res in
			XCTAssertEqual(res.status, .badRequest)

			let response = try res.content.decode(ErrorResponse.self)

			XCTAssertEqual(response.code, .invalidGrant)
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

extension PasswordAccessTokenRequest: Content {
}
