# Engine probes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A probe kit the maintainer installs on the local test server to answer the spec's five engine questions, and decide between each main path and its fallback, before the Cops and Robbers split starts.

**Architecture:** Throwaway server plugins and two client mods under `probes/engine/` in arcade-base, each logging tagged lines (`[arcade-probe]`) to the server log or `beamng.log`. An install script puts them on a test server without touching anything already there, and removes exactly what it added. Results go on arcade-base#1 and decide which of the spec's fallbacks apply.

**Tech Stack:** BeamMP Server 3.9.3 plugins (Lua 5.3), BeamNG.drive GE extensions (LuaJIT), a Vue UI app built like Cops and Robbers' apps, Bash.

**Spec:** [2026-11-27-arcade-manager-design.md](../specs/2026-11-27-arcade-manager-design.md), "Engine assumptions to check" and step 0 of "Order of work".

This is the first of four plans the spec needs: engine probes (this one), the Cops and Robbers 2.x split (written once the results are in, since they decide which fallbacks the seam must allow), the manager moving into the base, and Cops and Robbers 3.0.0.

## Global Constraints

- Server Lua runs under Lua 5.3 (BeamMP Server 3.9.3); client Lua under LuaJIT. Check client files with `luajit -bl <file> >/dev/null` (exit status 0 means valid; the listing on stdout is discarded) and server files with `luac -p`, using `lua5.3`/`luac5.3` when installed and `lua`/`luac` otherwise, as Cops and Robbers' Makefile does. The maintainer's machine has Lua 5.5; the server log in Task 4 is the real 5.3 check.
- `PluginConfig.toml` holds one top-level key: `LuaStateID = "arcade-probe"` (BeamMP Server v3.9.3, `TLuaEngine::FindAndParseConfig`).
- Plugin folders load in case-insensitive alphabetical order; folders sharing a state share one global `onInit`. Only the base probe defines `onInit`; game probes register into the global table `ArcadeProbeGames`.
- Every log line's message starts with `[arcade-probe]`.
- The test server is given explicitly (`install.sh <test-server-dir>`), never derived from the probe checkout. Probes never go on the live server.
- No source comments; no absolute home paths in committed files.
- The probe files are temporary: they live under `probes/engine/` and are deleted in the first task of the next plan.

## Review Focus

- The installer must never overwrite or delete anything that was on the test server before: it refuses collisions before its first write and removes only what its own record lists (Task 3 tests).
- A reload must not lose an active round's state or leave a stale game rule running: Probe 2 checks both after reloading the base and a game separately (Task 1).
- After unloading a game extension, none of its hooks or bindings may still answer, and after loading it again each trigger answers exactly once (Task 2).
- A client without the game mod must still report the base's version and "game missing" to the server (Task 2).
- If the games don't share the base's state, the explicit-path fallback must still be tested and reported (Task 1).

---

### Task 1: Server probes (probes 1 and 2, and probe 1's fallback)

**Files:**
- Create: `probes/engine/server/ArcadeProbeBase/PluginConfig.toml`, `main.lua`, `arcade_probe/collect.lua`
- Create: `probes/engine/server/ArcadeProbeAGame/PluginConfig.toml`, `entry.lua`, `arcade_probe_agame/rules.lua`
- Create: `probes/engine/server/ArcadeProbeZGame/PluginConfig.toml`, `entry.lua`, `arcade_probe_zgame/rules.lua`
- Create: `probes/engine/server/ArcadeProbeLoose/arcade_probe_loose/rules.lua` (no top-level file and no `PluginConfig.toml`: the fallback)
- Test: `probes/engine/tests/collect_test.lua`

