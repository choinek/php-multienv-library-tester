ARG PHP_VERSION=8.2
FROM php:${PHP_VERSION}-cli AS base

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    && docker-php-ext-install zip pcntl

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

FROM base AS with-files

COPY . /app/

RUN if [ ! -f "composer.json" ]; then \
        echo "Error: composer.json not found in /app"; \
        exit 1; \
    fi

RUN composer install --prefer-dist --no-progress --no-scripts

CMD ["composer", "php-library-test-docker-cmd"]
