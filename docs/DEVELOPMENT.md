# Developing Arcade Base

Setting up a machine and running the checks. How to contribute is in [CONTRIBUTING.md](../CONTRIBUTING.md); the full rules for people and coding agents are in [AGENTS.md](../AGENTS.md).

## Prerequisites

Needed to contribute today (`make test`, the hooks and the board script):

- `python3` for the privacy check and its tests
- `git` 2.41 or newer (the privacy check uses `--attr-source`)
- `ssh-keygen` for SSH commit signing
- Bash 4.4+, `jq` and `gh` 2.106+ for `scripts/board` and its tests

Needed once game code moves here from Cops and Robbers (not used by any check yet):

- `lua5.3` and `luajit` for tests and Lua checks
- Node 22 with npm for UI checks
- `zip`, `unzip`, `rsync`, `gzip`, `sha256sum` (GNU coreutils) and GNU tar for packaging

`make doctor` checks both groups and your contributor setup, so until you install the second group it reports those tools as missing. Everything in the first group must pass.

## Checks

- `make test` runs the tests of the privacy check, the board script and the doctor.
- `make privacy` scans the tree for personal data and private server details.
- `make version V=x.y.z` starts a release (see below).
- `make hooks` turns on the pre-push privacy check (once per clone, from a checkout of `develop` you trust).

The `docs/` folder is also an [Obsidian](https://obsidian.md) vault: open `docs/` with **Open folder as vault**. The shared `docs/.obsidian/app.json` keeps links in the plain Markdown format GitHub shows. Workspace layout, themes and plugins stay local.

## Releases

The version lives in `VERSION`. Feature branches never change it. To release, run `make version V=x.y.z`: it builds the version commit on top of `origin/develop` (not your local branch), pushes it as `release/x.y.z` and opens the **Release x.y.z** PR into `main`, without touching your checkout. Merging that PR publishes the release, and the release workflow then opens a PR that merges `main` back into `develop`. For a hotfix, `make version V=x.y.z FROM=main` starts the release branch from `main` instead. A release is the tag and a GitHub Release with generated notes; it has no assets until the base ships a mod.
