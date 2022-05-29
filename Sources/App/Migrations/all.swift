import Fluent

let migrations: [() -> Migration] = [
	CreateProject.init,
	CreateTask.init,
	CreateTodoSettings.init,
	SortTasks.init,
	CreateUsers.init,
	OAuthAccessToken.init,
]
