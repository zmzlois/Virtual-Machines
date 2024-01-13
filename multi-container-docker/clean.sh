#!/usr/bin/env bash

set -euo pipefail -vvv -v

base_dir="$(dirname "$(readlink -f "$0")")"
temp_ini="${base_dir}/tempdir.ini"

function cleanup_tempdir() {


    # Check if the file exists
    if [ ! -f "${temp_ini}" ]; then
        echo "Error: File '${temp_ini}' not found."
        exit 1
    fi

    # Read each line from the file and remove the corresponding directory
    while IFS= read -r directory; do
        if [ -d "$directory" ]; then
            echo "Removing directory: $directory"
            rm -rf "$directory"
        else
            echo "Directory not found: $directory"
        fi
    done <"$temp_ini"

    rm -rf ${temp_ini}
}

cleanup_tempdir