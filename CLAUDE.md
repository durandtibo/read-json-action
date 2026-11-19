# CLAUDE.md

Guidance for coding agents working in this repository.

## Repository purpose

A GitHub composite action (`action.yaml`) that reads a JSON file from the repository, validates
its syntax as strict RFC 8259 JSON, and exposes `json-content` and `is-valid-json` outputs. It must
work on GNU/Linux and BSD/macOS runners (Windows is not supported and not tested). The logic lives
in five small bash steps inside `action.yaml` (check inputs, check file, validate syntax, report
result, expose content), plus `scripts/validate-json.py` for the syntax check, which is tested
with `unittest` in `tests/`. `scripts/test-helper.sh` provides assertion helpers used by the test
workflow, `scripts/setup-fixtures.sh` creates the fixtures that cannot be committed, and
`test-data/` holds the fixtures and the case list `cases.json` those workflows read. `dev/` holds
maintainer helpers (`check_export.sh`), not part of the action. `review/` holds the review notes
(`target_state.md`), also not part of the action.

## Environment

- Use the `Makefile`; run `make help` to list targets.
- Do not edit `.make/`: it is a shared directory synced by `bot-sync-shared-makefile.yaml`.
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- Run the unit tests of `scripts/validate-json.py` with `make test` (standard library only). The
  action itself can only be exercised in GitHub Actions (`ci-action.yaml`). Say so in the PR
  instead of claiming it passes.

## Git workflow

- One branch and one PR per logical change, branched from an up-to-date `main`. Never commit or
  push to `main`.
- Name branches `<type>/<short-description>` in kebab-case, with type one of: `feat`, `bugfix`,
  `hotfix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`.
- Write commit messages and PR titles as a short imperative sentence starting with a verb such as
  `Add`, `Fix`, `Update`, `Remove` or `Improve`. Do not use conventional-commit prefixes like
  `docs:` or `feat:` (the type prefix is only for branch names). The squash-merge appends the PR
  number, so do not add one.
- PR descriptions cover what changed, what was deliberately left alone, and any behaviour change.
- Do not escape special characters such as the backtick (`` ` ``) in PR titles and descriptions
  (no `\``): the escape characters are not rendered well. Write them as plain Markdown.
- On conflicts with `main`, merge `origin/main` into the branch; do not rebase and force-push.
- Update `README.md` when inputs, outputs, behaviour, or workflows change.
- Releases are immutable exact version tags (`v0.1`, ...). Do not create or move floating tags
  (`v1`, `latest`) and do not document them as an option. After a release, update the SHA pinned
  in `ci-action.yaml` (the only place it lives).

## Action rules (`action.yaml`)

- Keep input/output names, defaults, and descriptions consistent with `README.md`. Renaming or
  removing an input or output (`file-path`, `fail-on-error`, `json-content`,
  `is-valid-json`) is a breaking change and must be flagged.
- Only ship what the action needs at runtime: files the action itself uses (`action.yaml`,
  `LICENSE`, the scripts it calls) are exported, and `.gitattributes` marks everything else
  `export-ignore`. When the action starts using a new file, un-ignore it there. Never make the
  action read tests, fixtures or other repo files that are not exported. Check the exported set
  with `make check-export` (`dev/check_export.sh`, which runs
  `git archive --worktree-attributes HEAD | tar t`). When the exported set changes, update the
  expected list in that script.
- Pass inputs to scripts through `env:`, never by interpolating them in `run:`.
- Never interpolate file content into `run:` or workflow expressions; read it from disk.
- Never print file content to the log.
- Every `run:` step sets `shell: bash` and starts with `set -euo pipefail`.
- Only the `inputs` and `result` steps may `exit 1`. `fail-on-error` is read in `result` only.
  The other steps report a `problem` output.
- `json-content` is set if and only if `is-valid-json` is `true`.
- Pin third-party actions in workflows to commit SHAs with a `# ratchet:<owner>/<repo>@<tag>`
  comment, never to tags or branches.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.

## Shell rules (`action.yaml`, `scripts/test-helper.sh`)

- Keep code portable between GNU and BSD tools (`sed`, `stat`, `date`, etc.).
- Quote all variables; validate inputs early.
- Report problems with clear `::error::` / `::warning::` messages.
- Code must pass `shellcheck` and `shfmt` via `make lint` / `make format`.
- A helper that can fail ends with an explicit `return 1` on failure (as in
  `scripts/test-helper.sh`). Never rely on `set -e`: a caller in an `||` list turns it off.

## Workflow structure (`.github/workflows/`)

Files are prefixed by role:

- `ci.yaml`: entry point for pull requests, pushes to `main`, a nightly schedule and manual runs.
  It holds no steps, only jobs that call the reusable workflows below.
  - `ci-format.yaml`: formatting (`make format` leaves no change) and lint (`make lint`) checks.
  - `ci-python.yaml`: unit tests of `scripts/validate-json.py` (`make test`) on the OS matrix and the
    standard Python versions.
  - `ci-export.yaml`: checks the exported set (`make check-export`, `dev/check_export.sh`).
  - `ci-action.yaml`: runs every case of `test-data/cases.json` with the action from this checkout
    (`uses: ./`), i.e. the version not released yet. With `use-released: true` it runs the released
    action (pinned by SHA) on the same cases.
- `ci-verify-workflows.yaml`: lints the workflow files themselves. It has its own triggers and is
  not called from `ci.yaml`, so it can be a required check.
- `nightly.yaml`: scheduled entry point that calls `ci-action.yaml` with `use-released: true`, which
  tests the latest released action. It is not part of `ci.yaml`.
- `lib-get-test-matrix.yaml`: reusable workflow that loads the shared OS and Python matrices from
  `durandtibo/workflow-config-action` once; callers pass it down through the `test-matrix` input.
  It exposes `os_matrix`, `os_macos`, `os_latest`, `python_versions` and
  `python_versions_standard`.
