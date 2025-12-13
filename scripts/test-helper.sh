#!/usr/bin/env bash
# ==============================================================================
# Test Helper Script for read-json-action
# ==============================================================================
# This script provides reusable functions to validate JSON action outputs
# and verify parsed values match expected content.

set -euo pipefail

# ==============================================================================
# Color codes for output
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Function: print_error
# Prints an error message with formatting
# ==============================================================================
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    echo "::error::$1"
}

# ==============================================================================
# Function: print_success
# Prints a success message with formatting
# ==============================================================================
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# ==============================================================================
# Function: print_info
# Prints an info message with formatting
# ==============================================================================
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ==============================================================================
# Function: verify_output_exists
# Verifies that a step output variable exists and is not empty
# Args:
#   $1 - Output name
#   $2 - Output value
# ==============================================================================
verify_output_exists() {
    local output_name="$1"
    local output_value="$2"

    if [ -z "$output_value" ]; then
        print_error "Output '$output_name' is empty or undefined"
        return 1
    fi

    return 0
}

# ==============================================================================
# Function: verify_file_exists
# Verifies that the file-exists output is 'true'
# Args:
#   $1 - file-exists output value
# ==============================================================================
verify_file_exists() {
    local file_exists="$1"

    print_info "Checking file existence..."

    if [ "$file_exists" != "true" ]; then
        print_error "File should exist (got: $file_exists)"
        return 1
    fi

    print_success "File exists"
    return 0
}

# ==============================================================================
# Function: verify_valid_json
# Verifies that the is-valid-json output is 'true'
# Args:
#   $1 - is-valid-json output value
# ==============================================================================
verify_valid_json() {
    local is_valid="$1"

    print_info "Checking JSON validity..."

    if [ "$is_valid" != "true" ]; then
        print_error "JSON should be valid (got: $is_valid)"
        return 1
    fi

    print_success "JSON is valid"
    return 0
}

# ==============================================================================
# Function: verify_invalid_json
# Verifies that the is-valid-json output is 'false' (for negative tests)
# Args:
#   $1 - is-valid-json output value
# ==============================================================================
verify_invalid_json() {
    local is_valid="$1"

    print_info "Checking JSON invalidity..."

    if [ "$is_valid" = "true" ]; then
        print_error "JSON should be invalid but was marked as valid"
        return 1
    fi

    print_success "JSON is correctly marked as invalid"
    return 0
}

# ==============================================================================
# Function: verify_json_value
# Verifies that a JSON value matches the expected value
# Args:
#   $1 - Field name (for error messages)
#   $2 - Expected value
#   $3 - Actual value
# ==============================================================================
verify_json_value() {
    local field_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" != "$expected" ]; then
        print_error "Expected $field_name='$expected', got '$actual'"
        return 1
    fi

    return 0
}

