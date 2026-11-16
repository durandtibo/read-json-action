# read-json-action: target state

Review date: 2026-11-15. Scope: `action.yaml`, `scripts/test-helper.sh`, `test-data/`, the test
workflows, `README.md` and `CLAUDE.md`. `.make/` is out of scope because it is synced from a shared
repository.

## 1. Properties of the action

These are the properties the target state must keep. Every design choice below is judged against
them.

| #   | Property                | Statement                                                                                                                                                                                                                                                                                 |
| --- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1  | Single purpose          | Read one JSON file from disk, check that it is valid JSON, and expose its text and a validity flag as step outputs. It does not parse, query or transform the content.                                                                                                                    |
| P2  | Correct contract        | Outputs are exact and documented. `json-content` is the file text, byte for byte, minus one trailing newline. It is non-empty if and only if `is-valid-json` is `true`.                                                                                                                   |
| P3  | Injection-safe          | Inputs reach scripts only through `env:`. File content is never interpolated into a script or expression. It is never printed to the log, so it cannot inject workflow commands.                                                                                                          |
| P4  | Fails loudly, by choice | A caller bug always fails. A file problem fails by default and is downgraded to a warning only when the caller sets `fail-on-error: false`. Messages use `::error::`/`::warning::`.                                                                                                       |
| P5  | Portable                | Works on GNU/Linux and BSD/macOS runners. Uses only `bash`, POSIX tools (`wc`, `tail`, `od`, `tr`, `cat`) and `python3` from the standard library. No install step, no network.                                                                                                           |
| P6  | Small and fast          | Few, short steps with one job each, one `python3` process, no external actions, no dependencies. A step costs a few hundred milliseconds of runner overhead, which is accepted in exchange for P7.                                                                                        |
| P7  | Maintainable            | Several small steps (at most about 20 lines each) that hand state over through step outputs, so each step can be read, reviewed and changed alone. One source of truth for each of: input/output names (`action.yaml`), documentation (`README.md`), test cases (`test-data/cases.json`). |
| P8  | Tested without drift    | Every behaviour has a fixture and a case. The same test workflow runs against the local checkout and against the released action, so there is no duplicated copy to keep in sync.                                                                                                         |
| P9  | Immutable releases      | Exact version tags only (`v0.x`). No floating tags.                                                                                                                                                                                                                                       |

Non-goals: Windows runners, JSON5/JSONC/comments, JSON Schema validation, extracting fields (use
`fromJSON()` or `jq`), files over 1 MiB (the GitHub step-output limit), and reading from a URL or
from stdin.

## 2. Findings in the current state

Ordered by impact.

### Correctness and security

- **1.** **File content is printed to the log.** The "Display summary" step runs `head -c 200
"$FILE_PATH"`.
  A line starting with `::error::`, `::add-mask::` or `::stop-commands::` in the file is executed
  as a workflow command. The file may also contain secrets. This contradicts P3 and the README's
  "injection-safe" claim, and no test covers it. The test "resembling workflow commands" only
  checks the output, not the log. `head -c` can also cut a UTF-8 character in half.
- **2.** **`fail-on-invalid-json` accepts any string.** Anything other than the exact text `true`
  means
  tolerant mode. `"True"`, `"yes"` or `"ture"` silently turn validation off. The fail-safe default
  is lost because of a typo.
- **3.** **`json-content` is inconsistent.** `cat file; echo ""` keeps a trailing newline when the
  file
  ends with a newline and drops it when it does not. The tests hide this by comparing parsed JSON
  and `rstrip()`ed text.
- **4.** **`json-content` is set for invalid files.** In tolerant mode the raw invalid text is
  exposed.
  The next `fromJSON()` call then fails the whole job with a confusing error. The safe contract is
  empty content when the JSON is invalid.
- **5.** **The Python call uses the locale encoding.** `open(path)` depends on the runner locale. A
  UTF-8
  file can be rejected or accepted differently on two runners. Python also accepts `NaN` and
  `Infinity`, which `fromJSON()` and RFC 8259 reject, so `is-valid-json: true` can still be
  followed by a `fromJSON()` failure.
- **6.** **No size check.** A step output is limited to 1 MiB. A bigger file fails in the runner
  with a
  cryptic message instead of a clear `::error::`.
- **7.** **Weak input validation.** An empty `file-path` gives "File not found: ". A path with a
  newline
  can forge log lines. A path starting with `-` is passed to `cat` without `--`. A directory gives
  the same message as a missing file.

