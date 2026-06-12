# Changelog

## [0.1.0] - 2025-06-12

### Features

- Consolidated CLI: `jira issue link`, `jira issue pending`, `jira issue --resume|--fields|--full`
- Extended `jira create` with JSON file, issue key update, and interactive mode
- `jira --version`, `jira self-update`, and passive update notifications
- Install scripts (`scripts/install.sh`, `scripts/install-core.sh`) and Makefile targets
- CI matrix (Debian, Rocky, Alpine), shellcheck, unit tests, and kcov coverage
- Release workflow with git-cliff and tarball artifacts
- Deprecation shims for legacy `bin/*` and `src/*` entry points

### Bug Fixes

- Fixed broken issue link payload in legacy `jira-issue-link.sh` (now `jira issue link`)

## [Unreleased]

See git history and [CONTRIBUTING.md](CONTRIBUTING.md).
