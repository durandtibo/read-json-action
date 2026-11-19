# read-json-action

[![CI](https://github.com/durandtibo/read-json-action/actions/workflows/ci.yaml/badge.svg)](https://github.com/durandtibo/read-json-action/actions/workflows/ci.yaml)
[![Nightly Tests](https://github.com/durandtibo/read-json-action/actions/workflows/nightly.yaml/badge.svg)](https://github.com/durandtibo/read-json-action/actions/workflows/nightly.yaml)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/durandtibo/read-json-action/blob/main/LICENSE)

A GitHub composite action that reads one JSON file from disk, checks that it is valid JSON, and
exposes its text and a validity flag as step outputs. It works on Linux and macOS runners, needs
only `bash` and the `python3` that GitHub-hosted runners already have, and does not parse, query
or transform the content: use `fromJSON()` for that.

## Inputs

| Input           | Required | Default | Description                                                                                                                                                         |
| --------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `file-path`     | yes      | -       | Path to the JSON file. Relative paths are resolved from the step's working directory. Must not be empty or contain a newline                                        |
| `fail-on-error` | no       | `true`  | `true` or `false`. When `false`, a problem with the file (missing, not a regular file, unreadable, over 1 MiB, invalid JSON) becomes a warning instead of a failure |

Any other value for `fail-on-error` fails the step, whatever the setting.

## Outputs

| Output          | Description                                                                                                                               |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `is-valid-json` | `true` if the file was read and is valid JSON, otherwise `false`. Always set, including when the step fails                               |
| `json-content`  | The file text, byte for byte, without one trailing newline. Empty if and only if `is-valid-json` is `false`. Safe to pass to `fromJSON()` |

## Quick start

Run `actions/checkout` first, so the file is on the runner.

```yaml
steps:
  - uses: actions/checkout@v7

  - id: config
    uses: durandtibo/read-json-action@v0.2
    with:
      file-path: config.json

  - name: Deploy
    env:
      APP_NAME: ${{ fromJSON(steps.config.outputs.json-content).app_name }}
    run: ./deploy.sh "$APP_NAME"
```

## Reading values safely

Pass every value to a script through `env:` and use it as `"$VAR"`. Never write
`${{ ... }}` inside `run:`: a value with a quote or a `$(...)` would be run as code. Read the
content once into an `env:` variable if you need several fields:

```yaml
- name: Use several fields
  env:
    CONFIG: ${{ steps.config.outputs.json-content }}
  run: |
    set -euo pipefail
    name="$(jq -r '.app_name' <<<"$CONFIG")"
    version="$(jq -r '.version' <<<"$CONFIG")"
    echo "Deploying $name $version"
```

## Tolerating errors

With `fail-on-error: false` the step succeeds and `is-valid-json` tells whether the content can be
used. Test it in an `if:`:

```yaml
- id: optional
  uses: durandtibo/read-json-action@v0.2
  with:
    file-path: optional.json
    fail-on-error: false

- name: Use the file
  if: steps.optional.outputs.is-valid-json == 'true'
  env:
    LEVEL: ${{ fromJSON(steps.optional.outputs.json-content).level }}
  run: echo "Level is $LEVEL"

- name: Use the defaults
  if: steps.optional.outputs.is-valid-json != 'true'
  run: echo "No usable optional.json, using defaults"
```

A caller mistake (empty `file-path`, a bad `fail-on-error`, no `python3`) always fails.

## Behaviour

- **Checks, in order:** the file exists, is a regular file (a symlink to one is fine), is readable,
  is at most 1,048,576 bytes (the GitHub step output limit), and is valid JSON. The first problem is
  reported.
- **Valid** means strict RFC 8259 in UTF-8: no BOM, no `NaN` or `Infinity`, no trailing data, no
  comments. Any top-level value is allowed. Large numbers are checked for syntax only and are not
  converted.
- **Newline:** `json-content` is the file text minus one trailing newline, whether the file has one
  or not.
- **Path:** relative paths start from the step's working directory, so `actions/checkout` must run
  first. The action does not restrict where `file-path` points. If a workflow builds the path from
  untrusted input, the workflow must check it first.
- **Log:** one line with the path, size and result. The file content is never printed.

## Security

- Inputs reach scripts only through `env:`. File content is read from disk and never interpolated
  into a script or an expression.
- File content is never printed to the log, so a line such as `::error::...` in a file cannot run
  a workflow command, and secrets in a file are not leaked by the action.
- Once you use a value in a later step, you are responsible for passing it through `env:` (see
  [Reading values safely](#reading-values-safely)).

## Release notes

### v0.2 (breaking)

| Change                                                   | Migration                                                                                                    |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Input `fail-on-invalid-json` renamed to `fail-on-error`  | Rename the key. It now also tolerates a missing file, a directory, an unreadable file and an over-size file. |
| Output `file-exists` removed                             | Use `is-valid-json`. In strict mode the step already failed when the file was missing.                       |
| `fail-on-error` rejects values other than `true`/`false` | Fix typos. Such values used to turn validation off silently.                                                 |
| `json-content` is empty for invalid files                | Test `is-valid-json` before using the content.                                                               |
| `json-content` loses one trailing newline, consistently  | Nothing for `fromJSON()` users. Compare exact text only if you relied on the old inconsistency.              |
| `NaN`, `Infinity`, BOM and non-UTF-8 files are invalid   | Fix the files. `fromJSON()` rejected them anyway.                                                            |
| No content preview in the log                            | Read the file in a later step if you need it, and mask secrets yourself.                                     |

Releases are immutable exact version tags (`v0.2`, ...). There are no floating tags such as `v1`.

## Contributing

Contributions are welcome! Open an issue or pull request on
[GitHub](https://github.com/durandtibo/read-json-action). Run `make format` and `make lint`
before committing, and `make test` to run the unit tests of `scripts/validate-json.py`. To add an
action test, add a fixture to `test-data/` and a case to `test-data/cases.json`. A case with
`"general": true` runs on every Linux and macOS runner, the other cases run on one runner (or on the
`*-latest` runners with `"os-sensitive": true`).

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file
for details.
