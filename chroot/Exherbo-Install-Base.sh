#!/usr/bin/env bash

set -o errexit
#set -o nounset
set -o xtrace
set -o pipefail

STEP="$1"
STOP_STEP="$2"
KERNEL_VERSION="$3"
KERNEL_URL="$4"
KERNEL_PATH="$5"
CHECK_DEFAULT_CONF="$6"
EXHERBO_HOSTNAME="$7"
EXHERBO_USERNAME="$8"

# STEP = 6
function checkExherbo {
    cd /etc/paludis && vim bashrc && vim *conf
}

# STEP = 9
function stageExherbo {
    cave update-world app-editors/vim
    cave update-world app-text/wgetpaste
    cave update-world net-misc/dhcpcd
    cave update-world sys-devel/gdb
    cave update-world net-misc/iputils
    cave update-world sys-apps/iproute2
    cave update-world sys-apps/pciutils
    cave purge -x
}

# STEP = 10
function configExherbo {
    echo "${EXHERBO_HOSTNAME}" > /etc/hostname
    echo "
127.0.0.1    ${EXHERBO_HOSTNAME}.domain.foo    ${EXHERBO_HOSTNAME}    localhost
::1          localhost" >> /etc/hosts
    ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
}

# STEP = 11
function updateExherbo {
    cave sync
    systemd-machine-id-setup
    cave resolve sys-apps/systemd -x
    cave resolve repository/hardware -x
    cave resolve firmware/linux-firmware -x
    cave resolve net-wireless/iwlwifi-7260-ucode -x
    cave resolve world -c -x
}

# STEP = 12
function configUserExherbo {
    echo "[Info] Choose a root password."
    passwd root
    useradd -g users -G adm,disk,wheel,cdrom,video,usb, -m -s /bin/bash "${EXHERBO_USERNAME}"
}

function main {
    if [ "$#" != 8 ] ; then
        echo "[Error] Chroot Kernel: usage: <STEP> <STOP_STEP> <KERNEL_VERSION> \
            <KERNEL_URL> <KERNEL_PATH> <CHECK_DEFAULT_CONF> <EXHERBO_HOSTNAME> <EXHERBO_USERNAME."
        return
    fi

    source /etc/profile
    export PS1="(chroot) $PS1"

    if [ "${STEP}" -le 6 ] && [ "${STOP_STEP}" -ge 6 ] && [ "${CHECK_DEFAULT_CONF}" -eq true ]
    then
        checkExherbo
    fi

    # STEP 7 et 8
    /Exherbo-Install-Kernel.sh "${STEP}" "${STOP_STEP}" "${KERNEL_VERSION}" "${KERNEL_URL}" "${KERNEL_PATH}"

    if [ "${STEP}" -le 9 ] && [ "${STOP_STEP}" -ge 9 ] ; then
        stageExherbo
    fi
    if [ "${STEP}" -le 10 ] && [ "${STOP_STEP}" -ge 10 ] ; then
        configExherbo
    fi
    if [ "${STEP}" -le 11 ] && [ "${STOP_STEP}" -ge 11 ] ; then
        updateExherbo
    fi
    if [ "${STEP}" -le 12 ] && [ "${STOP_STEP}" -ge 12 ] ; then
        configUserExherbo
    fi
}

main $*
