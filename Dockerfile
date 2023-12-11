from ubuntu:22.04 as base

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


# Host kernel
from base as host_kernel_build
RUN git clone https://github.com/coconut-svsm/linux && cd linux && git checkout svsm

# Qemu
from base as qemu_build
RUN git clone https://github.com/coconut-svsm/qemu && cd qemu && git checkout svsm-v8.0.0

WORKDIR qemu
RUN ./configure --prefix /work/bin/qemu-svsm/ --target-list=x86_64-softmmu
RUN ninja -C build/
RUN make install

# EDK2
from base as edk2_build
WORKDIR /
RUN git clone https://github.com/coconut-svsm/edk2.git && cd edk2 && git checkout svsm && git submodule init && git submodule update

WORKDIR /edk2
RUN PYTHON3_ENABLE=TRUE PYTHON_COMMAND=python3 make -j16 -C BaseTools/ && source ./edksetup.sh && build -a X64 -b DEBUG -t GCC5 -D DEBUG_ON_SERIAL_PORT -D DEBUG_VERBOSE -p OvmfPkg/OvmfPkgX64.dsc && cp Build/OvmfX64/DEBUG_GCC5/FV/OVMF_CODE.fd /firmware/ && cp Build/OvmfX64/DEBUG_GCC5/FV/OVMF_VARS.fd /firmware/

# SVSM
from base as svsm_build
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.74.1

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="$HOME/.cargo/bin:${PATH}"
RUN rustup install 1.74.1
WORKDIR /
RUN git clone https://github.com/coconut-svsm/svsm
WORKDIR /svsm
RUN make


from ubuntu:22.04 as final
COPY --from=edk2_build /edk2/Build/OvmfX64/DEBUG_GCC5/FV/OVMF_CODE.fd /work/firmware
COPY --from=edk2_build /edk2/Build/OvmfX64/DEBUG_GCC5/FV/OVMF_VARS.fd /work/firmware
COPY --from=qemu_build /work/bin/qemu-svsm /work/bin/qemu-svsm
COPY --from=svsm_build /svsm/target/ /work/svsm/target/