### Design

- **8.** **`file-exists` carries no information.** The step fails when the file is missing, so the
  output
  is `true` whenever the action succeeds. When the action fails, the value is only readable with
  `continue-on-error`. The `file-exists` workaround in the README exists only because of this.
- **9.** **The steps do not match the concerns.** The current steps (check, read, validate,
  summary) are split by chronology, not by responsibility: the validity result is needed before
  the content is exposed, yet the read step runs first and always exposes it. The summary step
  mixes reporting with leaking content. The target keeps small steps but cuts them along
  responsibilities (section 4).
- **10.** **Wrong or misleading metadata.** The description says "automatic compatibility checking
  for
  your Python version", which the action does not do. `file-path` is documented as "relative to
  the repository root", but it is relative to the step's working directory.
- **11.** **`uuidgen` with a Python fallback** to build a delimiter. `od` on `/dev/urandom` is
  portable on
  GNU and BSD, and needs neither `uuidgen` nor a second Python process.

### Tests and docs

- **12.** **`ci-action.yaml` (714 lines) and `nightly-test-released.yaml` (713 lines) are copies.**
  `CLAUDE.md` says to "keep both in sync" by hand. Every new test is added twice.
- **13.** **About 33 cases, each written as two hand-written steps** of 12 to 25 lines. The only
  difference between cases is a file, a flag and an expectation, which is data.
- **14.** **`scripts/test-helper.sh` is 500 lines.** About 60% is per-fixture wrappers
  (`test_single_line_json`, `test_multi_line_json`, `test_nested_json`) and print helpers. The
  wrappers hard-code fixture values in the script, which is the wrong place for them.
- **15.** **README examples break the project's own rule.** They use `${{ ...json-content }}`
  inside `run:`,
  and `echo '${{ ... }}' | jq`, which is injectable and breaks on a single quote in the JSON. The
  "avoid repeated `fromJSON()` calls" tip still repeats `fromJSON()` three times. The README is
  250 lines with a features list, an acknowledgments section and several near-duplicate examples.

## 3. Target contract

Breaking changes are intentional and listed in section 7. The target version is `v0.2`, because a
`v0.x` release carries no stability promise.

### Inputs

| Input           | Required | Default | Description                                                                                                                                                          |
| --------------- | -------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `file-path`     | yes      | -       | Path to the JSON file. Relative paths are resolved from the step's working directory (the workspace by default). Must not be empty or contain a newline.             |
| `fail-on-error` | no       | `true`  | `true` or `false`. When `false`, a problem with the file (missing, not a regular file, unreadable, over 1 MiB, invalid JSON) becomes a warning instead of a failure. |

Any other value for `fail-on-error` fails the step, whatever the setting. Caller mistakes (empty
path, bad flag value, `python3` missing) always fail.

`fail-on-invalid-json` is renamed to `fail-on-error` because the flag now covers every file
problem, not only invalid JSON. This also removes the need for a `file-exists` output and a second
flag for missing files (see "Rejected alternatives").

### Outputs

| Output          | Value                                                                                                                                                     |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `is-valid-json` | `true` if the file was read and is valid RFC 8259 JSON, otherwise `false`. Always set, including on failure, so it can be read after `continue-on-error`. |
| `json-content`  | The file text, byte for byte, without one trailing newline. Empty if and only if `is-valid-json` is `false`. Safe to pass to `fromJSON()`.                |

`file-exists` is removed.

### Behaviour

1. Validate inputs first (empty path, newline in path, `fail-on-error` value, `python3` present).
2. Check the file in this order and stop at the first problem: exists, is a regular file, is
   readable, is at most 1,048,576 bytes, is valid JSON.
3. "Valid" means strict RFC 8259 in UTF-8: no BOM, no `NaN`/`Infinity`, no trailing data, no
   comments. Any top-level value is allowed (object, array, string, number, `true`/`false`/`null`).
   Large numbers are checked only for syntax. They are not converted.
4. On a problem, set `is-valid-json=false`, leave `json-content` unset, then emit `::error::` and
   exit 1, or emit `::warning::` and exit 0 when `fail-on-error` is `false`.
5. On success, set `is-valid-json=true` and `json-content`. Print one log line with the path, size
   and result. Never print file content.

## 4. Target `action.yaml`

