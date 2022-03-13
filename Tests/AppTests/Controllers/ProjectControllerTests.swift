import XCTest
import XCTVapor
@testable import App

final class ProjectControllerTests: XCTestCase {
	var app: Application!
	let controller = ProjectController()

	func test__loadSingle__projectDoesNotExist__throwsNotFound() async throws {
		let projectID = UUID()

		do {
			_ = try await controller.loadSingle(id: projectID, on: app.db)
			XCTFail("Should have thrown")
		} catch {
			if let error = error as? AbortError {
				XCTAssertEqual(error.status, .notFound)
			} else {
				XCTFail("Unexpected error: \(error)")
			}
		}
	}

	override func tearDownWithError() throws {
		app.shutdown()
		app = nil
	}

	override func setUpWithError() throws {
		app = Application(.testing)
		try configure(app)
	}
}