- `bot-*.yaml`: scheduled automation that opens PRs or acts on runs (format files, pin actions,
  sync `.make/`, cancel stale queued runs).
- `security-*.yaml`: dependency review and OSSF Scorecard.

Conventions:

- Set `permissions` on every job (including jobs that call a reusable workflow). Every workflow
  has `permissions: {}` at the workflow level (it grants nothing), never a grant.
- Each reusable workflow uses `workflow_call` plus `workflow_dispatch`, so it can be run alone.
  Add a new check as a new `ci-<name>.yaml` plus a job in `ci.yaml`.
- Put `make` targets in the steps rather than duplicating commands, so local runs and CI match.
- Start each file with a comment saying what it does, and update it when the behaviour changes.

## Tests

- Tests are workflow jobs that run the action on fixtures in `test-data/` and check results with
  `scripts/test-helper.sh`. To add a test, add a fixture to `test-data/` and a case to
  `test-data/cases.json`; do not edit the workflows. `test-helper.sh` holds no fixture knowledge.
- Add a fixture to `test-data/` for each new case; cover success, failure, and edge cases (empty
  file, missing file, directory, invalid JSON, special characters, injection attempts). Fixtures that
  cannot be committed (over-size, unreadable) are created by `scripts/setup-fixtures.sh`.
- The syntax rules of `scripts/validate-json.py` are tested alone in `tests/test_validate_json.py`
  (`make test`, no network, no GitHub, standard library only), one behaviour per test. The README
  against `action.yaml` is checked by `tests/test_readme_sync.py`.
- Pass outputs to verification scripts through `env:`, never interpolated into the script.
- Every bug fix needs a regression test that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.

## Testing strategy

The strategy is the same for all the action repositories of `durandtibo`. The full reasoning and
the properties (T1 to T16) are in the `review/testing.md` of `cancel-queued-runs-action`. This
repository follows it: the action cases are the rows of `test-data/cases.json`, read by
`ci-action.yaml`, and checked by `scripts/test-helper.sh`.

Three levels:

1. **Code**: `scripts/validate-json.py` tested alone (`tests/`, `ci-python.yaml`). It covers the
   syntax rules and their edge cases. The five bash steps of `action.yaml` are inline, so they are
   tested only through level 2.
2. **Local action**: the action from this checkout (`uses: ./`) in a real workflow.
3. **Released action**: the latest stable release (`uses: durandtibo/read-json-action@<sha>`), run
   nightly with the same cases as level 2. Never run it on pull requests.

Rules:

- Test a behaviour at the cheapest level that can show it. The action tests (levels 2 and 3) check
  the contract and the wiring: inputs reach the steps, outputs are set, the action fails on an
  invalid input. Do not re-test the JSON syntax rules there; add them to level 1.
- Split the action tests in two, with the row fields of `cases.json`. **General behaviour**
  (`"general": true`: the default usage and the main documented usage, valid and invalid file) runs
  on the full matrix: `os_matrix`. **Edge cases** (all other rows) run on one runner
  (`ubuntu-latest`), or on `os_latest` (`"os-sensitive": true`) when the case depends on the OS
  (file system, encoding, locale, paths). There is no Python dimension: the action only needs the
  `python3` of the runner, and level 1 runs on `os_matrix` x `python_versions_standard`. There is
  no reduced matrix on pull requests: the same matrix runs on pull requests, pushes and the schedule.
- Supported equals tested: GNU/Linux and BSD/macOS runners. Windows is not supported, so it is not
  in any matrix.
- Never write an OS or a Python version in a workflow: read the lists from
  `durandtibo/workflow-config-action` through `lib-get-test-matrix.yaml`.
- Layout: one reusable `ci-action.yaml` with a boolean input `use-released`. `ci.yaml` calls it
  with `false`, `nightly.yaml` with `true`. Each job has two action steps, `uses: ./` with
  `if: ${{ !inputs.use-released }}` and the pinned release with `if: ${{ inputs.use-released }}`,
  and one verify step reading `steps.local.outputs.x || steps.released.outputs.x`.
- Put the cases in `test-data/cases.json` (a new case is a row, not a job). A row gets
  `"released": false` when the last release does not have the feature it tests; the released run
  must then skip it (add that filter when the first such row appears).
- The action tests use the real runner and the real tools, with no side effect outside the runner:
  throwaway files only. If something cannot be tested in CI, write down which check covers it.
- Every validated input has a case with an invalid value that asserts the action failed in the
  validation. Assert the value or the format of outputs, never just print them.
- Failure paths use `continue-on-error: true`, an `id`, and a step that asserts `steps.<id>.outcome`.
  Assert the outcome and the outputs (`is-valid-json`, empty `json-content`), not a log message.
  A negative case needs a positive run on the same runner before it, so it cannot pass for the
  wrong reason.
- Check what is shipped: the exported set (`make check-export`) must contain every file the action
  needs, because `uses: ./` runs the whole checkout and hides a missing file.
- Bound the cost: set `timeout-minutes`, `fail-fast: false` and `max-parallel` on matrix jobs. The
  general rows cross `os_matrix`; every other row is one cell, so a new edge case costs one job.
- Put assertions shared by the local and released runs in one script (`scripts/test-helper.sh`),
  not in two workflows.
- Keep the README inputs and outputs in step with `action.yaml`; `tests/test_readme_sync.py`
  (`make test`) compares the names and the default.

## Reporting

- State which checks ran (`make lint`, `make format`, `make test`, `make check-export`) and which
  did not.
- Note that CI was not awaited and that the action was not run locally.
- Report failures that already exist on `main` rather than hiding them.
