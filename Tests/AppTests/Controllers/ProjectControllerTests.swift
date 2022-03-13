import XCTest
import XCTVapor
@testable import App

final class ProjectControllerTests: XCTestCase {
	var app: Application!
	let controller = ProjectController()

	func test__loadSingle__projectDoesNotExist__throwsNotFound() async throws {
		let projectID = UUID()
		try await addProject(id: UUID())

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

	func test__loadSingle__projectExists__projectIsReturned() async throws {
		let projectID = UUID()
		try await addProject(id: projectID)

		let project = try await controller.loadSingle(id: projectID, on: app.db)
		XCTAssertEqual(projectID, project.id)
	}

	private func addProject(id: UUID) async throws {
		let project = ProjectDTO(
			id: id,
			name: "Test project",
			descr: "Test project description"
		)

		try await project.projectValue.save(on: app.db)
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