# ==============================================================================
# Function: display_outputs
# Displays the outputs from the read-json-action
# Args:
#   $1 - file-exists value
#   $2 - is-valid-json value
#   $3 - json-content value (optional, can be long)
#   $4 - show-content flag (optional, default: false)
# ==============================================================================
display_outputs() {
    local file_exists="$1"
    local is_valid="$2"
    local json_content="${3:-}"
    local show_content="${4:-false}"

    echo ""
    echo "📋 Action Outputs:"
    echo "  📁 File exists: $file_exists"
    echo "  ✓ Valid JSON: $is_valid"

    if [ "$show_content" = "true" ] && [ -n "$json_content" ]; then
        echo "  📄 Content:"
        echo "$json_content" | head -c 200
        if [ ${#json_content} -gt 200 ]; then
            echo "... (truncated)"
        fi
    fi
    echo ""
}

# ==============================================================================
# Function: run_basic_validation
# Runs basic validation (file exists + valid JSON)
# Args:
#   $1 - file-exists value
#   $2 - is-valid-json value
# Returns: 0 if all checks pass, 1 otherwise
# ==============================================================================
run_basic_validation() {
    local file_exists="$1"
    local is_valid="$2"

    local failed=0

    verify_file_exists "$file_exists" || failed=1
    verify_valid_json "$is_valid" || failed=1

    return $failed
}

# ==============================================================================
# Function: test_single_line_json
# Validates a single-line JSON test case
# Args:
#   $1 - file-exists output
#   $2 - is-valid-json output
#   $3 - name field value
#   $4 - version field value
#   $5 - active field value
# ==============================================================================
test_single_line_json() {
    local file_exists="$1"
    local is_valid="$2"
    local name="$3"
    local version="$4"
    local active="$5"

    echo "🧪 Testing single-line JSON..."

    local failed=0

    # Basic validation
    run_basic_validation "$file_exists" "$is_valid" || failed=1

    # Field validation
    verify_json_value "name" "test" "$name" || failed=1
    verify_json_value "version" "1.0.0" "$version" || failed=1
    verify_json_value "active" "true" "$active" || failed=1

    if [ $failed -eq 0 ]; then
        print_success "Single-line JSON test passed"
        return 0
    else
        print_error "Single-line JSON test failed"
        return 1
    fi
}

# ==============================================================================
# Function: test_multi_line_json
# Validates a multi-line JSON test case
# Args:
#   $1 - file-exists output
#   $2 - is-valid-json output
#   $3 - name field value
#   $4 - debug field value
#   $5 - timeout field value
# ==============================================================================
test_multi_line_json() {
    local file_exists="$1"
    local is_valid="$2"
    local name="$3"
    local debug="$4"
    local timeout="$5"

    echo "🧪 Testing multi-line JSON..."

    local failed=0

    # Basic validation
    run_basic_validation "$file_exists" "$is_valid" || failed=1

    # Field validation
    verify_json_value "name" "test-app" "$name" || failed=1
    verify_json_value "config.debug" "false" "$debug" || failed=1
    verify_json_value "config.timeout" "3000" "$timeout" || failed=1

    if [ $failed -eq 0 ]; then
        print_success "Multi-line JSON test passed"
        return 0
    else
        print_error "Multi-line JSON test failed"
        return 1
    fi
}

# ==============================================================================
# Function: test_nested_json
# Validates a nested JSON test case
# Args:
#   $1 - file-exists output
#   $2 - is-valid-json output
#   $3 - author field value
#   $4 - dev_url field value
#   $5 - prod_port field value
# ==============================================================================
test_nested_json() {
    local file_exists="$1"
    local is_valid="$2"
    local author="$3"
    local dev_url="$4"
    local prod_port="$5"

    echo "🧪 Testing nested JSON..."

    local failed=0

    # Basic validation
    run_basic_validation "$file_exists" "$is_valid" || failed=1

    # Field validation
    verify_json_value "metadata.author" "Test User" "$author" || failed=1
    verify_json_value "environments.dev.url" "https://dev.example.com" "$dev_url" || failed=1
    verify_json_value "environments.prod.port" "443" "$prod_port" || failed=1

    if [ $failed -eq 0 ]; then
        print_success "Nested JSON test passed"
        return 0
    else
        print_error "Nested JSON test failed"
        return 1
    fi
}

# ==============================================================================
# Function: usage
# Displays usage information
# ==============================================================================
usage() {
    cat << EOF
Usage: $0 <function_name> [arguments...]

Available functions:
  verify_file_exists <file-exists>
  verify_valid_json <is-valid-json>
  verify_invalid_json <is-valid-json>
  verify_json_value <field-name> <expected> <actual>
  display_outputs <file-exists> <is-valid-json> [json-content] [show-content]
  run_basic_validation <file-exists> <is-valid-json>
  test_single_line_json <file-exists> <is-valid-json> <name> <version> <active>
  test_multi_line_json <file-exists> <is-valid-json> <name> <debug> <timeout>
  test_nested_json <file-exists> <is-valid-json> <author> <dev-url> <prod-port>

Example:
  $0 verify_file_exists "true"
  $0 verify_json_value "name" "expected" "actual"
  $0 test_single_line_json "true" "true" "test" "1.0.0" "true"
EOF
}

# ==============================================================================
# Main script execution (if called directly)
# ==============================================================================
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    # Call the function with remaining arguments
    FUNCTION_NAME="$1"
    shift

    if declare -f "$FUNCTION_NAME" > /dev/null; then
        "$FUNCTION_NAME" "$@"
    else
        print_error "Function '$FUNCTION_NAME' not found"
        usage
        exit 1
    fi
fi