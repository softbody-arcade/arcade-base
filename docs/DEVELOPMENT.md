# Developing Arcade Base

Setting up a machine and running the checks. How to contribute is in [CONTRIBUTING.md](../CONTRIBUTING.md); the full rules for people and coding agents are in [AGENTS.md](../AGENTS.md).

## Prerequisites

The same as for Cops and Robbers, since the game code moving here needs them:

- `lua5.3`, `luajit` and `python3` for tests and Lua checks
- Node 22 with npm for UI checks
- `zip`, `unzip`, `rsync`, `gzip`, `sha256sum` (GNU coreutils) and GNU tar for packaging
- `git` 2.41 or newer (the privacy check uses `--attr-source`)
- `ssh-keygen` for SSH commit signing
- Bash 4.4+, `jq` and `gh` 2.106+ for `scripts/board` and its tests

Run `make doctor` to check these prerequisites and your contributor setup.

## Checks

- `make test` runs the tests of the privacy check, the board script and the doctor.
- `make privacy` scans the tree for personal data and private server details.
- `make hooks` turns on the pre-push privacy check (once per clone, from a checkout of `develop` you trust).

The `docs/` folder is also an [Obsidian](https://obsidian.md) vault: open `docs/` with **Open folder as vault**. The shared `docs/.obsidian/app.json` keeps links in the plain Markdown format GitHub shows. Workspace layout, themes and plugins stay local.
