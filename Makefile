UID ?= $(shell id -u)
GID ?= $(shell id -g)
USER ?= $(shell id -un)

BUILD_ARGS=--build-arg USER=${USER} --build-arg UID=${UID} --build-arg GID=${GID}
.PHONY:
build:
	cp /usr/src/linux-headers-$(shell uname -r)/.config host_config
	docker build --build-arg USER=${USER} --build-arg UID=${UID} --build-arg GID=${GID} -t coconut-artifacts:latest . --network=host

.PHONY:
run:
	docker run --init --rm -d -v$(abspath ../svsm):/svsm -v /lib/modules/:/lib/modules --privileged --name coconut-artifacts-${USER}-latest coconut-artifacts:latest sleep inf


.PHONY:
exec:
	docker exec -it coconut-artifacts-${USER}-latest /bin/bash || true

# individual stage builds

## QEMU
.PHONY:
qemu:
	docker build --build-arg USER=${USER} --build-arg UID=${UID} --build-arg GID=${GID} --target qemu_build -t qemu_build:latest . --network=host
.PHONY:
qemu_run:
	docker run --init --rm -d --name qemu-${USER}-latest qemu_build:latest sleep inf
.PHONY:
qemu_exec:
	docker exec -it --user ${USER} qemu-${USER}-latest /bin/bash || true

## SVSM
.PHONY:
svsm:
	docker build --build-arg USER=${USER} --build-arg UID=${UID} --build-arg GID=${GID} -t coconut-svsm:latest . --network=host
.PHONY:
svsm_run: | build
	docker run --init --rm -d -v$(abspath ../svsm):/svsm --name svsm-${USER}-latest --network=host  svsm_build:latest sleep inf

.PHONY:
svsm_exec:| 
	docker exec -it --user ${USER}  svsm-${USER}-latest /bin/bash || true
