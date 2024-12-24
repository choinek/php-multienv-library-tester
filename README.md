# PHP Library Test Environment with Docker

Beta. Final version will be released after:
- linux tests

**ETA for 1.0:** 2024-12-30

## Overview

This repository makes it easy to test PHP libraries across multiple PHP versions using Docker. It provides two modes:

1. **Full Testing Mode**: Builds a fresh environment for each PHP version, ensuring clean tests.
2. **Development Mode**: Uses volume mapping for faster testing during development, but requires rebuilding when switching PHP versions.

Both modes operate independently, meaning you can run tests for all PHP versions without switching the local environment.

## Features

- Test across multiple PHP versions.
- Local development version for ad hoc testing.
- Dynamically builds environments for each PHP version.
- Options to override base test commands and optimize caching mechanisms.

---

## Requirements

- **Docker**: Ensure Docker is installed and running on your system.

---

## Getting Started

### Step 1: Download

#### Download Automatically

Run the following command to set up the testing environment interactively:

```bash
export TARGET_DIR=php-multienv-library-tester \
    && curl -sSL https://raw.githubusercontent.com/choinek/php-multienv-library-tester/main/init.sh | bash \
    && cd "$TARGET_DIR" \
    && bash setup.sh
```

#### b) Download Manually

If you prefer, you can download the repository as a ZIP file:

1. Go to the [GitHub repository](https://github.com/choinek/php-multienv-library-tester).
2. Click "Code" > "Download ZIP".
3. Extract the ZIP file into your desired directory and follow the manual setup instructions in the repository.

The entire setup process is automated via the `setup.sh` script. Follow these steps:

### Step 2: Run Setup

1. Execute the setup script:
   ```bash
   bash setup.sh
   ```

2. The script will:
    - Configure the environment.
    - Set up required files and directories.
    - Prompt you for necessary inputs such as PHP versions and repository details.
    - Allow you to set up specific PHP versions or modify them at any time in the future.

3. During setup, you can choose any PHP version you want to include in your testing environment.

4. Once completed, the environment is ready for testing.

---

## Modes

### Full Testing Mode

Builds a fresh environment for each PHP version, including `composer install` and other setup tasks. This ensures clean testing.

### Development Mode

Uses volume mapping to test locally. Faster but it's not as clean and requires rebuilding when switching PHP versions.

Both modes operate independently, so you can run tests for all PHP versions without switching the local environment.

---

## Commands Overview

### Full Testing

Run tests across all defined PHP versions:
```bash
make test-all
```

Optional parameters (provide as environment variables):
- `PARALLEL=false`: Disable parallel execution.
- `SKIP_LOGS=true`: Suppress log file generation.

Example:
```bash
PARALLEL=false make test-all
```

### Specific Version Testing

Run tests for a specific PHP version:
```bash
make test-version
```

Example:
```bash
make test-version
```

You will be prompted to enter the desired PHP version (e.g., 8.1).

### Development Mode

Run tests in a local development environment:
```bash
make test-dev
```

### Coverage Report

Generate a test coverage report:
```bash
make coverage
```

---

## Logs

Logs are stored in the `php-library-test-docker-output` directory. The directory is automatically created by the Makefile if it does not exist.

---

## Workflow Examples

1. **Set up environment**:
   ```bash
   bash setup.sh
   ```

2. **Run tests in development mode**:
   ```bash
   make test-dev
   ```

3. **Run tests across all PHP versions in parallel**:
   ```bash
   make test-all
   ```

4. **Disable parallel testing**:
   ```bash
   PARALLEL=false make test-all
   ```

5. **Run tests for PHP 8.2**:
   ```bash
   make test-version
   ```

6. **Suppress logs while testing in parallel**:
   ```bash
   SKIP_LOGS=true make test-all
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
