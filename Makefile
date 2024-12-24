.PHONY: all prepare-logs prepare-framework get-versions validate setup test-all test test-version test-dev coverage end help

CONFIG_FILE=.php-library-test-docker.config

ifeq ($(wildcard $(CONFIG_FILE)),)
  ifneq ($(MAKECMDGOALS),setup help)
    $(error Configuration file $(CONFIG_FILE) not found. Run 'make setup' or 'bash setup.sh' first.)
  endif
endif

.PHONY: help
help:
	@echo "Usage:"
	@echo "   make test-all"
	@echo "      Description: Run tests in all PHP versions"
	@echo "      Optional parameters:"
	@echo "         - PARALLEL=false - Disable parallel execution (default: true)"
	@echo "               Usage: PARALLEL=false make test-all"
	@echo "         - SKIP_LOGS=true - Suppress log file generation (outputs to /dev/null)"
	@echo "               Usage: SKIP_LOGS=true make test-all"
	@echo ""
	@echo "   make test-version"
	@echo "      Description: Run tests in a specific PHP version (prompts for version)"
	@echo "      Optional parameters:"
	@echo "         - SKIP_LOGS=true - Suppress log file generation"
	@echo "               Usage: SKIP_LOGS=true make test-version"
	@echo ""
	@echo "   make test-dev"
	@echo "      Description: Run tests using the local development environment"
	@echo "      No optional parameters"
	@echo ""
	@echo "   make coverage"
	@echo "      Description: Generate a test coverage report based on the local development environment"
	@echo "      No optional parameters"
	@echo ""
	@echo "   make setup"
	@echo "      Description: Set up the project configuration"
	@echo "      No optional parameters"
	@echo ""
	@echo "   make validate"
	@echo "      Description: Validate the environment configuration"
	@echo "      No optional parameters"
	@echo ""
	@echo "   make cleanup"
	@echo "      Description: Remove dangling Docker images from the project"
	@echo "      No optional parameters"

.PHONY: setup
setup:
	bash ./setup.sh

LIBRARY_DIR=$(shell awk -F= '/^library_dir=/{print $$2}' $(CONFIG_FILE))

PHP_VERSION ?= not-set
LOG_DIR=php-library-test-docker-output
PARALLEL ?= true
SKIP_LOGS ?= false
BUILD_OUTPUT=$(if $(filter true,$(SKIP_LOGS)),/dev/null,$(LOG_DIR)/test-$$CURRENTVERSION-build-output.log)
RUN_OUTPUT=$(if $(filter true,$(SKIP_LOGS)),/dev/null,$(LOG_DIR)/test-$$CURRENTVERSION-run-output.log)
SUCCEED_MESSAGE="✔ PHP $$CURRENTVERSION - test succeed. $(if $(filter true,$(SKIP_LOGS)),"","Check $(LOG_DIR)/test-$$CURRENTVERSION-run-output.log for details.")"
PARALLEL_FINAL_MESSAGE="All parallel tests completed. $(if $(filter true,$(SKIP_LOGS)),"","Check $(LOG_DIR) for logs.")"
FAILED_MESSAGE="✘ PHP $$CURRENTVERSION - tests failed. $(if $(filter true,$(SKIP_LOGS)),"","Check $(LOG_DIR)/test-$$CURRENTVERSION.log and $(LOG_DIR)/test-$$CURRENTVERSION-build.log for details.")"

.PHONY: prepare-logs
prepare-logs:
	echo "Preparing logs..."
	@mkdir -p $(LOG_OUTPUT_DIR)

.PHONY: prepare-framework
prepare-framework:
	@mkdir -p $(LOG_DIR)
	@if [ -f .dockerignore ]; then \
		if ! grep -q 'composer.lock' .dockerignore; then \
			echo "Error: .dockerignore does not include 'composer.lock'. Please add it."; \
			exit 1; \
		fi; \
	else \
		echo ".dockerignore does not exist. Copying $LIBRARY_DIR/.gitignore to ./.dockerignore..."; \
		cp $LIBRARY_DIR/.gitignore .dockerignore; \
	fi

.PHONY: get-versions
get-versions:
	@grep 'service-library-test-' docker-compose.test.yml | sed -E 's/.*service-library-test-([0-9.]+):.*/\1/' | sort -u > "$(LOG_DIR)/.php_versions"


.PHONY: validate
validate:
	@bash ./validate.sh

