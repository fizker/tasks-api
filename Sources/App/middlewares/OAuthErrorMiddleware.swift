import Foundation
import OAuth2Models
import Vapor

struct OAuthErrorMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		do {
			return try await next.respond(to: request)
		} catch {
			guard let error = error as? ErrorResponse
			else { throw error }

			let encoder = JSONEncoder()
			let data = try encoder.encode(error)
			return .init(status: .badRequest, headers: ["content-type": "application/json"], body: .init(data: data))
		}
	}
}
