ACTION_SERVICE=action
TESTING_CMD=local/test.sh

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

check-running:
	@docker-compose ps --services | grep $(ACTION_SERVICE) > /dev/null || $(MAKE) start

exec: check-running
	@docker compose exec -it $(ACTION_SERVICE) sh

test: check-running
	@docker compose exec -it $(ACTION_SERVICE) $(TESTING_CMD)

dev: start-f exec
