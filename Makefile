SHELL=/bin/bash

# Makefile for read-json-action
#
# Available targets:
#   help    - Display this help message
#   format  - Run all formatting and linting checks

.PHONY : help
help :
	@echo "read-json-action - Available Make Targets"
	@echo ""
	@echo "  make help    - Display this help message"
	@echo "  make format  - Run formatting and linting checks"
	@echo ""
	@echo "Formatting tools used:"
	@echo "  - markdownlint: Validates Markdown files"
	@echo "  - prettier: Formats various file types"
	@echo "  - yamllint: Validates YAML files"
	@echo ""

.PHONY : format
format :
	@echo "🔍 Running markdownlint on Markdown files..."
	markdownlint **/*.md
	@echo "✅ Markdownlint passed"
	@echo ""
	@echo "✨ Running prettier to format files..."
	prettier --write .
	@echo "✅ Prettier formatting complete"
	@echo ""
	@echo "🔍 Running yamllint on YAML files..."
	yamllint -f colored .
	@echo "✅ Yamllint passed"
	@echo ""
	@echo "🎉 All format checks passed!"

.DEFAULT_GOAL := help
