PHP_VERSION ?= not-set
LOG_DIR=php-library-test-docker-output
PARALLEL ?= true
SKIP_LOGS ?= false
BUILD_OUTPUT=$(if $(filter true,$(SKIP_LOGS)),/dev/null,$(LOG_DIR)/test-$$CURRENTVERSION-build.log)
RUN_OUTPUT=$(if $(filter true,$(SKIP_LOGS)),/dev/null,$(LOG_DIR)/test-$$CURRENTVERSION.log)
SUCCEED_MESSAGE="✔ PHP $$CURRENTVERSION - test succeed. $(if $(filter true,$(SKIP_LOGS)),"","Check $(LOG_DIR)/test-$$CURRENTVERSION.log for details.")"
PARALLEL_FINAL_MESSAGE="All parallel tests completed. $(if $(filter true,$(SKIP_LOGS)),"","Check $(LOG_DIR) for logs.")"
FAILED_MESSAGE="✘ PHP $$CURRENTVERSION - tests failed. $(if $(filter true,$(SKIP_LOGS)),"","Check $(LOG_DIR)/test-$$CURRENTVERSION.log and $(LOG_DIR)/test-$$CURRENTVERSION-build.log for details.")"

.PHONY: prepare-logs
prepare-logs:
	echo "Preparing logs..."
	@mkdir -p $(LOG_OUTPUT_DIR)

.PHONY: all
all: prepare-logs

help:
	@echo "Usage:"
	@echo "   make test-all"
	@echo "   make test-version"
	@echo "   make setup-dev"
	@echo "   make test-dev"
	@echo "   make validate"

prepare-framework:
	@mkdir -p $(LOG_DIR)
	@if [ -f .dockerignore ]; then \
		echo ".dockerignore exists. Verifying contents..."; \
		if ! grep -q 'composer.lock' .dockerignore; then \
			echo "Error: .dockerignore does not include 'composer.lock'. Please add it."; \
			exit 1; \
		fi; \
	else \
		echo ".dockerignore does not exist. Copying {{PLACEHOLDER_DIR/.gitignore to ./.dockerignore..."; \
		cp {{PLACEHOLDER_DIR}}/.gitignore .dockerignore; \
	fi

get-versions:
	@grep 'service-library-test-' docker-compose.test.yml | sed -E 's/.*service-library-test-([0-9.]+):.*/\1/' | sort -u > "$(LOG_DIR)/.php_versions"


validate:
	@bash ./php-library-test-docker-validate.sh

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
	docker compose -f docker-compose.test.yml down --remove-orphans
	@echo $(PARALLEL_FINAL_MESSAGE)
else
	@cat "$(LOG_DIR)/.php_versions" | while read CURRENTVERSION; do \
		echo "Running tests for PHP $$CURRENTVERSION..."; \
		DOCKER_BUILDKIT=1 docker compose -f docker-compose.test.yml build service-library-test-$$CURRENTVERSION && \
		(docker compose -f docker-compose.test.yml run --rm service-library-test-$$CURRENTVERSION && \
		echo "$$(printf '%s' $(SUCCEED_MESSAGE))" || \
		echo "$(FAILED_MESSAGE)"); \
	done; \
	docker compose -f docker-compose.test.yml down --remove-orphans
endif

test-version: prepare-framework
	@read -p "Enter PHP version (e.g., 8.1): " CURRENTVERSION && \
	echo "Starting tests for PHP $$PHP_VERSION..." && \
	DOCKER_BUILDKIT=1 docker compose -f docker-compose.test.yml build service-library-test-$$CURRENTVERSION > $(BUILD_OUTPUT) 2>&1 && \
	docker compose -f docker-compose.test.yml run --rm service-library-test-$$CURRENTVERSION > $(RUN_OUTPUT) 2>&1 && \
	{ echo "$(SUCCEED_MESSAGE)"; } || { echo "$(FAILED_MESSAGE)"; } && \
	docker compose -f docker-compose.test.yml down --remove-orphans

setup-dev: prepare-framework
	@if [ "$(PHP_VERSION)" = "not-set" ]; then \
		echo "Please set PHP_VERSION in the envrionment, e.g., PHP_VERSION=8.1 make setup-dev"; \
		exit 1; \
	fi
	docker compose build library-development > $(LOG_DIR)/dev-build.log 2>&1



test-dev: prepare-framework
	docker compose run --rm library-development > $(LOG_DIR)/dev-tests.log 2>&1
