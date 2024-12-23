#!/bin/bash

REPO_URL="https://github.com/choinek/php-library-test-docker"

ask_for_directory() {
    read -p "Enter the name of the directory to clone the repository into: " TARGET_DIR
    if [[ -z $TARGET_DIR ]]; then
        echo "Error: Directory name cannot be empty."
        exit 1
    fi
}

if [[ -t 0 ]]; then
    ask_for_directory
else
    echo "Script is running in a piped context. Use an argument or interactive shell."
    exit 1
fi

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
