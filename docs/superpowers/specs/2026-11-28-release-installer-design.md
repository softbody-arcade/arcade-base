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
- A server can always go back to the version that ran before.

## Non-goals

- Installing on a timer, or without an admin pressing Install (decision 1).
- Reporting installs to GitHub (decision 4). The admin tool shows the result.
- Installing a game and a newer base together in one step (decision 5).
- Moving a server from Cops and Robbers 2.x to 3.0.0: that move is done by hand, with a clean install ([cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56)).
- Updating BeamMP Server itself, or third-party mods.
- Installing releases from outside the `softbody-arcade` organization.

## Anti-goals

- A release that was published by hand, built on a branch or from a pull request, or whose files were changed after the build, is offered or installed.
- An install kicks players out of a round they are playing, unless the admin chose that.
- An update resets server settings, player data or the leaderboard.
- A failed install leaves the server down, or running a half-replaced plugin, without the admin knowing.
- Two different packages are half-installed at the same time.
- Anything about how or where a live server runs ends up in a public repo.

## Decisions (the maintainer's)

Recorded on [#45](https://github.com/softbody-arcade/arcade-base/issues/45).

1. **Manual install.** The installer lists each new release that passes the trust check and installs it only when an admin presses Install, like the update button the server's admin tool already has for other mods. Nothing installs on a timer. (2026-11-28)
2. **Scope.** Every Softbody Arcade release, the base included. (2026-11-28)
3. **Timing.** Designed now, built after Cops and Robbers 3.0.0 is live. Until then the live server stays on the release it runs. (2026-11-28)
4. **No GitHub reporting.** The server's admin tool shows each install's result; the server holds no GitHub write token. (2026-11-28)
5. **One package at a time.** A game release that needs a base the server doesn't have can't be installed until that base is installed first. Each install is checked and rolled back on its own. (2026-11-28)
6. **Trust.** Only files built by the release workflow on `main` from the tagged commit are installed, proven by GitHub artifact attestations. What counts is where the files came from, not who published the release page: a release page made by hand carrying the genuine, attested files of the tagged commit is acceptable; anything else is refused. (2026-11-27, refined 2026-11-28)
7. **Shape.** The admin tool stages a release; the supervisor swaps it in while BeamMP Server is stopped, checks the log once it runs, and rolls back. (2026-11-28)
8. **Every newer release is listed.** The admin tool lists every newer trusted release of each package, marks whether it fits what is installed, and points out the newest playable set. (2026-11-28)
9. **Saved data.** A release whose first run changes a saved-data format says so in `release.json`. An automatic rollback restores the data copy taken at the swap. Going back by hand across such a release is disabled with the reason; otherwise it keeps the current data. (2026-11-28)
10. **Going back by hand.** A **Previous version** button stays: it is the only way back from a release that loads but plays badly without a hotfix release, and it reuses the rollback copy. (2026-11-28)

## How it works

### What a release contains

Every Softbody Arcade repo (the base and each game) publishes releases with the same shape, built by its release workflow:

| Asset | What it is |
|---|---|
| `<Name>.zip` | the client mod, installed into `Resources/Client` |
| `<Name>-server.tar.gz` | the server plugin folder(s), installed into `Resources/Server` |
| `release.json` | the install manifest (below) |
| `SHA256SUMS` | the SHA-256 of every other asset |

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
  "data": [],
  "changesData": false
}
```

- `id` matches the repo name; `version` matches the tag without its `v`.
- `needsBase` is what the game's manifest in Lua declares (an exact version while the base is 0.x, decision 9 of the [manager spec](2026-11-27-arcade-manager-design.md); a range from 1.0). The release workflow generates `release.json` from the same source, and a test checks they agree. The base's own `release.json` has no `needsBase`.
- `server` and `client` name every folder and ZIP the package owns. An install replaces exactly these, as a whole, so files a newer release removed don't linger.
- `keep` lists the paths inside those folders carried over from the installed version (when present) instead of taken from the release. The manager spec proposes storing settings outside the install folders; once a package does that, its `keep` can shrink to nothing.
- `data` lists saved-data locations outside the install folders (relative to the server folder), such as the per-game settings file the manager spec proposes. They are never replaced, but they are copied at the swap with the `keep` paths, so an automatic rollback can restore them.
- `changesData` is `true` when the release's first run changes the format of saved data in `keep` or `data` (decision 9).
- **Ownership.** The installer keeps an inventory of the folders and ZIPs each installed package owns, and never takes a release's word for it alone. It rejects a release when an entry in `server` or `client` is not one plain name (no `/`, no `..`), when it names a folder or ZIP another installed package owns, when an archive entry falls outside the named folders, or when a `keep` path falls outside them. When a new release no longer names a folder or ZIP the old one owned, the swap removes it, and the recovery record covers that removal too.
- **Adopting a hand install.** A package installed before the installer existed (3.0.0 is installed by hand) has no inventory. Its first Install takes the new release's own `server` and `client` lists as what the old version owned.

### Which releases are offered

The admin tool holds a list of repos to watch (the base and each installed game). For each, it lists the releases newer than the installed version and offers only those that pass every check:

1. Published, not a draft or prerelease, version `x.y.z`, and the tag is `v` plus that version.
2. **Built by the release workflow on `main` from the tag's commit** (decision 6). The release workflow attests every asset with GitHub's artifact attestations. The installer accepts an asset only when its attestation was signed by `.github/workflows/release.yml` running on `refs/heads/main` of the expected repo and the attested source commit is the tag's commit. A merged release pull request and a dispatch on `main` both run on `refs/heads/main` with the workflow files from `main`; a run from a branch or from a pull request closed without merging (which uses the pull request's own workflow files) runs on another ref and is refused. `github-actions[bot]` as the release's author proves nothing on its own, since every workflow run publishes as it. A dispatch retry after `main` has moved on attests a different commit and is refused; that case needs a new patch release.
3. The tag's commit is on `main`. The release page's "target" can't be used for this: the release workflow creates the tag through the API, and GitHub reports the default branch as the target either way.
4. All four assets are present; after downloading, every asset matches `SHA256SUMS` and `release.json` matches the tag.

Every newer release that passes is listed, newest first, marked with whether it fits what is installed (decision 8). Skipping versions is fine; each release is complete. While the base is 0.x, games pin an exact base version, so the newest base and the newest game don't always match: with base 0.3 installed, a newest game needing 0.4 and a newest base of 0.5, the admin tool points out the newest playable set ("install base 0.4, then the game"). Installs stay one at a time (decision 5); because the server has no playable game between the two, the second install's restart can be "now".

Next to each release the admin tool shows its notes and, for a game, whether the server's base meets `needsBase`. When it doesn't, Install is disabled with the reason ("needs base 0.4.0, the server has 0.3.0; install that first"). Before a base install, the admin tool lists the installed games that the new base would leave out, using their `needsBase`.

### Installing

1. **Stage.** The admin presses Install. The admin tool downloads and checks the release (above), unpacks it into a staging area outside `Resources`, and records it as staged. It never writes to the live plugin folders. Only one package can be staged at a time.
2. **Restart.** The admin chooses "when the server is empty" (the default) or "now". Players are never kicked by an install they didn't see coming.
3. **Swap (supervisor, before BeamMP starts).** If a release is staged:
   1. Write the recovery record (below).
   2. Copy the installed version, its `keep` paths and its `data` locations to the rollback copy, and verify the copy against the originals before going on.
   3. Carry the `keep` paths over from the installed version into the staged one.
   4. Replace each `server` folder and `client` ZIP with the staged one.
4. **Verify (supervisor, after BeamMP starts).** Read the log of this launch only, from the point the supervisor started BeamMP. The boot is healthy when the package's loaded line appears and no Lua error follows during a settle period after it. It fails on a Lua error before or during the settle period, on the manager reporting the installed package itself as left out, on a time limit passing without the loaded line, or on BeamMP exiting. For a base install, "left out" lines for the games the admin was warned about are expected and don't fail it.
5. **Finish.** On success, the installed version becomes the new version and the result is shown in the admin tool. On failure, roll back (below).

### Rolling back

- **Automatic.** A failed verify, or BeamMP not starting at all, puts the rollback copy back (the old folders, ZIPs, `keep` paths and `data` locations as they were at the swap), restarts, and verifies the old version the same way. The admin tool shows "3.1.0 failed to load (reason); back on 3.0.0".
- **Missing starts.** If BeamMP keeps dying before it logs anything, the supervisor counts attempts per staged version; after a fixed number it rolls back instead of trying again.
- **Rollback not confirmed.** If the old version doesn't verify either, the installer stops: the admin tool offers no installs until an admin has looked and cleared it.
- **Manual.** A **Previous version** button reinstalls the rollback copy through the same stage, restart and verify steps, keeping the current `keep` and `data` contents (decision 10). It respects the base check like any install, and is disabled with the reason when the installed release has `changesData` (decision 9).
- A release that failed to load stays offered, marked with its failure, so the admin can try again after fixing whatever was wrong outside the release.

### Recovery record

The supervisor can be killed at any point (power loss, a crash, the server being stopped). Before each rename it writes a small record of what it is about to do: the package, the old and new version, and the step. The record is written to a temporary file and renamed into place, so it is never half-written. At every start the hook reads the record first and either finishes the swap or reverts it, so the server never starts with a mix of two versions. A finished install clears the record only after the new version is recorded as installed.

A rename alone doesn't survive power loss, so each step is flushed to disk before the next one starts: the rollback copy once it is verified, the record each time it is written, each rename (with its directory), and the installed-version record before the recovery record is cleared. Tests kill the process between steps; safety against power loss rests on that flush order.

### Outages

A download, checksum or GitHub outage, or a restart that didn't happen, leaves nothing half-done: the release stays staged or offered, the admin sees the error and can retry. An outage never marks a release as failed; only a release that started and failed its verify does.

### The base's part

The installer relies on two things from the manager:

- **Loaded lines.** At start the manager logs one line per package it loaded, with id and version, and one line per game it left out, with the reason. **Proposed** format: `[arcade] loaded cops-and-robbers 3.1.0` and `[arcade] left out street-racing 1.2.0: needs base 0.4.0, the server has 0.3.0`. Packages from before the manager (Cops and Robbers 2.x) are out of scope (non-goals).
- **Shared state.** The installer only replaces whole folders while BeamMP is stopped, so the shared Lua state and hot reload never see a half-changed plugin.

## Approaches considered

| Part | Chosen | Rejected |
|---|---|---|
| When to install | An admin presses Install (decision 1) | A timer installing every stable release (would deploy releases meant to stay local, such as the 2.x split steps); an allowed version range in the server's config; the timer off until 3.0.0 |
| Where the swap happens | The supervisor, before BeamMP starts (decision 7) | The admin tool replacing files while BeamMP runs (BeamMP hot-reloads changed plugin files mid-round, and the admin tool can't read the server log); a separate updater with control over the whole server (far more power than copying folders needs) |
| A game needing a newer base | One package at a time (decision 5) | Installing both together in one restart, rolled back together (fewer clicks, more machinery) |
| Reporting | The admin tool only (decision 4) | GitHub deployments or a pinned status issue (needs a write token on the server) |
| Trust proof | GitHub artifact attestations from `release.yml` on `main`, bound to the tag's commit (decision 6) | The release's author and tag only (any workflow run publishes as `github-actions[bot]`); a signing key in an environment only `main` may use (a secret to guard and rotate) |
| Which releases are listed | Every newer trusted release, marked with whether it fits (decision 8) | Only the newest (can't reach a playable pair when the newest base and game don't match) |
| Saved data and going back | Declared format changes; automatic rollback restores the data copy; going back by hand blocked across a change (decision 9) | Every release keeps data readable by the version before it (a rule on every release, hard to test) |
| Install manifest | `release.json` beside the assets | Conventions only (can't express `keep` or several folders); reading the manifest out of the Lua (needs unpacking and parsing Lua before trusting it) |

## Open questions (the maintainer's)

None.

## Proposed (choices made in this design; correct any)

- Only admins of the server's admin tool may install or go back.
- One package staged at a time; one rollback copy per package (the version that ran before).
- The default restart is "when the server is empty".
- Any Lua error in the log during verify counts as a failure, whichever package logged it.
- A release that failed to load stays offered, marked.
- A player who joins in the seconds between the empty check and the stop is disconnected by the restart; that window is accepted.

## Choices left to the builder

- The verify time limit and the number of missing starts before a rollback.
- Where the staging area, rollback copies, recovery record and status file live, as long as they are outside `Resources` and outside every path an install replaces.
- How the admin tool shows releases, notes and results.
- How often the admin tool checks GitHub (also on demand), within GitHub's unauthenticated rate limit.
- The format of the status the supervisor hands to the admin tool.

## Engine assumptions to check

1. BeamMP Server watches server plugin files while it runs: it re-runs a changed top-level Lua file and fires `onFileChanged` for other changed files ([TPluginMonitor.cpp, v3.9.3](https://github.com/BeamMP/BeamMP-Server/blob/v3.9.3/src/TPluginMonitor.cpp#L47-L81)). This is why the swap happens only while BeamMP is stopped. Nothing to probe; recorded as the reason.
2. A Lua error in a plugin shows up in the server log with a marker the supervisor can match, both at load and in the first ticks. Check on the local test server with a deliberately broken release.
3. BeamMP sends the replaced client ZIP to players who join after the restart, with no cached copy getting in the way. Check with one client across an install.

## Automated acceptance

Tests with fixture releases and a fake server folder, no network:

- Each trust check rejects its own bad case: a draft, a prerelease, a tag that doesn't match `release.json`, a tag not on `main`, a missing asset, a checksum mismatch, and an asset signed by another workflow, from another ref or from another commit than the tag's, or not signed at all.
- A game whose `needsBase` the installed base doesn't meet can't be staged; a base install lists the games it would leave out.
- A successful swap keeps every `keep` path, removes files and whole folders the new release dropped, and leaves the rollback copy equal to the old version.
- A release naming a path outside its own folders, another package's folder, an archive entry outside the named folders, or a `keep` path outside them is rejected.
- A boot that logs the loaded line and then a Lua error within the settle period fails; log lines from an earlier launch never count.
- A game that doesn't fit the installed base is listed but can't be staged; with a 0.x base, the newest playable set is pointed out (fixture: base 0.3 installed, game needing 0.4, newest base 0.5).
- An automatic rollback restores `keep` and `data` as they were at the swap; **Previous version** keeps the current ones and is refused when the installed release has `changesData`.
- Killing the supervisor after each step of the swap and starting again always ends on one whole version, the old or the new, never a mix.
- A failed verify (no loaded line, a Lua error, left out, time limit, no start) rolls back and reports which.
- A rollback that doesn't verify stops further installs until cleared.
- An outage at download, checksum or restart leaves the release offered and not marked failed.
- For every repo: `release.json` agrees with the Lua manifest and the tag.

## Drills before the first live install

Every failure path above is drilled on a test copy of the server, never the live one, before the installer is used on the live server: a broken release, a release with a Lua error, a crash between each pair of renames, a server that won't start, an unconfirmed rollback, and a download or checksum failure. The admin decides when the installer goes live.

## Links

- [Manager spec](2026-11-27-arcade-manager-design.md): plugin loading, versions, settings storage.
- [cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56): the move to 3.0.0, by hand.
- [GitHub artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds).
