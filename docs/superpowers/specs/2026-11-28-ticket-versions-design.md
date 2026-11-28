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
- A refusal that comes after a write. Every check runs before the first issue or lane change of a command.

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

**Where the rule applies.** An open issue in any lane except Inbox needs an open milestone with a valid version. That includes an open card in Accepted: the rules allow an open issue there, and it is checked like any other. A closed issue is exempt. A reopened issue returns to Inbox, so it is exempt until it is triaged again, and re-triage replaces a released milestone.

**Choosing a version.** One helper decides a version for an issue, used by every command below, and it runs before any write:

1. `--milestone x.y.z` if given. It must be valid. If the milestone does not exist it is created; if it exists and is closed the command refuses. An explicit value wins over the issue's current milestone.
2. Otherwise the issue's current milestone, if valid and open.
3. Otherwise the repo's earliest valid open milestone.
4. Otherwise the command refuses and says to pass `--milestone` or run `board milestone N x.y.z`.

It prints the version it used and whether it was given, kept or defaulted.

**Commands.** Changes to `scripts/board`:

| Command | Change |
|---|---|
| `triage N TYPE PRIORITY [EFFORT] [--milestone x.y.z]` | Uses the helper. Applies to an Inbox card and to a card in any other lane, so a re-triage fixes a released or missing version. |
| `new TYPE PRIORITY [EFFORT] TITLE [--milestone x.y.z]` | Uses the helper when a priority is given (the card goes to Backlog). Works together with `--body-file`. `new` without a priority goes to Inbox and is exempt. |
| `move N <lane>` | `classified`, which already runs for every move whose destination is not Inbox, also requires a valid open version and refuses otherwise, with no lane change. This covers Backlog to Next, `start`, rework moves and the In-game check moves. A card in Backlog that lost its milestone, or never had one, cannot advance until it is fixed. |
| `move N playtest` for an In-game check from Inbox, Backlog or Next | Uses the helper first, since the card leaves Inbox; no option, so an override is `board milestone` first. |
| `milestone N x.y.z` | Tightened to a valid version. Creates the milestone in the repo if it does not exist, then assigns it. Refuses a closed milestone. |
| `milestone N none` | Refused for an open issue outside Inbox. Allowed for Inbox cards and closed issues. |
| `result N defer` | Resolves the version of the In-game check before creating it or moving a recovered one to Playtest: the work card's milestone if valid and open, else the repo's earliest valid open milestone, else refuse. The check runs before any write, for both a new check and one recovered after a partial failure. |
| `result N fail` | The Bug goes to Inbox and is exempt. It takes the work card's milestone when that is valid and open, and none otherwise. |
| `check` | Adds `#N missing version`, `#N version x.y.z is already released` and `#N version "<title>" is not x.y.z` for every open card outside Inbox, whatever its lane. Needs the milestone state in the card query. |
| `release` | After the board moves, runs the rollover below. `--dry-run` prints the moves without changing anything. |
| `--help` | Documents the above. |

**Rollover.** Scan the configured repo only, with pagination. Read all its milestones (`state=all`) and keep the valid ones. For each closed valid milestone with open issues (pull requests excluded), move each open issue to the lowest open valid milestone strictly above the closed one. If none exists, create the next minor (`x.(y+1).0`) above the highest valid version among all its milestones, open or closed, and use that. This includes Inbox cards and issues that are not on the board, because the milestone belongs to the repo, not the board. It does not touch milestones of another repo, even if the titles and issue numbers match. It prints each move and is safe to run twice.

**Rules.** In `AGENTS.md`: the **Milestone** bullet states what a version means and when it is required, replacing "assigns it when committing to a release"; "Every issue outside Inbox has a type, a priority and an effort" adds the version; the Lanes table rows for Inbox and Backlog say triage sets it; the release-PR check changes from "no open issues" to "read the open issues; finish what should ship, the rest rolls on"; the cross-repo sentence goes under Parent and sub-issues; the **Releases** view with its Slice by Repository is named where the Quick wins view is. `docs/ROLES.md` already lists who sets milestones. This is a decision that spans games, so `docs/README.md`'s decisions index gets a row linking to the decision comment on #48, in this same pull request.

**Board configuration (not in the repo).** The **Releases** view is sliced by Repository so a name clash cannot mix two repos. Done once in the web interface, by the maintainer or an agent acting for them, and noted on the ticket.

**Backfill.** After the script change is merged and the maintainer has run it from `develop`, an agent proposes a version for each open issue outside Inbox that has none (47 at the time of writing; the one Inbox issue is exempt and left alone) as a table on the ticket, using priority and the step order in the base's parent issue. The maintainer approves or edits it, then the agent applies it with `board milestone`. It is not part of the pull request. Until then those cards cannot move lanes, which is the intended effect.

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
- `result defer` refuses before creating anything when no version can be chosen, and takes the work card's version otherwise; recovery of an existing check does the same; the failed-check Bug stays in Inbox.
- `release` rolls an ordinary Backlog leftover, an Inbox leftover and an off-board issue to the next open milestone; creates the next minor when none is open; handles a closed milestone above every open one; leaves closed issues and another repo's matching milestone and issue numbers alone; is idempotent; and with `--dry-run` changes nothing.

## In-game checks

None. The change is board tooling and rules, with no in-game behaviour.

## Engine assumptions

None. One GitHub assumption to confirm: the board's group-by-milestone keeps same-named milestones of two repos apart. It is checked on the Releases view with a throwaway pair before the slice is relied on, and the slice makes it moot either way.
