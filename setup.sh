#!/bin/bash

VERBOSE=false
while getopts "v" opt; do
    case $opt in
        v)
            VERBOSE=true
            ;;
        *)
            echo "Invalid option: -$OPTARG" >&2
            echo "Usage: $0 [-v]"
            echo ""
            echo "Options:"
            echo "  -v Enable verbose mode to display detailed output."
            exit 1
            ;;
    esac
done

SUPPORTED_OSTYPES=("linux-gnu" "darwin")

if [[ -z "$OSTYPE" ]]; then
    echo "The OSTYPE environment variable is not set."
    echo "Supported values:"
    for ost in "${SUPPORTED_OSTYPES[@]}"; do
        echo "  - $ost"
    done

    read -p "Please select your OS type from the list above: " user_ostype

    if [[ " ${SUPPORTED_OSTYPES[*]} " == *"$user_ostype"* ]]; then
        export OSTYPE="$user_ostype"
        echo "OSTYPE set to $OSTYPE."
    else
        echo "Invalid OSTYPE: $user_ostype. Exiting."
        exit 1
    fi
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE=("sed" "-i" "")
else
    SED_INPLACE=("sed" "-i")
fi


CONFIG_FILE=".php-library-test-docker.config"
PLACEHOLDER_DIR="{{PLACEHOLDER_DIR}}"
PLACEHOLDER_PHP_VERSION_ACTIVE_DEVELOPMENT="{{PLACEHOLDER_PHP_VERSION_ACTIVE_DEVELOPMENT}}"
DEFAULT_PHP_VERSIONS="8.1,8.2,8.3,8.4"
DEFAULT_PHP_VERSION_ACTIVE_DEVELOPMENT="8.3"
FILES_WITH_PLACEHOLDERS=("Dockerfile" "docker-compose.yml" "docker-compose.test.yml" "validate.sh")

# COLORS :)

RESET_COLOR="\033[0m"

