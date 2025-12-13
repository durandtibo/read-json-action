# read-json-action

[![CI](https://github.com/durandtibo/read-json-action/actions/workflows/ci.yaml/badge.svg)](https://github.com/durandtibo/read-json-action/actions/workflows/ci.yaml)
[![Nightly Tests](https://github.com/durandtibo/read-json-action/actions/workflows/nightly-tests.yaml/badge.svg)](https://github.com/durandtibo/read-json-action/actions/workflows/nightly-tests.yaml)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/durandtibo/read-json-action/blob/main/LICENSE)

A GitHub composite action to read and validate JSON files from your repository. Works seamlessly on
both Linux and macOS runners.

## 🚀 Features

- ✅ **Simple JSON file reading** - Read any JSON file from your repository
- 🔍 **Automatic validation** - Validates JSON syntax using GitHub Actions' built-in `fromJSON()`
- 🖥️ **Cross-platform** - Works on both Linux and macOS runners
- 📊 **Helpful outputs** - Provides file existence, validity status, and content
- 🎯 **Easy integration** - Use with `fromJSON()` to parse the content in subsequent steps
- 💡 **Debug-friendly** - Shows file size and content preview in logs

## 📋 Inputs

| Input                  | Required | Default | Description                                                                                                                  |
|------------------------|----------|---------|------------------------------------------------------------------------------------------------------------------------------|
| `file-path`            | ✅ Yes    | -       | Path to the JSON file relative to the repository root (e.g., `config.json`, `data/settings.json`)                            |
| `fail-on-invalid-json` | ❌ No     | `true`  | Whether to fail if the file contains invalid JSON. When `false`, the action will succeed but `is-valid-json` will be `false` |

## 📤 Outputs

| Output          | Description                                                                             |
|-----------------|-----------------------------------------------------------------------------------------|
| `json-content`  | The complete JSON content as a string. Use `fromJSON()` to parse it in subsequent steps |
| `file-exists`   | Boolean indicating whether the file exists (`true` or `false`)                          |
| `is-valid-json` | Boolean indicating whether the file contains valid JSON (`true` or `false`)             |

## 📖 Usage

### Basic Example

```yaml
name: Read Configuration
on: [ push ]

jobs:
  read-config:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Read JSON file
        id: read-json
        uses: durandtibo/read-json-action@v0.1
        with:
          file-path: 'config.json'

      - name: Display the content
        run: |
          echo "File exists: ${{ steps.read-json.outputs.file-exists }}"
          echo "Valid JSON: ${{ steps.read-json.outputs.is-valid-json }}"
          echo "Content: ${{ steps.read-json.outputs.json-content }}"
```

### Parse JSON with `fromJSON()`

```yaml
- name: Read configuration
  id: config
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'config/settings.json'

- name: Use parsed values
  run: |
    echo "App name: ${{ fromJSON(steps.config.outputs.json-content).app_name }}"
    echo "Version: ${{ fromJSON(steps.config.outputs.json-content).version }}"
    echo "Debug mode: ${{ fromJSON(steps.config.outputs.json-content).debug }}"
```

### Example JSON file (`config/settings.json`)

```json
{
  "app_name": "my-application",
  "version": "1.2.3",
  "debug": true,
  "features": [
    "auth",
    "api",
    "dashboard"
  ]
}
```

### Access nested values

```yaml
- name: Read package.json
  id: package
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'package.json'

- name: Get dependencies
  run: |
    echo "Package name: ${{ fromJSON(steps.package.outputs.json-content).name }}"
    echo "Node version: ${{ fromJSON(steps.package.outputs.json-content).engines.node }}"
```

### Use in a matrix strategy

```yaml
- name: Read test matrix
  id: matrix
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: '.github/test-matrix.json'

- name: Set up matrix
  id: set-matrix
  run: |
    echo "matrix=${{ steps.matrix.outputs.json-content }}" >> $GITHUB_OUTPUT

test:
  needs: setup
  strategy:
    matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}
  runs-on: ${{ matrix.os }}
  steps:
    - name: Test on ${{ matrix.os }} with Python ${{ matrix.python-version }}
      run: echo "Testing..."
```

### Continue on invalid JSON

```yaml
- name: Read potentially invalid JSON
  id: read-json
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'data.json'
    fail-on-invalid-json: false

- name: Check validity
  run: |
    if [ "${{ steps.read-json.outputs.is-valid-json }}" = "true" ]; then
      echo "✅ JSON is valid, processing..."
      echo '${{ steps.read-json.outputs.json-content }}' | jq '.key'
    else
      echo "⚠️ JSON is invalid, using defaults..."
    fi
```

### Conditional steps based on JSON content

```yaml
- name: Read feature flags
  id: features
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'features.json'

- name: Deploy to staging
  if: fromJSON(steps.features.outputs.json-content).deploy_staging == true
  run: |
    echo "Deploying to staging..."

- name: Run integration tests
  if: fromJSON(steps.features.outputs.json-content).run_integration_tests == true
  run: |
    echo "Running integration tests..."
```

## 🔧 Requirements

- The action requires the JSON file to exist in your repository
- The file must be checked out before using this action (use `actions/checkout@v6`)
- For parsing the JSON content, use GitHub Actions' built-in `fromJSON()` function

## ⚠️ Error Handling

The action will **fail** in the following scenarios:

1. **File not found** - If the specified file doesn't exist at the given path
2. **Invalid JSON** - If `fail-on-invalid-json` is `true` (default) and the file contains invalid
   JSON syntax

You can check the outputs to handle these scenarios gracefully:

```yaml
- name: Read JSON file
  id: read-json
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'config.json'
    fail-on-invalid-json: false
  continue-on-error: true

- name: Handle errors
  if: always()
  run: |
    if [ "${{ steps.read-json.outputs.file-exists }}" != "true" ]; then
      echo "❌ File does not exist"
      exit 1
    elif [ "${{ steps.read-json.outputs.is-valid-json }}" != "true" ]; then
      echo "⚠️ Invalid JSON, using defaults"
    fi
```

## 💡 Tips and Best Practices

### Avoid repeated `fromJSON()` calls

If you need to access multiple values from the JSON, consider storing the parsed object:

```yaml
- name: Read config
  id: config
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'config.json'

- name: Set variables
  id: vars
  run: |
    echo "app-name=${{ fromJSON(steps.config.outputs.json-content).app_name }}" >> $GITHUB_OUTPUT
    echo "version=${{ fromJSON(steps.config.outputs.json-content).version }}" >> $GITHUB_OUTPUT

- name: Use variables
  run: |
    echo "Deploying ${{ steps.vars.outputs.app-name }} v${{ steps.vars.outputs.version }}"
```

### Use with environment variables

```yaml
- name: Read config
  id: config
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: 'config.json'

- name: Set environment
  run: |
    echo "APP_NAME=${{ fromJSON(steps.config.outputs.json-content).app_name }}" >> $GITHUB_ENV
    echo "APP_VERSION=${{ fromJSON(steps.config.outputs.json-content).version }}" >> $GITHUB_ENV

- name: Use environment variables
  run: |
    echo "Running $APP_NAME version $APP_VERSION"
```

## 🙏 Acknowledgments

- Uses GitHub Actions' built-in `fromJSON()` and `toJSON()` functions for JSON validation
- Inspired by the need for simple JSON file handling in GitHub workflows

## 🤝Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how
to contribute to this project.

## 📝 License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file
for details.
