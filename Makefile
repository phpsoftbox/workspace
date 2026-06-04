SHELL := /bin/bash

COMPOSE ?= docker compose --env-file .env -f compose.yml
WORKSPACE_CONFIG ?= .workspace.ini
CONFIG_PROFILES := $(strip $(shell sed -nE 's/^[[:space:]]*default_profiles[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' "$(WORKSPACE_CONFIG)" 2>/dev/null | tail -n 1 | tr ',' ' '))
PROFILES ?= $(CONFIG_PROFILES)
PROFILE_FLAGS = $(foreach profile,$(PROFILES),--profile $(profile))
PHP_EXEC_USER := $(strip $(shell sed -nE 's/^[[:space:]]*USER_NAME[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' .env 2>/dev/null | tail -n 1))
PHP_EXEC_USER := $(if $(PHP_EXEC_USER),$(PHP_EXEC_USER),dev)
PHP_CLI_RUN = $(COMPOSE) run --rm php-cli

ARGS = $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: \
	prepare \
	require-config \
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
	@if [[ " $(PROFILES) " == *" frontend "* ]]; then frontend_path="$$(sed -nE 's/^[[:space:]]*FRONTEND_PATH[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$$/\1/p' .env | tail -n 1)"; frontend_path="$${frontend_path:-./local/frontend}"; test -d "$$frontend_path" || (echo "Missing frontend project at $$frontend_path" >&2; exit 1); fi

profiles: require-config
	@printf 'Config: %s\n' "$(if $(WORKSPACE_CONFIG),$(WORKSPACE_CONFIG),none)"
	@printf 'Profiles: %s\n' "$(PROFILES)"

config: prepare
	$(COMPOSE) $(PROFILE_FLAGS) config

up: prepare
	$(COMPOSE) $(PROFILE_FLAGS) up -d

down: prepare
	$(COMPOSE) down --remove-orphans

down-clear: prepare
	$(COMPOSE) down -v --remove-orphans

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
