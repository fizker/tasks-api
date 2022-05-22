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
				.with(\.$refreshedBy)
				.first()
			else {
				XCTFail("Could not find token in database")
				return
			}

			XCTAssertEqual(response.scope, .init())
			XCTAssertNotNil(response.refreshToken)
			XCTAssertEqual(tokenModel.refreshedBy?.token, response.refreshToken)
			XCTAssertEqual(response.type, .bearer)
			XCTAssertEqual(response.expiration?.asTimeInterval ?? 0, 3600, accuracy: 2)
			XCTAssertEqual(tokenModel.createdOn.timeIntervalSinceNow, 0, accuracy: 2)
			XCTAssertEqual(response.expiration?.date(in: .theFuture).timeIntervalSince(tokenModel.expiresOn) ?? 10, 0, accuracy: 2)
		}
	}

	func test__token_post__passwordRequest_credentialsAreInvalid__returnsInvalidGrantError() async throws {
		let passwordRequest = PasswordAccessTokenRequest(username: "admin", password: "foo")

		try app.test(.POST, "/auth/token", beforeRequest: { req in
			try req.content.encode(passwordRequest)
		}) { res in
			XCTAssertEqual(res.status, .badRequest)

			let response = try res.content.decode(ErrorResponse.self)

			XCTAssertEqual(response.code, .invalidGrant)
		}
	}

	func test__token_post__refreshTokenRequest_tokenIsValid__newAccessTokenIsReturned_previousAccessTokenIsInvalidated() async throws {
		try await createAccessToken(code: "abc", refreshToken: "def")

		let refreshTokenRequest = RefreshTokenRequest(refreshToken: "def")

		try await app.test(.POST, "/auth/token", beforeRequest: { req in
			try req.content.encode(refreshTokenRequest)
		}) { res in
			XCTAssertEqual(res.status, .ok)

			let response = try res.content.decode(AccessTokenResponse.self)

			guard let tokenModel = try await AccessTokenModel.query(on: app.db)
				.filter(\.$code == response.accessToken)
				.with(\.$refreshedBy)
				.first()
			else {
				XCTFail("Could not find token in database")
				return
			}

			XCTAssertEqual(response.scope, .init())
			XCTAssertNotNil(response.refreshToken)
			XCTAssertEqual(tokenModel.refreshedBy?.token, response.refreshToken)
			XCTAssertEqual(response.type, .bearer)
			XCTAssertEqual(response.expiration?.asTimeInterval ?? 0, 3600, accuracy: 2)
			XCTAssertEqual(tokenModel.createdOn.timeIntervalSinceNow, 0, accuracy: 2)
			XCTAssertEqual(response.expiration?.date(in: .theFuture).timeIntervalSince(tokenModel.expiresOn) ?? 10, 0, accuracy: 2)

			guard
				let oldAccessToken = try await AccessTokenModel.query(on: app.db)
					.filter(\.$code == "abc")
					.with(\.$refreshedBy, { $0.with(\.$succeededBy) })
					.withDeleted()
					.first(),
				let oldRefreshToken = oldAccessToken.refreshedBy
			else {
				XCTFail("Could not find tokens in database")
				return
			}

			XCTAssertTrue(oldAccessToken.expiresOn <= Date())
			XCTAssertEqual(oldRefreshToken.succeededBy?.code, response.accessToken)
		}
	}

	func test__token_post__refreshTokenRequest_tokenIsAlreadyUsed__returnsInvalidGrantError_accessTokenIsInvalidated() async throws {
		/*@START_MENU_TOKEN@*/throw XCTSkip("Not implemented")/*@END_MENU_TOKEN@*/
	}

	func test__token_post__refreshTokenRequest_tokenIsUnknown__returnsInvalidGrantError() async throws {
		let refreshTokenRequest = RefreshTokenRequest(refreshToken: "abc")

		try app.test(.POST, "/auth/token", beforeRequest: { req in
			try req.content.encode(refreshTokenRequest)
		}) { res in
			XCTAssertEqual(res.status, .badRequest)

			let response = try res.content.decode(ErrorResponse.self)

			XCTAssertEqual(response.code, .invalidGrant)
		}
	}

	@discardableResult
	private func createAccessToken(code: String = UUID().uuidString, refreshToken: String = UUID().uuidString) async throws -> AccessTokenResponse {
		let accessTokenModel = AccessTokenModel(code: code, expiresIn: .oneHour)
		try await accessTokenModel.create(on: app.db)

		let refreshTokenModel = try RefreshTokenModel(token: refreshToken, refreshes: accessTokenModel)
		try await refreshTokenModel.create(on: app.db)

		return try await AccessTokenResponse(accessTokenModel, on: app.db)
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

extension RefreshTokenRequest: Content {
}
