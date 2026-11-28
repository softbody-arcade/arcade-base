# Ticket Versions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every open issue outside Inbox has an open `x.y.z` milestone in its own repo, enforced by `scripts/board` and stated in the rules.

**Architecture:** `scripts/board` gains a small set of version functions (validate, compare, read, resolve, apply, roll over) next to the existing helpers. Commands read an issue's version with `load_issue_version`, decide with `resolve_version` before their first write, and set it with `apply_version` (or pass it to `issue create`). `board check`, `move` (through `classified`), `result` and `release` enforce or repair it. Rules and docs follow the code.

**Tech Stack:** Bash 4.4+, `gh` 2.106+, `jq`; tests in `tests/board_test.sh` with a stubbed `gh`.

**Spec:** [docs/superpowers/specs/2026-11-28-ticket-versions-design.md](../specs/2026-11-28-ticket-versions-design.md). Ticket: [arcade-base#48](https://github.com/softbody-arcade/arcade-base/issues/48).

## Global Constraints

- A valid version matches `^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`, the format `scripts/publish-release` accepts.
- Versions are compared part by part by digit count, then lexicographically, and the next minor is computed on the decimal string; never shell arithmetic on a version part.
- Milestone titles from the API are data: never evaluated, always quoted.
- Closed issues are exempt from every version check. Drafts and Inbox cards are exempt.
- Every check the script can know up front runs before the first issue, comment, field or lane write of a command. Version writes and the recovery paths this plan specifies are repeatable. `board new` (files a new issue each time) and the existing staging comment keep today's behaviour.
- No change to `release.yml` or `scripts/publish-release`. Pull requests get no version.
- Default version for a card without a usable one: the repo's earliest valid open milestone.
- `scripts/board` keeps working from a game's `base/` (it reads the caller's `board.conf`); no repo-specific values.
- Commit messages end with the attribution line the session's system reminder gives. Write everything as if the repo were public: no home paths, hosts or emails.

## Review Focus

- A milestone title such as `$(touch pwned)` or `1.0.0; touch pwned` in an API response: reported by `check` as not `x.y.z`, never chosen, never executed (observable: the file does not exist). Pinned in Tasks 1 and 4.
- Version parts bigger than a shell integer, and same-length unequal parts (`1.10.0` against `1.20.0`): order correctly; the next minor of `99999999999999999999.9.0` is `99999999999999999999.10.0`. Pinned in Tasks 3 and 6.
- A Build or Review card whose milestone was deleted after triage: `start`, `move` and `result fail` refuse with no write; `priority`, `effort`, `parent`, `block`, `decide` and `move N inbox` still work; each succeeds after `board milestone`. Pinned in Tasks 3 and 5.
- A reopened issue back in Inbox that still carries a released milestone: exempt in `check`, replaced at triage, moved by `release` if still open in that milestone. Pinned in Tasks 3, 4 and 6.
- `release` with only lower open milestones, a closed milestone above every open one, a competing fallback creation, a failed second page, or the same titles and issue numbers in a second repo: moves only this repo's issues, creates one fallback, and a read failure changes nothing. Pinned in Task 6.

## File Structure

- `scripts/board`: all version logic and command changes (one file, as today).
- `tests/board_test.sh`: stub extensions, new helpers and every new test.
- `AGENTS.md`, `docs/ROLES.md`, `docs/README.md`: rules, roles row and the decisions-index row (Task 7).

## Test conventions

Existing helpers in `tests/board_test.sh`: `expect CODE PATTERN args…`, `guard MESSAGE args…` (exit 1, output equals MESSAGE exactly, no write in `$LOG`), `wrote TEXT`, with state set by environment variables such as `LANE=Backlog`. Arguments use the script's capitalised values (`High`, `Medium`, `Low`; `task`, `bug`, `feature` for types). `bad` exits 2 and appends the usage text, so a `bad` message is asserted with `expect 2 MESSAGE …` plus `nowrites`, not `guard`. Task 1 adds three helpers:

