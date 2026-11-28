# Always assign a version to tickets

Ticket: [arcade-base#48](https://github.com/softbody-arcade/arcade-base/issues/48). Roadmap decision: [arcade-base#47](https://github.com/softbody-arcade/arcade-base/issues/47).

## Why

The board has a **Releases** view that groups cards by milestone, but a version is optional today, so most open issues have none and the view says little about what ships when. Type, priority and effort are already required for every card outside Inbox and the board script enforces them. A version should be the same: set once at triage, checked by the script, and kept true after each release.

## Goals

- Every open issue outside Inbox has a milestone named `x.y.z` in the repo that owns it. Drafts and Inbox cards are exempt.
- The board script sets a version at the moments a card leaves Inbox, so nobody has to remember it.
- `board check` reports an open issue that has none, or whose milestone is already released.
- After a release, issues that did not ship move on to the repo's next milestone, so the rule stays true without manual re-milestoning.
- The rules, `docs/ROLES.md` and `--help` say so.

## Non-goals

- Dates, iterations or GitHub's Roadmap layout. Whether work lands depends on what BeamNG and BeamMP do in game.
- Versions on closed issues, and a backfill of the 50 closed issues that have none.
- Versions on pull requests.
- Changing `release.yml` or `scripts/publish-release`.
- Porting the change to a game's own `scripts/board` copy. A game gets it when it moves its `base/` pin; each game that keeps its own copy files its own follow-up.

## Anti-goals

- A version that means nothing: a placeholder such as `0.x` or `Later`, or the same milestone on everything with no way to tell what is committed.
- A script that guesses silently. A default is allowed only when it is printed and when the maintainer can override it in the same command.
- Extra write permission for the release workflow's publish job.
- A refusal that blocks the maintainer from fixing the board: `board milestone` must always be able to correct a version.

## What a version means

A milestone is the earliest release an issue could ship in, not a promise. What the maintainer has committed to is the Next lane (5 cards at most) and anything past it in the lane table. The Releases view therefore shows two things: the order of releases, and, inside each, how far along the work is. When the maintainer commits to a release, they pull the issues they want into its milestone. A release ships when the maintainer cuts it; what is still open then rolls on.

Milestones belong to one repo. A game's `0.2.0` and the base's `0.2.0` are unrelated milestones with the same name. A game issue that needs a base release records it as blocked-by on the base issue and names the base version in its text or in its milestone description.

## Approaches

1. **Hard gate with rolling carry-over (chosen).** Triage and `board new` set a version, defaulting to the repo's earliest open milestone; `board check` flags what is missing; `board release` moves leftovers on. The rule stays true by itself. Trade-off: a Backlog version is a soft promise.
2. **Hard gate, no defaults, no carry-over.** Every version is chosen by hand and every release means re-milestoning leftovers by hand. Most deliberate, most friction.
3. **Warn only.** `board check` reports a missing version and nothing refuses. Easy, but it does not give "always".

Carry-over could live in `release.yml` instead of `board release`. It is rejected: it would give the publish job issue write permission, and a game without a release workflow would not get it.

## Design

**Where the rule applies.** An open issue in any lane except Inbox needs a milestone. Closed issues and Accepted cards are exempt (they are closed). A milestone that is already closed (released) counts as missing for an open issue.

**Commands.** Changes to `scripts/board`:

| Command | Change |
|---|---|
| `triage N TYPE PRIORITY [EFFORT] [--milestone x.y.z]` | Keeps the issue's milestone if it is open. Otherwise uses `--milestone`, otherwise the repo's earliest open milestone, otherwise refuses and says to pass `--milestone`. Prints which one it used. |
| `new TYPE PRIORITY [EFFORT] TITLE [--milestone x.y.z]` | Same rule when a priority is given (the card goes to Backlog). `new` without a priority goes to Inbox and is exempt. |
| `move N playtest` for an In-game check from Inbox, Backlog or Next | Same rule, because the card leaves Inbox. |
| `milestone N x.y.z` | Creates the milestone in the repo if it does not exist, then assigns it. |
| `milestone N none` | Refused for an open issue outside Inbox. Allowed for Inbox cards. |
| `result N defer` and `result N fail` | The In-game check or Bug the script files takes the work card's milestone when that card has an open one. A Bug goes to Inbox and is exempt either way. |
| `check` | Adds `#N missing version` and `#N version x.y.z is already released` for open cards outside Inbox and Accepted. Needs the milestone state in the card query. |
| `release` | After the board moves, rolls open issues whose milestone is closed to the repo's lowest open milestone above it. If none is open it creates the next minor (`x.(y+1).0`) of the highest closed one. Prints each move. `--dry-run` prints without changing. |
| `--help` | Documents the above. |

`move N next` needs no new check, because a card cannot be in Backlog without a version.

**Order of milestones.** Compared as numbers (`0.10.0` is above `0.9.0`), never as text.

**Rules.** `AGENTS.md`: the **Milestone** bullet states what a version means (above) and when it is required; the sentence "Every issue outside Inbox has a type, a priority and an effort" adds the version; the Lanes table rows for Inbox and Backlog say triage sets it; the release-PR check changes from "no open issues" to "the open issues are the ones that roll on" (read the list, and finish what should ship first); the cross-repo sentence from the previous section goes under Parent and sub-issues; the **Releases** view and Slice by Repository are named where the Quick wins view is. `docs/ROLES.md` already says who sets milestones and needs no change beyond the new rule if it lists enforced fields.

**Board configuration (not in the repo).** The **Releases** view is sliced by Repository so a name clash cannot mix two repos. Done once in the web interface, by the maintainer or an agent acting for them, and noted on the ticket.

**Backfill.** After the script change is merged and the maintainer has run it from `develop`, an agent proposes a version for each of the open issues that have none (48 at the time of writing), as a table on the ticket, using priority and the step order in the base's parent issue. The maintainer approves or edits it, then the agent applies it with `board milestone`. It is not part of the pull request.

## Decision for the maintainer

**Default version for new Backlog issues.** Chosen so far: the earliest open milestone, as approved. The catch is that the next release's milestone then fills with the whole Backlog, so its progress bar stops meaning anything. The alternative is the furthest open milestone: new issues wait there until the maintainer pulls them forward to commit. It keeps the next release's progress meaningful, but a lone new idea sits under a version far from what is being built. If only one milestone is open, both choices give the same result. This spec follows the approved choice; switching is one line in the triage default and its test.

## Choices left to the builder

- How to read the milestones for a repo (REST `milestones?state=open` is enough).
- The exact wording of the new messages and `--help` lines, in the style of the existing ones.
- Test structure inside `tests/board_test.sh`.

## Automated acceptance

`tests/board_test.sh` (stubbed `gh`) covers:

- Triage keeps an open milestone, takes `--milestone`, falls back to the earliest open one, refuses with none open, and replaces a released one.
- `new` with a priority sets the version; `new` without one does not.
- `milestone` creates a missing milestone and refuses `none` outside Inbox.
- `check` reports a missing version and a released one, and ignores Inbox, Accepted and closed issues.
- Version ordering: `0.10.0` is above `0.9.0`.
- `release` rolls an open issue to the next open milestone, creates the next minor when none exists, leaves closed issues alone, and with `--dry-run` changes nothing.
- A deferred check and a failed-check Bug take the work card's milestone.

## In-game checks

None. The change is board tooling and rules, with no in-game behaviour.

## Engine assumptions

None. One GitHub assumption to confirm: the board's group-by-milestone keeps same-named milestones of two repos apart. It is checked on the Releases view with a throwaway pair before the slice is relied on, and the slice makes it moot either way.
