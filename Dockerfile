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

COPY guest_config /linux/.config


WORKDIR /linux/
RUN ./scripts/config --set-str LOCALVERSION "snp-guest"
RUN ./scripts/config --disable LOCALVERSION_AUTO
RUN ./scripts/config --enable  EXPERT
RUN ./scripts/config --enable  DEBUG_INFO
RUN ./scripts/config --enable  DEBUG_INFO_REDUCED
RUN ./scripts/config --enable  AMD_MEM_ENCRYPT
RUN ./scripts/config --disable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
RUN ./scripts/config --enable  KVM_AMD_SEV
RUN ./scripts/config --module  CRYPTO_DEV_CCP_DD
RUN ./scripts/config --disable SYSTEM_TRUSTED_KEYS
RUN ./scripts/config --disable SYSTEM_REVOCATION_KEYS
RUN ./scripts/config --disable MODULE_SIG_KEY
RUN ./scripts/config --module  SEV_GUEST
RUN ./scripts/config --disable IOMMU_DEFAULT_PASSTHROUGH
RUN ./scripts/config --disable PREEMPT_COUNT
RUN ./scripts/config --disable PREEMPTION
RUN ./scripts/config --disable PREEMPT_DYNAMIC
RUN ./scripts/config --disable DEBUG_PREEMPT
RUN ./scripts/config --enable  CGROUP_MISC
RUN ./scripts/config --module  X86_CPUID
RUN ./scripts/config --disable UBSAN
RUN yes "" | make -j 10 olddefconfig
RUN make -j20


FROM kernel_build as host_kernel_build
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="$HOME/.cargo/bin:${PATH}"
RUN ${HOME}/.cargo/bin/rustup default stable
WORKDIR linux/
COPY host_config .config
RUN ./scripts/config --set-str LOCALVERSION "snp-host"
RUN yes "" | make -j 10 olddefconfig
RUN make -j20
RUN make -j20 bindeb-pkg

# Qemu
FROM base as qemu_build

RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
		pkg-config \
		libglib2.0-dev \
		libpixman-1-dev
RUN git clone https://github.com/coconut-svsm/qemu && cd qemu && git checkout svsm-v8.0.0

WORKDIR qemu
RUN ./configure --prefix=/work/bin/qemu-svsm/ --target-list=x86_64-softmmu
RUN ninja -C build/
RUN make install

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
RUN git clone https://github.com/coconut-svsm/edk2.git && cd edk2 && git checkout svsm && git submodule init && git submodule update

WORKDIR /edk2
RUN PYTHON3_ENABLE=TRUE PYTHON_COMMAND=python3 make -j16 -C BaseTools/
RUN source ./edksetup.sh && build -a X64 -b DEBUG -t GCC5 -D DEBUG_ON_SERIAL_PORT -D DEBUG_VERBOSE -p OvmfPkg/OvmfPkgX64.dsc
#RUN cp Build/OvmfX64/DEBUG_GCC5/FV/OVMF_CODE.fd /firmware/
#RUN cp Build/OvmfX64/DEBUG_GCC5/FV/OVMF_VARS.fd /firmware/

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

FROM ubuntu:22.04 as final
RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
		pkg-config \
		libglib2.0-dev \
		libpixman-1-dev
COPY --from=edk2_build /edk2/Build/OvmfX64/DEBUG_GCC5/FV/OVMF_CODE.fd /work/firmware/
COPY --from=edk2_build /edk2/Build/OvmfX64/DEBUG_GCC5/FV/OVMF_VARS.fd /work/firmware/
COPY --from=qemu_build /work/bin/qemu-svsm /work/bin/qemu-svsm
COPY --from=guest_kernel_build /linux/arch/x86/boot/bzImage /work/kernel/guest/
COPY --from=host_kernel_build /linux/arch/x86/boot/bzImage /work/kernel/host/
COPY --from=host_kernel_build /*.deb /work/kernel/host/
