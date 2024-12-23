#!/bin/bash -u

CONFIG_FILE=".php-library-test-docker.config"
PLACEHOLDER_DIR="{{PLACEHOLDER_DIR}}"
DEFAULT_PHP_VERSIONS="8.1,8.2,8.3,8.4"
FILES_WITH_PLACEHOLDERS=("Dockerfile" "docker-compose.yml" "docker-compose.test.yml" "validate.sh")

load_config() {
    if [[ -f $CONFIG_FILE ]]; then
        echo "[Info] Loading existing configuration from $CONFIG_FILE..."
        # shellcheck source=.php-library-test-docker.config
        source "$CONFIG_FILE"
        if [[ -z $MODE || -z $PHP_VERSIONS ]]; then
            echo "[Error] Configuration file is incomplete. Please review $CONFIG_FILE and/or remove it and restart the setup."
            exit 1
        fi
        echo "[Info] Configuration loaded: MODE=$MODE, PHP_VERSIONS=$PHP_VERSIONS, SELF_DEVELOPMENT=${SELF_DEVELOPMENT:-false}, PHP_VERSION_ACTIVE_DEVELOPMENT=${PHP_VERSION_ACTIVE_DEVELOPMENT:-none}"
        return 0
    else
        echo "[Info] No existing configuration found."
        return 1
    fi
}

