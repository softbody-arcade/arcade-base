# Release installer: how a server installs Softbody Arcade releases

Status: design, built after Cops and Robbers 3.0.0 is live ([#45](https://github.com/softbody-arcade/arcade-base/issues/45), blocked by [cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56)).

This spec is for the person deciding how Softbody Arcade releases reach a server. It covers what every release must contain, which releases a server may trust, and what the installer must guarantee. How one particular server runs the installer (its admin tool, its process setup, its paths) is private to that server and is not described here; this spec calls that part **the server's admin tool** (where admins see releases and press Install) and **the supervisor** (the process that starts BeamMP Server, keeps running beside it, can stop it, and reads its log).

## Why

Releases are published by the release workflow, but a server is updated by hand: download, unpack, keep the settings, restart, read the log, and undo it if something broke. That is slow and easy to get wrong, and from 3.0.0 on a server runs the base plus one mod per game, so every update touches more than one package. The installer makes each update one press of a button, with the checks and the undo done the same way every time.

## Goals

- An admin sees each new trusted release of the base and of every game, and installs it with one press.
- Only releases built by the release workflow from `main` are ever offered.
- An install never resets settings, the leaderboard or other saved data.
- An install happens when the server is empty, or right away if the admin chooses.
- A release that fails to load is rolled back by itself, and the admin sees what happened.
- A server can go back to the version that ran before, unless the saved-data format changed since (decision 9).

## Non-goals

- Installing on a timer, or without an admin pressing Install (decision 1).
- Reporting installs to GitHub (decision 4). The admin tool shows the result.
- Installing a game and a newer base together in one step (decision 5).
- Moving a server from Cops and Robbers 2.x to 3.0.0: that move is done by hand, with a clean install ([cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56)).
- Updating BeamMP Server itself, or third-party mods.
- Installing releases from outside the `softbody-arcade` organization.

## Anti-goals

- A release is offered or installed whose files weren't built by the release workflow on `main` of the expected repo from the tag's commit: files built on a branch or by a pull request closed without merging, or changed after the build. (Who published the release page doesn't matter, decision 6.)
- An install kicks players out of a round they are playing, unless the admin chose that.
- An update resets server settings, player data or the leaderboard.
- A failed install leaves the server down, or running a half-replaced plugin, without the admin knowing.
- Two different packages are half-installed at the same time.
- Anything about how or where a live server runs ends up in a public repo.

## Decisions (the maintainer's)

Recorded on [#45](https://github.com/softbody-arcade/arcade-base/issues/45).

1. **Manual install.** The installer lists each new release that passes the trust check and installs it only when an admin presses Install. Nothing installs on a timer. (2026-11-28)
2. **Scope.** Every Softbody Arcade release, the base included. (2026-11-28)
3. **Timing.** Designed now, built after Cops and Robbers 3.0.0 is live. Until then the live server stays on the release it runs. (2026-11-28)
4. **No GitHub reporting.** The server's admin tool shows each install's result; the server holds no GitHub write token. (2026-11-28)
5. **One package at a time.** A game release that needs a base the server doesn't have can't be installed until that base is installed first. Each install is checked and rolled back on its own. (2026-11-28)
6. **Trust.** Only files built by the release workflow on `main` from the tagged commit are installed, proven by GitHub artifact attestations. What counts is where the files came from, not who published the release page: a release page made by hand carrying the genuine, attested files of the tagged commit is acceptable; anything else is refused. (2026-11-27, refined 2026-11-28)
7. **Shape.** The admin tool stages a release; the supervisor swaps it in while BeamMP Server is stopped, checks the log once it runs, and rolls back. (2026-11-28)
8. **Every newer release is listed.** The admin tool lists every newer trusted release of each package, marks whether it fits what is installed, and points out the newest playable set. (2026-11-28)
9. **Saved data.** A release whose first run changes a saved-data format says so in `release.json` (as a data format number, below). An automatic rollback restores the data copy taken at the swap. Going back by hand across such a release is disabled with the reason; otherwise it keeps the current data. (2026-11-28)
10. **Going back by hand.** A **Previous version** button stays: it is the only way back from a release that loads but plays badly without a hotfix release, and it reuses the copy of the version that ran before. (2026-11-28)

## How it works

### What a release contains

Every Softbody Arcade repo (the base and each game) publishes releases with the same shape, built by its release workflow:

| Asset | What it is |
|---|---|
| `<Name>.zip` | the client mod, installed into `Resources/Client` |
| `<Name>-server.tar.gz` | the server plugin folder(s), installed into `Resources/Server` |
| `release.json` | the install manifest (below) |
| `SHA256SUMS` | the SHA-256 of the other three assets |

Cops and Robbers already publishes the first two and `SHA256SUMS`; the base publishes no assets until it ships a mod.

**Proposed** `release.json`:

```json
{
  "id": "cops-and-robbers",
  "name": "Cops and Robbers",
  "version": "3.1.0",
  "needsBase": "0.4.0",
  "server": ["CopsAndRobbers"],
  "client": ["CopsAndRobbers.zip"],
  "keep": ["CopsAndRobbers/config.json", "CopsAndRobbers/data"],
  "dataFormat": 3
}
```

- `id` matches the repo name; `version` matches the tag without its `v`.
- `needsBase` is what the game's manifest in Lua declares (an exact version while the base is 0.x, decision 9 of the [manager spec](2026-11-27-arcade-manager-design.md); a range from 1.0). The release workflow generates `release.json` from the same source, and a test checks they agree. The base's own `release.json` has no `needsBase`.
- `server` and `client` name every folder and ZIP the package owns. An install replaces exactly these, as a whole, so files a newer release removed don't linger.
- `keep` lists the paths inside those folders carried over from the installed version (when present) instead of taken from the release. The manager spec proposes storing settings outside the install folders; once a package does that, its `keep` can shrink to nothing. An install carries over the installed version's `keep` paths as well as the new release's, so a release that drops a path from `keep` (because it moved those settings elsewhere) still finds the old file on its first run and moves the values itself; the release after it no longer receives the file.
- **Saved data outside the install folders** lives in the package's own saved-data folder: one folder per package, named by its `id`, under the saved-data root where the manager keeps settings and records (where that root is follows the manager's storage). The installer never replaces it; it copies the whole folder at the swap, so an automatic rollback can restore it. A release doesn't list it.
- `dataFormat` is a whole number the package raises in every release that changes the format of its saved data in `keep` or its saved-data folder (decision 9). Going back by hand is allowed only when the version gone back to has the same `dataFormat` as the installed one, so a skipped release is covered too: installing C straight from A, when B changed the format, leaves C with a higher number than A.

### Ownership

The installer keeps an inventory of what each installed package owns: its folders, its ZIPs, its saved-data folder, its `needsBase` and its `dataFormat`. It never takes a release's word for it alone.

- Every `server` and `client` entry is one plain name (no `/`, no `..`). Archive entries and `keep` paths must lie inside the named folders. Paths are checked after resolving links, so a link can't lead outside.
- A release that names a folder or ZIP another package owns is refused, and so is one that names a destination which already exists but is in no inventory (for example a hand-installed mod with the same name).
- When a new release no longer names a folder or ZIP the old one owned, the swap removes it, and the recovery record covers that removal too.
- **Adopting a hand install.** A package installed before the installer existed (3.0.0 is installed by hand) has no inventory. The first time the admin tool sees it, it proposes one: from the `release.json` of the release matching the installed version, used only if that release passes the trust checks below; otherwise from the folders and ZIPs found under the package's names, with its `dataFormat` unknown. A game's `needsBase` comes from the manager's line for it in the last launch's log (below), so it is known either way. The admin confirms it before any install of that package; nothing is replaced until then. An unknown `dataFormat` never matches, so **Previous version** back to that hand install stays disabled.

### Which releases are offered

The admin tool holds a list of repos to watch (the base and each installed game). For each, it lists the releases newer than the installed version that pass every check:

1. Published, not a draft or prerelease, version `x.y.z`, and the tag is `v` plus that version.
2. **Built by the release workflow on `main` from the tag's commit** (decision 6). The release workflow attests every asset with GitHub's artifact attestations. The installer accepts an asset only when its attestation was signed by `.github/workflows/release.yml` running on `refs/heads/main` of the expected repo and the attested source commit is the tag's commit. A merged release pull request and a dispatch on `main` both run on `refs/heads/main` with the workflow files from `main`; a run from a branch or from a pull request closed without merging (which uses the pull request's own workflow files) runs on another ref and is refused. `github-actions[bot]` as the release's author proves nothing on its own, since every workflow run publishes as it, and who published the release page doesn't matter. Rerunning the original workflow run keeps its commit and passes; a fresh dispatch after `main` has moved on attests a different commit and is refused.
3. The tag's commit is on `main`. The release page's "target" can't be used for this: the release workflow creates the tag through the API, and GitHub reports the default branch as the target either way.
4. All four assets are present and attested (check 2); the client ZIP, the server tarball and `release.json` match their lines in `SHA256SUMS`; `release.json` matches the tag.

Every newer release that passes is listed, newest first, marked with whether it fits what is installed (decision 8). Skipping versions is fine; each release is complete. While the base is 0.x, games pin an exact base version, so the newest base and the newest game don't always match: with base 0.3 installed, a newest game needing 0.4 and a newest base of 0.5, the admin tool points out the newest playable set ("install base 0.4, then the game"). Installs stay one at a time (decision 5); because the server has no playable game between the two, the second install's restart can be "now".

Next to each release the admin tool shows its notes and, for a game, whether the server's base meets `needsBase`. When it doesn't, Install is disabled with the reason ("needs base 0.4.0, the server has 0.3.0; install that first"). Before a base install, the admin tool lists the installed games that the new base would leave out, using their `needsBase`.

### Installing

1. **Stage.** The admin presses Install. The admin tool downloads and checks the release (above), unpacks it into a staging area outside `Resources` but on the same filesystem as the live folders, writes a list of the staged files with their checksums, flushes the tree and the list to disk, and only then records it as staged. The supervisor checks the staged tree against that list before any swap and discards a stage that doesn't match. It never writes to the live plugin folders. Only one package can be staged at a time. **Previous version** stages a verified copy of the previous-version copy, so the swap never reads from a copy it might replace.
2. **Restart.** The admin chooses "when the server is empty" (the default) or "now". Players are never kicked by an install they didn't see coming.
3. **Swap (supervisor, while BeamMP is stopped).** If a release is staged and matches its list:
   1. Note the pre-install state from the last launch: which packages loaded, and which games were left out and why.
   2. Build the swap snapshot: copy the installed folders and ZIPs, the `keep` paths and the saved-data folder, record which of the release's folders and ZIPs don't exist yet, verify it against the originals, and flush it. The previous-version copy (below) stays untouched.
   3. Write the recovery record (below).
   4. Bring the `keep` paths over into the staged tree: for an install, the installed version's and the new release's `keep` paths, from the installed version where present; for **Previous version**, mirror them exactly, so files deleted since the snapshot stay deleted. Flush.
   5. Replace each `server` folder and `client` ZIP with the staged one, and remove those the new release no longer names.
4. **Verify (supervisor, after BeamMP starts).** Read the log of this launch only, from the point the supervisor started BeamMP. The launch is compared with an expected state: for an install or **Previous version**, the state the target versions should give (the target package loaded; each game loaded or left out according to its `needsBase` and the base that will be installed); for an automatic rollback, the pre-install state. Each launch ends in one of three outcomes:
   - **Healthy:** every package reaches its expected state, and no Lua error follows during a settle period after the last of them.
   - **Failed:** after BeamMP has logged its own start, a Lua error appears before or during the settle period, a package ends up other than expected (the target package left out, a game loaded or left out against expectation), the time limit passes before every package has reached its expected state, or BeamMP exits. The supervisor rolls back at once.
   - **Didn't start:** BeamMP exits or hangs before it logs its own start. This counts one missing start for the staged version; the supervisor launches again, and after a fixed number of missing starts it rolls back with the reason "didn't start".
5. **Finish.** When healthy, the swap snapshot becomes the previous-version copy with one rename, the old previous-version copy is removed, the installed version is recorded, and the result is shown in the admin tool.

### Rolling back

- **Two copies.** The **previous-version copy** is the version that ran before the installed one; it changes only when an install finishes healthy. The **swap snapshot** is the installed version as it was at the swap, taken for each install. So a failed install never costs the previous version: with B installed and A as its previous version, a failed install of C returns to B, and A is still the previous version.
- **Automatic.** On a failed launch or the missing-start limit, the supervisor restores the swap snapshot exactly: the old folders and ZIPs, the `keep` paths and the saved-data folder as they were at the swap, and removes the folders and ZIPs the failed version added. It restarts and verifies against the pre-install state: each package must be as it was before, loaded if it loaded and left out for the same reason if it was left out. A game update that fails after a base install therefore returns to the old game left out, which is the state before the install, and counts as confirmed. The swap snapshot is then discarded. The admin tool shows "3.1.0 failed to load (reason); back on 3.0.0".
- **Rollback not confirmed.** If the restored server doesn't match the pre-install state, the installer stops: the admin tool offers no installs until an admin has looked and cleared it.
- **Manual.** A **Previous version** button reinstalls the previous-version copy through the same stage, restart and verify steps, with the current `keep` paths mirrored and the current saved-data folder kept (decision 10). It respects the base check like any install, and is disabled with the reason when the previous-version copy's `dataFormat` differs from the installed one or is unknown (decision 9). When it finishes healthy, the version it replaced becomes the previous version.
- A release that failed to load stays listed, marked with its failure, so the admin can try again after fixing whatever was wrong outside the release.

### Recovery record

The supervisor can be killed at any point (power loss, a crash, the server being stopped). Before each rename it writes a small record of what it is about to do: the package, the old and new version, and the step. The record is written to a temporary file and renamed into place, so it is never half-written. At every start the supervisor reads the record first and either finishes the swap or reverts it, so the server never starts with a mix of two versions, and the previous-version copy is replaced only by a finished, healthy install. A finished install clears the record only after the new version is recorded as installed.

A rename alone doesn't survive power loss, so the flush order is part of the design. The staged tree and its list are flushed before the stage is recorded; the swap snapshot is flushed before the record that refers to it; the record is flushed each time it is written; every rename is followed by flushing the directories on both sides of it; and the installed-version record is flushed before the recovery record is cleared. Staging, both copies and the live folders share one filesystem, so every rename is atomic. Tests kill the process between steps; safety against power loss rests on that flush order.

### Outages

A download, checksum or GitHub outage leaves nothing half-done: the release stays offered, the admin sees the error and can retry. A restart that doesn't happen (the server never became empty, or BeamMP wasn't stopped) leaves the release staged with nothing swapped; the admin can wait, restart now or cancel. Neither marks a release as failed; only a launch that failed or the missing-start limit does.

### The base's part

The installer relies on two things from the manager:

- **Loaded lines.** At start the manager logs one line per package it loaded, with id and version, and one line per game it left out, with the reason. A game's line also names the base it needs, so the installer knows it even for a hand install. **Proposed** format: `[arcade] loaded base 0.4.0`, `[arcade] loaded cops-and-robbers 3.1.0 (needs base 0.4.0)` and `[arcade] left out street-racing 1.2.0: needs base 0.4.0, the server has 0.3.0`. Packages from before the manager (Cops and Robbers 2.x) are out of scope (non-goals).
- **Shared state.** The installer only replaces whole folders while BeamMP is stopped, so the shared Lua state never sees a half-changed plugin.

## Approaches considered

| Part | Chosen | Rejected |
|---|---|---|
| When to install | An admin presses Install (decision 1) | A timer installing every stable release (would deploy releases meant to stay local, such as the 2.x split steps); an allowed version range in the server's config; the timer off until 3.0.0 |
| Where the swap happens | The supervisor, before BeamMP starts (decision 7) | The admin tool replacing files while BeamMP runs (BeamMP re-runs a changed top-level plugin file and notifies plugins of other changed files, mid-round); a separate updater with control over the whole server (far more power than copying folders needs) |
| A game needing a newer base | One package at a time (decision 5) | Installing both together in one restart, rolled back together (fewer clicks, more machinery) |
| Reporting | The admin tool only (decision 4) | GitHub deployments or a pinned status issue (needs a write token on the server) |
| Trust proof | GitHub artifact attestations from `release.yml` on `main`, bound to the tag's commit (decision 6) | The release's author and tag only (any workflow run publishes as `github-actions[bot]`); a signing key in an environment only `main` may use (a secret to guard and rotate) |
| Which releases are listed | Every newer trusted release, marked with whether it fits (decision 8) | Only the newest (can't reach a playable pair when the newest base and game don't match) |
| Saved data and going back | A data format number in `release.json`; automatic rollback restores the data copy; going back by hand blocked across a change (decision 9) | Every release keeps data readable by the version before it (a rule on every release, hard to test) |
| Install manifest | `release.json` beside the assets | Conventions only (can't express `keep` or several folders); reading the manifest out of the Lua (needs unpacking and parsing Lua before trusting it) |

## Open questions (the maintainer's)

None.

## Proposed (choices made in this design; correct any)

- Only admins of the server's admin tool may install or go back.
- One package staged at a time; per package one previous-version copy, plus a swap snapshot while an install runs.
- The default restart is "when the server is empty".
- Any Lua error in the log during verify counts as a failure, whichever package logged it.
- A release that failed to load stays listed, marked.
- The admin confirms the inventory of a hand-installed package before its first install.
- Rolling back restores saved data as it was at the swap; going back by hand keeps the current saved data and mirrors the current `keep` paths.
- A player who joins in the seconds between the empty check and the stop is disconnected by the restart; that window is accepted.

## Choices left to the builder

- The verify time limit, the settle period, the number of missing starts before a rollback, and which BeamMP log line marks its own start.
- Where the staging area, rollback copies, recovery record and status file live, as long as they are outside `Resources` and every path an install replaces, and on the same filesystem as the live folders.
- How the admin tool shows releases, notes and results.
- How often the admin tool checks GitHub (also on demand), within GitHub's unauthenticated rate limit.
- The format of the status the supervisor hands to the admin tool.

## Engine assumptions to check

1. BeamMP Server watches server plugin files while it runs: it re-runs a changed top-level Lua file and fires `onFileChanged` for other changed files ([TPluginMonitor.cpp, v3.9.3](https://github.com/BeamMP/BeamMP-Server/blob/v3.9.3/src/TPluginMonitor.cpp#L47-L81)). This is why the swap happens only while BeamMP is stopped. Nothing to probe; recorded as the reason.
2. A Lua error in a plugin shows up in the server log with a marker the supervisor can match, both at load and in the first ticks. Check on the local test server with a deliberately broken release.
3. BeamMP sends the replaced client ZIP to players who join after the restart, with no cached copy getting in the way. Check with one client across an install.

## Automated acceptance

Tests with fixture releases and a fake server folder, no network:

- **Trust.** Each check rejects its own bad case: a draft, a prerelease, a tag that doesn't match `release.json`, a tag not on `main`, a missing asset, a checksum mismatch, and an asset signed by another workflow, from another ref or from another commit than the tag's, or not signed at all. A release page made by hand carrying the genuine, attested files passes, and so does a rerun of the original release run.
- **Listing.** A game that doesn't fit the installed base is listed but can't be staged; a base install lists the games it would leave out; with a 0.x base the newest playable set is pointed out (fixture: base 0.3 installed, a game needing 0.4, newest base 0.5).
- **Ownership.** A release is refused when it names a path that isn't one plain name, another package's folder or ZIP, an existing destination in no inventory, an archive entry outside its folders, a `keep` path outside them, or a link leading outside. A hand install can't be updated until its inventory is confirmed; an adopted `release.json` that fails the trust checks isn't used; an adopted install with unknown `dataFormat` can't be gone back to by hand.
- **Stage.** A stage whose files don't match its list (power loss while waiting for the restart) is discarded, never swapped in.
- **Settings moving out.** A release that drops `config.json` from `keep` after moving settings elsewhere: starting from a non-default setting, the value is the same after the install, and the release after it no longer receives the old file.
- **Adoption.** An adopted game's `needsBase` comes from its line in the last launch's log, and a base install warns about it like any other game.
- **Swap.** A successful swap keeps every `keep` path and the saved-data folder, removes files and whole folders the new release dropped, and makes the swap snapshot the previous-version copy.
- **Crashes.** Killing the supervisor after each step, including while the swap snapshot is built, at the finish, and during a **Previous version**, and starting again always ends on one whole version, the old or the new, with the previous-version copy intact.
- **Verify.** A launch that logs the loaded line and then a Lua error within the settle period fails; log lines from an earlier launch never count; a failure after BeamMP's own start rolls back at once; exits before it count as missing starts and roll back with "didn't start" at the limit; a launch where the target loads but another package misses its expected state by the time limit fails. **Previous version** from base 0.4 to 0.3 expects the game pinned to 0.3 to load again, and passes when it does.
- **Rollback.** An automatic rollback restores `keep` and the saved-data folder as they were at the swap, and removes folders and ZIPs the failed version added. With B installed and A as its previous version, a failed install of C returns to B and **Previous version** still offers A. A game update that fails after a base install returns to the old game, left out as before, and installs stay available. A rollback that doesn't match the pre-install state stops further installs until cleared.
- **Going back.** **Previous version** mirrors the current `keep` paths (a file deleted inside a kept folder since the snapshot stays deleted) and keeps the current saved-data folder, and is refused when the `dataFormat` differs, including going back from C to A when B, which was skipped, changed the format.
- **Outages.** An outage at download or checksum leaves the release offered; a restart that doesn't happen leaves it staged; neither marks it failed.
- **Every repo.** `release.json` agrees with the Lua manifest and the tag.

## Drills before the first live install

Every failure path above is drilled on a test copy of the server, never the live one, before the installer is used on the live server: a broken release, a release with a Lua error, a crash between each pair of renames, a server that won't start, an unconfirmed rollback, and a download or checksum failure. The admin decides when the installer goes live.

## Links

- [Manager spec](2026-11-27-arcade-manager-design.md): plugin loading, versions, settings storage.
- [cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56): the move to 3.0.0, by hand.
- [GitHub artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds).
