#!/bin/bash

validate_docker() {
    echo "Validating Docker installation..."
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is not installed. Please install Docker 20.10.0 or later."
        exit 1
    fi

    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    MIN_VERSION="20.10.0"

    if [[ $(echo -e "$DOCKER_VERSION\n$MIN_VERSION" | sort -V | head -n 1) != "$MIN_VERSION" ]]; then
        echo "Error: Docker version $DOCKER_VERSION is too old. Please upgrade to version 20.10.0 or later."
        exit 1
    fi

    echo "Docker version $DOCKER_VERSION is supported."
}

REPO_URL="https://github.com/choinek/php-multienv-library-tester"

if [[ -z "$TARGET_DIR" ]]; then
    read -r -p "Enter the name of the directory to clone the repository into [default: php-multienv-library-tester]: " TARGET_DIR < /dev/tty
    TARGET_DIR=${TARGET_DIR:-php-multienv-library-tester}
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

validate_docker

echo "Repository cloned into '$TARGET_DIR'."
echo "Run the following command to proceed with the setup:"
echo "cd $TARGET_DIR && bash setup.sh"
