UID ?= $(shell id -u)
GID ?= $(shell id -g)
USER ?= $(shell id -un)
EDK2_DIR ?= "./edk2"
QEMU_DIR ?= "./qemu"
GUEST_LINUX ?= "./linux_guest"
HOST_LINUX ?= "./linux_host"
SVSM_DIR ?= "../svsm"

BUILD_ARGS=--build-arg USER=${USER} --build-arg UID=${UID} --build-arg GID=${GID}
DIRECTORY_MAPS = -v$(abspath ${EDK2_DIR}):/edk2 -v $(abspath ${QEMU_DIR}):/qemu -v $(abspath ${GUEST_LINUX}):/linux_guest -v $(abspath ${HOST_LINUX}):/linux_host -v $(abspath ${SVSM_DIR}):/svsm
.PHONY:
build:
	cp /usr/src/linux-headers-$(shell uname -r)/.config host_config
	docker build ${BUILD_ARGS} -t coconut-artifacts:latest . --network=host

.PHONY:
run:
	docker run --init --rm -d -v$(abspath ../svsm):/svsm -v /lib/modules/:/lib/modules --privileged --name coconut-artifacts-${USER}-latest coconut-artifacts:latest sleep inf


.PHONY:
exec:
	docker exec -it coconut-artifacts-${USER}-latest /bin/bash || true

# individual stage builds

## Linux guest
.PHONY:
linux_guest_docker:
	docker build ${BUILD_ARGS} --target guest_kernel_build -t svsm_linux_guest:latest . --network=host

.PHONY:
linux_guest_run:
	docker run --init --rm -d ${DIRECTORY_MAPS} --name svsm_linux_guest-${USER}-latest svsm_linux_guest:latest sleep inf

linux_guest_configure:
	docker exec -it --user ${USER} svsm_linux_guest-${USER}-latest /bin/sh -c "/linux_guest_configure.sh"

linux_guest_build:
	docker exec -it --user ${USER} svsm_linux_guest-${USER}-latest /bin/sh -c "cd linux_guest; make -j10"

## Linux host
.PHONY:
linux_host_docker:
	docker build ${BUILD_ARGS} --target host_kernel_build -t svsm_linux_host:latest . --network=host

.PHONY:
linux_host_run:
	docker run --init --rm -d ${DIRECTORY_MAPS} --name svsm_linux_host-${USER}-latest svsm_linux_host:latest sleep inf

linux_host_configure:
	docker exec -it --user ${USER} svsm_linux_host-${USER}-latest /bin/sh -c "/linux_host_configure.sh"

linux_host_build:
	docker exec -it svsm_linux_host-${USER}-latest /bin/sh -c "cd /linux_host; make -j 10"

## EDK2
.PHONY:
edk2_docker:
	docker build ${BUILD_ARGS} --target edk2_build -t edk2_build:latest . --network=host

.PHONY:
edk2_run:
	docker run --init --rm -d ${DIRECTORY_MAPS} --name edk2-${USER}-latest edk2_build:latest sleep inf

.PHONY:
edk2_configure:
	docker exec -it --user ${USER} edk2-${USER}-latest /bin/sh -c "cd /edk2; PYTHON3_ENABLE=TRUE PYTHON_COMMAND=python3 make -j16 -C BaseTools"
.PHONY:
edk2_build:
	docker exec -it --user ${USER} edk2-${USER}-latest /bin/bash -c "cd /edk2; source ./edksetup.sh && build -a X64 -b DEBUG -t GCC5 -D DEBUG_ON_SERIAL_PORT -D DEBUG_VERBOSE -p OvmfPkg/OvmfPkgX64.dsc"

## QEMU
.PHONY:
qemu_docker:
	docker build ${BUILD_ARGS} --target qemu_build -t qemu_build:latest . --network=host
.PHONY:
qemu_run:
	docker run --init --rm -d ${DIRECTORY_MAPS} --name qemu-${USER}-latest --network=host qemu_build:latest sleep inf 
.PHONY:
qemu_configure:
	docker exec -it --user ${USER} qemu-${USER}-latest /bin/bash -c "cd /qemu; ./configure --prefix=/qemu/bin/qemu-svsm/ --target-list=x86_64-softmmu; ninja -C build/"
qemu_build:
	docker exec -it --user ${USER} qemu-${USER}-latest /bin/bash -c "cd /qemu; make install"

## SVSM
.PHONY:
svsm_docker:
	docker build ${BUILD_ARGS} --target svsm_build -t svsm_build:latest . --network=host
.PHONY:
svsm_run: | svsm_docker
	echo ${SVSM_DIR}
	docker run --init --rm -d ${DIRECTORY_MAPS} --name svsm-${USER}-latest --network=host  svsm_build:latest sleep inf

svsm_build:
	docker exec -it --user ${USER} svsm-${USER}-latest /bin/bash -c "source ~/.bashrc; cd /svsm; cargo build"

.PHONY:
svsm_exec:| 
	docker exec -it --user ${USER}  svsm-${USER}-latest /bin/bash || true

## Run
final_docker:
	docker build ${BUILD_ARGS} --target final -t svsm_final:latest . --network=host

final_run:
	docker run --init --privileged --rm -d ${DIRECTORY_MAPS} --name svsm-final-${USER}-latest --network=host svsm_final:latest sleep inf

final_exec:|
	docker exec -it svsm-final-${USER}-latest /bin/bash || true
