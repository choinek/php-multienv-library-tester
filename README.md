# PHP Library Test Environment with Docker

Alpha 0.1. Final version will be released after:
- linux tests
- multiple libraries tests
- talk with some people about it 

ETA for 1.0: 2024-12-30

(Description in progrees)

(short story - this is base for easy testing your PHP libraries in multiple PHP versions)

This repository provides two modes:
- full testing all versions - it builds from start (including composer install, etc.) for 100% clean test
- test with volume mapping - one version, you have to rebuild before switching to another version; its optimization for development

Currently im thinking about:
- how to integrate it with library in automated way (like script for cicd which will download and setup this for tests); there will be script for auto-setup almost everything
- automatic get php versions based on your composer.json info
- maybe handle multiple commands and put them in different files
- override base command for tests (so you don't have to add it to composer.json)
- maybe move it to subdirectory to not mix, or to level up to not mix with library - ill check whats better

---

## Features

- **Test Across Multiple PHP Versions**: Dynamically build and test PHP libraries in different PHP versions using Docker Compose.
- **Local develoment version**: Set up a local development version to test your PHP libraries ad hoc (with mapped volume).

---

## Requirements

- **Docker**: Obviously :P Installed and running on your system.

---

## Getting Started

(! SCRIPT IN PROGRESS - IT WILL BE EASIER)

### Step 1: Download


1. Download the repository as a ZIP file:
    - Go to the [repository page](https://github.com/choinek/php-library-test-docker).
    - Click on "Code" > "Download ZIP".

2. Unpack ZIP and remove README.md and .gitignore to not overwrite your current one :P - it will be fixed in future

3. Move content to your library's root directory (with your `composer.json` file).

### Step 2: Add Files to `.gitignore`

To prevent these files from being tracked in your library's version control, add the following lines to your `.gitignore`:

```
# PHP Library Test Docker files
docker-compose.yml
docker-compose.test.yml
Dockerfile
Makefile
php-library-test-docker-output/
```

### Step 3: Update `composer.json`

1. Add your cli for tests to `composer.json`:
    ```json
    {
        "scripts": {
            "php-library-test-docker-cmd": "vendor/bin/phpunit --testdox"
        }
    }
    ```

### Step 4: Adjust Dockerfile and docker-compose.test.yml

- You might need more PHP extensions or other dependencies in your Dockerfile. Adjust it as needed.
- 


### Local Development Setup

1. Set up base PHP version for local development:
   ```bash
   make setup-dev PHP_VERSION=8.1
   ```

### Local Development Commands

#### Setup (you used it above)
```bash
make setup-dev
```

Set up the local development environment.

- **Required Parameter**:
    - `PHP_VERSION`: Specifies the PHP version to use.
        - Example: `PHP_VERSION=8.1 make setup-dev`

---
#### Test local developments
```bash
make test-dev
```
Run tests using the local development environment.
Its optimized for fast tests (it uses volume mapping)

- **No additional parameters.**
    - Example: `make test-dev`

---

## Commands Overview - Full Testing

### `make test-all`
Run tests across all defined PHP versions.

- **Optional Parameters**:
    - `PARALLEL=true`: Run tests in parallel.
        - Example: `PARALLEL=true make test-all`
    - `SKIP_LOGS=true`: Suppress log file generation.
        - Example: `SKIP_LOGS=true make test-all`

---

### `make test-version`
Run tests for a specific PHP version.

- **Optional Parameters**:
    - `SKIP_LOGS=true`: Suppress log file generation.

      ```bash
      SKIP_LOGS=true make test-version
      ```
---

## Logs

- Logs are stored in the `php-library-test-docker-output` directory - Makefile will create it if it doesn't exist.

---

## Full Workflow

1. Set up the development environment for PHP 8.1:
   ```bash
   > make setup-dev PHP_VERSION=8.1
   ```

2. Run tests using the local development environment:
   ```bash
   > make test-dev
   ```

3. Run tests across all PHP versions using parallel - multiple PHP at once:
   ```bash
   > PARALLEL=true make test-all
   ```

4. Something small to fix, so you fix it and want to test it without rebuilding local env:
   ```bash
    > make test-version
    Enter PHP version (e.g., 8.1): 8.2
   ```


4. 
7. Run tests in parallel while suppressing logs:
   ```bash
   PARALLEL=true SKIP_LOGS=true make test-all
   ```

4. Run tests for PHP 8.2:
   ```bash
   make test-version
   ```

---

## Contributing

Feel free to open issues or submit pull requests to improve this repository.
Currently, this project has been tested only on macOS. If you encounter any issues on other systems, please let me know.
I plan to test it on Linux after the holidays.

---

## License

This project is licensed under the [Attribution Assurance License](https://opensource.org/licenses/AAL), ensuring that the original author is credited in all derived works, including forks. 
Additionally, any fork must include a "Buy Me a Beer" for the original author.

---

## Authors

- **Author**: Adrian Chojnicki
- **Support Development**: [Buy Me a Beer](https://beer.chojnicki.pl)