Five small steps. Each has one job, fits on one screen, and passes its result to the next through
a step output. A later step is skipped, or reads the earlier result, instead of re-checking it.

| Step | `id`      | Job                                                                | Output            |
| ---- | --------- | ------------------------------------------------------------------ | ----------------- |
| 1    | `inputs`  | Reject caller mistakes (empty path, newline, bad flag, no python3) | -                 |
| 2    | `file`    | Check the file exists, is regular, readable and within the limit   | `problem`, `size` |
| 3    | `json`    | Validate the syntax. Skipped if step 2 found a problem             | `problem`         |
| 4    | `result`  | Merge the problems, set `is-valid-json`, fail or warn              | `is-valid-json`   |
| 5    | `content` | Write `json-content`. Runs only when `is-valid-json` is `true`     | `json-content`    |

`problem` is an empty string when there is nothing wrong. Because step 4 is the only step that
decides between failing and warning, `fail-on-error` is read in exactly one place. `is-valid-json`
falls back to `false` when an earlier step failed (a caller mistake), so it always has a value.

```yaml
name: "read-json-file"
description: "Read a JSON file from disk, validate it, and expose its content as a step output"
author: "Thibaut Durand"
branding:
  icon: "file-text"
  color: "blue"

inputs:
  file-path:
    description: |
      Path to the JSON file. Relative paths are resolved from the step's working directory
    required: true
  fail-on-error:
    description: |
      Whether to fail when the file is missing, unreadable, larger than 1 MiB or not valid JSON.
      When "false" these problems become a warning and is-valid-json is "false"
    required: false
    default: "true"

outputs:
  is-valid-json:
    description: '"true" if the file is valid JSON, otherwise "false"'
    value: ${{ steps.result.outputs.is-valid-json || 'false' }}
  json-content:
    description: |
      The file text without its trailing newline. Empty unless is-valid-json is "true".
      Use fromJSON() to parse it
    value: ${{ steps.content.outputs.json-content }}

runs:
  using: "composite"
  steps:
    # Step 1: caller mistakes always fail, whatever fail-on-error says.
    - name: Check inputs
      id: inputs
      shell: bash
      env:
        FILE_PATH: ${{ inputs.file-path }}
        FAIL_ON_ERROR: ${{ inputs.fail-on-error }}
      run: |
        set -euo pipefail

        die() {
          echo "::error::$1"
          exit 1
        }

        [ -n "$FILE_PATH" ] || die "file-path must not be empty"
        case "$FILE_PATH" in *$'\n'* | *$'\r'*) die "file-path must not contain a newline" ;; esac
        case "$FAIL_ON_ERROR" in
          true | false) ;;
          *) die "fail-on-error must be 'true' or 'false' (got '$FAIL_ON_ERROR')" ;;
        esac
        command -v python3 > /dev/null || die "python3 is required but was not found"

    # Step 2: file-level problems. Reports the first one and never fails by itself.
    - name: Check file
      id: file
      shell: bash
      env:
        FILE_PATH: ${{ inputs.file-path }}
      run: |
        set -euo pipefail

        limit=1048576 # GitHub step output limit (1 MiB)
        problem=""
        size=0
        if [ ! -e "$FILE_PATH" ]; then
          problem="File not found: $FILE_PATH"
        elif [ ! -f "$FILE_PATH" ]; then
          problem="Not a regular file: $FILE_PATH"
        elif [ ! -r "$FILE_PATH" ]; then
          problem="File is not readable: $FILE_PATH"
        else
          size="$(wc -c < "$FILE_PATH")"
          size=$((size)) # BSD wc pads with spaces
          if [ "$size" -gt "$limit" ]; then
            problem="File is $size bytes, over the $limit byte limit: $FILE_PATH"
          fi
        fi

        {
          echo "problem=$problem"
          echo "size=$size"
        } >> "$GITHUB_OUTPUT"

    # Step 3: syntax. The checker prints one line on failure and never the file content.
    - name: Validate JSON syntax
      id: json
      if: steps.file.outputs.problem == ''
      shell: bash
      env:
        FILE_PATH: ${{ inputs.file-path }}
      run: |
        set -euo pipefail

        problem=""
        if ! reason="$(python3 -I "$GITHUB_ACTION_PATH/scripts/validate-json.py" "$FILE_PATH" 2>&1)"; then
          problem="Invalid JSON in $FILE_PATH (${reason//$'\n'/ })"
        fi
        echo "problem=$problem" >> "$GITHUB_OUTPUT"

    # Step 4: the only step that decides between failing and warning.
    - name: Report result
      id: result
      shell: bash
      env:
        PROBLEM: ${{ steps.file.outputs.problem || steps.json.outputs.problem }}
        FAIL_ON_ERROR: ${{ inputs.fail-on-error }}
      run: |
        set -euo pipefail

        if [ -z "$PROBLEM" ]; then
          echo "is-valid-json=true" >> "$GITHUB_OUTPUT"
          exit 0
        fi

        echo "is-valid-json=false" >> "$GITHUB_OUTPUT"
        if [ "$FAIL_ON_ERROR" = "true" ]; then
          echo "::error::$PROBLEM"
          exit 1
        fi
        echo "::warning::$PROBLEM"

    # Step 5: only reached for a valid file. Content is never printed.
    - name: Expose content
      id: content
      if: steps.result.outputs.is-valid-json == 'true'
      shell: bash
      env:
        FILE_PATH: ${{ inputs.file-path }}
        SIZE: ${{ steps.file.outputs.size }}
      run: |
        set -euo pipefail

        # The delimiter is random, so no file content can end the output early.
        delimiter="ghadelimiter_$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
        {
          echo "json-content<<$delimiter"
          cat -- "$FILE_PATH"
          # $(...) strips a trailing newline, so this adds one only if the file lacks it.
          [ -z "$(tail -c 1 "$FILE_PATH")" ] || echo
          echo "$delimiter"
        } >> "$GITHUB_OUTPUT"
        echo "Read $FILE_PATH ($SIZE bytes, valid JSON)"
```

