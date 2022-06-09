.PHONY: deploy build-docker-deploy-image

build-docker-deploy-image:
	docker build \
		--tag registry.heroku.com/fzk-tasks-api/web \
		--platform linux/amd64 \
		.

deploy: build-docker-deploy-image
	heroku container:login
	docker push registry.heroku.com/fzk-tasks-api/web
	heroku container:release --app fzk-tasks-api web
