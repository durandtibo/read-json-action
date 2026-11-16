#!/usr/bin/env bash
# Assertion helpers for the action test workflows (ci-action.yaml).
# Source this file. It holds no knowledge about fixtures: expectations come
# from test-data/cases.json through environment variables, never from here.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_error() {
	echo -e "${RED}❌ ERROR: $1${NC}" >&2
	echo "::error::$1"
}

print_success() {
	echo -e "${GREEN}✅ $1${NC}"
}

# Args: description, expected outcome ("success" or "failure"), actual outcome
verify_step_outcome() {
	if [ "$3" != "$2" ]; then
		print_error "$1: expected outcome '$2', got '$3'"
		return 1
	fi
	print_success "$1: outcome is '$3' as expected"
}

# Args: field name, expected value, actual value
verify_json_value() {
	if [ "$3" != "$2" ]; then
		print_error "Expected $1='$2', got '$3'"
		return 1
	fi
	print_success "$1 is '$3' as expected"
}

# Args: output name, value. The value must be empty or unset.
verify_output_empty() {
	if [ -n "$2" ]; then
		print_error "Output '$1' should be empty (got: '$2')"
		return 1
	fi
	print_success "Output '$1' is empty as expected"
}

# Args: path. Fails if the path exists (e.g. a file a payload tried to create).
verify_path_absent() {
	if [ -e "$1" ] || [ -L "$1" ]; then
		print_error "'$1' should not exist (possible command injection)"
		return 1
	fi
	print_success "'$1' does not exist"
}

# Compares the content of an environment variable with a file, ignoring
# trailing whitespace. Works for files that are not valid JSON.
# Args: path of the file, name of the environment variable holding the content
verify_raw_content_matches_file() {
	if CONTENT_VAR="$2" python3 -I -c '
import os, sys
actual = os.environ[os.environ["CONTENT_VAR"]]
with open(sys.argv[1], encoding="utf-8", newline="") as f:
    expected = f.read()
sys.exit(0 if actual.rstrip() == expected.rstrip() else 1)
' "$1"; then
		print_success "json-content matches $1"
		return 0
	fi
	print_error "json-content does not match $1"
	return 1
}

# Compares the JSON value held by an environment variable with a JSON file
# (parsed, so formatting is ignored).
# Args: path of the file, name of the environment variable holding the JSON
verify_json_matches_file() {
	if CONTENT_VAR="$2" python3 -I -c '
import json, os, sys
actual = json.loads(os.environ[os.environ["CONTENT_VAR"]])
with open(sys.argv[1], encoding="utf-8") as f:
    expected = json.load(f)
sys.exit(0 if actual == expected and type(actual) is type(expected) else 1)
' "$1"; then
		print_success "Parsed value matches $1"
		return 0
	fi
	print_error "Parsed value does not match $1"
	return 1
}

# Checks one case of test-data/cases.json. Reads from the environment:
#   CASE_ID, FILE_PATH                        the case
#   EXPECT_OUTCOME, EXPECT_EXISTS,
#   EXPECT_VALID, EXPECT_CONTENT              what the case expects
#   OUTCOME, FILE_EXISTS, IS_VALID, CONTENT   what the action returned
# EXPECT_CONTENT is "file" (the file text), "empty" or "any" (not checked).
verify_case() {
	local failed=0
	echo "🧪 Case: $CASE_ID ($FILE_PATH)"
	verify_step_outcome "$CASE_ID" "$EXPECT_OUTCOME" "$OUTCOME" || failed=1
	verify_json_value "file-exists" "$EXPECT_EXISTS" "$FILE_EXISTS" || failed=1
	verify_json_value "is-valid-json" "$EXPECT_VALID" "$IS_VALID" || failed=1
	case "$EXPECT_CONTENT" in
	file) verify_raw_content_matches_file "$FILE_PATH" CONTENT || failed=1 ;;
	empty) verify_output_empty "json-content" "$CONTENT" || failed=1 ;;
	any) ;;
	*)
		print_error "Unknown expect-content '$EXPECT_CONTENT'"
		failed=1
		;;
	esac
	# No case may create a file through a payload hidden in the path.
	verify_path_absent "injected-by-path" || failed=1
	verify_path_absent "test-data/injected-by-path" || failed=1
	return "$failed"
}
