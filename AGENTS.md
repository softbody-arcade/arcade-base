# Softbody Arcade: agent rules

This file is the rule set shared by every Softbody Arcade repo, for every contributor and every coding agent, whatever the provider. The rules never require a harness-specific tool. "The maintainer" means the repo owner, ReinderN. "This repo" means the repo you are working in.

The repos live in the `softbody-arcade` organization for BeamNG multiplayer minigames. [arcade-base](https://github.com/softbody-arcade/arcade-base) holds the shared library the games run on, the repo tooling they share and this file. A game repo loads this file from its `base/` submodule (see **Game repos**) and adds its own rules in its own `AGENTS.md`. A repo's own rules may add to these or narrow them, never contradict them. The section **Only in arcade-base** at the end applies only when working in arcade-base itself.

## Tickets are the ledger

GitHub Issues and the organization board **Softbody Arcade** (project 1) record all work: ideas, bugs, in-game checks, and what is in progress. An issue is the single place that says what happened to a piece of work and why. Use what GitHub provides natively; never mirror the same fact twice.

- **Type** (the org's issue types): `Feature` for ideas and new functionality, `Bug`, `Task` for maintenance and tooling, `In-game check` for something to verify in game. Every issue outside Inbox has a type, a priority and an effort.
- **Priority** (the org's issue field): `Urgent`, `High`, `Medium` or `Low`. Rank by player impact, then host or panel problems, then cosmetics, then maintainer-only work. Every issue outside Inbox has one.
- **Effort** (the org's issue field): `High`, `Medium` or `Low`, a rough size set at triage and refined in Design. Together with Priority it ranks the work: the board's **Quick wins** view lists open Urgent or High issues with Low effort, which are good picks for Next and for contributors.
- **Milestone**: the release version an issue is targeted at, named `x.y.z`. The maintainer assigns it when committing to a release. A release ships when its milestone's issues are closed or moved on. In a repo with a release workflow, `release.yml` closes the milestone; otherwise the maintainer closes it.
- **Parent and sub-issues** give the structure: a large feature is a parent with its parts as sub-issues, and the issues folded into a fix batch become sub-issues of the batch's ticket. Progress rolls up on the parent.
- **Blocked by / blocking** (issue dependencies) records order: `scripts/board block <n> --by <m>`. Never use a label or prose for it. A blocker in another repo is set through the issue-dependencies API (`gh api -X POST repos/<repo>/issues/<n>/dependencies/blocked_by -F issue_id=<id of the blocking issue>`), because the board script only resolves issues in its own repo.
- **Labels** (the workflow labels; Dependabot adds its own) remain only where nothing native exists: `needs-decision` while an issue waits on the maintainer, `needs-playtest` on a PR whose change a player would see, hear or feel, and `good first issue` / `help wanted` for contributors, and `accessibility` for barriers affecting players with disabilities. Close duplicates and dropped work with GitHub's "duplicate" and "not planned" close reasons.
- **Development.** Branches and PRs are linked through the issue's native Development section: create the branch with `gh issue develop <n> --name feature/<topic> --base develop` (or `fixes/<topic>`), and the PR body says `Fixes #n`.
- **Links.** A `## Links` section in each ticket lists only what GitHub cannot link natively: its spec, plan and decision records in the repo, and outside references. Related issues use parent/sub-issues and blocked-by. Whoever writes a spec or plan links it the same day.
- **Decisions.** Every maintainer decision becomes a comment on the ticket: `**Decision (YYYY-MM-DD):**` followed by what was decided, the options and the reason (`scripts/board decide`). An agent posts a decision made in a chat before its turn ends, written for a public repo: only what was decided and why, never private details from the conversation. When unsure whether something may be published, the agent asks first. Nothing is decided only in chat.
- **Events.** Playtest results, deferred review findings (as links to new issues), deploys and scope changes also go on the ticket.
- **Findings.** A finding about a branch's own unmerged code goes in its PR and is fixed or filed before merge. Anything else found in passing becomes a new issue right away, including deferred review findings, with the affected file and the observable problem. Security problems are the exception: never file them in a public issue or PR, report them as the repo's `SECURITY.md` says.
- **Claiming.** A PR lists every issue it handles as `Fixes #n`.

### Lanes

| Lane | Holds | Leaves when |
|---|---|---|
| Inbox | New, untriaged issues | `board triage <n> <type> <priority> [effort]` sets type, priority and effort, moving it to Backlog. In any later lane except Done, the same command corrects the fields without moving the card |
| Backlog | Triaged; a simple ticket is fine | The maintainer picks it for Next |
| Next | At most 5 (`board check` warns above that), top first, each meeting the definition of ready | `board start <n> design\|build` |
| Design | Brainstorm, spec and plan | The maintainer approves the plan, then `board move <n> build` |
| Build | Branch, worktree, draft PR; per-task implement and review | The PR is ready: `board move <n> review`, or `board move <n> playtest --staged <sha>` when a player check comes first |
| Review | Whole-branch review, fixes, CI | With `needs-playtest`: `board move <n> playtest --staged <sha>`. Without it, the PR merges. Rework goes back with `board move <n> build` |
| Playtest | Waiting on the maintainer's in-game result, plus `In-game check` issues (moved in from Inbox, Backlog or Next with `board move <n> playtest`; from Inbox, set `board priority <n> ...` first) | `board result <n> ...` (below). After a new push, re-stage with `board move <n> playtest --staged <sha>`; for rework, `board move <n> build`. To postpone an `In-game check`, `board move <n> backlog` |
| Accepted | Merged work waiting for a release, and closed tickets not yet tidied. Cards arrive when their issue closes (the board does this; a staged PR that passed its playtest arrives when it merges), or when a playtester accepts merged work they tested on `develop` | `board release` (after each release, or any time) moves released work, not-planned and duplicate closes, closed checks and no-code tickets to Done. For rework, reopen the issue: the board returns the card to Inbox, and it goes through triage, Next and `board start` again like other work. If the issue is already open, `board move <n> inbox` puts it back for triage |
| Done | Released work; closed as not planned or duplicate; closed checks; no-code tickets. Only `board release` moves cards here, never `board move` | `board release` archives closed cards unchanged for 14 days |

**Definition of ready for Next.** The ticket body has these sections: `## Goal`, `## Why`, `## Scope`, `## Done when`, `## Constraints and known facts`, `## Open questions`, `## Links`. The **Ready ticket** issue template provides them, and `board move <n> next` refuses without them.

**Playtest results.**
- On a work card: `board result <n> pass`, `board result <n> fail`, or `board result <n> defer --checks-file F`, where F holds one check per line, each starting with its priority (`Urgent:`, `High:`, `Medium:` or `Low:`). `defer` files one `In-game check` issue with those checks as tasks; its Priority is the highest priority among the checks. Results are bound to the staged SHA.
- On an `In-game check` issue: `pass` or `fail` only. Both close it; `fail` also files a `Bug` that links the check.

**Who runs board commands.** Only the maintainer, or an agent acting for the maintainer, runs the board's write commands: `new`, `triage`, `priority`, `effort`, `start`, `move`, `result`, `block`, `unblock`, `parent`, `unparent`, `milestone`, `decide`, `labels` and `release`. Run `scripts/board` only from a trusted checkout of `develop`, never from a branch or snapshot under review, because a branch's `scripts/board` is untrusted code: for the maintainer that is their own checkout of `develop` (reads and writes), for a contributor their own clone of `develop` (reads only). When a contributor takes a card, the maintainer runs `board start <n> design|build` (which assigns the maintainer) and then hands the issue over with `gh issue edit <n> --add-assignee <login> --remove-assignee @me`. Contributors file issues with the templates (`gh issue create` or the web), read the board on GitHub or with `list`, `waiting`, `show` and `check` from their own trusted checkout (scope `read:project`), and drag their own cards on the board within the moves below. `scripts/board --help` lists the commands.

**Getting issues on the board.** The board's one auto-add workflow (the Free plan allows one) covers a single repo; each repo's own rules say whether it is that repo. In the others, the maintainer adds an issue someone filed with `gh project item-add 1 --owner softbody-arcade --url <issue URL>` (or **+ Add item** on the board), until the board bot adds issues from every repo. `scripts/board new` is only for tickets the maintainer creates; it files a new issue and adds it itself.

**Who may drag cards on the board.** The board doesn't enforce this; GitHub's history shows who moved what, and the maintainer fixes mistakes.
- **Maintainers:** anything.
- **Playtesters:** on a work card whose PR is already merged and was tested on `develop`: Playtest → Accepted when it passed, Playtest → Build when it didn't, with a comment saying what they saw. On an `In-game check` issue, or a staged PR that isn't merged, they only comment their result; the maintainer records it with `board result`, which needs the card in Playtest.
- **Contributors:** their own assigned cards between Build and Review. Leaving Design stays the maintainer's call (plan approval).
- **Everyone with board Write:** new minigame ideas go on the board as **draft items** (the **Game ideas** view). A draft becomes an issue in a game's repo once that game has one. Work on an existing game or on the base starts as an issue in its repo.
- The green status badge on an issue page is GitHub's own issue status (Backlog, Done, …), not the board lane. Ignore it; the board lane is what counts.

**Agent rules the script cannot check:**
- Run a board write only for something the maintainer asked for or decided in the current session (a standing instruction such as "triage the new issues" counts for that session).
- Run `board start <n> build` or `board move <n> build` only after the maintainer approved that plan (for a fix batch without a spec: that batch) in the current session.
- Run `board result` only with a result the maintainer reported in the current session.
- An agent never drags a card out of Playtest on the board; it uses `board result`, or `board move` for re-staging, rework and postponing an `In-game check`. (People in the playtesters team may drag merged work, as above.)

## Roles

arcade-base's [docs/ROLES.md](docs/ROLES.md) explains for people what each role can do, and which rulesets GitHub enforces. The teams are organization-wide and get the same access in every repo.

| Team | Repo | Board |
|---|---|---|
| `maintainers` | Admin | Admin |
| `contributors` | Write: `feature/*` and `fixes/*` branches and PRs | Write: their own moves above, and game idea drafts |
| `playtesters` | Triage: comment and file issues | Write: their own moves above, and game idea drafts |

- **Playtesters** take `In-game check` issues and post what they saw as a comment; the maintainer records the result. They may drag merged work they tested, as above.
- **Maintainer-only:** `scripts/board` writes, triage, ordering Next, every card move other than the playtester and contributor drags above, milestones, merging, releases, staging on the local test server, the in-game probe extensions and deploys. A contributor's agent skips these and says in its PR what still needs doing.

## Game repos

- **The base as a submodule.** A game repo includes arcade-base as a Git submodule at `base/`, pinned to the commit of a base release. Clone with `git clone --recurse-submodules`, or run `git submodule update --init` in an existing clone. Dependabot proposes moving the pin, and a pin moves only through a reviewed PR. A game moves its submodule and its pinned shared Actions to a new base release in the same PR, and its CI checks that both reference the same base version. A game adds the submodule only once the base has a release to pin.
- **Loading these rules.** The game's `CLAUDE.md` is `@base/AGENTS.md` followed by `@AGENTS.md`. The game's own `AGENTS.md` starts by telling every agent to read `base/AGENTS.md` first, then holds only what is specific to that game.
- **What a game's own rules list:** its repo name and what it is, which repo the board's auto-add covers, its local checks and CI jobs, staging on the local test server, engine probes, packaging, releases and deploys, and anything that narrows these shared rules.
- **Shared tooling.** The base's scripts and GitHub Actions are meant to be used from the base: scripts from `base/scripts/`, Actions pinned to the commit of a base release with the version in a comment. A script moves to that use only once it supports being called from a game: today `base/scripts/board` reads arcade-base's own `board.conf` and would act on arcade-base, so a game runs its own `scripts/board` (its `board.conf` names the game repo). Until a game has moved onto a shared script or Action, it keeps its own copy and its rules say so.
- **Docs.** A game keeps its own specs, plans and gameplay docs in its `docs/`, next to its code. What spans games lives in arcade-base.

## Design and implementation

- **Skills.** Use the [Superpowers v7.0.2 skills](https://github.com/obra/superpowers/tree/22f0b463e7a5e579904dd6211a520321035526f7/skills) in the repo's `.agents/skills/` for feature design, planning and implementation. Claude Code reads the same files through `.claude/skills/`. An agent without skill support reads each `SKILL.md` as instructions. See the [Codex tool mapping](.agents/skills/using-superpowers/references/codex-tools.md).
- **Documentation** lives in each repo's `docs/`, which is also an Obsidian vault. The root keeps only what must be found at once: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, `AGENTS.md` and `CLAUDE.md`; they link into `docs/` for detail. Links are plain relative Markdown links, so they work on GitHub and in the vault.
- **Specs and plans.**
  - For new features, agree on the design with the maintainer.
  - Write the spec in `docs/superpowers/specs/` and the task plan in `docs/superpowers/plans/` of the repo the change belongs to, and link both from the ticket.
  - Have the spec reviewed and fix the findings, then hand the spec to the maintainer before drafting the plan, unless the maintainer asks for a combined handoff. Then the same for the plan.
  - Implementation starts once the maintainer approves the plan and authorizes the build. Subagent-driven development is the default. An agent that cannot start subagents uses `executing-plans` inline, and gets each task reviewed in a separate, fresh session.
- **Writing a feature spec.**
  - Write it for the person deciding how the game should play, or, for the base, how games use it.
  - Give a full gameplay spec explicit sections: Why, Goals, Non-goals (adjacent work outside the feature) and Anti-goals (outcomes that would spoil it even if the code worked).
  - Compare viable approaches, with concrete gameplay examples of success and failure.
  - Distinguish the maintainer's decisions, proposed tuning, choices left to the builder, automated acceptance and in-game checks.
  - Choose the other sections to answer real questions about the feature.
  - Identify engine assumptions that still need a check.
  - Examples, from Cops and Robbers:
    - The [player settings spec](https://github.com/softbody-arcade/cops-and-robbers/blob/develop/docs/superpowers/specs/2026-11-16-player-settings-design.md) separates design decisions from choices left to the builder.
    - The [road placement spec](https://github.com/softbody-arcade/cops-and-robbers/blob/develop/docs/superpowers/specs/2026-11-16-cop-spots-by-road-design.md) explains what the current code does.
    - The [Pigeon helicopter spec](https://github.com/softbody-arcade/cops-and-robbers/blob/develop/docs/superpowers/specs/2026-11-17-pigeon-helicopter-design.md) records what was proven in game.
- **Writing a plan.** Another agent must be able to execute each task from its files, input fixtures, expected observations and verification commands. Break up steps that combine several decisions or checks. The [player settings plan](https://github.com/softbody-arcade/cops-and-robbers/blob/develop/docs/superpowers/plans/2026-11-16-player-settings.md) shows the expected detail.
- **Running the work.**
  - The coordinator moves the ticket's card, tracks the plan (for longer jobs, a progress checklist the maintainer can see, such as the task list on the ticket), and dispatches a fresh implementer per task with the worktree, requirements and context. The implementer tests, commits and self-reviews.
  - A separate reviewer checks each task for requirements and code quality. Fixes go back to an implementer and are re-reviewed.
  - Before merge, a fresh reviewer examines the whole branch diff and posts the review on the PR.
- **Parallel fix batches.** While the main work is being implemented or reviewed, and no other fix batch is running, pick clear, independently testable bugs from the Backlog whose files do not overlap the main work, for a parallel fix batch on its own `fixes/<topic>` branch and PR. Issues needing a maintainer decision or an in-game check stay out of it and get `needs-decision` or a playtest.

Add source comments or emojis only when the maintainer asks for them.

## Branches, pull requests and merging

- **Branch model.**
  - `develop` is the default branch. Every ticket's PR targets it, and merged tickets wait there, so several can be staged and playtested together. The one exception is a hotfix: its fix goes through a PR into that release's `release/x.y.z` branch, so unreleased work on `develop` stays out.
  - `main` only changes through releases and always matches the latest release.
  - `release/x.y.z` carries a release from `develop` (or, for a hotfix, from `main`) into `main`. In a repo with a release workflow, `release.yml` opens a PR after that merge that brings `main` back into `develop`.
- **One branch per piece of work.**
  - Each feature or fix batch gets its own branch and worktree, named `feature/<topic>` or `fixes/<topic>`, created with `gh issue develop <n>` so the issue's Development section shows it.
  - Push at the first commit and open a draft PR with `Fixes #n`.
- **Merge gate:**
  - the maintainer's go to merge that PR, given in the current session (a go for a named set of PRs counts for each of them)
  - CI green on the PR's current head
  - the final review done on that same head SHA, with its blocking findings resolved
  - for `needs-playtest` PRs, a `board result` of pass or defer for exactly that head SHA. A later push voids the result, the review and the go.
- **Merging.** From the maintainer's main checkout (on `develop`):
  1. Remove the worktree.
  2. `gh pr merge <pr> --admin --merge --delete-branch --match-head-commit <sha>`. The **Sync main into develop** PR is the exception: its head is `main`, so merge it without `--delete-branch`.
  3. Pull `develop`.

  `develop-merge` and `main-merge` let only maintainers update those branches, so every merge into them is a maintainer bypass:
  - On the command line, `--admin` claims that bypass. It skips only those `*-merge` rulesets: `develop-checks` and `main-checks` have no bypass, so CI still has to pass.
  - In the web UI, tick "Merge without waiting for requirements to be met (bypass rules)" before merging.
- **No direct commits on `develop` or `main`.** Every change, docs and these rules included, goes through a PR. Version bumps always do.
- **Identity.** Everyone commits with their GitHub noreply address (`ID+login@users.noreply.github.com`), never a personal or work email. The privacy check rejects other personal addresses (it allows only noreply and a few GitHub service addresses). The maintainer commits as `ReinderN` and SSH-signs.

## Trusted code

Hooks, Make targets and scripts run with the credentials of whoever runs them, and `make hooks` points git at the checked-out `.githooks`. So with the maintainer's credentials:
- Run `scripts/board` and release targets only from the maintainer's checkout of `develop`, and deploy targets only from a clean checkout of `main`.
- Push only from that checkout or from a worktree of a branch the maintainer or their agent wrote.
- Never check out, build, test, run or push a contributor's branch. Agents review contributor PRs by diff only, on GitHub or with `git diff`; CI runs their code.
- Agents never stage a contributor's PR on the test server.
- **The `base/` submodule is code.** A PR that changes `.gitmodules` or any gitlink is reviewed like any other code change. Check every submodule entry together: the only one is `base`, its path is `base`, its URL is `https://github.com/softbody-arcade/arcade-base` (or its SSH form), and the gitlink points at the commit of a base release. Run `base/` scripts only from a trusted checkout of `develop` whose submodule is at the pinned commit and clean: `git submodule status` shows no `+`, `-` or `U`, and `git -C base status --porcelain` prints nothing. Never run them from a branch under review.

## Privacy

- Write commits, files and messages as if the repo were public.
- **Never include:** IP addresses, email addresses other than GitHub noreply ones, SSH login targets, URLs with credentials, absolute home paths, or anything about how or where the live server runs (type, hosting, containers, paths). Use `<repo>` for the checkout root and `~` for home. Keep machine-specific values in environment variables or git-ignored files.
- **`scripts/privacy-check`** enforces this:
  - The pre-push hook runs it on every outgoing commit. Enable it once per clone with `make hooks`, from a checkout of `develop` you trust.
  - `make privacy` scans the tree.
  - CI checks every PR commit, and the full history on `develop` and `main`.
  - Exact exceptions go in `.github/privacy-allow.txt` as `path:text`.
  - Private terms live only in the uncommitted `.git/info/privacy-deny`.
- **Never rewrite history** that has been pushed.

## Verification and release

- **Automated tests first.** If known inputs determine the expected result, verify it with an automated test: for example recorded round data for leaderboard ranking, or sampled positions and speeds for catch timing. Add a missing regression test when needed. A passing test closes that part of the check.
- **Local checks.** Each repo's own rules list its local checks (at least `make test`). Keep game-side Lua compatible with BeamNG's LuaJIT: check each changed game-side Lua file with `luajit -bl path/to/file.lua >/dev/null`.
- **CI** runs on every PR and on every push to `develop` and `main`. Every CI job a repo runs on pull requests is a required check in its `develop-checks` and `main-checks` rulesets, by its exact job name, and no required check names a job that doesn't run. Adding or renaming a job changes both rulesets in the same step.
- **Playtests.**
  - Ask the maintainer for a playtest (label the PR `needs-playtest`) only when an open question depends on what BeamNG or BeamMP actually does, or on what the player sees, hears or feels. Use an engine probe or logs first when they can answer it.
  - For each manual check, give the shortest setup and action, the observable pass condition, and the uncertainty it resolves.
  - Ask for a second player only when observing a second client is essential.
  - A deferred check becomes an `In-game check` issue in Playtest, filed by `board result <n> defer --checks-file F`.
- **Staging, engine probes and deploys** are maintainer-only. Each game's own rules give the steps. Agents never stage a contributor's PR. A base change is playtested through a game whose `base/` is at exactly the base commit under review; a playtest against the game's previous pin doesn't count for it.
- **Releases.**
  - Agents release a version, by any route (merging a release PR, pushing a tag, publishing a GitHub Release), only after the maintainer said, in the current session, to release that version. A previous release's approval applies to that release alone.
  - Before merging a release PR, check that milestone `x.y.z` has no open issues (`gh issue list --milestone x.y.z --state open`); close them or move them to another milestone.
  - Version numbers stay out of feature plans and branches.
  - The base uses x.y.z versions. A minor release adds things but never breaks a game; anything that would break one waits for the next major version.

## Only in arcade-base

This section applies only when working in arcade-base itself. Game repos skip it.

- **What this repo is.** `softbody-arcade/arcade-base` is becoming the shared library Softbody Arcade games run on, and holds the repo tooling they share: the board script, privacy check, doctor, CI and these rules. No game runs on it yet: [Cops and Robbers](https://github.com/softbody-arcade/cops-and-robbers) is the first to move onto it ([cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56)). `CLAUDE.md` here is `@AGENTS.md`.
- **Changes reach every game.** A change to these rules, the scripts or the shared Actions reaches each game when it moves its `base` pin. Say in the PR how games are affected, and keep everything above this section true for a game reading it from `base/AGENTS.md`: relative links must resolve from `base/` too.
- **Board.** The board's auto-add covers Cops and Robbers, not this repo: issues filed here are added by the maintainer (see **Getting issues on the board**).
- **Local checks.** Run `make test` for every change, and `make privacy` before pushing a branch with new files. [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) lists the prerequisites (`make doctor` checks them).
- **CI** runs `test` and `privacy`, the two required checks.
- **Staging.** This repo has no install targets yet, so a base change can't be staged from here. It is playtested through a game that uses it, with the game's `base/` at the commit under review, from that game's trusted checkout and following that game's rules. Until a game runs on the base, base changes rely on automated tests.
- **Releases.** The base has no release workflow yet. It gets one, copied from Cops and Robbers, and releases 0.1.0 before any game adds the submodule (#9); game repos then pin the base's shared Actions and submodule to the commit of a release.
- **Board script.** `scripts/board` here reads this repo's `board.conf`, so it acts on arcade-base only; supporting calls from a game is softbody-arcade/arcade-base#8.
