FROM ubuntu:22.04 as base

ARG USER
ARG UID
ARG GID

RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
		build-essential \
		ninja-build \
		python3-dev \
		curl \
		ca-certificates \
		git \
		gcc \
		g++

RUN groupadd --gid ${GID} ${USER}
RUN useradd -ms /bin/bash --uid ${UID} --gid ${GID} ${USER}


# Host kernel
FROM base as kernel_build
RUN git clone https://github.com/coconut-svsm/linux && cd linux && git checkout svsm
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
	flex \
	bison \
	libssl-dev \
	libelf-dev \
	bc \
	apt-transport-https \
	ca-certificates \
	lsb-release \
	lxc \
	llvm \
	musl-tools \
	guestfs-tools \
	autoconf \
	automake \
	bash-completion \
	bc \
	bison \
	build-essential \
	ca-certificates \
	cabal-install \
	ccache \
	clang \
	cloud-image-utils \
	cloud-init \
	cmake \
	coreutils \
	cpio \
	curl \
	device-tree-compiler \
	doxygen \
	dpkg-dev \
	file \
	flex \
	g++ \
	gcc \
	gdb \
	ghc \
	git \
	gnupg \
	haskell-stack \
	iasl \
	jq \
	less \
    libc6-dev-arm64-cross \
	libelf-dev \
	libffi-dev \
	libglib2.0-dev \
	libfdt-dev \
	libpixman-1-dev \
 	libsqlite3-dev \
 	libssl-dev \
 	libxml2-utils \
	nasm \
    netbase \
    openssh-client \
    pkg-config \
    protobuf-compiler \
    procps \
    psmisc \
    python3-dev \
    python3-pip \
    python3-protobuf \
    python3-setuptools \
	qemu-efi \
	rsync \
 	sqlite3 \
 	strace \
	sudo \
	telnet \
	u-boot-tools \
    unzip \
    uuid-dev \
    wabt \
    wget \
    xxd \
    zlib1g-dev \
 	zstd \
 	meson \
	debhelper

FROM kernel_build as guest_kernel_build

COPY guest_config /guest_config
COPY linux_guest_configure.sh /linux_guest_configure.sh

FROM kernel_build as host_kernel_build
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="$HOME/.cargo/bin:${PATH}"
RUN ${HOME}/.cargo/bin/rustup default stable
COPY host_config /host_config
COPY linux_host_configure.sh /linux_host_configure.sh

# Qemu
FROM base as qemu_build

RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
		pkg-config \
		libglib2.0-dev \
		libpixman-1-dev

# EDK2
FROM base as edk2_build
SHELL ["/bin/bash", "-c"]
RUn apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
	uuid-dev \
	nasm \
	iasl
WORKDIR /

RUN PYTHON3_ENABLE=TRUE PYTHON_COMMAND=python3 make -j16 -C BaseTools/
RUN source ./edksetup.sh && build -a X64 -b DEBUG -t GCC5 -D DEBUG_ON_SERIAL_PORT -D DEBUG_VERBOSE -p OvmfPkg/OvmfPkgX64.dsc

FROM registry.suse.com/suse/sle15:latest AS suse_base

ARG USER
ARG UID
ARG GID

RUN zypper --non-interactive install  \
		ninja \
		python3 \
		curl \
		ca-certificates \
		git \
		gcc \
		wget \
		make
RUN zypper --non-interactive install -t pattern devel_basis
RUN groupadd --gid $GID ${USER}
RUN useradd -ms /bin/bash --uid ${UID} --gid ${GID} ${USER}
USER ${USER}

FROM suse_base as svsm_build
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="$HOME/.cargo/bin:${PATH}"
RUN ${HOME}/.cargo/bin/rustup install 1.74.1

FROM base as final
RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
		pkg-config \
		libglib2.0-dev \
		libpixman-1-dev
