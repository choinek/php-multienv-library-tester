#!/bin/bash

REPO_URL="https://github.com/choinek/php-library-test-docker"

read_directory_name() {
    read -p "Enter the name of the directory to clone the repository into: " TARGET_DIR < /dev/tty
    if [[ -z $TARGET_DIR ]]; then
        echo "Error: Directory name cannot be empty."
        exit 1
    fi
}

read_directory_name

if [[ -d $TARGET_DIR ]]; then
    echo "Error: Directory '$TARGET_DIR' already exists. Exiting."
    exit 1
fi

echo "Cloning repository into '$TARGET_DIR'..."
git clone "$REPO_URL" "$TARGET_DIR"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to clone repository. Exiting."
    exit 1
fi

cd "$TARGET_DIR" || exit 1

if [[ -f setup.sh ]]; then
    echo "Running setup script..."
    bash setup.sh
else
    echo "Error: setup.sh not found in the repository."
    exit 1
fi