- `nowrites`: fails if `$LOG` contains any line `guard` treats as a write, and also a mutating REST call (`api -X` or `api --method` with `POST`, `PATCH`, `PUT` or `DELETE`), `issue create`, `issue edit`. Explicit `GET` reads do not count.
- `absent TEXT`: fails (exit 1, prints the line) if `TEXT` appears in `$LOG`. Use it instead of a bare `! grep`, which cannot fail the script.
- `ordered A B`: fails unless the first `$LOG` line containing `A` comes before the first containing `B`. Choose `A` and `B` so they match the write itself, not a read that mentions the same word (for the milestone creation use `api -X POST repos/softbody-arcade/arcade-base/milestones`; for Effort use `setIssueFieldValue`; for Status `--field Status --value Playtest`).
- `wrote_line REGEX`: fails unless one single `$LOG` line matches `REGEX`; use it to prove two arguments belong to the same invocation. The stub's logger flattens newlines in its arguments to spaces so a multiline issue body stays on one line.

Fixture environment (all optional, defaults in brackets), added in Task 1:
- `STATE` [`OPEN`]: GraphQL card state; the REST issue record uses its lower-case value unless `ISSUE_STATE` is set.
- `MS_TITLE` [`1.0.0`], `MS_STATE` [`OPEN`]: the default card's milestone, GraphQL and REST. `MS_NONE=1` makes the milestone null in both (so a null milestone and an open milestone literally titled `-`, `MS_TITLE=-`, are different fixtures).
- `MILESTONES`: JSON object keyed by repo, each value a list of `{number,title,state}` with state `open` or `closed` [`{"softbody-arcade/arcade-base":[{"number":1,"title":"1.0.0","state":"open"}]}`].
- `ISSUES`: JSON object keyed `<repo>#<number>` overriding the REST record `{state,milestone,pull_request?}` of one issue; `LANES`: JSON object keyed by issue number overriding the board lane of that card. Together they let a parent issue and a recovered check differ.
- `MS_ISSUES`: JSON object keyed `<repo>#<milestone number>`, each value a list of pages (lists of `{number,pull_request?}`); the stub prints all pages concatenated, as `gh api --paginate` does.
- Failure injection: `LIST_FAIL=<repo>#<milestone number>:<page>` (exit 7 when that page is read), `MS_LIST_FAIL=1` (milestone list fails), `EDIT_FAIL=<issue number>` (`issue edit <n> --milestone …` exits 7), `POST_EXISTS=1` (milestone POST prints `already exists (HTTP 422)` and exits 1).
- Stateful stub: the stub also appends every invocation to `$LOG.all`, which `expect` does not clear (a new `fresh` helper clears both at the start of a scenario). The REST milestone of issue `N` is the last `issue edit N --milestone T` in `$LOG.all` if there is one, else the fixture value; with `POST_EXISTS=1` the milestone list contains the raced title once a POST line is in `$LOG.all`. This is how a retry, a race and a partial failure are modelled across invocations.
- Exact invocations the stub must answer: `api --paginate repos/R/milestones?state=all&per_page=100 --jq …` (endpoint `$3`, filter via `api_response "${@:4}"`) and `api --paginate repos/R/issues?milestone=N&state=open&per_page=100 --jq …`; an ordinary issue GET is `api repos/R/issues/N --jq …` (endpoint `$2`, `"${@:3}"`). Put the `milestone=` responder before the existing `'/issues?state='` one, keep the existing `id` (`123`) and the pull-request marker for issue `33` in the issue GET, and keep the `issue edit … --milestone 9.9.9` failure until Task 2 replaces it.
- Fixture mechanics are the implementer's to get right: run each new test, watch it fail for the right reason, and fix the stub when it disagrees with reality, never the product to suit the stub. Where this plan and the real stub or harness disagree, the harness wins and the change is reported in the PR.
- A new deferred check: `issue create` prints `.../issues/${NEW_ISSUE:-1}`; after a `issue create --title Deferred` line is logged, the board shows issue `${NEW_ISSUE}` in Inbox while issue `1` keeps its own lane (`LANES`). Migrate the existing new-defer assertion from `NODE-1` to `NODE-22` in the task that changes this fixture.

