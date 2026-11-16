# CLAUDE.md

Guidance for coding agents working in this repository.

## Repository purpose

A GitHub composite action (`action.yaml`) that reads a JSON file from the repository, validates
its syntax with Python's `json` module, and exposes `json-content`, `file-exists` and
`is-valid-json` outputs. It must work on GNU/Linux and BSD/macOS runners. The logic lives in
bash steps inside `action.yaml`. `scripts/test-helper.sh` provides assertion helpers used by the
test workflows, and `test-data/` holds the JSON fixtures (valid, empty, special characters,
injection attempts) those workflows read.

## Environment

- Use the `Makefile`; run `make help` to list targets.
- Do not edit `.make/`: it is a shared directory synced by `bot-sync-shared-makefile.yaml`.
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- The action itself can only be exercised in GitHub Actions (`ci-action.yaml`). Say so in the PR
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
- On conflicts with `main`, merge `origin/main` into the branch; do not rebase and force-push.
- Update `README.md` when inputs, outputs, behaviour, or workflows change.
- Releases are immutable exact version tags (`v0.1`, ...). Do not create or move floating tags
  (`v1`, `latest`) and do not document them as an option. After a release, update the SHA pinned
  in `ci-action.yaml` (the only place it lives).

## Action rules (`action.yaml`)

- Keep input/output names, defaults, and descriptions consistent with `README.md`. Renaming or
  removing an input or output (`file-path`, `fail-on-invalid-json`, `json-content`,
  `file-exists`, `is-valid-json`) is a breaking change and must be flagged.
- Pass inputs to scripts through `env:`, never by interpolating them in `run:`.
- Never interpolate file content into `run:` or workflow expressions; read it from disk.
- Never print file content to the log.
- Every `run:` step sets `shell: bash` and starts with `set -euo pipefail`.
- Pin third-party actions in workflows to commit SHAs with a `# ratchet:<owner>/<repo>@<tag>`
  comment, never to tags or branches.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.

## Shell rules (`action.yaml`, `scripts/test-helper.sh`)

- Keep code portable between GNU and BSD tools (`sed`, `stat`, `date`, etc.).
- Quote all variables; validate inputs early.
- Report problems with clear `::error::` / `::warning::` messages.
- Code must pass `shellcheck` and `shfmt` via `make lint` / `make format`.

## Workflow structure (`.github/workflows/`)

Files are prefixed by role:

- `ci.yaml`: entry point for pull requests, pushes to `main`, a nightly schedule and manual runs.
  It holds no steps, only jobs that call the reusable workflows below.
  - `ci-format.yaml`: Markdown, shell and YAML lint checks (via `make`).
  - `ci-action.yaml`: runs every case of `test-data/cases.json` on the OS matrix, with the action
    from this checkout (`uses: ./`), i.e. the version not released yet. With `use-released: true`
    it runs the released action (pinned by SHA) on the same cases.
- `ci-verify-workflows.yaml`: lints the workflow files themselves. It has its own triggers and is
  not called from `ci.yaml`, so it can be a required check.
- `nightly.yaml`: scheduled entry point that calls `ci-action.yaml` with `use-released: true`, which
  tests the latest released action. It is not part of `ci.yaml`.
- `lib-get-test-matrix.yaml`: reusable workflow that loads the shared OS matrix from
  `durandtibo/workflow-config-action` once; callers pass it down through the `test-matrix` input.
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
  file, missing file, directory, invalid JSON, special characters, injection attempts).
- Pass outputs to verification scripts through `env:`, never interpolated into the script.
- Every bug fix needs a regression test that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.

## Reporting

- State which checks ran (`make lint`, `make format`) and which did not.
- Note that CI was not awaited and that the action was not run locally.
- Report failures that already exist on `main` rather than hiding them.
