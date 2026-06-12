# Contributing to jira-cli

Thank you for contributing.

## Development setup

```bash
git clone git@github.com:caherrera/jira-cli.sh.git
cd jira-cli.sh
export PATH="$PWD/bin:$PATH"
make deps   # shellunittest test framework only
```

You need external **helpers.sh** (e.g. symlink `vendor/helpers.sh` to [shell-helpers](https://github.com/kero-sh/shell-helpers) or set `HELPER_SCRIPT`).

### Dependencies

- **[shell-helpers](https://github.com/kero-sh/shell-helpers)** — external `helpers.sh`; not part of this repo. Local dev: symlink under `vendor/` or set `HELPER_SCRIPT`.
- **[shellunittest](https://github.com/caherrera/shellunittest)** — test framework under `.deps/shellunittest` (fetched by `make deps`).

## Checks before opening a PR

```bash
make check-scripts
bash test/test_help.sh
bash test/test_version_check.sh
make test-unit
```

## Code style

- Shell scripts: English identifiers, comments, and user-facing CLI messages.
- Run `shellcheck` on changed scripts.
- Keep changes focused; match existing patterns in `src/jira.sh` and `lib/`.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.) so release notes can be generated with git-cliff.

## Reporting issues

Include your OS, `jira --version`, and a minimal command that reproduces the problem (redact secrets).
