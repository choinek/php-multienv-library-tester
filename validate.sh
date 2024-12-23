#!/bin/bash

validate_docker() {
    echo "Validating Docker installation..."
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is not installed. Please install Docker 20.10.0 or later."
        exit 1
    fi

    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    MIN_VERSION="20.10.0"

    # Portable version comparison using awk
    if [[ $(echo -e "$DOCKER_VERSION\n$MIN_VERSION" | awk '{ print $1 | "sort" }' | head -n 1) != "$MIN_VERSION" ]]; then
        echo "Error: Docker version $DOCKER_VERSION is too old. Please upgrade to version 20.10.0 or later."
        exit 1
    fi

    echo "Docker version $DOCKER_VERSION is supported."
}

# Function to check if jq is installed or fallback to grep
validate_jq() {
    if ! command -v jq &>/dev/null; then
        echo "Warning: jq is not installed. Falling back to grep. Results may not be 100% accurate."
        USE_JQ=false
    else
        USE_JQ=true
    fi
}

validate_composer_commands() {
    echo "Validating composer commands..."

    if [[ ! -f docker-compose.yml ]]; then
        echo "Error: docker-compose.yml not found in the current directory."
        exit 1
    fi

    if [[ ! -f {{PLACEHOLDER_DIR}}/composer.json ]]; then
        echo "Error: composer.json not found in {{PLACEHOLDER_DIR}}. Please ensure the file exists."
        exit 1
    fi

    echo "Extracting commands from docker-compose.yml..."
    COMPOSE_COMMANDS=$(grep -E 'command: \["composer"' docker-compose.yml | sed -E 's/.*command: \["composer", "([^"]+)"\].*/\1/' | tr -d '"')

    if [[ -z "$COMPOSE_COMMANDS" ]]; then
        echo "No composer commands found in docker-compose.yml."
        exit 1
    fi

    echo "Commands from docker-compose.yml: $COMPOSE_COMMANDS"
    echo "Validating against {{PLACEHOLDER_DIR}}/composer.json scripts..."

    for COMMAND in $COMPOSE_COMMANDS; do
        if [[ "$USE_JQ" == true ]]; then
            if ! jq -e --arg cmd "$COMMAND" '.scripts[$cmd] != null' {{PLACEHOLDER_DIR}}/composer.json &>/dev/null; then
                echo "Command $COMMAND is missing in {{PLACEHOLDER_DIR}}/composer.json scripts."
                exit 1
            fi
        else
            if ! grep -q "\"$COMMAND\"" {{PLACEHOLDER_DIR}}/composer.json; then
                echo "Command $COMMAND might be missing in {{PLACEHOLDER_DIR}}/composer.json scripts (not 100% sure, jq is not installed)."
                exit 1
            fi
        fi
    done

    echo "Validation successful. All commands are present in {{PLACEHOLDER_DIR}}/composer.json scripts."
}

validate_docker
validate_jq
validate_composer_commands
