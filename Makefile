SHELL = /bin/bash

include .make/all.mk

.PHONY: test
test: ## Run the unit tests of scripts/validate-json.py
	python3 -m unittest discover --start-directory tests --verbose

.PHONY: check-export
check-export: ## Check that the exported files are the files the action needs
	./dev/check_export.sh

.PHONY: all
all: format lint test ## Format, lint and test

.PHONY: clean
clean: ## Remove the temporary files (see .gitignore)
	rm -f ./*.tmp ./*.bak ./*.log
