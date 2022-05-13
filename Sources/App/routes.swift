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
	let u = UserController()

	app.group("projects") { app in
		app.get(use: p.all(req:))
		app.post(use: p.create(req:))

		app.group(":project") { app in
			app.get { try await p.get(req: $0, id: try $0.parameters.require("project")) }
			app.put { try await p.update(req: $0, id: try $0.parameters.require("project")) }
			app.delete { try await p.delete(req: $0, id: try $0.parameters.require("project")) }

			app.group("tasks") { app in
				app.get { try await t.all(req: $0, projectID: try $0.parameters.require("project")) }
				app.post { try await t.create(req: $0, projectID: try $0.parameters.require("project")) }
				app.group(":task") { app in
					app.get { try await t.get(req: $0, projectID: try $0.parameters.require("project"), id: try $0.parameters.require("task")) }
					app.put { try await t.update(req: $0, projectID: try $0.parameters.require("project"), id: try $0.parameters.require("task")) }
					app.delete { try await t.delete(req: $0, projectID: try $0.parameters.require("project"), id: try $0.parameters.require("task")) }
				}
			}
		}
	}

	app.group("todo") { app in
		app.get(use: todo.currentItem(req:))
		app.post(use: todo.moveToNextItem(req:))
	}

	app.group("users") { app in
		app.post("register", use: u.register(req:))
	}
}
