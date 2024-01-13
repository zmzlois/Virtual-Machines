#!/usr/bin/env bash

set -euo pipefail -vvv -v

identifier="$(tr </dev/urandom -dc 'a-z0-9' | fold -w 5 | head -n 1)" || :
NAME="vm-${identifier}"
base_dir="$(dirname "$(readlink -f "$0")")"
echo "Base directory: ${base_dir}"

function cleanup() {
    container_id=$(docker inspect --format="{{.Id}}" "${NAME}" || :)
    if [[ -n "${container_id}" ]]; then
        echo "Cleaning up container ${NAME}"
        docker rm --force "${container_id}"
    fi
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        echo "Cleaning up tempdir ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}

function setup_tempdir() {
    TEMP_DIR=$(mktemp --directory "/tmp/${NAME}".XXXXXXXX)
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

    cat > "${DOCKER_COMPOSE_FILE}" << EOL
    version: '3'


services:
  container1:
    build: .
    ports:
      - "2201:22"
    networks:
      - ansible-net

  container2:
    build: .
    ports:
      - "2202:22"
    networks:
      - ansible-net

  container3:
    build: .
    ports:
      - "2203:22"
    networks:
      - ansible-net

networks:
  ansible-net:
EOL
    echo "Compose up all containers in detached mode"
    docker compose up -d
}

function setup_test_inventory() {
    TEMP_INVENTORY_FILE="${TEMP_DIR}/hosts"

    cat >"${TEMP_INVENTORY_FILE}" <<EOL
[target_group]
localhost:2201
localhost:2202
localhost:2203
[target_group:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
EOL
    export TEMP_INVENTORY_FILE
}

function load_configuration() {
    ANSIBLE_CONFIG="${base_dir}/ansible.cfg"
    export ANSIBLE_INVENTORY=${TEMP_DIR}/hosts
    # ansible-playbook -i "${TEMP_INVENTORY_FILE}" -vvv "${base_dir}/playbook.yml"
}

setup_tempdir
trap cleanup EXIT
trap cleanup ERR
create_temporary_ssh_id
setup_test_inventory
load_configuration

for i in {1..3}; do

    start_container
done
