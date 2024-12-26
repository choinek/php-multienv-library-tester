#!/bin/bash

LIBRARY_PATH="${LIBRARY_PATH:-src-library}"

esuccess() { echo -e "\033[1;32m$1\033[0m"; }
ewarning() { echo -e "\033[1;33m$1\033[0m"; }
eerror() { echo -e "\033[1;31m$1\033[0m"; }

if [[ -f "$LIBRARY_PATH/.gitignore" ]]; then
    echo "# Auto-generated .dockerignore based on $LIBRARY_PATH/.gitignore" > .dockerignore

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            echo "$line" >> .dockerignore
            continue
        fi

        clean_line=$(echo "$line" | sed 's|^/||')

        if [[ "$clean_line" != "$LIBRARY_PATH/"* ]]; then
            echo "$LIBRARY_PATH/$clean_line" >> .dockerignore
        else
            echo "$clean_line" >> .dockerignore
        fi
    done < "$LIBRARY_PATH/.gitignore"

    esuccess "Copied and processed .gitignore from $LIBRARY_PATH to .dockerignore."
else
    ewarning " !: .gitignore not found in $LIBRARY_PATH. Creating an empty .dockerignore."
    echo "# Auto-generated .dockerignore (no .gitignore found)" > .dockerignore
fi

if ! grep -q "^${LIBRARY_PATH}/composer.lock$" .dockerignore; then
    echo "${LIBRARY_PATH}/composer.lock" >> .dockerignore
    esuccess "Added '${LIBRARY_PATH}/composer.lock' to .dockerignore."
fi

if ! grep -q "^${LIBRARY_PATH}/vendor/$" .dockerignore; then
    echo "${LIBRARY_PATH}/vendor/" >> .dockerignore
    esuccess "Added '${LIBRARY_PATH}/vendor/' to .dockerignore."
fi

esuccess ".dockerignore has been successfully created and updated:"
