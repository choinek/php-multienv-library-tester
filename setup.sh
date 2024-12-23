#!/bin/bash

CONFIG_FILE=".php-library-test-docker.config"
PLACEHOLDER_DIR="{{PLACEHOLDER_DIR}}"
DEFAULT_PHP_VERSIONS="8.1,8.2,8.3,8.4"

# Function to load existing configuration
load_config() {
    if [[ -f $CONFIG_FILE ]]; then
        echo "Loading existing configuration from $CONFIG_FILE..."
        source "$CONFIG_FILE"
        if [[ -z $mode || -z $php_versions ]]; then
            echo "Error: Configuration file is incomplete. Please check $CONFIG_FILE."
            exit 1
        fi
        echo "Configuration loaded: mode=$mode, php_versions=$php_versions"
        return 0
    else
        echo "No existing configuration found. Running full setup."
        return 1
    fi
}

# Function to prompt for PHP versions
configure_php_versions() {
    echo "Available PHP versions: $DEFAULT_PHP_VERSIONS"
    read -p "Enter PHP versions (comma-separated) or press Enter to use defaults($DEFAULT_PHP_VERSIONS): " user_versions
    if [[ -z $user_versions ]]; then
        php_versions="$DEFAULT_PHP_VERSIONS"
    else
        php_versions="$user_versions"
    fi
    echo "Using PHP versions: $php_versions"
}

# Function to save the configuration
save_config() {
    echo "Saving configuration..."
    echo "mode=$mode" > "$CONFIG_FILE"
    echo "php_versions=$php_versions" >> "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE."
}

# Function to replace placeholders
replace_placeholders() {
    echo "Replacing $PLACEHOLDER_DIR in files..."

    case $mode in
        subdirectory) REPLACEMENT="src-library" ;;
        rootpath) REPLACEMENT="." ;;
        *)
            echo "Error: Unsupported mode '$mode' in configuration."
            exit 1
            ;;
    esac

    for file in Dockerfile docker-compose.yml docker-compose.test.yml Makefile; do
        if [[ -f $file ]]; then
            sed -i '' "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$file" 2>/dev/null || \
            sed -i "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$file"
            echo "Updated $file"
        else
            echo "File $file not found. Skipping."
        fi
    done

    echo "Placeholder replacement completed. Using directory: $REPLACEMENT."
}

# Main script logic
if load_config; then
    echo "Existing setup detected."
    configure_php_versions
    save_config
    replace_placeholders
else
    echo "Starting new setup..."
    read -p "Enter setup mode (subdirectory/rootpath): " mode
    configure_php_versions
    save_config
    replace_placeholders
fi

echo "Setup complete."
