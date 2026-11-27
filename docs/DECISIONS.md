# Decisions across games

An index of decisions that apply to more than one repo. Each record lives on its ticket, with the options considered and the reason; this page only points to it. Decisions about one game stay on that game's tickets.

| Decision | Record |
|---|---|
| A shared library, arcade-base, in its own repo; each game depends on it, and Cops and Robbers moves onto it first | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| All games run on one server, one at a time; any player switches the game in the settings app between rounds, without a restart | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| A server installs the base plus one mod per game | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Versions: minor base releases never break a game; each game declares the base range it needs and the server leaves out games whose range isn't met | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Repo tooling lives in arcade-base; games pin its shared Actions to a release commit, bumped by Dependabot | [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1) (Decided) |
| Setting up arcade-base: settings, rulesets, required checks, board view | [arcade-base#1 comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7224836681) |
| Documentation: shared rules, roles and cross-game decisions in arcade-base; each game's docs next to its code; this index as the starting point | [arcade-base#1 comment](https://github.com/softbody-arcade/arcade-base/issues/1#issuecomment-7225133314) |
| Games load the shared rules through a `base/` submodule pinned to a base release | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225308653) |
| Games pin only to base releases (0.1.0 first); every PR CI job is a required check; the submodule is reviewed as code | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225525423) |
| Relative-link checking uses an existing link checker in CI ([#11](https://github.com/softbody-arcade/arcade-base/issues/11)) | [arcade-base#6 comment](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225650992) |
| Board bot: one org GitHub App for release tags and issue triage, parked in arcade-base | [cops-and-robbers#42](https://github.com/softbody-arcade/cops-and-robbers/issues/42#issuecomment-7223984437), [cops-and-robbers#47](https://github.com/softbody-arcade/cops-and-robbers/issues/47) |

When a decision changes, the new record goes on its ticket and this row is updated in the same PR.