`scripts/validate-json.py` (the one extra file; it can be run and tested alone):

```python
"""Exit 0 if the file is strict RFC 8259 JSON in UTF-8. Otherwise print one line and exit 1."""

import json
import sys


def reject(constant):
    raise ValueError("invalid constant " + constant)


try:
    with open(sys.argv[1], encoding="utf-8") as f:
        json.load(f, parse_constant=reject)
except (ValueError, OSError) as e:  # JSONDecodeError and UnicodeDecodeError are ValueErrors
    print(type(e).__name__ + ": " + str(e))
    sys.exit(1)
```

Notes on the sketch:

- Steps 2 and 3 never fail: they report a `problem`. Only steps 1 and 4 call `exit 1`, so there are
  two places to look when the action fails and one place that reads `fail-on-error`.
- Step 3 is skipped when step 2 found a problem, so `steps.json.outputs.problem` is empty then
  and `steps.file.outputs.problem || steps.json.outputs.problem` picks the right one.
- Step 5 is skipped on any problem, so `json-content` is unset exactly when `is-valid-json` is
  `false`. No step has to remember to blank it.
- `problem` values come from the path and from a one-line Python message, never from file content
  beyond what `UnicodeDecodeError` reports (byte values and a position), so they are safe to pass
  through `env:` and `GITHUB_OUTPUT`.
- Moving Python to `scripts/validate-json.py` keeps the YAML free of quoting tricks and makes the
  validator runnable on a fixture without GitHub Actions.
- No `uuidgen`, no second Python process, no `mktemp`/`trap`.
- Python stays the validator because it is on every GitHub-hosted runner, and `-I` stops it from
  loading anything from the working directory. `jq` is the alternative and is also preinstalled,
  but the two disagree on large numbers and `NaN`, and Python gives clearer error messages.
- The sketch must pass `shellcheck` and `shfmt` before it is merged. Both are run by `make lint`
  and `make format`. The pass was not verified for this review.

## 5. Target tests

The goal is that adding a test means adding a fixture and one line of JSON, and that the local
action and the released action run exactly the same cases.

### Structure

```text
test-data/
  cases.json          # one entry per case, the single source for both workflows
  *.json              # fixtures (kept; add the new ones listed below)
scripts/
  test-helper.sh      # ~60 lines: assert_eq, assert_content_matches_file, assert_path_absent
.github/workflows/
  ci-action.yaml      # reusable; input use-released (bool, default false)
  nightly.yaml        # calls ci-action.yaml with use-released: true
                      # nightly-test-released.yaml is deleted
```

`cases.json` entry:

```json
{
  "id": "invalid-trailing-comma-tolerant",
  "file-path": "test-data/trailing-comma.json",
  "fail-on-error": "false",
  "expect-outcome": "success",
  "expect-valid": "false"
}
```

