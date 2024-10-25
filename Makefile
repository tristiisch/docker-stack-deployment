
# -- Deprecated
ACTION_SERVICE=action
TESTING_CMD=local/test.sh
# --

start:
	@docker compose up -d

start-f:
	@docker compose up -d --force-recreate

start-b:
	@docker compose up -d --build

stop:
	@docker compose stop

down:
	@docker compose down

# -- Deprecated
check-running:
	@docker compose ps --services | grep $(ACTION_SERVICE) > /dev/null || $(MAKE) start

exec: check-running
	@docker compose exec -it $(ACTION_SERVICE) sh

test: check-running
	@docker compose exec -it $(ACTION_SERVICE) $(TESTING_CMD)

dev: start-f exec
# --

tests-build:
	@docker build -f ./tests/host/Dockerfile -t docker_throw_ssh .

tests-deploy: tests-build
	@docker tag docker_throw_ssh ghcr.io/tristiisch/docker_throw_ssh:latest
	@docker push ghcr.io/tristiisch/docker_throw_ssh:latest
