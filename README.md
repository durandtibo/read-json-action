# read-json-action

[![CI](https://github.com/durandtibo/read-json-action/actions/workflows/ci.yaml/badge.svg)](https://github.com/durandtibo/read-json-action/actions/workflows/ci.yaml)
[![Nightly Tests](https://github.com/durandtibo/read-json-action/actions/workflows/nightly.yaml/badge.svg)](https://github.com/durandtibo/read-json-action/actions/workflows/nightly.yaml)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/durandtibo/read-json-action/blob/main/LICENSE)

A GitHub composite action to read and validate JSON files from your repository. Works seamlessly on
both Linux and macOS runners.

## 🚀 Features

- ✅ **Simple JSON file reading** - Read any JSON file from your repository
- 🔍 **Automatic validation** - Validates JSON syntax with Python's built-in `json` module
- 🖥️ **Cross-platform** - Works on both Linux and macOS runners
- 📊 **Helpful outputs** - Provides file existence, validity status, and content
- 🎯 **Easy integration** - Use with `fromJSON()` to parse the content in subsequent steps
- 🔒 **Injection-safe** - File content is never interpolated into shell commands or workflow expressions
- 💡 **Debug-friendly** - Shows the file size in logs, never the file content

## 📋 Inputs

| Input           | Required | Default | Description                                                                                                                                                         |
| --------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `file-path`     | ✅ Yes   | -       | Path to the JSON file. Relative paths are resolved from the step's working directory. Must not be empty or contain a newline                                        |
| `fail-on-error` | ❌ No    | `true`  | `true` or `false`. When `false`, a problem with the file (missing, not a regular file, unreadable, over 1 MiB, invalid JSON) becomes a warning instead of a failure |

## 📤 Outputs

| Output          | Description                                                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `is-valid-json` | `true` if the file was read and is valid JSON, otherwise `false`. Always set, including on failure                                   |
| `json-content`  | The file text without one trailing newline. Empty unless `is-valid-json` is `true`. Use `fromJSON()` to parse it in subsequent steps |

## 📖 Usage

### Basic Example

```yaml
name: Read Configuration
on: [push]

jobs:
  read-config:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Read JSON file
        id: read-json
        uses: durandtibo/read-json-action@v0.1
        with:
          file-path: "config.json"

      - name: Display the content
        run: |
          echo "Valid JSON: ${{ steps.read-json.outputs.is-valid-json }}"
          echo "Valid JSON: ${{ steps.read-json.outputs.is-valid-json }}"
          echo "Content: ${{ steps.read-json.outputs.json-content }}"
```

### Parse JSON with `fromJSON()`

```yaml
- name: Read configuration
  id: config
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: "config/settings.json"

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
  "features": ["auth", "api", "dashboard"]
}
```

### Access nested values

```yaml
- name: Read package.json
  id: package
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: "package.json"

- name: Get dependencies
  run: |
    echo "Package name: ${{ fromJSON(steps.package.outputs.json-content).name }}"
    echo "Node version: ${{ fromJSON(steps.package.outputs.json-content).engines.node }}"
```

### Continue on invalid JSON

```yaml
- name: Read potentially invalid JSON
  id: read-json
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: "data.json"
    fail-on-error: false

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
    file-path: "features.json"

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
- The file must be checked out before using this action (use `actions/checkout@v7`)
- For parsing the JSON content, use GitHub Actions' built-in `fromJSON()` function
- The runner must have Python 3 available (preinstalled on GitHub-hosted Linux and macOS runners)

## ⚠️ Error Handling

The action will **fail** in the following scenarios:

1. **File problem** - The file is missing, is not a regular file, is not readable or is over 1 MiB,
   and `fail-on-error` is `true` (default)
2. **Invalid JSON** - The file is not strict RFC 8259 JSON in UTF-8 and `fail-on-error` is `true`
   (default)
3. **Caller mistake** - An empty `file-path`, a `file-path` with a newline, a `fail-on-error`
   other than `true` or `false`, or no `python3`. These fail whatever `fail-on-error` says

You can check the outputs to handle these scenarios gracefully:

```yaml
- name: Read JSON file
  id: read-json
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: "config.json"
    fail-on-error: false

- name: Handle errors
  if: steps.read-json.outputs.is-valid-json != 'true'
  run: echo "⚠️ No usable JSON, using defaults"
```

## 💡 Tips and Best Practices

### Avoid repeated `fromJSON()` calls

If you need to access multiple values from the JSON, consider storing the parsed object:

```yaml
- name: Read config
  id: config
  uses: durandtibo/read-json-action@v0.1
  with:
    file-path: "config.json"

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
    file-path: "config.json"

- name: Set environment
  run: |
    echo "APP_NAME=${{ fromJSON(steps.config.outputs.json-content).app_name }}" >> $GITHUB_ENV
    echo "APP_VERSION=${{ fromJSON(steps.config.outputs.json-content).version }}" >> $GITHUB_ENV

- name: Use environment variables
  run: |
    echo "Running $APP_NAME version $APP_VERSION"
```

## 🔒 Security

File content is never interpolated directly into shell commands or workflow expressions inside
the action; it's only read from disk and passed through `GITHUB_OUTPUT`/environment variables.
This means JSON content containing shell metacharacters (e.g. `$(...)`, `` `...` ``) is safe
to read and cannot execute commands on the runner.

That said, once you pull a value out with `fromJSON(...)` inside a subsequent `run:` step, **you**
are responsible for not interpolating untrusted content directly into a shell command. Prefer
passing it through `env:` and referencing it as `"$MY_VAR"`, rather than embedding
`${{ fromJSON(...).field }}` directly in the script body.

## 🙏 Acknowledgments

- Uses Python's built-in `json` module (preinstalled on GitHub-hosted runners) for JSON validation
- Inspired by the need for simple JSON file handling in GitHub workflows

## 🤝Contributing

Contributions are welcome! Open an issue or pull request on
[GitHub](https://github.com/durandtibo/read-json-action). Run `make format` and `make lint`
before committing.

## 📝 License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file
for details.