### Workflow

- A small `get-cases` job reads `test-data/cases.json` and outputs it. The `cases` job uses it as
  `matrix.case` and crosses it with every runner of the shared `os_matrix` (decision: option A,
  see "Cost and the decision taken"). Each matrix job has four steps:
  1. checkout,
  2. `uses: ./` with `continue-on-error: true` and `if: !inputs.use-released`,
  3. the same call to the released action, pinned by SHA with a `# ratchet:` comment, with
     `if: inputs.use-released`. This is now the only place that SHA lives, and `CLAUDE.md` says so,
  4. one verify step for every case. It receives the outcome, the outputs and the case through
     `env:` and runs `scripts/test-helper.sh`.
- The verify step checks, for every case:
  - `steps.<id>.outcome` equals `expect-outcome`;
  - `is-valid-json` equals `expect-valid`, even after a failure;
  - when valid, `json-content` equals the file minus one trailing newline, byte for byte (compared
    from `env:`, not from the parsed value);
  - when not valid, `json-content` is empty;
  - the log contains no copy of the file content (see the log-injection case below).
- A second job, `python-compat`, runs three cases (a valid object, an invalid file, a large
  number) on `ubuntu-latest` and `macos-latest` with the oldest and newest Python from
  `python_versions_standard`. The Python version barely affects the action (it only needs the
  `json` module), so it is not a dimension of the main matrix.
- A third job, `fromjson-compat`, checks that `fromJSON(json-content)` works for the valid
  fixtures. It runs only on `ubuntu-latest`, because workflow expressions run the same everywhere.
  This is the only place where the old `test_*_json` field checks are kept.

#### Cost and the decision taken

Today one job runs the whole case list for every combination of `os_matrix` and
`python_versions_standard`: currently 13 Unix runners x 5 Python versions = 65 jobs of about 33
cases each (values from `workflow-config-action` `configs/versions.json` at the time of writing).

Decision: **option A**. Every case runs as its own job on every runner of `os_matrix`. The Python
version is dropped from the main matrix and covered by `python-compat`.

| Option                                                 | Jobs per run    | YAML for cases            | Coverage                 |
| ------------------------------------------------------ | --------------- | ------------------------- | ------------------------ |
| **A. Case matrix on every OS (chosen)**                | ~600 short jobs | ~0 (data in `cases.json`) | Every case on 13 runners |
| B. One job per OS, cases as steps, no Python dimension | 13 jobs         | ~450 lines (steps)        | Every case on 13 runners |
| C. Case matrix on 2 OS plus a `smoke` job on every OS  | ~115 jobs       | ~0 (data in `cases.json`) | 2 runners, 3 cases on 13 |

Consequences to accept, and how the design limits them:

- About 600 jobs per run (about 45 cases x 13 runners, plus `python-compat` and `fromjson-compat`).
  Each job spends 15 to 30 seconds on runner start and checkout for about a second of testing, so
  the total runner time is higher than today and the wall time depends on the runner pool.
