# Ticket Versions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every open issue outside Inbox has an open `x.y.z` milestone in its own repo, enforced by `scripts/board` and stated in the rules.

**Architecture:** `scripts/board` gains a small set of version functions (validate, compare, read, resolve, apply, roll over) next to the existing helpers. Commands call `resolve_version` before their first write and `apply_version` when they must set one. `board check`, `move` (through `classified`), `result` and `release` enforce or repair it. Rules and docs follow the code.

**Tech Stack:** Bash 4.4+, `gh` 2.106+, `jq`; tests in `tests/board_test.sh` with a stubbed `gh`.

**Spec:** [docs/superpowers/specs/2026-11-28-ticket-versions-design.md](../specs/2026-11-28-ticket-versions-design.md). Ticket: [arcade-base#48](https://github.com/softbody-arcade/arcade-base/issues/48).

## Global Constraints

- A valid version matches `^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`, the format `scripts/publish-release` accepts.
- Versions are compared part by part by digit count, then lexicographically; never with shell arithmetic.
- Milestone titles from the API are data: never evaluated, always quoted.
- Closed issues are exempt from every version check. Drafts and Inbox cards are exempt.
- Every check the script can know up front runs before the first issue, comment, field or lane write of a command; every write is safe to repeat.
- No change to `release.yml` or `scripts/publish-release`. Pull requests get no version.
- Default version for a card without a usable one: the repo's earliest valid open milestone.
- Keep `scripts/board` working from a game's `base/` (it reads the caller's `board.conf`); no repo-specific values.
- Commit messages end with the attribution line the session's system reminder gives. Write everything as if the repo were public: no home paths, hosts or emails.

## Review Focus

- A milestone titled `1.0.0; touch pwned` or `$(id)` in an API response: reported by `check` as not `x.y.z`, never chosen as a default, never executed. Pinned in Task 1 and Task 4.
- A version part bigger than a shell integer (`99999999999999999999.0.0`): orders above `1.0.0`. Pinned in Task 1.
- A Build or Review card whose milestone was deleted after triage (null milestone): `start`, `move` and `result fail` refuse with no write; `priority`, `effort` and `move N inbox` still work. Pinned in Tasks 3 and 5.
- A reopened issue back in Inbox that still carries a released milestone: exempt in `check`, replaced at triage, moved by `release` if still open there. Pinned in Tasks 2, 4 and 6.
- `release` with only lower open milestones, a closed milestone above every open one, or the same milestone titles and issue numbers in a second repo: moves only this repo's issues, creates one fallback. Pinned in Task 6.

## File Structure

- `scripts/board`: all version logic and command changes (one file, as today).
- `tests/board_test.sh`: stub extensions and every new test; existing fixtures migrated in Task 1.
- `AGENTS.md`, `docs/ROLES.md`, `docs/README.md`: rules, roles row and the decisions-index row (Task 7).

Lines in `tests/board_test.sh` use the existing helpers: `expect CODE PATTERN args…`, `guard MESSAGE args…` (exit 1, output equals MESSAGE exactly, and no write in `$LOG`), `wrote TEXT` (text appears in `$LOG`), with state set by environment variables such as `LANE=Backlog`.

## Messages (exact text, used by tests and code)

| Situation | Text |
|---|---|
| Chosen version printed | `Version: x.y.z (given)`, `Version: x.y.z (kept)`, `Version: x.y.z (defaulted)` |
| `--milestone` value not valid | `Invalid version: <value>` (through `bad`) |
| Explicit milestone exists and is closed | `Milestone x.y.z is already released` |
| Nothing can be chosen | `No open version milestone: pass --milestone x.y.z or run board milestone N x.y.z` |
| `classified` without a valid open version | `Set a valid open version first: board milestone N x.y.z` |
| `milestone N none` on an open issue outside Inbox | `An open issue outside Inbox needs a version` |
| `result N fail` on a work card without one | `Set a valid open version before a failed playtest: board milestone N x.y.z` |
| `check` | `#N missing version`, `#N version x.y.z is already released`, `#N version "<title>" is not x.y.z` |
| Rollover | `#N would move to x.y.z`, `#N moved to x.y.z`, `Milestone x.y.z would be created`, `Milestone x.y.z created` |

`N` is the issue number (`$n`).

---

### Task 1: Version functions, card query and fixture migration

**Files:**
- Modify: `scripts/board` (`cards`, `parse`, new functions near `classified`)
- Modify: `tests/board_test.sh` (stub, default card, existing assertions)