**Interfaces:**
- Produces: global `ArcadeProbeGames` = `{ [id] = { module = "<module name>", version = "<x.y.z>" } }`, written by each `entry.lua`.
- Produces: `arcade_probe.collect` returns `{ collect = function(registry) -> list }`: items `{ id, module, version }` sorted by id; `nil` registry gives an empty list; calling it twice gives equal lists.
- Produces: each `rules.lua` returns `{ hello = function() -> string }`, returning `"<id> v1"`.
- Produces: chat commands handled by the base probe: `/probe start`, `/probe state`, `/probe rule`, `/probe rule fresh`, `/probe loose`, `/probe versions` (the last used by Task 2).

- [ ] **Step 1: Write the failing test** `collect_test.lua`: `collect({ zgame = {module="a", version="1"}, agame = {module="b", version="2"} })` gives ids `{"agame","zgame"}`; a second call gives an equal list; `collect(nil)` and `collect({})` give `{}`.
- [ ] **Step 2: Run** `$(command -v lua5.3 || command -v lua) probes/engine/tests/collect_test.lua` from the repo root — expect failure: module `arcade_probe.collect` not found.
- [ ] **Step 3: Implement** `collect.lua`.
- [ ] **Step 4: Implement** the plugin files:
  - every `PluginConfig.toml`: `LuaStateID = "arcade-probe"`;
  - each `entry.lua`: `ArcadeProbeGames = ArcadeProbeGames or {}`, its own entry (`agame` → `arcade_probe_agame.rules`, `zgame` → `arcade_probe_zgame.rules`, version `0.0.1`), and a log line `[arcade-probe] entry <id> loaded`;
  - `main.lua`, at file load (before and independent of `onInit`): `ArcadeProbeState = ArcadeProbeState or { inits = 0, loads = 0, round = nil }`, increment `loads`, log `[arcade-probe] base loaded loads=<n> registry=<visible|nil> games=<count>`; then run the loose check (below) once, so it reports even if `onInit` never fires or the registry is missing;
  - the loose check: prepend `Resources/Server/ArcadeProbeLoose/?.lua` to `package.path`, `pcall(require, "arcade_probe_loose.rules")`, log `[arcade-probe] loose ok=<bool> hello=<value or error>`;
  - `onInit`: increment `inits`, log `[arcade-probe] onInit inits=<n> loads=<n> registry=<visible|nil> games=<count>`, then for each item of `collect(ArcadeProbeGames)` log `[arcade-probe] shared require <id> ok=<bool> hello=<value or error>`, and finally `[arcade-probe] package.path=<package.path>`;
  - chat commands (registered with `MP.RegisterEvent("onChatMessage", ...)`, returning 1 to hide them): `/probe start` sets `ArcadeProbeState.round = { id = <os.time()>, rule = <first game id> }` and logs it; `/probe state` logs the round (or `none`) and `inits`/`loads`; `/probe rule` calls `require(<module of round.rule>).hello()` and logs the result; `/probe rule fresh` does the same after `package.loaded[<module>] = nil`; `/probe loose` re-runs the loose check.
- [ ] **Step 5: Run** the collect test — expect it to pass; run `luac -p` (or `luac5.3 -p`) on every server file — expect exit status 0.
- [ ] **Step 6: Commit** `probes: server plugins for shared state, loading and reload`.

### Task 2: Client probes (probes 3, 4 and 5)

