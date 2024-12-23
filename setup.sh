#!/bin/bash

CONFIG_FILE=".php-library-test-docker.config"
PLACEHOLDER_DIR="{{PLACEHOLDER_DIR}}"
DEFAULT_PHP_VERSIONS="8.1,8.2,8.3,8.4"

function update_config() {
    local mode="$1"
    local php_versions="$2"

    echo "Saving configuration..."
    echo "mode=$mode" > "$CONFIG_FILE"
    echo "php_versions=$php_versions" >> "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

function inject_files() {
    echo "Injecting files into the current directory..."
    update_config "rootpath" "$DEFAULT_PHP_VERSIONS"
    replace_placeholders "."
}

function create_src_library() {
    echo "Creating 'src-library' directory..."
    mkdir -p src-library
    cd src-library || exit
    read -p "Would you like to clone a repository here? (yes/no): " clone_repo
    if [[ $clone_repo == "yes" ]]; then
        read -p "Enter the repository URL: " repo_url
        git clone "$repo_url" .
    fi
    cd ..
    update_config "subdirectory" "$DEFAULT_PHP_VERSIONS"
    replace_placeholders "src-library"
}

function replace_placeholders() {
    local replacement="$1"
    echo "Replacing placeholders with: $replacement"

    for file in Dockerfile docker-compose.yml docker-compose.test.yml Makefile; do
        if [[ -f $file ]]; then
            sed -i '' "s|$PLACEHOLDER_DIR|$replacement|g" "$file" 2>/dev/null || \
            sed -i "s|$PLACEHOLDER_DIR|$replacement|g" "$file"
            echo "Updated $file"
        else
            echo "File $file not found. Skipping."
        fi
    done
}

function configure_php_versions() {
    echo "Available PHP versions: $DEFAULT_PHP_VERSIONS"
    read -p "Enter PHP versions (comma-separated) or press Enter to use defaults: " user_versions
    if [[ -z $user_versions ]]; then
        echo "$DEFAULT_PHP_VERSIONS"
    else
        echo "$user_versions"
    fi
}

echo "Welcome to the php library multiple versions test setup script!"
echo "Would you like to:"
echo "1) Inject files here (root path mode)"
echo "2) Create 'src-library' directory (subdirectory mode)"

read -p "Enter your choice (1/2): " choice

php_versions=$(configure_php_versions)

case $choice in
1)
    inject_files
    ;;
2)
    create_src_library
    ;;
*)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

echo "Setup complete."
