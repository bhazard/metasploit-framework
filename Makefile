# Makefile

# Generally ...
#  make clean-build run
#    should get things done.

# Start a command-line session with metasploit
run:
	docker-compose run -it ms

shell:
	docker-compose exec -it ms /bin/bash

# Run docker containers
up: dirs
	docker-compose up

build:
	docker-compose build

# Building clean takes about 35 mins on a mac m1
# Reduced to 20 mins (from nothing) when using go binaries
# Note that --force-recreate is a flag for up --build and does not work with the build sub-command
clean-build: down 
	docker-compose build --no-cache

# Stop docker containers, but not remove them nor the volumes
stop:
	docker-compose stop

# the various sources limit downloads, so we'll just do them in advance and "cache" them
# for the docker image builder processes ...
downloads:
	mkdir -p ./downloads
	curl -O https://dl.google.com/go/go1.19.3.linux-amd64.tar.gz

dirs:
	mkdir -p home/.msf4
	chmod 777 home/.msf4

# Stop docker containers, remove them AND the named data volumes
down:
	docker-compose down -v

clean: down

purge:
	-docker rm -fv $$(docker ps -aq)
	-docker rmi -f $$(docker images -aq)