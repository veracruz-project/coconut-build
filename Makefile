.PHONY:
build:
	docker build -t coconut:latest . --network=host

.PHONY:
run:
	docker run --init --rm --name coconut-mine-latest coconut:latest sleep inf

.PHONY:
exec:
	docker exec -it coconut-mine-latest /bin/bash || true
