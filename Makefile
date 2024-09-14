#-----------------------------------------
# Variables
#-----------------------------------------
MKFILE_PATH := $(abspath $(lastword ${MAKEFILE_LIST}))
PROJECT_PATH := $(dir ${MKFILE_PATH})
PROJECT_NAME := feuxfollets
export PROJECT_NAME
PROJECT_URL=$(PROJECT_NAME).docker.localhost
export PROJECT_URL
UID=$(shell id -u)
export UID
GID=$(shell id -g)
export GID

# command name that are also directories
.PHONY:

#-----------------------------------------
# Allow passing arguments to make
#-----------------------------------------
SUPPORTED_COMMANDS := test.unit
SUPPORTS_MAKE_ARGS := $(findstring $(firstword $(MAKECMDGOALS)), $(SUPPORTED_COMMANDS))
ifneq "$(SUPPORTS_MAKE_ARGS)" ""
  COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(COMMAND_ARGS):;@:)
endif

#-----------------------------------------
# Help commands
#-----------------------------------------
.DEFAULT_GOAL := help

help: ## Prints this help
	@grep -E '^[a-zA-Z_\-\0.0-9]+:.*?## .*$$' ${MAKEFILE_LIST} | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#-----------------------------------------
# Commands
#-----------------------------------------
clean: ## Cleans up environnement
	@mkdir -p ./dist/docs && rm -rf ./dist/docs/*
	@mkdir -p ${HOME}/.cache/yarn
	@mkdir -p ${HOME}/.coverage
	@docker-compose down --remove-orphans

install: ## yarn install all project
	@docker-compose run --rm --label "traefik.enable=false" app yarn
	@cd ./tests/e2e && docker-compose run --rm --entrypoint=/usr/local/bin/yarn cypress

docker.pull: ## Retrieves latest images
	@docker-compose pull

docker.build:
	@docker-compose build --pull

dev.up:
	@docker-compose up -d --force-recreate
	@echo "App running at https://${PROJECT_URL}"

dev: clean docker.pull docker.build dev.up ## Starts dev stack

sh: ## Runs command inside container
	@docker-compose run --rm --label "traefik.enable=false" app bash

#-----------------------------------------
# Tests
#-----------------------------------------
SKIP_OPEN :=
test.unit: ## Runs unit tests
	@docker-compose run --rm app bash -c "yarn run test:unit -t=${COMMAND_ARGS}"; \
	 echo "Test report file://${PROJECT_PATH}coverage/tests.html"; \
     test "${SKIP_OPEN}" || xdg-open "file://${PROJECT_PATH}coverage/tests.html"

test.coverage: ## Runs unit tests with code coverage
	@docker-compose run --rm app bash -c 'yarn run test:coverage'; \
	 echo "Test report file://${PROJECT_PATH}coverage/tests.html"; \
	 echo "Coverage report file://${PROJECT_PATH}coverage/lcov-report/index.html"; \
     test "${SKIP_OPEN}" || xdg-open "file://${PROJECT_PATH}coverage/tests.html"; \
	 test "${SKIP_OPEN}" || xdg-open "file://${PROJECT_PATH}coverage/lcov-report/index.html"

#-----------------------------------------
# Builds
#-----------------------------------------
build.app: ## Build production app
	@docker-compose run --rm app bash -c 'yarn install --frozen-lockfile && yarn build'

#-----------------------------------------
# Tools
#-----------------------------------------
lint: ## Lint app (style and typing)
	@docker-compose run --rm -l 'traefik.enable=false' app yarn lint