configure_php_versions() {
    echo "Available PHP versions: $DEFAULT_PHP_VERSIONS"
    read -p "Enter PHP versions (comma-separated) or press Enter to use defaults: " user_versions
    if [[ -z $user_versions ]]; then
        PHP_VERSIONS="$DEFAULT_PHP_VERSIONS"
    else
        user_versions=$(echo "$user_versions" | tr -d ' ')
        IFS=',' read -r -a version_array <<< "$user_versions"
        valid_versions=()
        for version in "${version_array[@]}"; do
            if ! [[ $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
                echo "❌ php:${version}-cli: invalid PHP version format: $version (must follow SemVer, e.g., 8.1 or 8.1.2)"
                continue
            fi
            if curl -sSf "https://registry.hub.docker.com/v2/repositories/library/php/tags/$version" 2>/dev/null > /dev/null; then
                echo "✔ php:${version}-cli: available"
                valid_versions+=("$version")
            else
                echo "❌ php:${version}-cli: not available on Docker Hub."
            fi
        done
        if [[ ${#valid_versions[@]} -eq 0 ]]; then
            echo "Error: No valid or available PHP versions provided."
            exit 1
        fi
        PHP_VERSIONS=$(IFS=','; echo "${valid_versions[*]}")
    fi
    echo "Using PHP versions: $PHP_VERSIONS"
}


configure_repository() {
    read -p "Would you like to clone a library repository? Warning - it will remove src-library directory if exists. (Y/n): " clone_repo
    rm -rf src-library
    if [[ $clone_repo != "n" && $clone_repo != "N" ]]; then
        while true; do
            read -p "Enter the repository address: " repo_url
            read -p "Check if it's correct - I will run: git clone \"$repo_url\" src-library (Y/n): " confirm
            if [[ $confirm != "n" && $confirm != "N" ]]; then
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
    echo "MODE=$MODE" > "$CONFIG_FILE"
    echo "PHP_VERSIONS=$PHP_VERSIONS" >> "$CONFIG_FILE"
    echo "PHP_VERSION_ACTIVE_DEVELOPMENT=${PHP_VERSION_ACTIVE_DEVELOPMENT:-}" >> "$CONFIG_FILE"
    echo "SELF_DEVELOPMENT=${SELF_DEVELOPMENT:-false}" >> "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE."
}

replace_placeholders() {
    if [[ $SELF_DEVELOPMENT == "true" ]]; then
        echo "Development mode is enabled. Skipping placeholder replacement."
        return 0
    fi

    echo "Replacing $PLACEHOLDER_DIR in files..."

    case $MODE in
        subdirectory) REPLACEMENT="src-library" ;;
        rootpath) REPLACEMENT="." ;;
        *)
            echo "[Error] Unsupported mode '$MODE' in configuration."
            exit 1
            ;;
    esac

    for file in "${FILES_WITH_PLACEHOLDERS[@]}"; do
        template_file="$file.template"
        output_file="$file"
        echo "--- Processing: $template_file -> $output_file ---"
        if [[ -f $template_file ]]; then
            cp "$template_file" "$output_file"
            echo " ✅ Copied $template_file to $output_file"

            sed -i '' "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$output_file" 2>/dev/null || \
            sed -i "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$output_file"
            echo " 🔧 Replaced placeholders in $output_file"
        else
            echo " ❌ Template file $template_file not found. Skipping."
        fi
        echo "---"
    done

    echo "Placeholder replacement completed. Using directory: $REPLACEMENT."
}


generate_docker_compose() {
    local template_file="docker-compose.test.yml.template"
    local output_file="docker-compose.test.yml"

    echo "Generating $output_file from $template_file..."

    if [[ -f $template_file ]]; then
        template=$(<"$template_file")

        iterator_block="${template#*<<<ITERATOR_START>>>}"
        iterator_block="${iterator_block%<<<ITERATOR_END>>>*}"
        iterator_block=$(echo "$iterator_block" | sed '1d;$d')

        IFS=',' read -ra php_versions_array <<< "$PHP_VERSIONS"

        if [[ ${#php_versions_array[@]} -eq 0 ]]; then
            echo "Error: PHP_VERSIONS array is empty or not set."
            exit 1
        fi

        local services=""
        for version in "${php_versions_array[@]}"; do
            version=$(echo "$version" | xargs)
            if [[ -z $version ]]; then
                continue
            fi
            service="${iterator_block//<<<PHP_VERSION>>>/$version}"
            services+="$service\n"
        done

        final_content=$(echo -e "$template" | awk '
            BEGIN { in_block = 0 }
            /<<<ITERATOR_START>>>/ { in_block = 1; print "<<<ITERATOR_PLACEHOLDER>>>"; next }
            /<<<ITERATOR_END>>>/ { in_block = 0; next }
            !in_block { print }
        ')

        final_content="${final_content//<<<ITERATOR_PLACEHOLDER>>>/${services}}"

        echo -e "$final_content" > "$output_file"
        echo "Generated $output_file with services for PHP versions: ${PHP_VERSIONS[*]}"
    else
        echo "Error: Template file $template_file not found."
        exit 1
    fi
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

configure_active_php_version() {
    local default_version="8.3"
    echo "Setting active development PHP version (default: $default_version)"

    while true; do
        read -p "Enter PHP version or press Enter to use default: " user_version
        user_version=${user_version:-$default_version}

        if ! [[ $user_version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            echo "❌ Error: Invalid PHP version format: $user_version (must follow SemVer, e.g., 8.1 or 8.1.2). Please try again."
            continue
        fi

        if curl -sSf "https://registry.hub.docker.com/v2/repositories/library/php/tags/$user_version" 2>/dev/null > /dev/null; then
            echo "✔ php:${user_version}-cli available"
            PHP_VERSION_ACTIVE_DEVELOPMENT="$user_version"
            break
        else
            echo "❌ Error: php:${user_version}-cli not available on Docker Hub. Please try again."
        fi
    done

    echo "Active development PHP version set to: $PHP_VERSION_ACTIVE_DEVELOPMENT"
}


main_menu() {
    while true; do
        if [[ $SELF_DEVELOPMENT == "true" ]]; then
            echo "! Warning - you are using development mode. It's not intended to test libraries, but to develop this script."
        fi
        echo ""
        echo "Choose one of available Working Modes:"
        echo "   1) Standalone Mode (library in subdirectory for independent testing)"
        echo "   2) Integrated Mode (library in root path for pipeline testing)"
        echo "   3) Composer Mode (simulate installation via Composer)"
        echo "   ---"
        if [[ $SELF_DEVELOPMENT == "true" ]]; then
            echo "   undev) Disable Development Mode"
            dev_option_label="undev"
        else
            echo "   dev) Development Mode (do not use it for library testing)"
            dev_option_label="dev"
        fi
        echo ""
        read -p "Please select an option (1/2/3/$dev_option_label): " choice

        case $choice in
            1)
                MODE="subdirectory"
                break
                ;;
            2)
                MODE="rootpath"
                break
                ;;
            3)
                MODE="composer"
                break
                ;;
            dev)
                SELF_DEVELOPMENT="true"
                save_config
                echo "Development mode enabled. Returning to the menu..."
                ;;
            undev)
                SELF_DEVELOPMENT="false"
                save_config
                echo "Development mode disabled. Returning to the menu..."
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    done

    echo "Selected mode: $MODE"
}

update_main_menu() {
    echo "Setup already configured."
    echo "   1) Change PHP versions"
    echo "   2) Change PHP version for active development"
    echo "   3) Update templates and placeholders"
    echo "   ---"
    echo "   reset) Reset configuration - it will remove all configuration files and you will need to run the setup again."
    if [[ $SELF_DEVELOPMENT == "true" ]]; then
        echo "   undev) Disable Development Mode"
        dev_option_label="undev"
    else
        echo "   dev) Development Mode (do not use it for library testing)"
        dev_option_label="dev"
    fi
    echo ""

    read -p "Enter your choice (1/2/3/$dev_option_label): " choice

    case $choice in
        1)
            configure_php_versions
            save_config
            generate_docker_compose
            echo "PHP versions updated."
            ;;
        2)
            configure_active_php_version
            save_config
            replace_placeholders
            echo "Active development PHP version updated."
            ;;
        3)
            replace_placeholders
            generate_docker_compose
            echo "Templates and placeholders updated."
            ;;
        reset)
            reset_configuration
            ;;
        dev)
            SELF_DEVELOPMENT="true"
            save_config
            echo "Development mode enabled."
            ;;
        undev)
            SELF_DEVELOPMENT="false"
            save_config
            echo "Development mode disabled."
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

if load_config; then
       update_main_menu
else
    main_menu
    configure_php_versions
    configure_active_php_version
    configure_repository
    save_config
    replace_placeholders
fi

echo "Setup script complete."
