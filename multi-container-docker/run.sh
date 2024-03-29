#!/usr/bin/env bash

set -euo pipefail -vvv -v

identifier="$(tr </dev/urandom -dc 'a-z0-9' | fold -w 5 | head -n 1)" || :
NAME="vm-${identifier}"
base_dir="$(dirname "$(readlink -f "$0")")"
temp_ini="${base_dir}/tempdir.ini"
echo "Base directory: ${base_dir}"

function cleanup() {
    echo "Run docker compose down to clean up"
    docker compose down

    rm -rf docker-compose.yml
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        echo "Cleaning up tempdir ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}


function setup_tempdir() {
    TEMP_DIR=$(mktemp --directory "/tmp/${NAME}".XXXXXXXX)
    echo ${TEMP_DIR} >>${temp_ini}
    cp ./Dockerfile ${TEMP_DIR}/Dockerfile
    export TEMP_DIR
}


function create_temporary_ssh_id() {
    ssh-keygen -b 2048 -t rsa -C "${USER}@email.com" -f "${TEMP_DIR}/id_rsa" -N ""
    chmod 600 "${TEMP_DIR}/id_rsa"
    chmod 644 "${TEMP_DIR}/id_rsa.pub"
}

function start_container() {
    echo "Start building all containers"
    DOCKER_COMPOSE_FILE="${base_dir}/docker-compose.yml"

    cat >"${DOCKER_COMPOSE_FILE}" <<EOL
version: '3'


services:
  container1:
    build: 
        context: ${TEMP_DIR}
        dockerfile: ./Dockerfile
        args:
            USER: ${USER}
    ports:
      - "127.0.0.1:2201:22"

  container2:
    build: 
        context: ${TEMP_DIR}
        dockerfile: ./Dockerfile
        args:
            USER: ${USER}
    ports:
      - "127.0.0.1:2202:22"


  container3:
    build: 
        context: ${TEMP_DIR}
        dockerfile: ./Dockerfile
        args:
            USER: ${USER}
    ports:
      - "127.0.0.1:2203:22"

EOL
    docker compose build --no-cache
    echo "Compose up all containers in detached mode"
    docker compose up -d
}

function setup_test_inventory() {
    TEMP_INVENTORY_FILE="${base_dir}/hosts.ini"

    cat >"${TEMP_INVENTORY_FILE}" <<EOL
[target_group]
container1 ansible_host=127.0.0.1 ansible_port=2201
container2 ansible_host=127.0.0.1 ansible_port=2202
container3 ansible_host=127.0.0.1 ansible_port=2203
[target_group:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
EOL
    export ANSIBLE_INVENTORY=TEMP_INVENTORY_FILE
}

function load_configuration() {
    ANSIBLE_CONFIG="${base_dir}/ansible.cfg"

    # ansible-playbook -i "${TEMP_INVENTORY_FILE}" -vvv "${base_dir}/playbook.yml"
}

# TODO: make the trap become executable argument to ./run.sh
setup_tempdir
setup_test_inventory
load_configuration

# trap cleanup EXIT
# trap cleanup ERR
create_temporary_ssh_id
start_container

