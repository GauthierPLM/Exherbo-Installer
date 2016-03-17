#!/usr/bin/env sh

set -o errexit
set -o nounset
#set -o xtrace
set -o pipefail

STEP=2

MOUNT_PATH="/mnt/exherbo/"
ROOT_PARTITION="/dev/sda9"
HOME_PARTITION="/dev/sda7"
SWAP_PARTITION="/dev/sda4"

FORMAT_HOME=false
FORMAT_SWAP=false
UPDATE_EXHERBO=false

KERNEL_VERSION="4.5"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_PATH="/usr/src/kernel"

# STEP = 1
function createPartition {
    mkfs.ext4 "${ROOT_PARTITION}"
    mkdir -p "${MOUNT_PATH}" && mount "${ROOT_PARTITION}" "${MOUNT_PATH}" && cd "${MOUNT_PATH}"
    if [ ${FORMAT_HOME} -eq true ] ; then
        mkfs.ext4 "${HOME_PARTITION}"
    fi
    if [ ${FORMAT_SWAP} -eq true ] ; then
        mkswap "${SWAP_PARTITION}" || true
    fi
}

# STEP = 2
function fetchExherbo {
    curl -O https://galileo.mailstation.de/stages/amd64/exherbo-amd64-current.tar.xz
    curl -O https://galileo.mailstation.de/stages/amd64/sha1sum
    grep exherbo-amd64-current.tar.xz sha1sum | sha1sum -c
    if [ "$?" != 0 ] ; then
        echo "[Error] Integrity check failed: 'exherbo-amd64-current.tar.xz' and 'sha1sum' doesn't match."
    fi
}

# STEP = 3
function prepareExherbo {
    tar xJpf exherbo*xz
    ROOT_UUID=$(blkid ${ROOT_PARTITION} -s UUID -o value)
    HOME_UUID=$(blkid ${HOME_PARTITION} -s UUID -o value)
    SWAP_UUID=$(blkid ${SWAP_PARTITION} -s UUID -o value)
    echo"<fs>       <mountpoint>    <type>    <opts>      <dump/pass>
UUID=${ROOT_UUID}    /               ext4      defaults    0 0
UUID=${HOME_UUID}    /home           ext4      defaults    0 2
UUID=${SWAP_UUID}    swap            swap      defaults    0 0
EOF
" > "${MOUNT_PATH}/etc/fstabn"
}

# STEP = 4
function chrootExherbo {
    mount -o rbind /dev "${MOUNT_PATH}/dev/"
    mount -o bind /sys "${MOUNT_PATH}/sys/"
    mount -t proc none "${MOUNT_PATH}/proc/"
    mount /dev/sda1 boot/
    mount /dev/sda3 home
    cp /etc/resolv.conf etc/resolv.conf
    env -i TERM=${TERM} SHELL=/bin/bash HOME=$HOME $(which chroot) "${MOUNT_PATH}" /bin/bash
    source /etc/profile
    export PS1="(chroot) $PS1"
}

# STEP = 5
function updateExherbo {
    cd /etc/paludis && vim bashrc && vim *conf
    cave sync
}

# STEP = 6
function kernelConfigExherbo {
    mkdir -p "${KERNEL_PATH}"
    cd "${KERNEL_PATH}"
    curl -o "${KERNEL_URL}"
    tar xJpf linux*xz
    mkdir shims
    ln -s /usr/host/bin/x86_64-pc-linux-gnu-pkg-config shims/pkg-config
    PATH=${PWD}/shims:${PATH} make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu- nconfig
}

# STEP = 7
function installKernelExherbo {
    cd "${KERNEL_PATH}"
    make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu- menuconfig
    make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu-
    make HOSTCC=x86_64-pc-linux-gnu-gcc CROSS_COMPILE=x86_64-pc-linux-gnu- modules_install
    cp arch/x86/boot/bzImage /boot/kernel
    echo "[Warning] Exherbo' Grub entry: this script is not yet able to add Exherbo entry to Grub."
}

function main {
    if [ ${USER} != "root" ] ; then
        echo "[Error] Bad user: This script must be launched as root."
        return
    fi

    if [ ${STEP} -le 1 ] ; then
        createPartition
    fi
    if [ ${STEP} -le 2 ] ; then
        fetchExherbo
    fi
    if [ ${STEP} -le 3 ] ; then
        prepareExherbo
    fi
    if [ ${STEP} -le 4 ] ; then
        chrootExherbo
    fi
    if [ ${STEP} -le 5 && ${UPDATE_EXHERBO} -eq true ] ; then
        updateExherbo
    fi
    if [ ${STEP} -le 6 ] ; then
        kernelExherbo
    fi
}

main