etext_optionadv() {
    local color_name=$1
    local style_name=$2
    local text=$3
    local require_verbose=$4
    local extra_indent=${5:-6}
    local max_width=${6:-100}

    if [[ $require_verbose == "true" && $VERBOSE == "false" ]]; then
        return
    fi

    local color_code=""
    local style_code=""

    case $color_name in
        green) color_code="32" ;;
        bgreen) color_code="92" ;;
        cyan) color_code="36" ;;
        bcyan) color_code="96" ;;
        yellow) color_code="33" ;;
        byellow) color_code="93" ;;
        red) color_code="31" ;;
        white) color_code="97" ;;
        magenta) color_code="95" ;;
        blue) color_code="34" ;;
        bblue) color_code="94" ;;
        *) color_code="" ;;
    esac

    case $style_name in
        bold) style_code="1" ;;
        normal) style_code="0" ;;
        *) style_code="" ;;
    esac

   wrap_text() {
       local input="$1"
       local width="$2"
       local first_indent="$3"
       local extra_indent="$4"

       local indent="${first_indent:-}"
       local wrapped_text=""
       local first_line=true

       while [[ -n $input ]]; do
           local line_width=$((width - ${#indent}))

           if [[ ${#input} -le $line_width ]]; then
               local line="$input"
               input=""
           else
                local line
                line=$(echo "$input" | grep -oE "^.{1,$line_width}( |$)" | sed 's/[[:space:]]*$//')

               if [[ -z "$line" ]]; then
                   line=${input:0:$line_width}
               fi

               input=${input:${#line}}
               input=$(echo "$input" | sed 's/^[[:space:]]*//')
           fi

           wrapped_text+="${indent}${line}\n"

           if $first_line; then
               first_line=false
               indent=$(printf "%${extra_indent}s")
           fi
       done

       echo -e "$wrapped_text"
   }

    local first_indent
    first_indent=$(echo "$text" | grep -oE "^\s*")
    local indented_text

    if [[ -n $color_code && -n $style_code ]]; then
        indented_text=$(wrap_text "$text" $max_width "$first_indent" "$extra_indent")
        echo -e "\033[${style_code};${color_code}m${indented_text}${RESET_COLOR}"
    else
        indented_text=$(wrap_text "$text" $max_width "$first_indent" "$extra_indent")
        echo -e "${indented_text}"
    fi
}


esuccess() {
    etext_optionadv green normal "  ✔ $1" false 6
}

ecomplete() {
    etext_optionadv green bold "  ➤ $1" false 6
}


esuccesshidden() {
    etext_optionadv cyan bold "  ✔ $1" true
}

einfo() {
    local color=${2:-cyan}
    etext_optionadv "$color" normal "  ⓘ  $1" false
}

einfohidden() {
    etext_optionadv cyan normal "  ⓘ  $1" true
}

eheader() {
    local text=$1
    local line_length=${2:-0}
    local require_verbose=${3:-false}

    if [[ -n "$text" ]]; then
        etext_optionadv bblue bold " $1" $require_verbose
    fi

    if (( line_length > 0 )); then
        local line
        line=$(printf '=%.0s' $(seq 1 "$line_length"))
        local max_width=$((line_length + 4))
        etext_optionadv bblue bold " $line" "$require_verbose" 0 $max_width
    fi
}

eheaderhidden() {
    local text=$1
    local line_length=${2:-0}
    eheader "$1" "$2" true
}

ewarning() {
    etext_optionadv yellow bold "   ⚠️ $1" false 8
}

eaction() {
    etext_optionadv yellow bold "   →️ $1" false 8
}

eerror() {
    etext_optionadv red bold "  ✖ $1" false
}

eoption() {
    text=$1
    left_width=${2:-5}
    style=${3:-bold}
    before="${text%%)*}"
    after="${text#*)}"
    indent=$((left_width + 8))
    before=$(printf "%${left_width}s" "$before")
    etext_optionadv white "$style" "  ➤ \033[0;93m$before)\033[0;97m$after" false $indent
}

eoptionadv() {
    eoption "$1" "$2" normal
}

niceprompt() {
    local formatted_prompt
    formatted_prompt=$(etext_optionadv byellow normal "  ➤ $1" false)
    read -p "$(echo -e "${formatted_prompt} ")" response
    echo "$response"
}

presskey() {
    formatted_prompt=$(etext_optionadv yellow normal "  ➟ Press any key to continue..." false)
    read -p "$(echo -e "${formatted_prompt} ")" response
    echo "$response"
}

equestion() {
    local formatted_prompt
    formatted_prompt=$(etext_optionadv byellow normal "  ➤ $1" false)
    echo "$formatted_prompt"
}


load_config() {
    if [[ -f $CONFIG_FILE ]]; then
        einfohidden "Loading existing configuration from $CONFIG_FILE..."
        # shellcheck source=.php-library-test-docker.config
        source "$CONFIG_FILE"
        if [[ -z $MODE || -z $PHP_VERSIONS ]]; then
            eerror "Configuration file is incomplete. Recreating $CONFIG_FILE..."
            rm $CONFIG_FILE
            load_config
            return $?
        fi
        einfohidden "Configuration loaded: MODE=$MODE, PHP_VERSIONS=$PHP_VERSIONS, SELF_DEVELOPMENT=${SELF_DEVELOPMENT:-false}, PHP_VERSION_ACTIVE_DEVELOPMENT=${PHP_VERSION_ACTIVE_DEVELOPMENT:-none}"
        return 0
    else
        einfohidden "No existing configuration found."
        return 1
    fi
}

configure_php_versions() {
    eheader "Set PHP versions" 76
    einfo "Default value: $DEFAULT_PHP_VERSIONS" bcyan
    einfo "Accepted formats: x, x.y, x.y.z"
    einfo "Example: 8, 8.4, 8.4.3"
    echo ""
    user_versions=$(niceprompt "Enter PHP versions (comma-separated) or press ↵ to use default value: ")
    if [[ -z $user_versions ]]; then
        PHP_VERSIONS="$DEFAULT_PHP_VERSIONS"
    else
        user_versions=$(echo "$user_versions" | tr -d ' ')
        IFS=',' read -r -a version_array <<< "$user_versions"
        valid_versions=()
        for version in "${version_array[@]}"; do
            if ! [[ $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
                echo "❌ php:${version}-cli: Invalid PHP version format: $version (must follow SemVer, e.g., 8.1 or 8.1.2)"
                continue
            fi
            if curl -sSf "https://registry.hub.docker.com/v2/repositories/library/php/tags/$version" 2>/dev/null > /dev/null; then
                esuccess "php:${version}-cli: Available"
                valid_versions+=("$version")
            else
                echo "❌ php:${version}-cli: Not available on Docker Hub."
            fi
        done
        if [[ ${#valid_versions[@]} -eq 0 ]]; then
            eerror "Error: No valid or available PHP versions provided."
            exit 1
        fi
        PHP_VERSIONS=$(IFS=','; echo "${valid_versions[*]}")
    fi

    ecomplete "PHP versions set to: $PHP_VERSIONS"
}


configure_repository() {

    eheader "Setup library repository" 76
    einfo "Actions to perform:"
    eaction "\`./src-library\` directory will be removed"
    echo ""
    clone_repo=$(niceprompt "Execute [Y/n]?")
    rm -rf src-library
    if [[ $clone_repo != "n" && $clone_repo != "N" ]]; then
        while true; do
            repo_url=$(niceprompt "Enter the repository address: ")
            if [[ -z $repo_url ]]; then
                continue
            fi
            echo ""
            einfo "Actions to perform:"
            eaction "git clone \"$repo_url\" src-library"
            echo ""
            confirm=$(niceprompt "Execute [Y/n]?")
            if [[ $confirm != "n" && $confirm != "N" ]]; then
                mkdir -p src-library
                if [[ "$VERBOSE" == "true" ]]; then
                  git clone "$repo_url" src-library
                else
                  git clone "$repo_url" src-library >/dev/null 2>&1
                fi
                if [[ $? -eq 0 ]]; then
                    einfo "Repository cloned into src-library."
                    break
                else
                    eerror "Failed to clone repository. Please check the URL and try again."
                fi
            else
                einfo "Ok, then provide another repository address."
            fi
        done

        einfohidden "Running dockerignore.sh to create/update .dockerignore..."
        sh ./dockerignore.sh
        esuccesshidden "sh .dockerignore finished with status: $?"
    else
        einfo "Skipping repository setup."
    fi
}


save_config() {
    echo "MODE=$MODE" > "$CONFIG_FILE"
    echo "PHP_VERSIONS=$PHP_VERSIONS" >> "$CONFIG_FILE"
    echo "PHP_VERSION_ACTIVE_DEVELOPMENT=${PHP_VERSION_ACTIVE_DEVELOPMENT:-}" >> "$CONFIG_FILE"
    echo "SELF_DEVELOPMENT=${SELF_DEVELOPMENT:-false}" >> "$CONFIG_FILE"
    esuccess "Configuration saved to $CONFIG_FILE."
    echo ""
}

replace_placeholders() {
    eheader "Update templates and placeholders" 76

    if [[ $SELF_DEVELOPMENT == "true" ]]; then
        echo "   ! Development mode is enabled. Skipping placeholder replacement."
        return 0
    fi

    case $MODE in
        subdirectory) REPLACEMENT="./src-library" ;;
        rootpath) REPLACEMENT="." ;;
        *)
            eerror "Unsupported mode '$MODE' in configuration."
            exit 1
            ;;
    esac

    for file in "${FILES_WITH_PLACEHOLDERS[@]}"; do
        template_file="$file.template"
        output_file="$file"
        eheaderhidden "Processing: $template_file -> $output_file"
        if [[ -f $template_file ]]; then
            cp "$template_file" "$output_file"
            esuccesshidden "Copied $template_file to $output_file"
            "${SED_INPLACE[@]}" "s|$PLACEHOLDER_DIR|$REPLACEMENT|g" "$output_file"
            "${SED_INPLACE[@]}" "s|$PLACEHOLDER_PHP_VERSION_ACTIVE_DEVELOPMENT|$PHP_VERSION_ACTIVE_DEVELOPMENT|g" "$output_file"
            esuccess "Replaced placeholders in $output_file"

        else
            eerror "Template file $template_file not found. Skipping."
        fi
        eheaderhidden "" 80
    done

    echo ""
    einfo "Placeholder replacement completed"
    echo ""
}


generate_docker_compose() {
    local template_file="docker-compose.test.yml.template"
    local output_file="docker-compose.test.yml"

    if [[ -f $template_file ]]; then
        template=$(<"$template_file")

        iterator_block="${template#*<<<ITERATOR_START>>>}"
        iterator_block="${iterator_block%<<<ITERATOR_END>>>*}"
        iterator_block=$(echo "$iterator_block" | sed '1d;$d')

        IFS=',' read -ra php_versions_array <<< "$PHP_VERSIONS"

        if [[ ${#php_versions_array[@]} -eq 0 ]]; then
            eerror "PHP_VERSIONS array is empty or not set."
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
        esuccess "Generated $output_file with services for PHP versions: ${PHP_VERSIONS[*]}"
    else
        eerror "Template file $template_file not found."
        exit 1
    fi
}


reset_configuration() {
    for file in "${FILES_WITH_PLACEHOLDERS[@]}"; do
        if [[ -f $file ]]; then
            rm -f "$file"
            esuccess "Removed $file"
        fi
    done

    if [[ -f $CONFIG_FILE ]]; then
        rm -f "$CONFIG_FILE"
        esuccess "Removed configuration file: $CONFIG_FILE"
    fi

    echo ""
    ecomplete "Configuration reset complete. You can now run the setup again."
    echo ""
    exit;
}

configure_active_php_version() {
    eheader "Set PHP version for active development" 76
    einfo "Default value: $DEFAULT_PHP_VERSION_ACTIVE_DEVELOPMENT" bcyan
    einfo "Accepted formats: x, x.y, x.y.z"
    einfo "Example: 8.4.7"
    echo ""

    while true; do
        user_version=$(niceprompt "Enter PHP version or press ↵ to use default value: ")
        user_version=${user_version:-$DEFAULT_PHP_VERSION_ACTIVE_DEVELOPMENT}

        if ! [[ $user_version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            eerror "Error: Invalid PHP version format: $user_version (must follow SemVer, e.g., 8.1 or 8.1.2). Please try again."
            continue
        fi

        if curl -sSf "https://registry.hub.docker.com/v2/repositories/library/php/tags/$user_version" 2>/dev/null > /dev/null; then
            esuccess "php:${user_version}-cli: Available"
            PHP_VERSION_ACTIVE_DEVELOPMENT="$user_version"

            docker_image=$(docker images --filter "label=com.docker.compose.project=$(basename "$(pwd)")" --filter "reference=php-library-test-docker-library-development" --quiet)
            if [[ -n "$docker_image" ]]; then
                docker rmi "$docker_image" --force >/dev/null 2>&1
                esuccesshidden "Removed Docker Image"
            else
                esuccesshidden "No matching Docker Image Found"
            fi
            break
        else
            eerror "Error: php:${user_version}-cli: Not available on Docker Hub. Please try another version or prepare docker-compose.yml without setup."
        fi
    done

    ecomplete "Active development PHP set to version: $PHP_VERSION_ACTIVE_DEVELOPMENT"
}


main_menu() {
    while true; do
        if [[ $SELF_DEVELOPMENT == "true" ]]; then
            echo "   ! Warning - you are using development mode. It's not intended to test libraries, but to develop this script."
        fi
        echo ""
        eheader "PHP Multienv Library Tester First Setup" 76
        eoption "1) Standalone Mode (library in subdirectory for independent testing)" 6
        eoption "2) [Not supported yet] Integrated Mode (library in root path for pipeline testing)" 6
        eoption "3) [Not supported yet] Composer Mode (simulate installation via Composer)" 6
        if [[ $SELF_DEVELOPMENT == "true" ]]; then
            eoptionadv "undev) Disable Development Mode" 6
            dev_option_label="undev"
        else
            eoptionadv "dev) Development Mode (do not use it for library testing)" 6
            dev_option_label="dev"
        fi
        echo ""
        choice=$(niceprompt "Choose: [1, 2, 3, $dev_option_label] or ↵ to exit: ")

        case "$choice" in
            1)
                MODE="subdirectory"
                break
                ;;
            2)
                MODE="rootpath"
                echo "Not supported yet."
                exit 0;
                break
                ;;
            3)
                MODE="composer"
                echo "Not supported yet."
                exit 0;
                break
                ;;
            dev)
                SELF_DEVELOPMENT="true"
                save_config
                einfo "Development mode enabled. Returning to the menu..."
                ;;
            undev)
                SELF_DEVELOPMENT="false"
                save_config
                einfo "Development mode disabled. Returning to the menu..."
                ;;
            exit)
                exit 0
                ;;
            "")
                ecomplete "↵ Exiting..."
                exit 0
                ;;
            *)
                eerror "Invalid choice. Please try again."
                ;;
        esac
    done

    echo ""
    einfo "Selected mode: $MODE"
    echo ""
}

update_main_menu() {
    einfohidden "Setup already configured."
    echo ""
    eheader "PHP Multienv Library Tester Configuration" 76
    eoption "1) Set PHP versions" 6
    eoption "2) Set PHP version for active development" 6
    eoption "3) Update templates and placeholders" 6
    eoptionadv "reset) Reset configuration - it will remove all configuration files and you will need to run the setup again." 6
    if [[ $SELF_DEVELOPMENT == "true" ]]; then
        eoptionadv "undev) Disable Development Mode" 6
        dev_option_label="undev"
    else
        eoptionadv "dev) Development Mode (do not use it for library testing)" 6
        dev_option_label="dev"
    fi
    echo ""

    choice=$(niceprompt "Choose: [1, 2, 3, reset, $dev_option_label] or ↵ to exit: ")
    echo ""
    case $choice in
        1)
            configure_php_versions
            save_config
            replace_placeholders
            generate_docker_compose
            ecomplete "PHP versions updated."
            presskey
            ;;
        2)
            configure_active_php_version
            save_config
            replace_placeholders
            generate_docker_compose
            ecomplete "Active development PHP version updated."
            presskey
            ;;
        3)
            replace_placeholders
            generate_docker_compose
            ecomplete "Templates and placeholders updated."
            presskey
            ;;
        reset)
            reset_configuration
            ;;
        dev)
            SELF_DEVELOPMENT="true"
            save_config
            ecomplete "Development mode enabled."
            presskey
            ;;
        undev)
            SELF_DEVELOPMENT="false"
            save_config
            ecomplete "Development mode disabled."
            presskey
            ;;
        exit)
            exit 0
            ;;
        "")
            ecomplete "Exiting..."
            exit 0
            ;;
        *)
            eerror "Invalid choice."
            ;;
    esac

    update_main_menu
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
    generate_docker_compose
fi
echo ""
eheader "Setup finished" 76
einfo "Next steps:"
eaction "Run \`make help\` to see available commands."
eaction "Run \`make test-all\` to start tests for all PHP versions."