- Use `fail-fast: false`, so one failing case does not hide the others. Set `max-parallel`
  explicitly (keep today's 8 as the starting value and raise it if runs are too slow), and keep
  `timeout-minutes: 5` on the job.
- Skip the Python setup in the case jobs: the action only needs the preinstalled `python3`, and
  not installing one is part of what the test checks.
- Because the case matrix is large, `ci.yaml` triggers it as it does today (pull requests, `main`,
  schedule). If PR feedback becomes too slow, the first thing to try is option C for pull requests
  and A only for the nightly run. That is a change to one `if:`, not a redesign.
- The job names are `<case id> (<os>)`, so a failure points to the exact case and runner.

### Cases to keep

All 33 current cases keep their meaning. Rename `fail-on-invalid-json` to `fail-on-error` in them.
Update the expectations: missing file, directory and empty path keep failing in strict mode, and
tolerant mode now succeeds with `is-valid-json=false` for a missing file or a directory. Only
the empty path still fails in tolerant mode.

### Cases to add (each needs a fixture and would have failed before)

| Fixture or input                                                                          | Expectation                                                            | Regression for finding |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ---------------------- |
| `fail-on-error: "True"`, `"yes"`, `""`                                                    | fails with a clear message, in both modes                              | 2                      |
| `file-path` containing a newline                                                          | fails; no forged log line                                              | 7                      |
| `file-path: "-n"` (a file named `-n`)                                                     | reads the file as a path                                               | 7                      |
| `test-data/log-injection.json` (`::error::forged` and `::add-mask::x` on their own lines) | succeeds; no annotation is created; log contains none of the file text | 1                      |
| `test-data/nan.json`, `infinity.json`                                                     | invalid                                                                | 5                      |
| `test-data/bom.json` (UTF-8 BOM)                                                          | invalid                                                                | 5                      |
| `test-data/latin1.json` (invalid UTF-8)                                                   | invalid, with `LC_ALL=C` and with a UTF-8 locale                       | 5                      |
| `test-data/over-1mib.json` (generated in a setup step, not committed)                     | fails with the size message                                            | 6                      |
| `test-data/with-trailing-newline.json`                                                    | `json-content` has no trailing newline                                 | 3                      |
| `no-trailing-newline.json` (exists)                                                       | `json-content` is exactly the file                                     | 3                      |
| Any invalid fixture, tolerant mode                                                        | `json-content` is empty                                                | 4                      |
| Unreadable file (`chmod 000`, skipped when running as root)                               | fails or warns with the "not readable" message                         | 7                      |
| Symlink to a valid file                                                                   | succeeds                                                               | -                      |
| `test-data/a-directory.json/`, missing, empty path                                        | the three distinct messages                                            | 7                      |

Rules kept from `CLAUDE.md`: outputs always reach scripts through `env:`; if a check fails for a
real reason, report it and do not weaken the test.

### `scripts/test-helper.sh`

Keep `print_error`/`print_success`, `verify_step_outcome`, `verify_json_value`,
`verify_raw_content_matches_file` (made exact: no `rstrip`), `verify_output_empty` and
`verify_path_absent`. Delete `test_single_line_json`, `test_multi_line_json`, `test_nested_json`,
`run_basic_validation`, `display_outputs`, `verify_output_exists`, `verify_file_exists` and the
`usage` text for them. The rule is that fixture knowledge lives in `test-data/`, never in the script.

## 6. Target documentation

### `README.md` (about 110 lines, down from 250)

Sections, in order: one-paragraph description and badges, inputs table, outputs table, quick start,
reading values safely, tolerating errors, behaviour (what "valid" means, size limit, newline rule,
path resolution), security, contributing, license.

Changes:

- Delete the feature list with emoji, the "Acknowledgments" section and the near-duplicate examples
  (access nested values, conditional steps, environment variables). One `fromJSON()` example
  covers them.
- **Every example passes values through `env:`**, which matches the security section:

  ```yaml
  - id: config
    uses: durandtibo/read-json-action@v0.2
    with:
      file-path: config.json

  - name: Deploy
    env:
      APP_NAME: ${{ fromJSON(steps.config.outputs.json-content).app_name }}
    run: ./deploy.sh "$APP_NAME"
  ```

- Fix the error-handling example. With `fail-on-error: false`, test `is-valid-json` and no longer
  `file-exists`. A conditional `if: steps.config.outputs.is-valid-json == 'true'` replaces the
  `continue-on-error` and `if: always()` workaround.
- Say that `file-path` is relative to the working directory and that `actions/checkout` must run
  first. State the 1 MiB limit, the strict RFC 8259 rule and that `json-content` is empty unless
  the file is valid.
- State plainly that the action does not restrict where `file-path` points. If a workflow builds
  the path from untrusted input, the workflow must check it first.
- Keep one release-note block per version listing breaking changes (see section 7).

### `CLAUDE.md`

- Change the breaking-name list to `file-path`, `fail-on-error`, `json-content`, `is-valid-json`.
- Replace the "mirrors `ci-action.yaml`: keep both in sync" rule with: `nightly.yaml` calls
  `ci-action.yaml` with `use-released: true`; the released-action SHA is pinned in `ci-action.yaml`
  only. Remove `nightly-test-released.yaml` from the workflow list and from the release step.
- Replace "Add each new test to both workflows" with "add a fixture to `test-data/` and a case to
  `test-data/cases.json`".
- Add: "Never print file content to the log."

## 7. Breaking changes (release notes for `v0.2`)

| Change                                                   | Migration                                                                                                    |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Input `fail-on-invalid-json` renamed to `fail-on-error`  | Rename the key. It now also tolerates a missing file, a directory, an unreadable file and an over-size file. |
| Output `file-exists` removed                             | Use `is-valid-json`. In strict mode the step already failed when the file was missing.                       |
| `fail-on-error` rejects values other than `true`/`false` | Fix typos. Such values used to turn validation off silently.                                                 |
| `json-content` is empty for invalid files                | Test `is-valid-json` before using the content.                                                               |
| `json-content` loses one trailing newline, consistently  | Nothing for `fromJSON()` users. Compare exact text only if you relied on the old inconsistency.              |
| `NaN`, `Infinity`, BOM and non-UTF-8 files are invalid   | Fix the files. `fromJSON()` rejected them anyway.                                                            |
| No content preview in the log                            | Read the file in a later step if you need it, and mask secrets yourself.                                     |

## 8. Rejected alternatives

- **One big step.** Fewer process starts, but one 60-line script mixes input checks, file checks,
  validation, reporting and output writing, and a change to one concern needs the whole script in
  your head. Small steps cost a few hundred milliseconds each and are easier to read, review and
  change. The preference is for small steps.
- **Keep `file-exists` and add `fail-on-missing-file`.** Two flags and three states for one job.
  The single `fail-on-error` flag plus `is-valid-json` answers the real question ("can I use this
  content?"). If a "file is optional" case appears that needs to be told apart from "invalid", add
  `file-exists` then, and not before.
- **Output minified JSON from Python.** This would shorten the content, but it changes number
  formatting (`1.5e300` becomes `1.5e+300`), key order handling and Unicode escapes, and it adds a
  second pass over the data. Exact text is a simpler contract.
- **A JavaScript or Docker action.** It is faster to author in TypeScript with a typed API, but it
  adds a build step, a `dist/` directory to keep in sync, and (for Docker) a slow start and no macOS
  support. A few short bash steps with no build meet P5 and P6.
- **`jq` instead of Python.** Equal in speed and preinstalled on GitHub-hosted runners, but the
  behaviour for large numbers and `NaN` differs between `jq` versions. The Python behaviour is
  fixed by the standard library.
- **Emit the content as base64 or JSON-escaped.** It would remove the delimiter, but every consumer
  would have to decode it. The random delimiter is enough.
- **A Windows runner.** `bash` exists there, but P5 and the runner matrix target Linux and macOS.
  Add it only if there is demand, because it needs `od` and `tail` checks on Git Bash.

## 9. Delivery plan

One branch and one PR per logical change, each from an up-to-date `main`, with `make format` and
`make lint` run before committing.

| Order | Branch                             | PR title                                                   | Contents                                                                                                                                                                                                           |
| ----- | ---------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1     | `bugfix/stop-logging-file-content` | Remove the file content preview from the log               | Finding 1 only, with the log-injection regression test. Small, so it can ship first, even before the rest lands.                                                                                                   |
| 2     | `test/data-driven-action-tests`    | Run action tests from a shared case list                   | `cases.json`, the matrix workflow, the `use-released` toggle, the slimmed helper, and removal of `nightly-test-released.yaml`. Behaviour of the action is unchanged. This PR proves that the old cases still pass. |
| 3     | `refactor/split-action-steps`      | Split the action into small steps and tighten the contract | New `action.yaml`, `scripts/validate-json.py`, new cases from section 5, `fail-on-error`, removal of `file-exists`, and the `CLAUDE.md` changes.                                                                   |
| 4     | `docs/rewrite-readme`              | Rewrite the README around the new contract                 | Section 6. It lands with, or just after, PR 3 so the README is never out of date on `main`.                                                                                                                        |
| 5     | (release)                          | -                                                          | Tag `v0.2`, then set the pinned SHA in `ci-action.yaml`.                                                                                                                                                           |

Reporting for each PR, following `CLAUDE.md`: say which of `make lint` and `make format` ran, say
that CI was not awaited, and say that the action could not be run locally and can only be exercised
by `ci-action.yaml` in GitHub Actions.

## 10. What stays as it is

- `action.yaml` name, branding, author, composite type, `shell: bash`, `set -euo pipefail`, and
  inputs passed through `env:`.
- The workflow layout and prefixes (`ci-*`, `lib-*`, `bot-*`, `security-*`), least-privilege
  `permissions`, `timeout-minutes`, SHA pinning with `# ratchet:` comments, and the shared
  `.make/` directory.
- `test-data/` fixtures. The existing ones are kept, and only the additions in section 5 are new.
