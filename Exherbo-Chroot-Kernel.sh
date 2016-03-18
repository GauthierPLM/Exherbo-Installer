#!/usr/bin/env sh

set -o errexit
#set -o nounset
set -o xtrace
set -o pipefail

STEP="$1"
STOP_STEP="$2"
KERNEL_VERSION="$3"
KERNEL_URL="$4"
KERNEL_PATH="$5"

CONFIG_TOOL="menuconfig"

# STEP = 7
function kernelConfigExherbo {
    mkdir -p "${KERNEL_PATH}"
    cd "${KERNEL_PATH}"
    if [ ! -e $(basename "${KERNEL_URL}") ] ; then
        curl -O "${KERNEL_URL}"
        tar xJpf linux*xz
    else
        echo "Kernel already present. Use existing version."
    fi
    cd "${KERNEL_PATH}/linux-${KERNEL_VERSION}/"
    mkdir -p shims
    ln -s -f /usr/host/bin/x86_64-pc-linux-gnu-pkg-config shims/pkg-config
    PATH=${PWD}/shims:${PATH} make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu- ${CONFIG_TOOL}
}

# STEP = 8
function installKernelExherbo {
    cd "${KERNEL_PATH}/linux-${KERNEL_VERSION}/"
    make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu- CONFIG_TOOL
    make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu-
    make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu- modules_install
    cp arch/x86/boot/bzImage /boot/kernel
    echo "[Warning] Exherbo' Grub entry: this script is not yet able to add Exherbo entry to Grub."
}

function main {
    if [ "$#" != 5 ] ; then
        echo "[Error] Chroot Kernel: usage: <STEP> <STOP_STEP> <KERNEL_VERSION> <KERNEL_URL> <KERNEL_PATH>."
        return
    fi

    if [ ${STEP} -le 7 ] && [ ${STOP_STEP} -ge 7 ] ; then
        kernelConfigExherbo
    fi
    if [ ${STEP} -le 8 ] && [ ${STOP_STEP} -ge 8 ] ; then
        installKernelExherbo
    fi
}

main $*
