#!/bin/bash

CONFIG_FILE=".php-library-test-docker.config"
PLACEHOLDER_DIR="{{PLACEHOLDER_DIR}}"
DEFAULT_PHP_VERSIONS="8.1,8.2,8.3,8.4"
FILES_WITH_PLACEHOLDERS=("Dockerfile" "docker-compose.yml" "docker-compose.test.yml" "Makefile")

load_config() {
    if [[ -f $CONFIG_FILE ]]; then
        echo "Loading existing configuration from $CONFIG_FILE..."
        # shellcheck source=.php-library-test-docker.config
        source "$CONFIG_FILE"
        if [[ -z $mode || -z $php_versions ]]; then
            echo "Error: Configuration file is incomplete. Please review $CONFIG_FILE. Fastest way to fix is to remove this file."
            exit 1
        fi
        echo "Configuration loaded: mode=$mode, php_versions=$php_versions, development=${development:-false}"
        return 0
    else
        echo "No existing configuration found."
        return 1
    fi
}

configure_php_versions() {
    echo "Available PHP versions: $DEFAULT_PHP_VERSIONS"
    read -p "Enter PHP versions (comma-separated) or press Enter to use defaults: " user_versions
    if [[ -z $user_versions ]]; then
        php_versions="$DEFAULT_PHP_VERSIONS"
    else
        php_versions="$user_versions"
    fi
    echo "Using PHP versions: $php_versions"
}

configure_repository() {
    read -p "Would you like to clone a library repository? (yes/no): " clone_repo
    if [[ $clone_repo == "yes" ]]; then
        while true; do
            read -p "Enter the repository public URL: " repo_url
            read -p "Check if it's correct - I will run: git clone \"$repo_url\" src-library (yes/no): " confirm
            if [[ $confirm == "yes" ]]; then
                mkdir -p src-library
                git clone "$repo_url" src-library
                if [[ $? -eq 0 ]]; then
                    echo "Repository cloned into src-library."
                    break
                else
                    echo "Failed to clone repository. Please check the URL and try again."
                fi
            else
                echo "Please enter the repository URL again."
            fi
        done

        if [[ -f src-library/.gitignore ]]; then
            cp src-library/.gitignore .dockerignore
            echo "Copied .gitignore from library to .dockerignore."
        else
            echo "Warning: .gitignore not found in the repository."
        fi

        if ! grep -q "composer.lock" .dockerignore; then
            echo "composer.lock" >> .dockerignore
            echo "Added 'composer.lock' to .dockerignore."
            echo "Please ensure 'composer.lock' is added to .gitignore in your library repository."
        fi
    else
        echo "Skipping repository setup."
    fi
}


save_config() {
    echo "Saving configuration..."
    echo "mode=$mode" > "$CONFIG_FILE"
    echo "php_versions=$php_versions" >> "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE."
}

replace_placeholders() {
    if [[ $development == "true" ]]; then
        echo "Development mode is enabled. Skipping placeholder replacement."
        return
    fi

    echo "Replacing $PLACEHOLDER_DIR in files..."

    case $mode in
        subdirectory) REPLACEMENT="src-library" ;;
        rootpath) REPLACEMENT="." ;;
        *)
            echo "Error: Unsupported mode '$mode' in configuration."
            exit 1
            ;;
    esac

    for file in "${FILES_WITH_PLACEHOLDERS[@]}"; do
        template_file="$file.template"
        output_file="$file"

        if [[ -f $template_file ]]; then
            cp "$template_file" "$output_file"
            echo "Copied $template_file to $output_file"

            sed -i '' "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$output_file" 2>/dev/null || \
            sed -i "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$output_file"
            echo "Replaced placeholders in $output_file"
        else
            echo "Template file $template_file not found. Skipping."
        fi
    done

    echo "Placeholder replacement completed. Using directory: $REPLACEMENT."
}

reset_configuration() {
    echo "Resetting configuration..."
    for file in "${FILES_WITH_PLACEHOLDERS[@]}"; do
        if [[ -f $file ]]; then
            rm -f "$file"
            echo "Removed $file"
        fi
    done

    if [[ -f $CONFIG_FILE ]]; then
        rm -f "$CONFIG_FILE"
        echo "Removed configuration file: $CONFIG_FILE"
    fi

    echo "Configuration reset complete. You can now run the setup again."
}

if load_config; then
    echo "Setup already configured."
    echo "1) Change PHP versions"
    echo "2) Reset configuration"
    read -p "Enter your choice (1/2): " choice

    case $choice in
        1)
            configure_php_versions
            save_config
            echo "PHP versions updated."
            ;;
        2)
            reset_configuration
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    echo "Setup Working Mode:"
    echo "1) Standalone Mode (library in subdirectory for independent testing)"
    echo "2) Integrated Mode (library in root path for pipeline testing)"
    echo "3) Composer Mode (simulate installation via Composer)"
    read -p "Enter your choice (1/2/3): " choice

    case $choice in
        1) mode="subdirectory" ;;
        2) mode="rootpath" ;;
        3) mode="composer" ;;
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac

    echo "Selected mode: $mode"

    configure_php_versions
    configure_repository
    save_config
    replace_placeholders
fi

echo "Setup script complete."
