# Always assign a version to tickets

Ticket: [arcade-base#48](https://github.com/softbody-arcade/arcade-base/issues/48). Roadmap decision it amends: [arcade-base#47](https://github.com/softbody-arcade/arcade-base/issues/47).

## Why

The board has a **Releases** view that groups cards by milestone, but a version is optional today, so most open issues have none and the view says little about what ships when. Type, priority and effort are already required for every card outside Inbox and the board script enforces them. A version should be the same: set once at triage, checked by the script, and kept true after each release.

## Goals

- Every open issue outside Inbox has an open milestone named `x.y.z` in the repo that owns it, whatever its lane. Drafts and Inbox cards are exempt.
- The board script sets a version at the moments a card leaves Inbox, and refuses to move a card without one.
- `board check` reports an open issue that has none, one whose milestone is already released, and one whose milestone is not named `x.y.z`.
- After a release, open issues in a released milestone move on to the repo's next milestone, so the rule stays true without manual re-milestoning.
- The rules, the decisions index, `docs/ROLES.md` and `--help` say so.

## Non-goals

- Dates, iterations or GitHub's Roadmap layout. Whether work lands depends on what BeamNG and BeamMP do in game.
- Versions on closed issues, and a backfill of the 50 closed issues that have none.
- Versions on pull requests.
- Changing `release.yml` or `scripts/publish-release`.
- Porting the change to a game's own `scripts/board` copy. A game gets it when it moves its `base/` pin; each game that keeps its own copy files its own follow-up.

## Anti-goals

- A version that means nothing: a placeholder such as `0.x` or `Later`, or one milestone on everything with no way to tell what is committed.
- A script that guesses silently. A default is allowed only when it is printed and when the maintainer can override it: with `--milestone` on `triage` and `new`, or by running `board milestone N x.y.z` first for a move.
- A refusal that blocks the maintainer from fixing the board: `board milestone` must always be able to correct a version.
- A refusal that comes after a write when it could have come before. Every check the script can know up front runs before the first issue, comment or lane change of a command. Some failures can only appear after a write (a new issue that does not enter Inbox, a network error mid-command); each write is then safe to repeat, and a retry finishes the job (see Retry).

## What a version means

A milestone is the earliest release an issue could ship in, not a promise. What the maintainer has committed to is the Next lane (5 cards at most) and whatever they pull forward into the next release's milestone. A release ships when the maintainer cuts it; what is still open then rolls on.

This amends the roadmap decision on #47, which treated assigning a milestone as committing to a release. The amendment follows from the maintainer choosing that every issue outside Inbox has a version: with 40-odd Backlog issues, a version cannot be a commitment. The rule text in `AGENTS.md` changes to match, and the decision is recorded on #48 and indexed (see Rules).

Milestones belong to one repo. A game's `0.2.0` and the base's `0.2.0` are unrelated milestones with the same name. A game issue that needs a base release records it as blocked-by on the base issue and names the base version in its text or in its milestone description.

## Approaches

1. **Hard gate with rolling carry-over (chosen).** Triage and `board new` set a version, defaulting to the repo's earliest open milestone; `board check` and every move enforce it; `board release` moves leftovers on. The rule stays true by itself. Trade-off: a Backlog version is a soft promise.
2. **Hard gate, no defaults, no carry-over.** Every version is chosen by hand and every release means re-milestoning leftovers by hand. Most deliberate, most friction.
3. **Warn only.** `board check` reports a missing version and nothing refuses. Easy, but it does not give "always".

Carry-over could live in the release workflow instead of `board release`. The publish job already has `issues: write`, so permission is not the objection. It is rejected because a game without a release workflow would not get it, and because `board release --dry-run` lets the maintainer see each move before it happens.

## Design

**A valid version** is `x.y.z` with no leading zeros, the same format `scripts/publish-release` accepts: `^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`. `board milestone` is tightened to it. Milestone titles read from the API that do not match are never chosen as a default or a rollover target, and `board check` reports an issue that carries one. Versions are compared part by part as numbers (`0.10.0` is above `0.9.0`), never as text, and a title is validated before it reaches any shell arithmetic.

**Where the rule applies.** An open issue in any lane except Inbox needs an open milestone with a valid version. That includes an open card in Accepted: the rules allow an open issue there, and it is checked like any other. A closed issue is exempt from every version check, in every command: closing a card never needs a version, and `triage` of a closed card sets type, priority and effort as it does today (it still refuses a Done card). A reopened issue returns to Inbox, so it is exempt until it is triaged again, and re-triage replaces a released milestone. An open issue that is not on the board is read from the issue itself, not from a board card: the helper below gets the issue's state and milestone from the repo, because the board lookup leaves the state unset for an issue it cannot find.

**Choosing a version.** One helper decides a version for an open issue. It is used by every command below and has two steps, so that validation comes before any write:

*Resolve (read-only).*
1. `--milestone x.y.z` if given. It must be valid. If a milestone with that title exists and is closed, the command refuses. An explicit value wins over the issue's current milestone.
2. Otherwise the issue's current milestone, if valid and open.
3. Otherwise the repo's earliest valid open milestone.
4. Otherwise the command refuses and says to pass `--milestone` or run `board milestone N x.y.z`.

*Apply (writes).* Create the milestone if an explicit title does not exist yet, then assign it if it differs from the issue's current one. This runs after every read-only check of the command has passed (including the Done refusal) and before the command's first lane, field or comment write.

It prints the version it used and whether it was given, kept or defaulted.

**Retry.** Assigning a milestone and creating a missing one are idempotent. If a command fails after a write, running it again must finish the job: it re-reads, does not duplicate a comment, issue or milestone, and repairs what the first run left behind. `result N defer` has the one case that needs spelling out (below).

**Commands.** Changes to `scripts/board`:

| Command | Change |
|---|---|
| `triage N TYPE PRIORITY [EFFORT] [--milestone x.y.z]` | Uses the helper. Applies to an Inbox card and to a card in any other lane, so a re-triage fixes a released or missing version. |
| `new TYPE PRIORITY [EFFORT] TITLE [--milestone x.y.z]` | Uses the helper when a priority is given (the card goes to Backlog). Works together with `--body-file`. `new` without a priority goes to Inbox and is exempt. |
| `move N <lane>`, `start N` | For an open issue, `classified`, which already runs for every move whose destination is not Inbox, also requires a valid open version and refuses otherwise, with no write. This covers Backlog to Next, `start`, and the rework and re-stage moves. A card in Backlog that lost its milestone, or never had one, cannot advance until it is fixed. `move N inbox` needs no version and stays available for recovery, as do `priority`, `effort`, `parent`, `unparent`, `block`, `unblock` and `decide`. |
| `move N playtest` for an In-game check from Inbox, Backlog or Next | This shortcut skips `classified` today and gets its own sequence, the same from every source lane: resolve with the helper (no option, so an override is `board milestone` first); if nothing resolves, refuse before writing anything; otherwise assign the version, then write Effort when it is missing, then write Status. Never Effort or Status before the version is assigned. |
| `milestone N x.y.z` | Tightened to a valid version. Creates the milestone in the repo if it does not exist, then assigns it. Refuses a closed milestone. |
| `milestone N none` | Refused for an open issue outside Inbox. Allowed for Inbox cards and closed issues. |
| `result N fail` on a work card | The card goes back to Build, so it needs a valid open version. Validate it before the first write (the PR edit, the comments and the Status write); on a missing, released or invalid one refuse, name `board milestone N x.y.z` as the fix, and leave the PR, the comments and the lane untouched. |
| `result N defer` on a work card | Resolves the version of the In-game check before creating it or moving a recovered one to Playtest: the work card's milestone if valid and open, else the repo's earliest valid open milestone, else refuse before any write. For a new check, assign the version in the same step that files it. A retry that finds an existing check that is **open** verifies it and repairs it before reporting success: it assigns the resolved version if the check's is missing, released or invalid, and moves it to Playtest when it is in another lane; this includes a check already in Playtest, whose earlier run failed after the move (for example on the comment to the work card). A check that is already **closed** was completed by an earlier run (`find_created` also returns closed issues); a retry does not repair or reopen it and reports as it does today. |
| `result N pass` on a work card, `result N pass` or `fail` on an In-game check | No version needed: a pass changes no lane, and a check is closed by its result. |
| `result N fail` on an In-game check | The Bug it files goes to Inbox and is exempt. It takes the check's milestone when that is valid and open, and none otherwise. |
| `check` | Adds `#N missing version`, `#N version x.y.z is already released` and `#N version "<title>" is not x.y.z` for every open card outside Inbox, whatever its lane. Needs the milestone state in the card query. |
| `release` | After the board moves, runs the rollover below. `--dry-run` prints the moves without changing anything. |
| `--help` | Documents the above. |

**Rollover.** It plans first and applies second, as the rest of `board release` does. Scan the configured repo only.

1. *Collect.* Read all its milestones (`state=all`, every page) and keep the valid ones. For each closed valid milestone, read all its open issues, every page, before changing anything, and drop pull requests (the issues endpoint returns them). Moving issues while paging would shrink the result set under the pagination, so no move happens until every list is complete.
2. *Plan.* For each source issue, the target is the lowest open valid milestone strictly above its closed milestone. If none exists, the target is the next minor (`x.(y+1).0`) above the highest valid version among all the repo's milestones, open or closed. All sources that need a new milestone share one planned title, so two closed sources create it once.
3. *Apply.* Create the fallback milestone once, before the moves; if creation reports that it already exists (another run or a maintainer made it), read it again and use it. For each issue, re-read its milestone just before the update and skip it if it is no longer the source milestone, because a maintainer may have moved it meanwhile; never overwrite a later assignment. Each move prints one line.

This includes Inbox cards and issues that are not on the board, because the milestone belongs to the repo, not the board. It does not touch milestones of another repo, even if the titles and issue numbers match. Running it twice, or after a partial failure, finishes the plan and moves nothing twice. `--dry-run` runs collect and plan and prints the moves.

**Representation.** `cards` must tell a missing milestone from an invalid title: the missing case keeps the `-` placeholder it has today in its own field, the title and its state travel in separate fields, and a title is data throughout parsing and reporting (never evaluated, never used unquoted). Versions are compared without shell arithmetic on unbounded values: compare the parts by digit count, then lexicographically, so a component larger than a shell integer still orders correctly.

**Rules.** In `AGENTS.md`: the **Milestone** bullet states what a version means and when it is required, replacing "assigns it when committing to a release"; "Every issue outside Inbox has a type, a priority and an effort" adds the version; the Lanes table rows for Inbox and Backlog say triage sets it; the release-PR check changes from "no open issues" to "read the open issues; finish what should ship, the rest rolls on"; the cross-repo sentence goes under Parent and sub-issues; the **Releases** view with its Slice by Repository is named where the Quick wins view is. `docs/ROLES.md` already lists who sets milestones, but its board-workflow table row gets the version requirement and the carry-over in `board release`. This is a decision that spans games, so `docs/README.md`'s decisions index gets a row linking to the decision comment on #48, in this same pull request.

**Board configuration (not in the repo).** The **Releases** view is sliced by Repository so a name clash cannot mix two repos. Done once in the web interface, by the maintainer or an agent acting for them, and noted on the ticket.

**Backfill.** After the script change is merged and the maintainer has run it from `develop`, an agent proposes a version for each open issue outside Inbox that has none (47 at the time of writing: 11 in arcade-base and 36 in Cops and Robbers; the one arcade-base Inbox issue is exempt and left alone) as a table on the ticket, using priority and the step order in the base's parent issue. The maintainer approves or edits it, then the agent applies it with `board milestone`, one repo at a time, each batch from that repo's own trusted checkout of `develop` (issue numbers repeat across the two repos, so a batch run from the wrong checkout would version the wrong issues). It is not part of the pull request. Until then those cards cannot move lanes, which is the intended effect.

## Decision for the maintainer

**Default version for new Backlog issues.** Chosen so far: the earliest open milestone, as approved. The catch is that the next release's milestone then fills with the whole Backlog, so its progress bar stops meaning anything. The alternative is the furthest open milestone: new issues wait there until the maintainer pulls them forward. It keeps the next release's progress meaningful, but a lone new idea sits under a version far from what is being built. If only one milestone is open, both give the same result. This spec follows the approved choice; switching is one line in the helper and its test. The maintainer's answer goes in the decision comment on #48.

## Choices left to the builder

- Which REST endpoints read milestones and their open issues, as long as they paginate.
- The exact wording of the new messages and `--help` lines, in the style of the existing ones.
- Test structure inside `tests/board_test.sh`.

## Automated acceptance

`tests/board_test.sh` (stubbed `gh`) covers:

- The card query itself: a test that fails unless the selection requests `milestone{title state}`, so a fixture cannot hide a missing field.
- The helper: explicit value wins over the current milestone; creates a missing explicit milestone; refuses an explicit closed one with no write; keeps an open current one; replaces a released one; falls back to the earliest open; skips an invalid open title; refuses with none open.
- Version validation: `01.2.3` is rejected; `0.10.0` is above `0.9.0`.
- `triage` and `new` (also with `--body-file`) set the version; `new` without a priority does not; `triage` of a non-Inbox card fixes a missing or released one.
- `move`: refuses without a valid open version and leaves the lane unchanged, for Backlog to Next and for an In-game check from Inbox; works after `board milestone`.
- `milestone` creates a missing milestone, refuses a closed one, and refuses `none` for an open issue outside Inbox.
- `check` reports a missing version, a released one and an invalid one, including on an open Accepted card; it ignores Inbox cards and closed issues.
- `result fail` on a work card with a missing, released or invalid version leaves the PR, the comments and the lane untouched, and works after `board milestone`.
- `result defer` refuses before creating anything when no version can be chosen, and takes the work card's version otherwise. Recovery: an existing open check that is already in Playtest with a missing or released version is repaired on the recovered issue number; one in another lane is versioned and moved; a closed one is left alone.
- The failed-check Bug stays in Inbox and takes the check's milestone only when it is valid and open.
- The In-game check shortcut to Playtest, from Inbox, from Backlog and from Next, each with a default available and with none: nothing is written when it refuses, and when it proceeds the version is assigned before Effort and Status.
- `start` with a deleted milestone makes no assignee write. `move N inbox`, `priority`, `effort`, `parent`, `block` and `decide` still work on an unversioned issue. A closed card still triages without a version, and a Done card is still refused.
- The helper reads an off-board open issue from the repo, and `milestone N none` is refused for it when it is open.
- Representation: a missing milestone and an invalid title are reported differently; a version component larger than a shell integer orders correctly.
- `release` plans before it applies: a milestone with a second page of open issues moves every issue; a pull request returned by the issues endpoint is left alone; two closed sources that need one fallback create it once; a retry after a partial success finishes without repeating a move; an issue a maintainer moved after the plan is skipped. It also rolls an ordinary Backlog leftover, an Inbox leftover and an off-board issue to the next open milestone, creates the next minor when none is open, handles a closed milestone above every open one, leaves closed issues and another repo's matching milestone and issue numbers alone, and with `--dry-run` changes nothing.
- The no-write assertions also catch REST mutations spelled `gh api --method …` and `gh api -X …`, not only the commands the helper catches today.

**Existing tests to migrate.** The stub's default card has no milestone state; give it a valid open milestone so the readiness tests, the staging, blocked and assignee guards, Review to Accepted, the open Accepted check, Build and `start`, the route guards, the clean Next count, the staged-SHA and linked-PR paths, and the rework, re-stage and check moves keep passing. Update the exact `new` and `triage` output assertions for the printed version, and replace the old expectation that a missing milestone is acceptable. The implementer lists the migrated tests in the pull request.

## In-game checks

None. The change is board tooling and rules, with no in-game behaviour.

## Engine assumptions

None. One GitHub assumption to confirm: the board's group-by-milestone keeps same-named milestones of two repos apart. It is checked on the Releases view with a throwaway pair before the slice is relied on, and the slice makes it moot either way.
