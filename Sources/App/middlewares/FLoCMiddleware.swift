import Vapor

/// Middleware telling the google pervasive-tracking to fuck off
class FLoCMiddleware: AsyncMiddleware {
	static let flocHeader = "Permissions-Policy"
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let response = try await next.respond(to: request)

		response.headers.replaceOrAdd(name: Self.flocHeader, value: "interest-cohort=()")
		return response
	}
}
