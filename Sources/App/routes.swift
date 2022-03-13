import Fluent
import Vapor

func notImplemented() throws -> Never {
	throw Abort(.notImplemented)
}

extension Request {
	func require(_ name: String) throws -> UUID {
		guard
			let strID = parameters.get("id"),
			let id = UUID(uuidString: strID)
		else { throw Vapor.Abort(.badRequest) }
		return id
	}
}

func routes(_ app: Application) throws {
	app.get { req in
		return "It works!"
	}

	app.get("hello") { req -> String in
		return "Hello, world!"
	}

	let p = ProjectController()
	let t = TaskController()
	let todo = TodoController()

	app.group("projects") { app in
		app.get(use: p.all(req:))
		app.post(use: p.create(req:))

		app.group(":project") { app in
			app.get { p.get(req: $0, id: try $0.parameters.require("project")) }
			app.put { try await p.update(req: $0, id: try $0.parameters.require("project")) }
			app.delete { p.delete(req: $0, id: try $0.parameters.require("project")) }

			app.group("tasks") { app in
				app.get { t.all(req: $0, projectID: try $0.parameters.require("project")) }
				app.post { try t.create(req: $0, projectID: try $0.parameters.require("project")) }
				app.group(":task") { app in
					app.get { t.get(req: $0, projectID: try $0.parameters.require("project"), id: try $0.parameters.require("task")) }
					app.put { try t.update(req: $0, projectID: try $0.parameters.require("project"), id: try $0.parameters.require("task")) }
					app.delete { try await t.delete(req: $0, projectID: try $0.parameters.require("project"), id: try $0.parameters.require("task")) }
				}
			}
		}
	}

	app.group("todo") { app in
		app.get(use: todo.currentItem(req:))
		app.post(use: todo.moveToNextItem(req:))
	}
}