test-all: prepare-framework get-versions
ifeq ($(PARALLEL), true)
	@cat "$(LOG_DIR)/.php_versions" | while read CURRENTVERSION; do \
		( \
			echo "Running tests for PHP $$CURRENTVERSION..."; \
			DOCKER_BUILDKIT=1 docker compose -f docker-compose.test.yml build service-library-test-$$CURRENTVERSION > $(BUILD_OUTPUT) 2>&1 && \
			docker compose -f docker-compose.test.yml run --rm service-library-test-$$CURRENTVERSION > $(RUN_OUTPUT) 2>&1 && \
			echo $(SUCCEED_MESSAGE) || \
			echo $(FAILED_MESSAGE) \
		) & echo $$! > $(LOG_DIR)/test-$$CURRENTVERSION.pid; \
	done; \
	while true; do \
		sleep 2; \
		remaining=0; \
		for pid_file in $(LOG_DIR)/*.pid; do \
			if [ -f $$pid_file ]; then \
				pid=$$(cat $$pid_file); \
				process_info=$$(ps -p $$pid -o command= 2>/dev/null); \
				if [ -z "$$process_info" ]; then \
					rm -f $$pid_file; \
				else \
					remaining=$$((remaining + 1)); \
				fi; \
			fi; \
		done; \
		if [ $$remaining -eq 0 ]; then \
			break; \
		fi; \
	done; \
	docker compose -f docker-compose.test.yml down --remove-orphans > /dev/null 2>&1 || true
	@echo $(PARALLEL_FINAL_MESSAGE)
else
	@cat "$(LOG_DIR)/.php_versions" | while read CURRENTVERSION; do \
		echo "Running tests for PHP $$CURRENTVERSION..."; \
		DOCKER_BUILDKIT=1 docker compose -f docker-compose.test.yml build service-library-test-$$CURRENTVERSION && \
		(docker compose -f docker-compose.test.yml run --rm service-library-test-$$CURRENTVERSION && \
		echo "$$(printf '%s' $(SUCCEED_MESSAGE))" || \
		echo "$(FAILED_MESSAGE)"); \
	done; \
	docker compose -f docker-compose.test.yml down --remove-orphans > /dev/null 2>&1 || true
endif

PHP_VERSIONS=$(shell tr '\n' ',' < $(LOG_DIR)/.php_versions | sed -e 's/,$$//')
test: test-all
test-version: prepare-framework get-versions
	@echo "Available PHP versions: $(PHP_VERSIONS)" && \
	read -p "Enter PHP version: " CURRENTVERSION < /dev/tty && \
	if grep -q "^$$CURRENTVERSION$$" "$(LOG_DIR)/.php_versions"; then \
		echo "Starting tests for PHP $$CURRENTVERSION..."; \
		DOCKER_BUILDKIT=1 docker compose -f docker-compose.test.yml build service-library-test-$$CURRENTVERSION > $(BUILD_OUTPUT) 2>&1 && \
		docker compose -f docker-compose.test.yml run --rm service-library-test-$$CURRENTVERSION > $(RUN_OUTPUT) 2>&1 && \
		{ echo "$(SUCCEED_MESSAGE)"; } || { echo "$(FAILED_MESSAGE)"; }; \
	else \
		echo "Error: PHP version $$CURRENTVERSION is not valid or not defined in services."; \
		exit 1; \
	fi && \
	docker compose -f docker-compose.test.yml down --remove-orphans > /dev/null 2>&1 || true

.PHONY: coverage
coverage: prepare-framework
	@mkdir -p $(LOG_DIR)/coverage
	docker compose run --rm library-development sh -c "composer install && composer php-library-test-docker-cmd -- --coverage-html=/coverage"
	@echo "Coverage report generated at $(LOG_DIR)/coverage"

test-dev: prepare-framework
	@echo "Running tests in development environment..."
	docker compose run --rm library-development > $(LOG_DIR)/development-tests.log 2>&1
	@echo "Finished running tests. Check $(LOG_DIR)/development-tests.log for details."

.PHONY: cleanup
cleanup:
	@if [ -n "$$(docker images --filter "label=com.docker.compose.project=$(basename $(pwd))" -q --filter "dangling=true")" ]; then \
		docker rmi $$(docker images --filter "label=com.docker.compose.project=$(basename $(pwd))" -q --filter "dangling=true") >/dev/null 2>&1; \
		echo "(Cleanup) Dangling images removed."; \
	fi
