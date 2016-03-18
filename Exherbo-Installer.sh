#!/usr/bin/env sh

set -o errexit
#set -o nounset
set -o xtrace
set -o pipefail

MY_PATH=$(pwd)

STEP=5
STOP_STEP=7

MOUNT_PATH="/mnt/exherbo/"
ROOT_PARTITION="/dev/sda9"
HOME_PARTITION="/dev/sda7"
SWAP_PARTITION="/dev/sda4"

FORMAT_HOME=false
FORMAT_SWAP=false

CHECK_DEFAULT_CONF=false

KERNEL_VERSION="4.5"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_PATH="/usr/src/kernel"

EXHERBO_HOSTNAME="pogam-_g-exherbo"
EXHERBO_USERNAME="pogam-_g"

# STEP = 1
function createPartition {
    mkfs.ext4 "${ROOT_PARTITION}"
    mkdir -p "${MOUNT_PATH}" && mount "${ROOT_PARTITION}" "${MOUNT_PATH}" && cd "${MOUNT_PATH}"
    if [ ${FORMAT_HOME} -eq true ] ; then
        echo "[Info] Formatting: your home partition (${HOME_PARTITION}) will be formatted. Disable the 'FORMAT_HOME' \
        to avoid this behavior."
        mkfs.ext4 "${HOME_PARTITION}"
    fi
    if [ ${FORMAT_SWAP} -eq true ] ; then
        mkswap "${SWAP_PARTITION}" || true
    fi
}

# STEP = 2
function fetchExherbo {
    cd "${MOUNT_PATH}"
    curl -O https://galileo.mailstation.de/stages/amd64/exherbo-amd64-current.tar.xz
    curl -O https://galileo.mailstation.de/stages/amd64/sha1sum
    grep exherbo-amd64-current.tar.xz sha1sum | sha1sum -c
    if [ "$?" != 0 ] ; then
        echo "[Error] Integrity check failed: 'exherbo-amd64-current.tar.xz' and 'sha1sum' doesn't match."
    fi
}

# STEP = 3
function prepareExherbo {
    cd "${MOUNT_PATH}"
    tar xJpf exherbo*xz
    ROOT_UUID=$(blkid ${ROOT_PARTITION} -s UUID -o value)
    HOME_UUID=$(blkid ${HOME_PARTITION} -s UUID -o value)
    SWAP_UUID=$(blkid ${SWAP_PARTITION} -s UUID -o value)
    echo "# /etc/fstab: static file system information.
#
# noatime turns off atimes for increased performance (atimes normally aren't
# needed; notail increases performance of ReiserFS (at the expense of storage
# efficiency). It's safe to drop the noatime options if you want and to
# switch between notail / tail freely.
#
# The root filesystem should have a pass number of either 0 or 1.
# All other filesystems should have a pass number of 0 or greater than 1.
#
# Use /dev/<UUID> for device nodes. To find the UUIDs, use e. g.:
# blkid
# The above command will give you all information you need. Or you use
# blkid /dev/<something>
# to get the UUID for a specific device node.
#
# See the manpage fstab(5) for more information.
#

<fs>       <mountpoint>    <type>    <opts>      <dump/pass>
UUID=${ROOT_UUID}    /               ext4      defaults    0 1
UUID=${HOME_UUID}    /home           ext4      defaults    0 2
UUID=${SWAP_UUID}    swap            swap      defaults    0 0

# glibc 2.2 and above expects tmpfs to be mounted at /dev/shm for
# POSIX shared memory (shm_open, shm_unlink).
# (tmpfs is a dynamically expandable/shrinkable ramdisk, and will
# use almost no memory if not populated with files)
shm                  /dev/shm        tmpfs     nodev,nosuid,noexec  0 0
" > ${MOUNT_PATH}/etc/fstab
}

# STEP = 4
function prepareChrootExherbo {
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

# STEP = 5
function chrootExherbo {
    cd "${MOUNT_PATH}"
    cp /etc/resolv.conf etc/resolv.conf
    cp ${MY_PATH}/Exherbo-Chroot*.sh ./
    chmod +x ./Exherbo-Chroot*.sh
    env -i TERM=${TERM} SHELL=/bin/bash HOME=$HOME $(which chroot) "${MOUNT_PATH}" /bin/bash -c \
        "su - -c \"/Exherbo-Chroot.sh ${STEP} ${STOP_STEP} ${KERNEL_VERSION} ${KERNEL_URL} ${KERNEL_PATH} \
            ${CHECK_DEFAULT_CONF} ${EXHERBO_HOSTNAME} ${EXHERBO_USERNAME}\""
}

# STEP = 99
function cleanExherbo {
    cd "${MOUNT_PATH}"
    rm exherbo-amd64-current.tar.xz
    rm sha1sum
    rm Exherbo-Chroot*.sh
}

function main {
    if [ ${USER} != "root" ] ; then
        echo "[Error] Bad user: This script must be launched as root."
        return
    fi

    if [ ${STEP} -le 1 ] && [ ${STOP_STEP} -ge 1 ] ; then
        createPartition
    fi
    if [ ${STEP} -le 2 ] && [ ${STOP_STEP} -ge 2 ] ; then
        fetchExherbo
    fi
    if [ ${STEP} -le 3 ] && [ ${STOP_STEP} -ge 3 ] ; then
        prepareExherbo
    fi
    if [ ${STEP} -le 4 ] && [ ${STOP_STEP} -ge 4 ] ; then
        prepareChrootExherbo
    fi
    if [ ${STEP} -le 5 ] && [ ${STOP_STEP} -ge 5 ] ; then
        chrootExherbo
    fi

    if [ ${STEP} -le 99 ] && [ ${STOP_STEP} -ge 99 ] ; then
        cleanExherbo
    fi
}

main $*
