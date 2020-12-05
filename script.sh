#!/bin/bash

set -eu

trap cleanup EXIT

#
##
update_system() {
    #
    apt update
    apt -yqq upgrade
}

#
##
install_base_system() {
    #
    apt -yqq install --no-install-recommends apt-utils 2>&1
    apt -yqq install --no-install-recommends apt-transport-https 2>&1
    #
    apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
}

#
##
get_environment_file() {
    apt -yqq install wget
    wget https://raw.githubusercontent.com/deploy-script/minio/master/.env
}

#
##
setup_environment() {
    # check .env file exists
    if [ ! -f .env ]; then
        get_environment_file
    fi

    # load env file
    set -o allexport
    source .env
    set +o allexport

    echo >&2 "Deploy-Script: [ENV]"
    echo >&2 "$(printenv)"
}

#
##
install_minio() {
    wget https://dl.min.io/server/minio/release/linux-amd64/minio
    
    chmod +x minio
    
    mv minio /usr/local/bin/minio
    
    rm -f /usr/bin/minio
    
    ln -s /usr/local/bin/minio /usr/bin/minio
    
    mkdir -p $DATA_DIRECTORY
    
    #
    crontab -l | grep -q "MINIO_ACCESS_KEY" && echo 'MinIO startup cron task already exists!' || \
    crontab -l | { cat; echo -e "@reboot while sleep 1; do MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY MINIO_SECRET_KEY=$MINIO_SECRET_KEY minio server $DATA_DIRECTORY >> .minio.log 2>&1 ; done >/dev/null 2>&1"; } | crontab -
    
    #
    export MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY
	export MINIO_SECRET_KEY=$MINIO_SECRET_KEY
	minio server $DATA_DIRECTORY >> .minio.log 2>&1 &
}

#
##
cleanup() {
    #
    rm -f .env
    rm -f script.sh
}

#
##
main() {
    echo >&2 "Deploy-Script: [OS] $(uname -a)"

    #
    update_system
    
    #
    install_base_system

    #
    setup_environment

    #
    install_minio

    #
    cleanup

    echo >&2 "Install completed."
}

# Check is root user
if [[ $EUID -ne 0 ]]; then
    echo "You must be root user to install scripts."
    sudo su
fi

main