**Interfaces:**
- Produces: `valid_version V` (exit 0 when valid); `version_greater A B` (exit 0 when A > B); `repo_milestones` (prints `number<TAB>title<TAB>state` per milestone of `$repo`, `state` is `open` or `closed`, paginated); `load_issue_version` (sets `issue_state` `OPEN|CLOSED`, `issue_ms_title` empty when none, `issue_ms_state` `open|closed` or empty, read from `gh api repos/$repo/issues/$n`); `parse` now also sets `mstate` (`OPEN`, `CLOSED`, or `-` when the card has no milestone) between `milestone` and `labels`.
- Consumes: nothing.

- [ ] **Step 1: Extend the stub and migrate the default card.** In `tests/board_test.sh`: the card's milestone becomes `{title: ($ms_title), state: ($ms_state)}` from `MS_TITLE` (default `1.0.0`) and `MS_STATE` (default `OPEN`); `MS_TITLE=-` yields `milestone: null`. Add stub patterns, placed before `'api repos/'*`: `'api --paginate repos/'*'/milestones?'*` printing the tab-separated rows of `MILESTONES` (JSON array of `{number,title,state}`, default `[{"number":1,"title":"1.0.0","state":"open"}]`) through the `--jq` argument like `api_response`; and extend the existing `'api repos/'*'/issues/'*` pattern to include `state` (`ISSUE_STATE`, default `open`) and `milestone` (`MS_TITLE`/`MS_STATE`, lower-cased state) in its JSON. Make `guard`'s write detection also match `api --method` and `api -X` lines.
- [ ] **Step 2: Write the failing tests.**
  - `valid_version`/`version_greater` are exercised through `check` and `triage` later; here add a unit-style block that sources the functions: `source <(sed -n '/^valid_version()/,/^}/p;/^version_greater()/,/^}/p' scripts/board)` then asserts: `valid_version 1.2.3`, `! valid_version 01.2.3`, `! valid_version Later`, `! valid_version '1.0.0; touch pwned'`, `version_greater 0.10.0 0.9.0`, `! version_greater 0.9.0 0.10.0`, `version_greater 99999999999999999999.0.0 1.0.0`, `! version_greater 1.0.0 1.0.0`.
  - Card query: `expect 0 '' list` then assert the stub log contains `milestone{title state}`.
  - Representation: with `MS_TITLE=-` the stub emits a null milestone and the parsed card has `mstate` `-`; a milestone literally titled `-` with state OPEN has `mstate` `OPEN`. Task 4's `check` tests pin the visible difference (missing versus not `x.y.z`).
- [ ] **Step 3: Run `make test`; the new asserts fail** (functions and `mstate` missing).
- [ ] **Step 4: Implement** the five functions with the signatures above in `scripts/board`, add `milestone{title state}` to the `cards` GraphQL selection and an extra jq field `(.content.milestone.state // "-")` right after the title, and extend `parse`'s `read` list. `valid_version` is the Global Constraints regex; `version_greater` splits on dots and, per part, compares length then string.
- [ ] **Step 5: Migrate existing tests** so `make test` passes again with the default card now carrying a valid open milestone: the stub default already does for most; the exact `new`/`triage` output assertions change in Task 3, and the old `issue edit … --milestone 9.9.9` failure test and the open-Next expectations around line 332 are replaced in Tasks 2 and 3. Here, only add `MS_TITLE`/`MS_STATE` where an existing test now needs a different card. List which tests changed in the commit body.
- [ ] **Step 6: Run `make test`** — Expected: PASS.
- [ ] **Step 7: Commit** `Board: version functions and milestone state on cards`.

### Task 2: `board milestone` creates, tightens and refuses

**Files:**
- Modify: `scripts/board` (the `milestone)` handler, `usage` text)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Task 1 functions.
- Produces: `milestone N x.y.z` and `milestone N none` as the spec's table says.

