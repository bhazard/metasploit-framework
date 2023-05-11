# Makefile

# Generally ...
#  make clean-build run
#    should get things done.

# Run docker containers
# run should not, by default, run signals because typically the db is not configured yet
# and signals will fail.
up run:
	docker-compose up

# Building clean takes about 35 mins on a mac
clean-build:
	docker-compose  build --no-cache

# Stop docker containers, but not remove them nor the volumes
stop:
	docker-compose stop

# Stop docker containers, remove them AND the named data volumes
down:
	docker-compose down -v

logs:
	docker-compose logs

volumes:
	@docker volume ls

