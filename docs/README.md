# Softbody Arcade documentation

The starting point for every Softbody Arcade repo. Each repo keeps its own docs next to its code; what spans games lives here.

## Shared

- [Agent rules](../AGENTS.md): the rules every repo follows, for people and coding agents
- [Roles](ROLES.md): who can do what in the repos and on the board
- [Decisions across games](#decisions-across-games): below, each linked to its record
- [Board](https://github.com/orgs/softbody-arcade/projects/1): all work in every repo, and the game ideas

## Arcade Base (this repo)

- [Development](DEVELOPMENT.md): prerequisites, checks and releases
- [Specs](superpowers/specs/) and [plans](superpowers/plans/) for each feature

Outside this folder: [README](../README.md), [Contributing](../CONTRIBUTING.md) and [Security](../SECURITY.md).

## Games

| Game | Docs | Specs | Plans |
|---|---|---|---|
| [Cops and Robbers](https://github.com/softbody-arcade/cops-and-robbers) | [Index](https://github.com/softbody-arcade/cops-and-robbers/blob/develop/docs/README.md) | [Specs](https://github.com/softbody-arcade/cops-and-robbers/tree/develop/docs/superpowers/specs) | [Plans](https://github.com/softbody-arcade/cops-and-robbers/tree/develop/docs/superpowers/plans) |

Game ideas that don't have a repo yet are draft items in the board's **Game ideas** view.

## Decisions across games

Decisions that apply to more than one repo. Each record lives on its ticket, with the options considered and the reason; a row only says what was decided and links to it. Decisions about one game stay on that game's tickets.

| Decision | Record |
|---|---|
| A shared library, arcade-base, in its own repo; each game depends on it, and Cops and Robbers moves onto it first | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| The base's first version holds everything Cops and Robbers already has; it grows as new games or modes need more | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| All games run on one server, one at a time; any player switches the game in the settings app between rounds, without a restart | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| A server installs the base plus one mod per game | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Versions: minor base releases never break a game; each game declares the base range it needs, and the server leaves out games whose range isn't met | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| A game's CI tests against the oldest base version it declares and the newest base release | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Repo tooling lives in arcade-base; games pin its shared Actions to a release commit, bumped by Dependabot | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| arcade-base copies Cops and Robbers' repo settings, team access and rulesets, requires `test` and `privacy` at bootstrap, and has its own board view | [arcade-base#1 comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7224836681) |
| Documentation: shared rules, roles and cross-game decisions in arcade-base; each game's docs next to its code; arcade-base's `docs/README.md` as the starting point | [arcade-base#1 comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7225133314) |
| Games load the shared rules through a `base/` submodule pinned to a base release | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225308653) |
| Games pin only to base releases (0.1.0 first); every PR CI job is a required check; the submodule is reviewed as code | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225525423) |
| Relative-link checking uses an existing link checker in CI ([#11](https://github.com/softbody-arcade/arcade-base/issues/11)) | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225650992) |
| Board bot: one org GitHub App for release tags and issue triage, parked in arcade-base | [cops-and-robbers#42 comment](https://github.com/softbody-arcade/cops-and-robbers/issues/42#issuecomment-7223984437), [cops-and-robbers#47 comment](https://github.com/softbody-arcade/cops-and-robbers/issues/47#issuecomment-7224677373) |