## Messages (exact text, used by tests and code)

| Situation | Text | Exit |
|---|---|---|
| Chosen version printed | `Version: x.y.z (given)`, `(kept)` or `(defaulted)` | 0 |
| `--milestone` value not valid | `Invalid version: <value>` (`bad`) | 2 |
| `milestone N <arg>` malformed | `Expected x.y.z or none` (`bad`) | 2 |
| Explicit milestone exists and is closed | `Milestone x.y.z is already released` | 1 |
| Nothing can be chosen | `No open version milestone: pass --milestone x.y.z or run board milestone N x.y.z` (for `new`, which has no number yet: `No open version milestone: pass --milestone x.y.z`) | 1 |
| `classified` without a valid open version | `Set a valid open version first: board milestone N x.y.z` | 1 |
| `milestone N none` on an open issue outside Inbox | `An open issue outside Inbox needs a version` | 1 |
| `result N fail` on a work card without one | `Set a valid open version before a failed playtest: board milestone N x.y.z` | 1 |
| `check` | `#N missing version`, `#N version x.y.z is already released`, `#N version "<title>" is not x.y.z` | 1 |
| Rollover | `#N would move to x.y.z`, `#N moved to x.y.z`, `Milestone x.y.z would be created`, `Milestone x.y.z created` | 0 |

`N` is the issue number.

---

### Task 1: Version functions, card query, helpers and fixtures

**Files:**
- Modify: `scripts/board` (`cards`, `parse`, `load`, new functions beside `classified`)
- Modify: `tests/board_test.sh` (stub, helpers, default card)

**Interfaces:**
- Produces:
  - `valid_version V` (exit 0 when valid);
  - `version_greater A B` (exit 0 when A > B);
  - `next_minor V` (prints `x.(y+1).0`, computed on the decimal string);
  - `repo_milestones` (prints `number<TAB>title<TAB>state` per milestone of `$repo`, state `open` or `closed`, paginated);
  - `load_issue_version NUMBER` (sets `issue_state` `OPEN|CLOSED`, `issue_ms_title` (empty when none), `issue_ms_state` (`open|closed` or empty), from `gh api repos/$repo/issues/NUMBER`);
  - `parse` also sets `mstate` (`OPEN`, `CLOSED`, or `-` when the card has no milestone) between `milestone` and `labels`; `load` also unsets `mstate`.
- Consumes: nothing.

- [ ] **Step 1: Extend the stub and helpers.** Add the fixture environment and the three helpers from **Test conventions**. The default card's milestone comes from `MS_TITLE`/`MS_STATE`/`MS_NONE`; add the `milestones` list, the REST issue record (`state`, `milestone`) honouring `ISSUES`, `LANES` and `STATE`/`ISSUE_STATE`, and the `MILESTONES` and `MS_ISSUES` responders. Refactor `guard` to call `nowrites`.
- [ ] **Step 2: Write the failing tests.**
  - Card query: `expect 0 '' list`, then the log contains `milestone{title state}`.
  - Representation (a null milestone versus one titled `-`) is pinned by Task 4's `check` tests; this task adds no test for it.
  - Ordering and validity are pinned through behaviour in Tasks 3 and 6 (default selection and rollover target), not by sourcing functions out of the script.
- [ ] **Step 3: Run `make test`; the card-query assert fails.**
- [ ] **Step 4: Implement** the six functions with the signatures above, add `milestone{title state}` to the `cards` GraphQL selection and a jq field `(.content.milestone.state // "-")` right after the title, extend `parse`'s `read` list and `load`'s `unset` list. `valid_version` is the Global Constraints regex. `version_greater` splits on dots and, per part, compares length then string. `next_minor` increments the minor part as a decimal string.
- [ ] **Step 5: Run `make test`** — Expected: PASS (existing tests keep their cards; only add `MS_TITLE`/`MS_STATE` where one now needs a different card).
- [ ] **Step 6: Commit** `Board: version functions, milestone state on cards, test helpers`.

