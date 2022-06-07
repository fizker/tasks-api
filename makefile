.PHONY: deploy

deploy:
	heroku container:login

	docker build \
		--tag registry.heroku.com/fzk-tasks-api/web \
		--platform linux/amd64 \
		.
	docker push registry.heroku.com/fzk-tasks-api/web

	heroku container:release --app fzk-tasks-api web
