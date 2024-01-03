# Introduction
This project provides a build environment for the Coconut-SVSM project (https://github.com/coconut-svsm) and it's required dependencies.

While these instructions presume you will use the dependencies from the Coconut-SVSM project(their kernel, their QEMU, their EDK2), the environment is designed to allow you to use modified versions of these projects from anywhere that you require.
This means that you need to provide the paths to the source code for the various projects when you perform the build steps, and the Dockerfile do not clone the repos for you. 

Thus, the "Clone" steps in the instructions below are optional, and it is expected that you will want to use your own code sources as you develop your changes.

# Getting Started

- Clone the Linux kernel you want to use (We recommend using the one from the Coconut SVSM project, but you be you):
```
git clone https://github.com/coconut-svsm/linux
cd linux
git checkout svsm
cd ..
```

Now, copy the linux source tree into `linux_guest` and `linux_host`:
```
cp -r linux/ linux_guest/
cp -r linux/ linux_host/
```


- Clone the QEMU source code (also recommend using Coconut-SVSM's version, this will be a recurring theme):
```
git clone https://github.com/coconut-svsm/qemu
cd qemu
git checkout svsm-v8.0.0
```

- Clone the EDK2 guest firmware (also from coconut-svsm):
```
git clone https://github.com/coconut-svsm/edk2.git
cd edk2/
git checkout svsm
git submodule init
git submodule update
```

- Clone the Coconut-SVSM code itself:
```
git clone https://github.com/coconut-svsm/svsm
```

# Building
## Building the Guest kernel
```
make linux_guest_docker
make GUEST_LINUX=<PATH TO GUEST LINUX SOURCE DIRECTORY> linux_guest_run
make linux_guest_configure
make linux_guest_build
```
## Building the Host kernel
```
make linux_host_docker
make HOST_LINUX=<PATH TO HOST LINUX SOURCE DIRECTORY> linux_host_run
make linux_host_confugure
make linux_host_build
```
## Build EDK2
```
make edk2_docker
make EDK2_DIR=<PATH TO EDK2 SOURCE> edk2_run
make edk2_configure
make edk2_build
```

## Build QEMU
```
make qemu_docker
make QEMU_DIR=<PATH TO QEMU SOURCE> qemu_run
make qemu_configure
make qemu_build
```

## Build SVSM
```
make svsm_docker
make SVSM_DIR=<PATH TO SVSM CODE> svsm_run
make svsm_build
```