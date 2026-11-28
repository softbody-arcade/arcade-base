# Release installer: how a server installs Softbody Arcade releases

Status: design, built after Cops and Robbers 3.0.0 is live ([#45](https://github.com/softbody-arcade/arcade-base/issues/45), blocked by [cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56)).

This spec is for the person deciding how Softbody Arcade releases reach a server. It covers what every release must contain, which releases a server may trust, and what the installer must guarantee. How one particular server runs the installer (its admin tool, its process setup, its paths) is private to that server and is not described here; this spec calls that part **the server's admin tool** and **the start hook**.

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
6. **Trust.** Only releases published by the release workflow from a tag on `main`, never a release made by hand. (2026-11-27; see **Open questions** for how this is checked.)
7. **Shape.** The admin tool stages a release; the start hook, which runs before BeamMP Server starts, swaps it in, checks the log and rolls back. (2026-11-28)

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
  "keep": ["CopsAndRobbers/config.json", "CopsAndRobbers/data"]
}
```

- `id` matches the repo name; `version` matches the tag without its `v`.
- `needsBase` is what the game's manifest in Lua declares (an exact version while the base is 0.x, decision 9 of the [manager spec](2026-11-27-arcade-manager-design.md); a range from 1.0). The release workflow generates `release.json` from the same source, and a test checks they agree. The base's own `release.json` has no `needsBase`.
- `server` and `client` name every folder and ZIP the package owns. An install replaces exactly these, as a whole, so files a newer release removed don't linger.
- `keep` lists the paths inside those folders carried over from the installed version (when present) instead of taken from the release. The manager spec proposes storing settings outside the install folders; once a package does that, its `keep` can shrink to nothing.

### Which releases are offered

The admin tool holds a list of repos to watch (the base and each installed game). For each, it lists the releases newer than the installed version and offers only those that pass every check:

1. Published, not a draft or prerelease, version `x.y.z`, and the tag is `v` plus that version.
2. **Built by the release workflow from `main`** (open question 1 decides how this is proven).
3. The tag's commit is on `main`. The release page's "target" can't be used for this: the release workflow creates the tag through the API, and GitHub reports the default branch as the target either way.
4. All four assets are present; after downloading, every asset matches `SHA256SUMS` and `release.json` matches the tag.

When several newer releases pass, the newest is offered (skipping versions is fine; each release is complete).

Next to each release the admin tool shows its notes and, for a game, whether the server's base meets `needsBase`. When it doesn't, Install is disabled with the reason ("needs base 0.4.0, the server has 0.3.0; install that first"). Before a base install, the admin tool lists the installed games that the new base would leave out, using their `needsBase`.

### Installing

1. **Stage.** The admin presses Install. The admin tool downloads and checks the release (above), unpacks it into a staging area outside `Resources`, and records it as staged. It never writes to the live plugin folders. Only one package can be staged at a time.
2. **Restart.** The admin chooses "when the server is empty" (the default) or "now". Players are never kicked by an install they didn't see coming.
3. **Swap (start hook, before BeamMP starts).** If a release is staged:
   1. Write the recovery record (below).
   2. Copy the installed version to the rollback copy, and verify the copy against the installed files before going on.
   3. Carry the `keep` paths over from the installed version into the staged one.
   4. Replace each `server` folder and `client` ZIP with the staged one.
4. **Verify (start hook, after BeamMP starts).** Watch the server log until the package's loaded line appears, a Lua error appears, the manager reports the package as left out, or a time limit passes. Only the loaded line counts as success.
5. **Finish.** On success, the installed version becomes the new version and the result is shown in the admin tool. On failure, roll back (below).

### Rolling back

- **Automatic.** A failed verify, or BeamMP not starting at all, puts the rollback copy back, restarts, and verifies the old version the same way. The admin tool shows "3.1.0 failed to load (reason); back on 3.0.0".
- **Missing starts.** If BeamMP keeps dying before it logs anything, the start hook counts attempts per staged version; after a fixed number it rolls back instead of trying again.
- **Rollback not confirmed.** If the old version doesn't verify either, the installer stops: the admin tool offers no installs until an admin has looked and cleared it.
- **Manual.** A **Previous version** button reinstalls the rollback copy through the same stage, restart and verify steps. It respects the base check like any install.
- A release that failed to load stays offered, marked with its failure, so the admin can try again after fixing whatever was wrong outside the release.

### Recovery record

The start hook can be killed at any point (power loss, a crash, the server being stopped). Before each rename it writes a small record of what it is about to do: the package, the old and new version, and the step. The record is written to a temporary file and renamed into place, so it is never half-written. At every start the hook reads the record first and either finishes the swap or reverts it, so the server never starts with a mix of two versions. A finished install clears the record only after the new version is recorded as installed.

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
| Where the swap happens | The start hook, before BeamMP starts (decision 7) | The admin tool replacing files while BeamMP runs (BeamMP hot-reloads changed plugin files mid-round, and the admin tool can't read the server log); a separate updater with control over the whole server (far more power than copying folders needs) |
| A game needing a newer base | One package at a time (decision 5) | Installing both together in one restart, rolled back together (fewer clicks, more machinery) |
| Reporting | The admin tool only (decision 4) | GitHub deployments or a pinned status issue (needs a write token on the server) |
| Install manifest | `release.json` beside the assets | Conventions only (can't express `keep` or several folders); reading the manifest out of the Lua (needs unpacking and parsing Lua before trusting it) |

## Open questions (the maintainer's)

1. **How "built by the release workflow from `main`" is proven.** Checking that `github-actions[bot]` published the release and that its tag is on `main` is not enough: every workflow run in a repo publishes as `github-actions[bot]`, including a run from a branch or a pull request (a pull request's workflow runs with that pull request's own copy of the workflow files). Such a run could attach its own assets to a release for a tag on `main`, and checksums alone don't help, because it would publish matching `SHA256SUMS`. Options:
   - **Build provenance (proposed).** The release workflow attests its assets with GitHub's artifact attestations, and the installer verifies that each asset's attestation was signed by `.github/workflows/release.yml` running on `refs/heads/main` of the expected repo. No secret to keep. The release workflow must then run on a push to `main` (or a dispatch on `main`) instead of on the closed pull request, because a pull request run is signed with the pull request's ref.
   - **A signing key.** The release workflow signs `SHA256SUMS` with a key held in a GitHub environment that only `main` may use, and the installer checks the signature with the public key. Simpler to verify, but a secret to guard and rotate, and the same trigger change is needed.
2. **The gap while the base is 0.x.** Games pin an exact base version until 1.0, so every base update leaves the installed game out until its matching release is installed: one at a time, that is two restarts with no playable game in between. Accept that gap (the second install can use "now", since the server is in the lobby), or allow staging the matching game right after the base install succeeds so the second restart follows at once?

## Proposed (choices made in this design; correct any)

- Only admins of the server's admin tool may install or go back.
- One package staged at a time; one rollback copy per package (the version that ran before).
- The default restart is "when the server is empty".
- Any Lua error in the log during verify counts as a failure, whichever package logged it.
- The newest passing release is offered; older ones aren't listed.
- A release that failed to load stays offered, marked.

## Choices left to the builder

- The verify time limit and the number of missing starts before a rollback.
- Where the staging area, rollback copies, recovery record and status file live, as long as they are outside `Resources` and outside every path an install replaces.
- How the admin tool shows releases, notes and results.
- How often the admin tool checks GitHub (also on demand), within GitHub's unauthenticated rate limit.
- The format of the status the start hook hands to the admin tool.

## Engine assumptions to check

1. BeamMP Server hot-reloads a server plugin when its files change while it runs ([TPluginMonitor.cpp, v3.9.3](https://github.com/BeamMP/BeamMP-Server/blob/v3.9.3/src/TPluginMonitor.cpp)). This is why the swap happens only while BeamMP is stopped. Nothing to probe; recorded as the reason.
2. A Lua error in a plugin shows up in the server log with a marker the start hook can match, both at load and in the first ticks. Check on the local test server with a deliberately broken release.
3. BeamMP sends the replaced client ZIP to players who join after the restart, with no cached copy getting in the way. Check with one client across an install.

## Automated acceptance

Tests with fixture releases and a fake server folder, no network:

- Each trust check rejects its own bad case: a draft, a prerelease, a tag that doesn't match `release.json`, a tag not on `main`, a missing asset, a checksum mismatch, and (per open question 1) an asset not signed by the release workflow on `main`.
- A game whose `needsBase` the installed base doesn't meet can't be staged; a base install lists the games it would leave out.
- A successful swap keeps every `keep` path, removes files the new release dropped, and leaves the rollback copy equal to the old version.
- Killing the start hook after each step of the swap and starting again always ends on one whole version, the old or the new, never a mix.
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