### Task 2: `board milestone` creates, tightens and refuses

**Files:**
- Modify: `scripts/board` (the `milestone)` handler, `usage`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Produces: `ensure_milestone VERSION` (reads `repo_milestones`; refuses with `Milestone V is already released` (`refuse`, exit 1) when it exists closed; creates it with `command gh api -X POST repos/$repo/milestones -f title=V` when absent; if that POST fails with `already exists`, reads again and uses the raced milestone if it is open; any other failure exits 2 like every other `gh` failure; does nothing when it exists open).
- Consumes: Task 1 functions.

- [ ] **Step 1: Write the failing tests** (replace the old assertions that `milestone 1 none` succeeds on an open Next card and that a missing milestone fails with `9.9.9`):
  - `expect 2 'Expected x.y.z or none' milestone 1 01.2.3` and `… Later`, each followed by `nowrites`.
  - Missing milestone: `MILESTONES='{"softbody-arcade/arcade-base":[]}' expect 0 '' milestone 1 1.2.0`, then `wrote 'api -X POST repos/softbody-arcade/arcade-base/milestones'`, `wrote 'issue edit 1 --milestone 1.2.0'` and `ordered 'api -X POST repos/softbody-arcade/arcade-base/milestones' 'issue edit 1 --milestone'`.
  - Closed: `guard 'Milestone 1.2.0 is already released' milestone 1 1.2.0` with a closed `1.2.0` in `MILESTONES`.
  - Open and existing: no POST in the log (`absent 'api -X POST'`).
  - `POST_EXISTS=1` with a missing milestone: the POST fails with `already exists`, the list is read again and shows the raced title open, and the edit follows; if the raced title is closed the command refuses (exit 1); a POST failing for another reason exits 2 with no edit.
  - Help: `expect 0 'milestone N x.y.z|none' --help`.
  - `none`: `LANE=Backlog guard 'An open issue outside Inbox needs a version' milestone 1 none`; the same for an off-board open issue (no card, `ISSUES` record open); `LANE=Inbox` succeeds and `wrote 'issue edit 1 --remove-milestone'`; `STATE=CLOSED` succeeds too.
- [ ] **Step 2: Run** `make test` — Expected: the new tests FAIL.
- [ ] **Step 3: Implement** in the `milestone)` case: validate with `valid_version` (`bad 'Expected x.y.z or none'`); run `project` before `load`; `load_issue_version "$n"`; for `none`, refuse when `issue_state` is `OPEN` and the card is not in Inbox (an absent card counts as not Inbox); otherwise `ensure_milestone` then `issue edit "$n" --milestone "$1"`. Update `usage` to `milestone N x.y.z|none`.
- [ ] **Step 4: Run** `make test` — Expected: PASS.
- [ ] **Step 5: Commit** `Board: milestone creates a missing version and refuses released ones`.

### Task 3: Resolve and apply; `triage`, `new` and the version gate

**Files:**
- Modify: `scripts/board` (`classified`, `triage`, `new`, `create`, `usage`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - `reset_issue_version` (sets `issue_state=OPEN`, empty `issue_ms_title` and `issue_ms_state`, for an issue that does not exist yet);
  - `resolve_version [GIVEN]` (read-only; sets `chosen` and `chosen_how` (`given|kept|defaulted`); order from the spec; refuses with the table's messages; uses the loaded `issue_ms_*`);
  - `apply_version NUMBER` (reloads NUMBER's own milestone with `load_issue_version NUMBER`, so it never compares against another issue's; `ensure_milestone "$chosen"`; `issue edit NUMBER --milestone "$chosen"` when that issue's title differs; prints `Version: $chosen ($chosen_how)`; leaves `chosen` and `chosen_how` untouched);
  - `classified` also refuses an open issue without a valid open version;
  - trailing options for `triage` (`--milestone V`) and `new` (`--body-file F` and `--milestone V`, either order, each at most once, after the title).

- [ ] **Step 1: Write the failing tests** (replace the old exact `new`/`triage` output assertions for the extra `Version:` line):
  - Defaults through `triage` (`LANE=Inbox`, `MS_NONE=1`): two open milestones `1.3.0`, `1.4.0` → `Version: 1.3.0 (defaulted)`; open `0.9.0` and `0.10.0` → `0.9.0`; `1.10.0` and `1.20.0` → `1.10.0`; `99999999999999999999.0.0` and `1.0.0` → `1.0.0`. Current open (`MS_TITLE=1.4.0`) → `(kept)`. `--milestone 1.9.0` absent → `(given)` and a POST first. Released current (`MS_STATE=CLOSED`) → replaced by the earliest open. An open title `$(touch "$tmp/pwned")` is skipped as a default and `[[ ! -e $tmp/pwned ]]` afterwards.
  - Refusals leave no write: `--milestone 01.0.0` → `expect 2 'Invalid version: 01.0.0'` and `nowrites`; explicit closed → `guard 'Milestone 1.3.0 is already released'`; none open and none given → `guard 'No open version milestone: pass --milestone x.y.z or run board milestone 1 x.y.z' triage 1 task High`.
  - `triage` of a closed card (`STATE=CLOSED LANE=Accepted`, `MS_NONE=1`, no open milestone at all): exit 0, type/priority/effort written, `absent 'issue edit 1 --milestone'` and no POST; a Done card is still refused with its existing message; a non-Inbox card with a released milestone is replaced.
  - `new` (successful prioritized cases need `LANE=Inbox` or the delayed-Inbox fixture, or `create` refuses with `Issue #1 did not enter Inbox`): `new task High Medium "T" --milestone 1.3.0 --body-file F` and the options in the other order both create with the milestone on the `issue create` invocation (`wrote_line 'issue create.*--title T.*--milestone 1.3.0'`); grammar errors, each `expect 2` plus `nowrites`: `--milestone` twice, `--body-file` twice, `--milestone` with no value, an option before the title; `new task High "T"` defaults to the earliest open one; with no open milestone → `guard 'No open version milestone: pass --milestone x.y.z' new task High "T"` and `absent 'issue create'`; `new task "T"` (no priority) creates with no `--milestone`; `new task "T" --milestone 1.3.0` creates with it. Help: `expect 0 '[--milestone x.y.z]' --help` for both `triage` and `new`. A failure to add the new issue to the board is not retried (documented, not tested).
  - Gate: `MS_NONE=1 LANE=Backlog guard 'Set a valid open version first: board milestone 1 x.y.z' move 1 next`; likewise `LANE=Next MS_NONE=1 … start 1 build` (no assignee write), `LANE=Build MS_NONE=1 … move 1 review`, and each with `MS_STATE=CLOSED`; each then succeeds after a version is present. Still allowed with `MS_NONE=1`: `move 1 inbox`, `priority 1 High`, `effort 1 Low`, `parent 1 2`, `block 1 --by 2`, `decide 1 --file F`.
- [ ] **Step 2: Run** `make test` — Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the functions above. In `triage` and `new`, parse the trailing options before positional handling, validate `--milestone` with `valid_version` (`bad "Invalid version: <v>"`), and for an open issue run `load_issue_version`/`resolve_version` after the existing read-only checks and before the first write, then `apply_version "$n"` for `triage`. `new` with a priority calls `reset_issue_version` and `resolve_version` before `create`, ensures the milestone, and passes `--milestone "$chosen"` to `issue create` through `create`'s extra arguments; it prints `Version: …` after the URL. `classified` appends the version refusal for an open issue (use the loaded card's `mstate` and `milestone`).
- [ ] **Step 4: Run** `make test` — Expected: PASS.
- [ ] **Step 5: Commit** `Board: triage, new and moves require a valid open version`.

### Task 4: `check`, and the In-game check shortcut

**Files:**
- Modify: `scripts/board` (`check` branch of `list|waiting|check`, the In-game check branch of `move`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Tasks 1–3.

- [ ] **Step 1: Write the failing tests.**
  - `check` (exit 1 and the message): `MS_NONE=1 LANE=Backlog` → `#1 missing version`; `MS_STATE=CLOSED` → `#1 version 1.0.0 is already released`; `MS_TITLE='1.0.0; touch pwned'` and `MS_TITLE='$(touch "$tmp/pwned")'` → `#1 version "<title>" is not x.y.z` and no file created; `MS_TITLE=-` (an open milestone literally titled `-`) → `not x.y.z`, while `MS_NONE=1` → `missing version`; an open `LANE=Accepted` card without a version is flagged; a reopened issue in `LANE=Inbox` with `MS_STATE=CLOSED`, and any `STATE=CLOSED` card, are not.
  - In-game check shortcut (`TYPE='In-game check'`, `SIZE=-`) from `LANE=Inbox`, `Backlog` and `Next`, each with a default available and with none: with none, `guard 'No open version milestone: pass --milestone x.y.z or run board milestone 1 x.y.z' move 1 playtest`; with a default (set `MS_NONE=1` so an edit is needed): `ordered 'issue edit 1 --milestone' 'setIssueFieldValue'` and `ordered 'setIssueFieldValue' '--field Status --value Playtest'`; a closed check with no version available (`STATE=CLOSED`) writes no milestone at all.
- [ ] **Step 2: Run** `make test` — Expected: FAIL.
- [ ] **Step 3: Implement** the three `check` messages (open cards, any lane but Inbox, regardless of Accepted) from `mstate` and `milestone`, and in the shortcut branch `load_issue_version "$n"`, `resolve_version`, `apply_version "$n"` before the existing Effort and Status writes, for open issues only.
- [ ] **Step 4: Run** `make test` — Expected: PASS.
- [ ] **Step 5: Commit** `Board: check reports versions; checks get one before Playtest`.

### Task 5: `result`

**Files:**
- Modify: `scripts/board` (the `result)` handler)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Tasks 1–3 (`load_issue_version NUMBER`, `resolve_version`, `apply_version NUMBER`, `ensure_milestone`).

- [ ] **Step 1: Write the failing tests.** Fixture: the work card is issue `1` (lane Playtest) and the deferred or recovered check is issue `22`, with its own `ISSUES` and `LANES` records.
  - Work-card `fail` with `MS_NONE=1`, with `MS_STATE=CLOSED`, and with `MS_TITLE=Later`: each `guard 'Set a valid open version before a failed playtest: board milestone 1 x.y.z' result 1 fail`, no `pr edit`, comment or Status write; after a valid version it proceeds as before; `result 1 pass` needs no version.
  - `defer --checks-file F`: new check created with the milestone on the creation line (`wrote 'issue create --title Deferred'` and `wrote '--milestone 1.0.0'` on the same line) and the work card's version used (`kept`); with the card unversioned the repo default; with neither, the no-version `guard` and `absent 'issue create'`. The report and the comment name check `#22` and go to `#1`.
  - Recovery: an existing open check `22` in Playtest with no milestone → `wrote 'issue edit 22 --milestone 1.0.0'`, no edit of `1`; with a released milestone → repaired; with an invalid title → repaired; already valid and open → no `issue edit 22`, even if the work card differs; open in Inbox or in Backlog → versioned and moved to Playtest (extend the handler, which today moves only from Inbox or an absent lane, to any lane other than Playtest); for every repaired case `ordered 'issue edit 22 --milestone' 'comment'` so the repair precedes the success comments; closed with no default available → no resolve, no edit, no move, same report as today; success only after the repair.
  - `fail` on an In-game check: the Bug is created in Inbox with `--milestone` only when the check's milestone is valid and open; with `MS_NONE=1` the creation line has no `--milestone`.
- [ ] **Step 2: Run** `make test` — Expected: FAIL.
- [ ] **Step 3: Implement.** Work-card `fail`: `load_issue_version "$n"` and refuse before the PR edit. `defer`: find `existing` first; if it exists, `load_issue_version "$existing"` and skip everything when it is closed; resolve a version only when one is needed (new check, or an existing open check whose milestone is not valid and open), using the work card's own data (`load_issue_version "$original"`), before any write; a new check gets `--milestone "$chosen"` passed to `create` (after `ensure_milestone`); a recovered open check that needs one gets `apply_version "$existing"`. `find_created`'s rows stay numbers only; read the recovered check's state with `load_issue_version`. The stub's `api repos/*/issues/<n>` answers for 22 come from `ISSUES`. Bug creation passes `--milestone` only when the check's version is valid and open.
- [ ] **Step 4: Run** `make test` — Expected: PASS.
- [ ] **Step 5: Commit** `Board: result keeps versions on cards and deferred checks`.

### Task 6: `release` rollover

**Files:**
- Modify: `scripts/board` (the `release)` case, new rollover functions, `usage`)
- Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: Task 1 and 2 functions.
- Produces: `rollover_plan` (read-only: collects, then plans; sets `roll_create` (title or empty) and `roll_moves` (lines `N source target`); fails before anything is written when a read fails); `rollover_apply` (creates the fallback once with `ensure_milestone`, re-reads each issue right before `issue edit`, skips changed or closed ones, prints the Rollover lines; with `$dry_run` true it prints the `would` lines and writes nothing).

- [ ] **Step 1: Write the failing tests** (a released tag, milestone and issue records keyed by repo):
  - A closed `1.0.0` (number 1) with open issues `7` (Backlog), `8` (Inbox) and `9` (not on the board), and an open `1.1.0`: `#7 moved to 1.1.0` … and `issue edit 7 --milestone 1.1.0`; the same call with two pages of issues moves every issue.
  - Multiple higher open targets (`1.2.0`, `1.1.0`, `1.10.0` above closed `1.0.0`) → `1.1.0`. None above → one `Milestone 1.1.0 created` (a single POST, before the moves). Two closed sources (`1.0.0`, `0.9.0`) needing one fallback → one POST. Only lower open milestones plus a closed one above every open one → the next minor of the highest of all; `99999999999999999999.9.0` closed → `99999999999999999999.10.0`.
  - A pull request in the list, a closed issue, and another repo with identical titles and numbers (`OTHER_REPO`) are untouched (assert exact `issue edit` lines).
  - Read-before-write: `ordered` the last list read before the first `issue edit`; `MS_LIST_FAIL=1`, and `LIST_FAIL=…:2` (second page), make `release` exit non-zero with **zero** writes: no `item-edit`, no archive, no `issue edit`, no POST. A failure on the second `issue edit` (`EDIT_FAIL=8`) leaves `7` moved; the retry with the source still closed moves `8` and not `7` again.
  - Competing creation: `POST_EXISTS=1` with a missing fallback reads the list again and moves the issues.
  - An issue whose REST milestone changed after the plan (`ISSUES` record) is skipped, and so is one that closed after collection while still holding the source milestone.
  - A closed milestone `1.99999999999999999999.0` with nothing above it creates `1.100000000000000000000.0` (a minor longer than a shell integer, ending in nines, carries).
  - Help: `expect 0 'rolls' --help` mentions that release rolls open issues.
  - A reopened issue in Inbox still holding the closed milestone is moved; `--dry-run` prints `would` lines and writes nothing (no POST, no edit, no item-edit).
- [ ] **Step 2: Run** `make test` — Expected: FAIL.
- [ ] **Step 3: Implement** `rollover_plan` and `rollover_apply` per the spec (milestones `state=all` and each closed valid milestone's open non-PR issues, every page, collected first; the re-read before each update checks that the issue is still open and still holds the source milestone; the target is the lowest open valid milestone strictly above the source, else one shared `next_minor` of the highest valid version among all). In `release)`, call `rollover_plan` right after the board plan is built and before the apply loop, call `rollover_apply` after the loop, and in dry-run print both. The POST conflict path needs `command gh` (the `gh` wrapper exits on failure). Update `usage` to say that release rolls open issues.
- [ ] **Step 4: Run** `make test` — Expected: PASS.
- [ ] **Step 5: Commit** `Board: release rolls open issues to the next version`.

### Task 7: Rules, roles, decisions index, help

**Files:**
- Modify: `AGENTS.md`, `docs/ROLES.md` (Board workflows row, line 101), `docs/README.md`
- Modify: `scripts/board` (`usage`); Test: `tests/board_test.sh`

**Interfaces:**
- Consumes: the finished commands.

- [ ] **Step 1: Read `scripts/board --help` through the existing fixture** and confirm each help assertion added in Tasks 2, 3 and 6 still passes together; fix any `usage` wording that reads wrongly now that all three changes are in.
- [ ] **Step 3: Edit `AGENTS.md`** per the spec's **Rules** paragraph: the Milestone bullet states what a version means and when it is required (replacing "The maintainer assigns it when committing to a release"); "Every issue outside Inbox has a type, a priority and an effort" gains the version; the Inbox and Backlog lane rows say triage sets it; the release-PR check becomes "read the open issues; finish what should ship, the rest rolls on"; the cross-repo sentence goes under Parent and sub-issues; the **Releases** view with Slice by Repository is named beside the Quick wins view. Relative links must resolve from `base/`.
- [ ] **Step 4: Edit `docs/ROLES.md`** line 101: the Board workflows row gains the version requirement and that `scripts/board release` rolls open issues to the next version, and its last cell no longer reads "Board only" but "Board, and issue milestones through the maintainer's `scripts/board`".
- [ ] **Step 5: Add the `docs/README.md` row** under **Decisions across games**: "Every open issue outside Inbox has a version; a milestone is the earliest release it could ship in", linking `https://github.com/softbody-arcade/arcade-base/issues/48#issuecomment-7238876205`.
- [ ] **Step 6: Run** `make test`, `make privacy` and the offline link check CI runs (see `docs/DEVELOPMENT.md`) — Expected: all pass.
- [ ] **Step 7: Commit** `Rules: every open issue outside Inbox has a version`.

### Task 8: Whole-branch verification and hand-off

**Files:** none.

- [ ] **Step 1:** `make test && make privacy` from the worktree — Expected: PASS; `git status` clean.
- [ ] **Step 2:** The draft PR already exists from the first push (title `Always assign a version to tickets outside Inbox`, body `Fixes #48`). Update its body with the tests migrated in Task 1 to 3, the unchanged `release.yml`, how games are affected (they get it when they move their `base/` pin; a game with its own `scripts/board` copy files its own follow-up), and what is left for the maintainer.
- [ ] **Step 3:** Mark the PR ready only after a fresh reviewer from the counterpart family of whoever actually wrote the implementation (`agent-usage review <author> …`) reviews the whole branch diff against the spec with extra scrutiny on security, rollover and the stub's realism, and posts the review on the PR. After blocking fixes, review the final head again; the merge gate needs the review on the head SHA that merges.
- [ ] **Step 4 (maintainer, not in the PR):** after merge, slice the **Releases** view by Repository in the web interface and note it on #48; confirm with a throwaway pair that same-named milestones of two repos stay apart in the group-by. Audit each repo's open issues directly (`gh issue list --state open --json number,milestone`, issues outside Inbox must all have an open milestone); a game that still has the old `scripts/board` cannot verify it with `board check`, so wait until it adopts this version. The backfill is already done.
