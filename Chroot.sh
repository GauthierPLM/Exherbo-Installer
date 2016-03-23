#!/usr/bin/env bash

MY_PATH=$(pwd)i
MOUNT_PATH="/mnt/exherbo"
ROOT_PARTITION="/dev/sda9"
HOME_PARTITION="/dev/sda7"
MOUNT=true

function prepareChrootExherbo {
    mount "${ROOT_PARTITION}" "${MOUNT_PATH}"
    cd "${MOUNT_PATH}"
    mount -o rbind /dev "${MOUNT_PATH}/dev/" \
        || echo "[Warning] Chroot: command 'mount -o rbind ${MOUNT_PATH}/dev/' failed. Continuing..."
    mount -o bind /sys "${MOUNT_PATH}/sys/" \
        || echo "[Warning] Chroot: command 'mount -o bind ${MOUNT_PATH}/sys/' failed. Continuing..."
    mount -t proc none "${MOUNT_PATH}/proc/" \
        || echo "[Warning] Chroot: command 'mount -t proc none ${MOUNT_PATH}/proc/' failed. Continuing.."
    mount /dev/sda1 boot/ \
        || echo "[Warning] Chroot: command 'mount /dev/sda1 boot/' failed. Continuing.."
    mount "${HOME_PARTITION}" home/ \
        || echo "[Warning] Chroot: command 'mount ${HOME_PARTITION} home/' failed. Continuing.."
}

function chrootExherbo {
    cd "${MOUNT_PATH}"
    cp /etc/resolv.conf etc/resolv.conf
    env -i TERM=${TERM} SHELL=/bin/bash HOME=$HOME $(which chroot) "${MOUNT_PATH}" /bin/bash
}

function main {
    if [ ${USER} != "root" ] ; then
        echo "[Error] Bad user: This script must be launched as root."
        return
    fi

    if [ "${MOUNT}" = true ] ; then
        prepareChrootExherbo
    fi

    chrootExherbo
}

main
