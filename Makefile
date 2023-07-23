# Makefile

# Generally ...
#  make clean-build run
#    should get things done.

# Start a command-line session with metasploit
run:
	docker run -i metasploit:dev

# Run docker containers
up:
	docker-compose up

# Building clean takes about 35 mins on a mac m1
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

