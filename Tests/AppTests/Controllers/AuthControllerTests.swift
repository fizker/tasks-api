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
		try await createAccessToken(code: "abc", refreshToken: "def")

		let refreshTokenRequest = RefreshTokenRequest(refreshToken: "def")

		try await app.test(.POST, "/auth/token", beforeRequest: { req in
			try req.content.encode(refreshTokenRequest)
		}) { res in
			XCTAssertEqual(res.status, .ok)
			guard res.status == .ok
			else {
				XCTFail("Failed to refresh first token")
				return
			}

			guard let refreshTokenModel = try await RefreshTokenModel.query(on: app.db)
				.filter(\.$token == "def")
				.with(\.$refreshes)
				.with(\.$succeededBy)
				.withDeleted()
				.first()
			else {
				XCTFail("Could not load refresh token")
				return
			}

			XCTAssertNotNil(refreshTokenModel.succeededBy)

			try await app.test(.POST, "/auth/token", beforeRequest: { req in
				try req.content.encode(refreshTokenRequest)
			}) { res in
				XCTAssertEqual(res.status, .badRequest)

				let response = try res.content.decode(ErrorResponse.self)

				XCTAssertEqual(response.code, .invalidGrant)

				guard
					let refreshTokenModel = try await RefreshTokenModel.query(on: app.db)
						.filter(\.$token == "def")
						.with(\.$refreshes)
						.with(\.$succeededBy)
						.withDeleted()
						.first(),
					let succeeededBy = refreshTokenModel.succeededBy
				else {
					XCTFail("Could not load tokens")
					return
				}

				XCTAssertTrue(refreshTokenModel.refreshes.expiresOn <= Date())
				XCTAssertTrue(succeeededBy.expiresOn <= Date())
			}
		}
	}

	func test__token_post__refreshTokenRequest_tokenIsAlreadyUsed_theRequestedTokenIs2Of3__returnsInvalidGrantError_allAccessTokensAreInvalidated() async throws {
		try await createAccessToken(code: "abc", refreshToken: "def")

		let firstRefreshToken = "def"

		// Creating token 2
		try await app.test(.POST, "/auth/token", beforeRequest: { req in
			try req.content.encode(RefreshTokenRequest(refreshToken: firstRefreshToken))
		}) { res in
			let newAccessToken = try res.content.decode(AccessTokenResponse.self)
			guard let secondRefreshToken = newAccessToken.refreshToken
			else {
				XCTFail("Access token response did not include refresh token")
				return
			}

			// Creating token 3
			try await app.test(.POST, "/auth/token", beforeRequest: { req in
				try req.content.encode(RefreshTokenRequest(refreshToken: secondRefreshToken))
			}) { res in
				let accessTokenResponse = try res.content.decode(AccessTokenResponse.self)
				guard let thirdRefreshToken = accessTokenResponse.refreshToken
				else {
					XCTFail("Access token response did not include refresh token")
					return
				}

				try await app.test(.POST, "/auth/token", beforeRequest: { req in
					try req.content.encode(RefreshTokenRequest(refreshToken: thirdRefreshToken))
				}) { res in

					// Reusing second token
					try await app.test(.POST, "/auth/token", beforeRequest: { req in
						try req.content.encode(RefreshTokenRequest(refreshToken: secondRefreshToken))
					}) { res in
						XCTAssertEqual(res.status, .badRequest)

						let response = try res.content.decode(ErrorResponse.self)

						XCTAssertEqual(response.code, .invalidGrant)

						guard
							let firstRefreshTokenModel = try await RefreshTokenModel.query(on: app.db)
								.filter(\.$token == firstRefreshToken)
								.with(\.$refreshes)
								.withDeleted()
								.first(),
							let secondRefreshTokenModel = try await RefreshTokenModel.query(on: app.db)
								.filter(\.$token == secondRefreshToken)
								.with(\.$refreshes)
								.withDeleted()
								.first(),
							let thirdRefreshTokenModel = try await RefreshTokenModel.query(on: app.db)
								.filter(\.$token == thirdRefreshToken)
								.with(\.$refreshes)
								.with(\.$succeededBy)
								.withDeleted()
								.first(),
							let fourthAccessToken = thirdRefreshTokenModel.succeededBy
						else {
							XCTFail("Could not load tokens")
							return
						}

						XCTAssertTrue(firstRefreshTokenModel.refreshes.expiresOn <= Date())
						XCTAssertTrue(secondRefreshTokenModel.refreshes.expiresOn <= Date())
						XCTAssertTrue(thirdRefreshTokenModel.refreshes.expiresOn <= Date())
						XCTAssertTrue(fourthAccessToken.expiresOn <= Date())
						XCTAssertEqual(firstRefreshTokenModel.$succeededBy.id, secondRefreshTokenModel.refreshes.id)
						XCTAssertEqual(secondRefreshTokenModel.$succeededBy.id, thirdRefreshTokenModel.refreshes.id)
					}
				}
			}
		}
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