- [ ] **Step 1: Write the failing tests.**
  - `guard 'Expected x.y.z or none' milestone 1 01.2.3` and `… Later`.
  - `MILESTONES='[{"number":1,"title":"1.0.0","state":"open"}]' expect 0 '' milestone 1 1.2.0` then `wrote 'api -X POST repos/softbody-arcade/arcade-base/milestones'`, `wrote 'issue edit 1 --milestone 1.2.0'`, and that the POST line precedes the edit line.
  - `MILESTONES='[{"number":2,"title":"1.2.0","state":"closed"}]' guard 'Milestone 1.2.0 is already released' milestone 1 1.2.0`.
  - Existing open milestone: no POST in `$LOG`.
  - `milestone 1 none` on an open issue with `LANE=Backlog` (and off-board, `ISSUE_STATE=open` with the card absent): `guard 'An open issue outside Inbox needs a version'`; with `LANE=Inbox`, and with `ISSUE_STATE=closed`: exit 0 and `wrote 'issue edit 1 --remove-milestone'`.
- [ ] **Step 2: Run** `make test` — Expected: the new tests FAIL.
- [ ] **Step 3: Implement** in the `milestone)` case: validate with `valid_version`; `load_issue_version`; for `none`, refuse when `issue_state` is `OPEN` and the card's lane (via `load`, treated as not-Inbox when the card is absent) is not `Inbox`; for a version, read `repo_milestones`, refuse a closed match, create a missing one with `gh api -X POST repos/$repo/milestones -f title=<version>` (quoted), then `issue edit "$n" --milestone <version>`. Update `usage` to read `milestone N x.y.z|none`.
- [ ] **Step 4: Run** `make test` — Expected: PASS.
- [ ] **Step 5: Commit** `Board: milestone creates a missing version and refuses released ones`.

### Task 3: Resolve and apply, in `triage`, `new` and the version gate

