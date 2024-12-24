#!/bin/bash

REPO_URL="https://github.com/choinek/php-multienv-library-tester"

read_directory_name() {
    read -r -p "Enter the name of the directory to clone the repository into [default: php-multienv-library-tester]: " TARGET_DIR < /dev/tty
    TARGET_DIR=${TARGET_DIR:-php-multienv-library-tester}
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