**Files:**
- Create the base mod under `probes/engine/client-base/`: `scripts/arcadeProbe/modScript.lua` (`load("arcadeProbeBase")`, `setExtensionUnloadMode("arcadeProbeBase", "manual")`, as Cops and Robbers' `client/scripts/copsAndRobbers/modScript.lua`), `mod_info/ArcadeProbe/info.json` (`"version_string": "0.0.1"`), `lua/ge/extensions/arcadeProbeBase.lua`, `ui/modules/apps/ArcadeProbe/app.json` and `app.vue` (built like `client/ui/modules/apps/CopsAndRobbersAnnouncements/` in Cops and Robbers).
- Create the game mod under `probes/engine/client-game/`: `mod_info/ArcadeProbeGame/info.json` (`"version_string": "0.0.2"`) and `lua/ge/extensions/arcadeProbeGame.lua` (no modScript: the base loads it).
- Modify: `probes/engine/server/ArcadeProbeBase/main.lua` (receive the version report)

**Interfaces:**
- Produces (GE console API on `arcadeProbeBase`): `loadGame()`, `unloadGame()`, `ping()`, `show(fields)`, `snapshot(fields)`, `versions()`.
- Produces: `arcadeProbeGame` logs `[arcade-probe] game onUpdate n=<count>` once a second while loaded; its `onArcadeProbePing` hook logs `[arcade-probe] game ping n=<count>`; its UI binding `arcadeProbeGame.uiPing()` (called by the app's "Ping game" button) logs `[arcade-probe] game ui ping n=<count>`; `onExtensionUnloaded` logs `[arcade-probe] game unloaded`.
- Produces: client-to-server event `arcadeProbeVersions` with a JSON body `{ base = "<version or missing>", game = "<version or missing>", source = "<api used>" }`; the server base logs `[arcade-probe] versions from <player name>: <body>`.

- [ ] **Step 1: Implement** `arcadeProbeGame.lua`: the frame counter in `onUpdate`, the `onArcadeProbePing` hook and the `uiPing` binding as above.
- [ ] **Step 2: Implement** `arcadeProbeBase.lua`:
  - `loadGame()` and `unloadGame()` call `extensions.load("arcadeProbeGame")` / `extensions.unload("arcadeProbeGame")` and log `[arcade-probe] load ok=<bool>` / `[arcade-probe] unload`; calling either twice in a row must not error.
  - `ping()` calls `extensions.hook("onArcadeProbePing")` and logs `[arcade-probe] ping sent`.
  - `show(fields)` sends `guihooks.trigger("ArcadeProbe", fields)`; `snapshot(fields)` sends `guihooks.trigger("ArcadeProbeSnapshot", fields)`.
  - `versions()`: discovery first: log `[arcade-probe] modmanager keys=<sorted list of the keys core_modmanager exposes, or missing>`; then for each function key whose name starts with `get` and that takes no arguments, `pcall` it and log the key, the result type and, for tables, the count. From the results, take only mods that are active or mounted (log which field says so) and read the `ArcadeProbe` and `ArcadeProbeGame` versions, logging which fields held them. Then, independently, read the packaged files `/mod_info/ArcadeProbe/info.json` and `/mod_info/ArcadeProbeGame/info.json` through the game's file API (`jsonReadFile`) and log their `version_string` or `missing`. Send `arcadeProbeVersions` with `TriggerServerEvent` (as Cops and Robbers' `copsAndRobbers/game.lua` does) and log what was sent. The report carries both readings: `{ base, game, source }` from the mod manager (`source = "none"` if no API lists mods) and `{ base_file, game_file }` from the packaged files.
  - Call `versions()` once when the world is ready (`onWorldReadyState` with state 2, as Cops and Robbers does).
- [ ] **Step 3: Implement** the app: it shows every key and value of one `fields` object. On `ArcadeProbe` (the game-switch update the manager would send) it replaces the game's fields with the new ones; on `ArcadeProbeSnapshot` it rebuilds its whole state from the message. It has a "Ping game" button that runs `api.engineLua('if arcadeProbeGame then arcadeProbeGame.uiPing() end')`. On mount it calls, through the bridge Cops and Robbers' `copsAndRobbers/hud.js` uses (`useBridge().api.engineLua`), `log("I", "arcadeProbe", "[arcade-probe] app mounted")`.
- [ ] **Step 4: Implement** the server side in `main.lua`: `MP.RegisterEvent("arcadeProbeVersions", ...)` logging the player name and body; `/probe versions` logs how many reports have arrived.
- [ ] **Step 5: Run** `luajit -bl <file> >/dev/null` on `modScript.lua` and both extensions — expect exit status 0; `luac -p` on `main.lua`; `python3 -m json.tool` on `app.json` and both `info.json`.
- [ ] **Step 6: Commit** `probes: client mods for load, unload, hooks, app content and versions`.

### Task 3: Install script, check target and run sheet

**Files:**
- Create: `probes/engine/install.sh`, `probes/engine/README.md`
- Modify: `Makefile` (target `probes-check`)
- Test: `probes/engine/tests/install_test.sh`

**Interfaces:**
- Consumes: the folders from Tasks 1 and 2.
- Produces: `install.sh [--no-game] <test-server-dir>`: refuses (exit 1, nothing written) if the directory has no `Resources/Server` or `Resources/Client`, if any of `Resources/Server/ArcadeProbeBase`, `ArcadeProbeAGame`, `ArcadeProbeZGame`, `ArcadeProbeLoose`, `Resources/Client/ArcadeProbe.zip` or `ArcadeProbeGame.zip` already exists, or if a record file `Resources/.arcade-probe-installed` exists. Otherwise it copies the four server folders, zips `client-base/` to `ArcadeProbe.zip` and (without `--no-game`) `client-game/` to `ArcadeProbeGame.zip`, and writes every created path, one per line, to the record file.
- Produces: `install.sh --remove <test-server-dir>` first validates the whole record: every line must be one of the six probe paths (`Resources/Server/ArcadeProbeBase`, `…/ArcadeProbeAGame`, `…/ArcadeProbeZGame`, `…/ArcadeProbeLoose`, `Resources/Client/ArcadeProbe.zip`, `Resources/Client/ArcadeProbeGame.zip`), with no duplicates. Only then does it delete those paths and the record file. Without a record file, or with any other line, it exits 1 and deletes nothing.
- Produces: `make probes-check` runs the collect test, `luac -p` on the server files, `luajit -bl … >/dev/null` on the client Lua, `bash -n` on `install.sh`, and the install test.

- [ ] **Step 1: Write the failing test** `install_test.sh`, in temp directories:
  - a server dir with `Resources/Server/Other/` and `Resources/Client/other.zip`: install, then check the four probe folders, both zips and the record exist; `--remove`, then check they're gone and `Other/`, `other.zip` remain;
  - `--no-game`: only `ArcadeProbe.zip` is created, and `--remove` works;
  - a pre-existing `Resources/Server/ArcadeProbeBase/` with a marker file, and separately a pre-existing `Resources/Client/ArcadeProbe.zip`: install exits 1 and writes nothing (no record), and a following `--remove` exits 1; the marker file and the zip are unchanged;
  - a directory without `Resources/Server`: install exits 1;
  - after a normal install, a record edited to add `Resources/Server/Other`: `--remove` exits 1, and `Other/` and every probe file are still there.
- [ ] **Step 2: Run** `bash probes/engine/tests/install_test.sh` — expect failure: `install.sh` missing.
- [ ] **Step 3: Implement** `install.sh` (`set -euo pipefail`; all collision checks before the first write; zip from inside each client folder with `zip -qr`), the `probes-check` target, and `README.md`.
- [ ] **Step 4: Write** `README.md`, one section per probe, each with: setup, the actions (chat commands, or one comment-free GE console line each), the `[arcade-probe]` lines that mean pass, the uncertainty it resolves, and the spec path it decides:
  - **Probe 1, shared state:** after a server start, pass = `onInit inits=1 … registry=visible games=2`, and `shared require agame ok=true` and `zgame ok=true`. (The `base loaded` line comes before `ArcadeProbeZGame` has loaded, since folders load alphabetically, so it shows `games=1`; that's expected.) Fallback decided by `loose ok=<bool>`: shared state works → main path; shared fails and loose works → spec fallback 1; both fail → spec fallback 2 (separate plugins).
  - **Probe 2, reload:** `/probe start` (note the round id), then `/probe rule` (expect `<id> v1`). Then three cases, one at a time. BeamMP checks for changed files about every three seconds, so after each change wait until the log shows the reload (case a: a new `base loaded loads=<n+1>`; case b: a new `entry <id> loaded`; case c: wait ten seconds, since nested files may not be watched) and any `onInit` line that follows, then run `/probe state` and `/probe rule`. If a case ended the round, `/probe start` again before the next. (a) touch `ArcadeProbeBase/main.lua`; (b) touch the round's game `entry.lua`; (c) change that game's `rules.lua` to return `"<id> v2"`, then run `/probe rule` and `/probe rule fresh`. Record for each: the round id before and after, `inits`/`loads`, and the versions returned. Outcomes: the round id survives (a) and (b) → main path; it doesn't → the spec's fallback (reloads end the round). For (c): `rule` still `v1` and `rule fresh` `v2` → nested edits only take effect when the manager clears the module cache on reload, which the manager then does; both `v1` → nested edits need a server restart, which the run sheet records.
  - **Probe 3, extension load and unload:** with the game mod installed, place the probe app, then in the console `arcadeProbeBase.loadGame()` twice (no error), then `arcadeProbeBase.ping()` and the app's "Ping game" button (expect exactly one `game ping` and one `game ui ping`), `arcadeProbeBase.unloadGame()` (expect `game unloaded`, and `game onUpdate` lines stop), `arcadeProbeBase.ping()` and the button again (expect neither line), `arcadeProbeBase.unloadGame()` again (no error), `arcadeProbeBase.loadGame()`, then `ping()` and the button (expect exactly one of each). Counts one, zero, one → main path; any answer after unload, or two per trigger after reload → fallback (dormant extensions).
  - **Probe 4, app content:** place the probe app and confirm `app mounted`; `arcadeProbeBase.show({game="A", extra="only in A"})`, then the game-switch update `arcadeProbeBase.show({game="B"})`. If the app shows B with no `extra`, without a client restart → main path. If `extra` is still shown, send `arcadeProbeBase.snapshot({game="B"})`; if that clears it → the spec's fallback (a full snapshot on every switch); if not → record it as a failure for the plan. A screenshot after each step.
  - **Probe 5, versions:** after joining with both mods, the server log shows `versions from <name>` with the mod-manager reading and the packaged-file reading. Then leave the server, `install.sh --remove`, `install.sh --no-game`, restart the server and rejoin: expect game `missing` and base still `0.0.1`. Outcomes: either reading gives base `0.0.1` and game `0.0.2` (and `missing` without the game mod) → main path, using that reading; a report arrives but neither reading has the versions → fallback (the outdated-mod check as Cops and Robbers does it today); no `versions from` line at all → the client-to-server event failed, recorded as a failure for the plan.
  - **Removal:** `install.sh --remove <test-server-dir>`, then restart the test server and reconnect or quit the client: BeamMP stops watching deleted files but keeps their plugin state loaded until restart.
- [ ] **Step 5: Run** `make probes-check` — expect every part to pass; run `make test` — expect it unchanged.
- [ ] **Step 6: Commit** `probes: install script, check target and run sheet`.

### Task 4: Run the probes and record the results (maintainer)

- [ ] **Step 1:** From a trusted arcade-base checkout, the maintainer runs `probes/engine/install.sh <cops-and-robbers checkout>/.testserver` (the local test server lives in the Cops and Robbers checkout), restarts the local BeamMP server, joins, and follows `probes/engine/README.md`.
- [ ] **Step 2:** The maintainer shares the `[arcade-probe]` lines from the server log and `beamng.log`, and the probe 4 screenshots.
- [ ] **Step 3:** Record the results on arcade-base#1: each probe's outcome and, for each, the spec path it decides (main path or which fallback).
- [ ] **Step 4:** Remove the probes as the run sheet says (remove, restart the server, reconnect). `probes/engine/` and the `probes-check` target are deleted in the next plan's first task.