**Files:**
- Modify: `scripts/board` (`classified`, `triage`, `new`, `usage`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: `resolve_version [GIVEN]` (read-only; sets `chosen` and `chosen_how` `given|kept|defaulted`; refuses with the table's messages; requires `load_issue_version` first); `apply_version` (creates the milestone when `chosen` is not in `repo_milestones`, assigns when it differs from `issue_ms_title`, prints `Version: <chosen> (<chosen_how>)`); `classified` also refuses an open issue without a valid open version.

- [ ] **Step 1: Write the failing tests.**
  - Helper order via `triage`: `MS_TITLE=- MILESTONES='[{"number":3,"title":"1.4.0","state":"open"},{"number":2,"title":"1.3.0","state":"open"}]' LANE=Inbox expect 0 'Version: 1.3.0 (defaulted)' triage 1 task high`; with a current open milestone `MS_TITLE=1.4.0` → `(kept)`; with `--milestone 1.9.0` → `(given)` and a POST to create it; with `--milestone 01.0.0` → `Invalid version: 01.0.0` and exit 2; explicit closed → `Milestone 1.3.0 is already released`; current released (`MS_STATE=CLOSED`) is replaced by the earliest open; an invalid open title (`1.0.0; touch pwned`) is skipped as a default; none open and none given → `guard 'No open version milestone: pass --milestone x.y.z or run board milestone 1 x.y.z'`.
  - Validation before writes: each refusal above leaves `$LOG` without `item-edit`, `issue edit` or `-X`.
  - `new task high medium "T" --milestone 1.3.0 --body-file F` sets it; `new task "T"` (no priority) writes no milestone; `new task high "T"` defaults.
  - Triage of a closed card (`STATE=CLOSED LANE=Accepted`) succeeds without a version; a Done card is still refused with the existing message; triage of a non-Inbox card with a released version replaces it.
  - Gate: `MS_TITLE=- LANE=Backlog guard 'Set a valid open version first: board milestone 1 x.y.z' move 1 next`; the same for `start 1 build` (no assignee write), `move 1 review` from Build, and with `MS_STATE=CLOSED`; `MS_TITLE=- LANE=Next expect 0 '' move 1 inbox`; `MS_TITLE=- expect 0 '' priority 1 high`, `effort 1 low`.
- [ ] **Step 2: Run** `make test` — Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the helpers above. In `triage` and `new`, parse `--milestone x.y.z` (position: after the other arguments for `triage`; before the title for `new`, alongside `--body-file`), validate with `valid_version` (else `bad "Invalid version: <v>"`), run `load_issue_version` and `resolve_version` after the existing read-only checks and before the first write, then `apply_version` before the first field write. `new` without a priority skips both. Only for an `OPEN` issue; a closed one skips. `classified` appends the version refusal for an open issue (use `mstate`/`milestone` from the loaded card). Update `usage`.
- [ ] **Step 4: Update the exact `new` and `triage` output assertions** in existing tests for the extra `Version:` line.
- [ ] **Step 5: Run** `make test` — Expected: PASS.
- [ ] **Step 6: Commit** `Board: triage, new and moves require a valid open version`.

### Task 4: `check`, and the In-game check shortcut

**Files:**
- Modify: `scripts/board` (`check` branch of `list|waiting|check`, the In-game check branch of `move`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Tasks 1–3.

- [ ] **Step 1: Write the failing tests.**
  - `check`: `MS_TITLE=- LANE=Backlog expect 1 '#1 missing version' check`; `MS_STATE=CLOSED … '#1 version 1.0.0 is already released'`; `MS_TITLE='1.0.0; touch pwned' … '#1 version "1.0.0; touch pwned" is not x.y.z'` and no file `pwned` exists; an open Accepted card without a version is flagged; Inbox and closed (`STATE=CLOSED`) cards are not; a milestone literally titled `-` is reported as `not x.y.z`, not as missing.
  - Shortcut (`TYPE='In-game check'`, destination Playtest) from Inbox, Backlog and Next, each with a default available (`MS_TITLE=-` plus an open milestone) and with none: with none, `guard 'No open version milestone: pass --milestone x.y.z or run board milestone 1 x.y.z' move 1 playtest`; with a default, `$LOG` shows the milestone `issue edit` before the Effort write (`SIZE=-`) and before `--field Status --value Playtest`.
- [ ] **Step 2: Run** `make test` — FAIL.
- [ ] **Step 3: Implement** the three `check` messages (open cards, any lane but Inbox, regardless of Accepted) and, in the shortcut branch, `load_issue_version`, `resolve_version`, then `apply_version`, then the existing Effort and Status writes.
- [ ] **Step 4: Run** `make test` — PASS.
- [ ] **Step 5: Commit** `Board: check reports versions; checks need one before Playtest`.

### Task 5: `result`

**Files:**
- Modify: `scripts/board` (the `result)` handler)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Tasks 1–3.

- [ ] **Step 1: Write the failing tests.**
  - Work card, `MS_TITLE=- LANE=Playtest guard 'Set a valid open version before a failed playtest: board milestone 1 x.y.z' result 1 fail` (and with `MS_STATE=CLOSED`), with no `pr edit`, comment or Status write; with a valid version it proceeds as today. `result 1 pass` needs no version.
  - `result 1 defer --checks-file F` with a work-card version: the new In-game check gets that milestone (`issue edit <new> --milestone <v>` before its `Status Playtest` write); with none on the card, the repo default; with neither, `guard` the no-version message and no `issue create` in `$LOG`.
  - Recovery: `EXISTING` open check already in Playtest with no milestone → a milestone `issue edit` on the recovered number and success; open check in Inbox → versioned and moved; a closed one (the stub's `find_created` row gets `state:"closed"`) → no edit, no move, same report as today.
  - `result fail` on an In-game check: the Bug is created in Inbox, gets the check's milestone only when valid and open.
- [ ] **Step 2: Run** `make test` — FAIL.
- [ ] **Step 3: Implement.** For a work card `fail`, run `load_issue_version` and refuse before any write (the PR edit and comments come after). For `defer`, call `resolve_version` against the work card first and `apply_version` on the check number (`n` swapped to the check's number around the call). In the recovery branch, verify an open existing check: assign when its milestone is missing, released or invalid, and move to Playtest when it is in another lane, even when it is already in Playtest; skip a closed one. The stub's `find_created` rows must expose `state` for this (extend `'api --paginate '*'/issues?state='*`).
- [ ] **Step 4: Run** `make test` — PASS.
- [ ] **Step 5: Commit** `Board: result keeps versions on cards and deferred checks`.

### Task 6: `release` rollover

**Files:**
- Modify: `scripts/board` (the `release)` case, new `rollover` function, `usage`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Task 1 functions, `edit`-style helper `issue edit "$n" --milestone V`.
- Produces: `rollover` (reads `$dry_run`; prints the Rollover lines from the table).

- [ ] **Step 1: Stub for rollover.** Add `MS_ISSUES` (JSON object: milestone number → array of `{number,pull_request?}`) and a pattern `'api --paginate repos/'*'/issues?milestone='*'&state=open'*` printing issue numbers with pull requests dropped by the passed `--jq`; the existing `'api repos/'*'/issues/'*` pattern answers the re-read before an update.
- [ ] **Step 2: Write the failing tests.** All with a released tag: a closed milestone `1.0.0` (number 1) holding open issues 7 and 8 and an open `1.1.0` → `#7 moved to 1.1.0`, `#8 moved to 1.1.0`, and `issue edit 7 --milestone 1.1.0`. Plus: no open milestone above → one `Milestone 1.1.0 created` (POST once) before both moves; two closed sources (`1.0.0`, `0.9.0`) needing one fallback → one POST; only a lower open milestone and a closed one above it → fallback is the next minor above the highest of all (`x.(y+1).0`); a pull request in `MS_ISSUES` is left alone; every list read in `$LOG` precedes the first `issue edit`; an issue whose re-read milestone is no longer the source is skipped (stub `ISSUE_MS_NOW`); a second repo (`OTHER_REPO`) with the same titles and numbers is not touched; running twice moves nothing the second time (all milestones open); `--dry-run` prints `would` lines and writes nothing (no POST, no edit).
- [ ] **Step 3: Run** `make test` — FAIL.
- [ ] **Step 4: Implement `rollover`** per the spec: collect (all milestones, then each closed valid milestone's open non-PR issues, all pages) before changing anything; plan targets (lowest open valid strictly above, else one shared next-minor fallback); apply (create the fallback once, re-reading if the POST reports it exists; re-read each issue's milestone just before `issue edit` and skip when it changed). Call it at the end of `release)`, after the board moves, for both dry and real runs. Update `usage` to mention that release rolls open issues.
- [ ] **Step 5: Run** `make test` — PASS.
- [ ] **Step 6: Commit** `Board: release rolls open issues to the next version`.

### Task 7: Rules, roles, decisions index

**Files:**
- Modify: `AGENTS.md` (Milestone bullet, the type/priority/effort sentence, Lanes rows for Inbox and Backlog, the release-PR check sentence, Parent and sub-issues bullet, the Quick wins sentence)
- Modify: `docs/ROLES.md` (the Board workflows row at line 101)
- Modify: `docs/README.md` (a row under **Decisions across games**)
- Modify: `scripts/board` (`usage` text if not complete)

**Interfaces:**
- Consumes: the finished commands.

- [ ] **Step 1: Edit `AGENTS.md`** with the spec's **Rules** paragraph: Milestone bullet states what a version means and when it is required (replacing "The maintainer assigns it when committing to a release"); "Every issue outside Inbox has a type, a priority and an effort" gains the version; the Inbox and Backlog lane rows say triage sets it; the release-PR check becomes "read the open issues; finish what should ship, the rest rolls on"; the cross-repo sentence (blocked-by on the base issue, base version named in the text or milestone description) goes under Parent and sub-issues; the **Releases** view with its Slice by Repository is named beside the Quick wins view. Keep every relative link resolving from `base/`.
- [ ] **Step 2: Edit `docs/ROLES.md`** line 101: the Board workflows row gains the version requirement and that `scripts/board release` rolls open issues to the next version.
- [ ] **Step 3: Add the `docs/README.md` row**: "Every open issue outside Inbox has a version; a milestone is the earliest release it could ship in" linking to `https://github.com/softbody-arcade/arcade-base/issues/48#issuecomment-7238876205`.
- [ ] **Step 4: Run** `make test`, `make privacy` and the link check CI runs (see `docs/DEVELOPMENT.md`; `lychee` offline on `docs/` and the root `.md` files) — Expected: all pass.
- [ ] **Step 5: Commit** `Rules: every open issue outside Inbox has a version`.

### Task 8: Whole-branch verification and hand-off

**Files:** none.

- [ ] **Step 1:** `make test && make privacy` from the worktree — Expected: PASS. Confirm `git status` is clean and `scripts/board --help` lists `--milestone`, the changed `milestone` and `release` text.
- [ ] **Step 2:** Open the draft PR with `Fixes #48`, listing in its body the tests migrated in Task 1, the unchanged `release.yml`, and the follow-up for games that keep their own `scripts/board` copy.
- [ ] **Step 3 (maintainer or an agent acting for them, not in the PR):** slice the **Releases** view by Repository in the board's web interface and note it on #48; verify with a throwaway pair that same-named milestones of two repos stay apart in the group-by.
- [ ] **Step 4 (after merge, from each repo's own trusted `develop` checkout):** propose versions for the open issues without one (47 at the time of writing) as a table on #48; apply with `board milestone` after the maintainer approves. Cops and Robbers files its own follow-up to move its `base/` pin.
