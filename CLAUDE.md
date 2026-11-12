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
- Do not edit `.make/`: it is a shared directory synced from a shared Makefile repository.
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- The action itself can only be exercised in GitHub Actions (`test-local.yaml`). Say so in the PR
  instead of claiming it passes.

## Git workflow

- One branch and one PR per logical change, branched from an up-to-date `main`. Never commit or
  push to `main`.
- Name branches `<type>/<short-description>` in kebab-case, with type one of: `feat`, `bugfix`,
  `hotfix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`.
- PR descriptions cover what changed, what was deliberately left alone, and any behaviour change.
- On conflicts with `main`, merge `origin/main` into the branch; do not rebase and force-push.
- Update `README.md` when inputs, outputs, behaviour, or workflows change.

## Action rules (`action.yaml`)

- Keep input/output names, defaults, and descriptions consistent with `README.md`. Renaming or
  removing an input or output is a breaking change and must be flagged.
- Pass inputs to scripts through `env:`, never by interpolating them in `run:`.
- Never interpolate file content into `run:` or workflow expressions; read it from disk.
- Every `run:` step sets `shell: bash` and starts with `set -euo pipefail`.
- Keep shell code portable between GNU and BSD tools; quote all variables.
- Report problems with clear `::error::` / `::warning::` messages.
- Pin third-party actions in workflows to commit SHAs with a `# ratchet:<owner>/<repo>@<tag>`
  comment, never to tags or branches.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.

## Workflow structure (`.github/workflows/`)

- `ci.yaml`: entry point for pull requests, pushes to `main` and a nightly schedule. It holds no
  steps, only jobs that call the reusable workflows below.
  - `lib-get-test-matrix.yaml`: loads the OS matrix from `durandtibo/workflow-config-action`.
  - `ci-format.yaml`: Markdown, shell and YAML lint checks (via `make`).
  - `ci-action.yaml`: runs the action from this checkout (`uses: ./`), i.e. the version not
    released yet.
- `nightly.yaml`: scheduled entry point that calls `nightly-test-released.yaml`, which tests the
  latest released action (pinned by SHA; update it on release).
- `ci-verify-workflows.yaml`: lints the workflow files themselves, with its own triggers.
- `bot-cancel-stale-queued-runs.yaml`: scheduled automation that cancels stale queued runs.
- `security-dependency-review.yaml`: dependency review on pull requests.

Conventions:

- Set `permissions` on every workflow and job; grant only what is needed.
- Reusable workflows use `workflow_call` plus `workflow_dispatch`, so they can be run alone.
- Put `make` targets in the steps rather than duplicating commands, so local runs and CI match.
- Start each file with a comment saying what it does, and update it when the behaviour changes.

## Tests

- Tests are workflow jobs that run the action on fixtures in `test-data/` and check results with
  `scripts/test-helper.sh`.
- Add a fixture to `test-data/` for each new case; cover success, failure, and edge cases (empty
  file, missing file, invalid JSON, special characters, injection attempts).
- Every bug fix needs a regression test that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.

## Reporting

- State which checks ran (`make lint`, `make format`) and which did not.
- Note that CI was not awaited.
- Report failures that already exist on `main` rather than hiding them.
