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

struct EnsureLoggedInMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		guard
			let auth = request.headers.bearerAuthorization,
			let token = try await AccessTokenModel.query(on: request.db)
				.filter(\.$code == auth.token)
				.with(\.$user)
				.first()
		else { throw Abort(.unauthorized) }

		request.auth.login(token.user)

		return try await next.respond(to: request)
	}
}

func routes(_ app: Application) throws {
	app.get { req in
		return "It works!"
	}

	app.get("hello") { req -> String in
		return "Hello, world!"
	}

	let auth = AuthController()
	let p = ProjectController()
	let t = TaskController()
	let todo = TodoController()
	let u = UserController()

	app.group("auth") { app in
		app.post("token", use: auth.requestToken(req:))
	}


	app
	.grouped(EnsureLoggedInMiddleware())
	.group("projects") { app in
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

	app
	.grouped(EnsureLoggedInMiddleware())
	.group("todo") { app in
		app.get(use: todo.currentItem(req:))
		app.post(use: todo.moveToNextItem(req:))
	}

	app.group("users") { app in
		app.post("register", use: u.register(req:))

		let app = app.grouped(EnsureLoggedInMiddleware())
		app.get("self", use: u.get(req:))
		app.put("self", use: u.update(req:))
	}
}
