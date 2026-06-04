SHELL := /bin/bash

COMPOSE ?= docker compose --env-file .env -f compose.yml
WORKSPACE_CONFIG ?= .workspace.ini
CONFIG_PROFILES := $(strip $(shell sed -nE 's/^[[:space:]]*default_profiles[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' "$(WORKSPACE_CONFIG)" 2>/dev/null | tail -n 1 | tr ',' ' '))
PROFILES ?= $(CONFIG_PROFILES)
EMPTY :=
space := $(EMPTY) $(EMPTY)
COMMA := ,
PROFILE_LIST_CSV := $(subst $(space),$(COMMA),$(strip $(PROFILES)))
PROFILE_FLAGS = $(foreach profile,$(PROFILES),--profile $(profile))
PHP_EXEC_USER := $(strip $(shell sed -nE 's/^[[:space:]]*USER_NAME[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' .env 2>/dev/null | tail -n 1))
PHP_EXEC_USER := $(if $(PHP_EXEC_USER),$(PHP_EXEC_USER),dev)
PHP_CLI_RUN = $(COMPOSE) run --rm php-cli

ARGS = $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: \
	prepare \
	require-config \
	require-app-ready \
	init \
	app-key \
	profiles \
	config \
	up \
	down \
	down-clear \
	build \
	build-no-cache \
	ps \
	logs \
	php-shell \
	php-run \
	composer-install \
	composer-update \
	composer-require \
	composer-require-dev \
	test \
	test-coverage \
	test-coverage-html \
	cs-check \
	cs-fix \
	yarn-install \
	yarn-build \
	vite-dev

require-config:
	@test -f "$(WORKSPACE_CONFIG)" || (echo "Missing $(WORKSPACE_CONFIG). Run: cp .workspace.ini.example .workspace.ini" >&2; exit 1)
	@test -n "$(PROFILES)" || (echo "Missing default_profiles in $(WORKSPACE_CONFIG)" >&2; exit 1)

prepare: require-config
	@test -f .env || cp .env.example .env
	@mkdir -p local
	@backend_path="$$(sed -nE 's/^[[:space:]]*BACKEND_PATH[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' .env | tail -n 1)"; backend_path="$${backend_path:-./local/backend}"; test -d "$$backend_path" || (echo "Missing backend project at $$backend_path. Run: phpsoftbox new backend" >&2; exit 1)

require-app-ready: prepare
	@backend_path="$$(sed -nE 's/^[[:space:]]*BACKEND_PATH[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' .env | tail -n 1)"; backend_path="$${backend_path:-./local/backend}"; test -f "$$backend_path/vendor/autoload.php" || (echo "Missing $$backend_path/vendor/autoload.php. Run: make init" >&2; exit 1)
	@app_key="$$(sed -nE 's/^[[:space:]]*APP_KEY[[:space:]]*=(.*)[[:space:]]*$$/\1/p' .env | tail -n 1)"; test -n "$$app_key" || (echo "Missing APP_KEY in .env. Run: make init" >&2; exit 1)

profiles: require-config
	@printf 'Config: %s\n' "$(if $(WORKSPACE_CONFIG),$(WORKSPACE_CONFIG),none)"
	@printf 'Profiles: %s\n' "$(PROFILES)"

init: app-key composer-install yarn-install

app-key: prepare
	@key="$$(sed -nE 's/^[[:space:]]*APP_KEY[[:space:]]*=(.*)[[:space:]]*$$/\1/p' .env | tail -n 1)"; \
	if [ -n "$$key" ]; then \
		echo "APP_KEY already configured"; \
	else \
		key="$$( $(PHP_CLI_RUN) php -r 'echo "base64:" . base64_encode(random_bytes(32));' )"; \
		tmp="$$(mktemp)"; \
		awk -v key="$$key" 'BEGIN { done = 0 } /^[[:space:]]*APP_KEY[[:space:]]*=/ { print "APP_KEY=" key; done = 1; next } { print } END { if (done == 0) print "APP_KEY=" key }' .env > "$$tmp"; \
		mv "$$tmp" .env; \
		echo "APP_KEY generated"; \
	fi

config: prepare
	$(COMPOSE) $(PROFILE_FLAGS) config

up: require-app-ready
	$(COMPOSE) $(PROFILE_FLAGS) up -d

down: prepare
	env COMPOSE_PROFILES=$(PROFILE_LIST_CSV) $(COMPOSE) $(PROFILE_FLAGS) down --remove-orphans

down-clear: prepare
	env COMPOSE_PROFILES=$(PROFILE_LIST_CSV) $(COMPOSE) $(PROFILE_FLAGS) down -v --remove-orphans

build: prepare
	$(COMPOSE) $(PROFILE_FLAGS) build --pull

build-no-cache: prepare
	$(COMPOSE) $(PROFILE_FLAGS) build --pull --no-cache

ps: prepare
	$(COMPOSE) ps

logs: prepare
	$(COMPOSE) logs -f --tail=200

php-shell: prepare
	$(PHP_CLI_RUN) bash

php-run: prepare
	@test -n "$(ARGS)" || (echo "Usage: make -- php-run php -v" && exit 1)
	$(PHP_CLI_RUN) $(ARGS)

composer-install: prepare
	$(PHP_CLI_RUN) composer install

composer-update: prepare
	$(PHP_CLI_RUN) composer update

composer-require: prepare
	@test -n "$(ARGS)" || (echo "Usage: make composer-require vendor/package" && exit 1)
	$(PHP_CLI_RUN) composer require $(ARGS)

composer-require-dev: prepare
	@test -n "$(ARGS)" || (echo "Usage: make composer-require-dev vendor/package" && exit 1)
	$(PHP_CLI_RUN) composer require --dev $(ARGS)

test: prepare
	$(PHP_CLI_RUN) composer test

test-coverage: prepare
	$(COMPOSE) run --rm -e XDEBUG_MODE=coverage php-cli composer test -- --no-coverage --coverage-text

test-coverage-html: prepare
	$(COMPOSE) run --rm -e XDEBUG_MODE=coverage php-cli composer test

cs-check: prepare
	$(PHP_CLI_RUN) composer cs:check

cs-fix: prepare
	$(PHP_CLI_RUN) composer cs:fix

yarn-install: prepare
	$(PHP_CLI_RUN) yarn install

yarn-build: prepare
	$(PHP_CLI_RUN) yarn build

vite-dev: prepare
	$(COMPOSE) exec --user $(PHP_EXEC_USER) php-fpm sh -lc "yarn install && yarn dev --host 0.0.0.0"

ifneq (,$(filter php-run composer-require composer-require-dev,$(MAKECMDGOALS)))
%:
	@:
endif
