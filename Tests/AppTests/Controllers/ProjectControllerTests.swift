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
		try await addProject(id: projectID, tasks: [
			.init(name: "task", descr: "task d"),
		])

		let project = try await controller.loadSingle(id: projectID, on: app.db)
		XCTAssertEqual(projectID, project.id)
		XCTAssertEqual("Test project", project.name)
		XCTAssertEqual("Test project description", project.descr)
		XCTAssertEqual(1, project.tasks?.count)
		if let task = project.tasks?.first {
			XCTAssertEqual("task", task.name)
			XCTAssertEqual("task d", task.descr)
		}
	}

	func test__update__projectExists_projectHasNoTasks_dtoHasNoTasks__projectIsUpdated() async throws {
		let projectID = UUID()
		try await addProject(id: projectID)

		let dto = ProjectDTO(
			name: "Updated",
			descr: "Updated description"
		)

		let result = try await controller.update(id: projectID, dto: dto, db: app.db)

		XCTAssertEqual(result.id, projectID)
		XCTAssertEqual(result.name, dto.name)
		XCTAssertEqual(result.descr, dto.descr)
		XCTAssertEqual(result.tasks?.isEmpty, true)

		let single = try await controller.loadSingle(id: projectID, on: app.db)

		XCTAssertEqual(result, single)
	}

	private func addProject(id: UUID, tasks: [TaskDTO] = []) async throws {
		let project = ProjectDTO(
			id: id,
			name: "Test project",
			descr: "Test project description"
		)

		try await project.projectValue.save(on: app.db)

		var nextSortOrder = 1
		for var task in tasks {
			task.project = id
			if let so = task.sortOrder {
				if so < nextSortOrder {
					task.sortOrder = nil
				} else {
					nextSortOrder = so + 1
				}
			}

			if task.sortOrder == nil {
				task.sortOrder = nextSortOrder
				nextSortOrder += 1
			}
			try await task.taskValue.save(on: app.db)
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
