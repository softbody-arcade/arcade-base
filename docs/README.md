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
| A shared library, arcade-base, in its own repo; each game depends on it, and Cops and Robbers is the first game on it | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| The base's first version holds everything Cops and Robbers already has that other games need; it grows as new games or modes need more | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| All games run on one server, one at a time; any player switches the game in the settings app between rounds, without a restart | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| A server installs the base plus one mod per game | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Versions: the base stays at 0.x with exact pins while one game uses it; from 1.0 (once a second game runs on it) minor releases never break a game; each game declares the base it needs, and the server leaves out games that don't match | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided), [stability comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226571692) |
| A game's CI tests against the oldest base version it declares and the newest base release | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Players never manage versions: BeamMP sends the server's client mods on join, and the outdated-client-mod warning moves into the base for every game | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Repo tooling lives in arcade-base; games pin its shared Actions to a release commit, bumped by Dependabot | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| The base runs the session (lobby, ready-up, spectating, settings, switching, leaderboard store, cleanup); games are plugins that provide their rules and content | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226405615) |
| Order: Cops and Robbers first splits its manager half from its game half in its own repo, in playtestable 2.x releases; moving the manager half into the base follows, and Cops and Robbers 3.0.0 is the switch | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226544100) |
| Switching: any player switches game in the settings app between rounds, no vote; ready states reset, a pending next round is cancelled, everyone is told; the last-played game is active at server start | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226602884) |
| Series: switching is blocked while a game's series runs; players can end it early with the standings so far | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226602884) |
| Settings: global settings with per-game overrides; a setting only one game has stays that game's | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226663808) |
| Apps: the manager defines the set of apps; games provide content for them and can't ship apps | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226663808) |
| Player settings: colour and preferences are shared across games; the card has a global section and one per game | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226451387) |
| Car changes: the base has the tools (apply a change, rebuild, report missing parts); a game's mode built on them, such as Cops and Robbers' evolving mode, stays that game's | [comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7226695779) |
| arcade-base copies Cops and Robbers' repo settings, team access and rulesets, requires `test` and `privacy` at bootstrap, and has its own board view | [arcade-base#1 comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7224836681) |
| Documentation: shared rules, roles and cross-game decisions in arcade-base; each game's docs next to its code; arcade-base's `docs/README.md` as the starting point | [arcade-base#1 comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7225133314) |
| Games load the shared rules through a `base/` submodule pinned to a base release; a game moves the submodule and its pinned shared Actions in one PR, and its CI checks both are on the same base version | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225308653) |
| Games pin only to base releases; the base released 0.1.0 before any game added the submodule | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225525423) |
| Every CI job a repo runs on pull requests is a required check, by its exact name | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225525423) |
| A change to `.gitmodules` or the `base` pin is reviewed as code, and `base/` scripts run only from a trusted `develop` at its pin | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225525423) |
| Relative-link checking will use an existing link checker in CI, not a hand-written one (planned in [#11](https://github.com/softbody-arcade/arcade-base/issues/11)) | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225650992) |
| Board bot: one org GitHub App for release tags and issue triage, parked in arcade-base | [cops-and-robbers#42 comment](https://github.com/softbody-arcade/cops-and-robbers/issues/42#issuecomment-7223984437), [cops-and-robbers#47 comment](https://github.com/softbody-arcade/cops-and-robbers/issues/47#issuecomment-7224677373) |
| Board bot triage: issues from the repo owner, org members and collaborators are triaged when opened; anyone else's wait until a team member adds the `triage` label | [cops-and-robbers#47 comment](https://github.com/softbody-arcade/cops-and-robbers/issues/47#issuecomment-7224210725) |
| Board bot triage runs as a GitHub Action: the model only returns type, priority, effort and a reason, gets no shell or token, and a script checks each value before writing with the board bot's token | [cops-and-robbers#47](https://github.com/softbody-arcade/cops-and-robbers/issues/47) (issue description) |
