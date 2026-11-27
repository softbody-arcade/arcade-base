# Engine probes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A probe kit the maintainer installs on the local test server to answer the spec's five engine questions before the Cops and Robbers split starts.

**Architecture:** Throwaway server plugins and a client mod under `probes/engine/` in arcade-base, each logging tagged lines (`[arcade-probe]`) to the server log or `beamng.log`. An install script puts them on a test server and removes them again. Results go on arcade-base#1 as a comment and decide which of the spec's fallbacks apply.

**Tech Stack:** BeamMP Server 3.9.3 plugins (Lua 5.3), BeamNG.drive GE extensions (LuaJIT), a Vue UI app (same structure as Cops and Robbers' apps), Bash.

**Spec:** [2026-11-27-arcade-manager-design.md](../specs/2026-11-27-arcade-manager-design.md), section "Engine assumptions to check" and step 0 of "Order of work".

This is the first of four plans the spec needs: engine probes (this one), the Cops and Robbers 2.x split (written once the probe results are in, since they decide which fallbacks the seam must allow), the manager moving into the base, and Cops and Robbers 3.0.0.

## Global Constraints

- Server Lua runs under Lua 5.3 (BeamMP Server 3.9.3); client Lua under LuaJIT. Check every client file with `luajit -bl` and every server file with `luac -p`, using `lua5.3`/`luac5.3` when installed and `lua`/`luac` otherwise, as Cops and Robbers' Makefile does (the maintainer's machine has Lua 5.5; the server log in Task 4 is the real 5.3 check).
- `PluginConfig.toml` holds one top-level key: `LuaStateID = "arcade-probe"` (BeamMP Server v3.9.3, `TLuaEngine::FindAndParseConfig`).
- Plugin folders load in case-insensitive alphabetical order, and every folder sharing a state shares the one global `onInit`. Only the base probe defines `onInit`; game probes register into the global table `ArcadeProbeGames`.
- Every log line starts with `[arcade-probe]` so the maintainer can grep it.
- Probes never go on the live server. No source comments. No absolute home paths in committed files (privacy check).
- Probe files are temporary: they live under `probes/engine/` and are deleted in the plan that follows once results are recorded.

## Review Focus

- A second load of the base probe's file (hot reload) must not duplicate manifests or lose the count of `onInit` calls: tested by `collect` being idempotent (Task 1).
- A game folder that sorts before the base (`ArcadeProbeAGame`) must still be found: covered by having one game on each side of the base alphabetically (Task 1).
- Uninstalling must leave the test server exactly as before: `install.sh --remove` deletes only the probe folders and zip (Task 3 test).
- A client with an older or missing probe mod must still log something useful rather than erroring: the version dump logs `missing` (Task 2).
- The base extension unloading the game extension twice, or loading it twice, must not error (Task 2 console steps).

---

### Task 1: Server probes (probes 1 and 2, and probe 1's fallback)

**Files:**
- Create: `probes/engine/server/ArcadeProbeBase/PluginConfig.toml`, `probes/engine/server/ArcadeProbeBase/main.lua`, `probes/engine/server/ArcadeProbeBase/arcade_probe/collect.lua`
- Create: `probes/engine/server/ArcadeProbeAGame/PluginConfig.toml`, `.../ArcadeProbeAGame/entry.lua`, `.../ArcadeProbeAGame/arcade_probe_agame/rules.lua`
- Create: `probes/engine/server/ArcadeProbeZGame/PluginConfig.toml`, `.../ArcadeProbeZGame/entry.lua`, `.../ArcadeProbeZGame/arcade_probe_zgame/rules.lua`
- Create: `probes/engine/server/ArcadeProbeLoose/arcade_probe_loose/rules.lua` (no top-level file, no `PluginConfig.toml`: the fallback)
- Test: `probes/engine/tests/collect_test.lua`

**Interfaces:**
- Produces: global `ArcadeProbeGames` = `{ [id] = { module = "<module name>", version = "<x.y.z>" } }`, written by each `entry.lua`.
- Produces: `collect.lua` returns `{ collect = function(registry) -> list }`, the list sorted by id, each item `{ id, module, version }`; calling it twice on the same registry gives the same list.
- Produces: each `rules.lua` returns `{ hello = function() -> string }` returning its game id.

- [ ] **Step 1: Write the failing test** `probes/engine/tests/collect_test.lua` (plain Lua 5.3, `package.path` pointing at `probes/engine/server/ArcadeProbeBase/?.lua`): `collect({ zgame = {module="a", version="1"}, agame = {module="b", version="2"} })` returns ids `{"agame","zgame"}` in that order; a second call returns an equal list; `collect({})` returns an empty list.
- [ ] **Step 2: Run** `$(command -v lua5.3 || command -v lua) probes/engine/tests/collect_test.lua` — expect failure: module `arcade_probe.collect` not found.
- [ ] **Step 3: Implement** `collect.lua`, then the plugin files:
  - each `PluginConfig.toml`: `LuaStateID = "arcade-probe"`;
  - each `entry.lua`: `ArcadeProbeGames = ArcadeProbeGames or {}` then its own entry (`agame`, `zgame`; module names `arcade_probe_agame.rules`, `arcade_probe_zgame.rules`; version `0.0.1`), and log `[arcade-probe] entry <id> loaded`;
  - `main.lua`: keep `ArcadeProbeState = ArcadeProbeState or { inits = 0, loads = 0 }`, increment `loads` at file load and log it; define `onInit` that increments `inits`, logs `[arcade-probe] onInit inits=<n> loads=<n>`, then for each item from `collect(ArcadeProbeGames)` does `pcall(require, item.module)` and logs `[arcade-probe] require <id> ok=<bool> hello=<value or error>`; then the fallback: prepend `Resources/Server/ArcadeProbeLoose/?.lua` to `package.path`, `pcall(require, "arcade_probe_loose.rules")`, log `[arcade-probe] loose ok=<bool> hello=<value or error>`; finally log `[arcade-probe] package.path=<package.path>`.
- [ ] **Step 4: Run** the test again — expect `collect ok`; run `luac -p` (or `luac5.3 -p`) on every server file — expect no output.
- [ ] **Step 5: Commit** `probes: server plugins for shared state, require and reload`.

### Task 2: Client probes (probes 3, 4 and 5)

**Files:**
- Create: `probes/engine/client/scripts/arcadeProbe/modScript.lua` (`load("arcadeProbeBase")`, `setExtensionUnloadMode("arcadeProbeBase", "manual")`, as Cops and Robbers' `client/scripts/copsAndRobbers/modScript.lua`)
- Create: `probes/engine/client/mod_info/ArcadeProbe/info.json` (`"version_string": "0.0.1"`)
- Create: `probes/engine/client/lua/ge/extensions/arcadeProbeBase.lua`, `probes/engine/client/lua/ge/extensions/arcadeProbeGame.lua`
- Create: `probes/engine/client/ui/modules/apps/ArcadeProbe/app.json`, `app.vue` (copy the structure of Cops and Robbers' `CopsAndRobbersAnnouncements` app: `domElement`, `directive`, one component)

**Interfaces:**
- Produces (console API on `arcadeProbeBase`): `loadGame(name)`, `unloadGame(name)`, `show(text)`, `versions()`.
- Produces: `arcadeProbeGame` logs `[arcade-probe] game onUpdate n=<count>` once per second while loaded, and `[arcade-probe] game unloaded` from `onExtensionUnloaded`.
- Produces: the app listens for the guihook `ArcadeProbe` and shows `data.text`.

- [ ] **Step 1: Implement** `arcadeProbeGame.lua`: an `onUpdate` that counts frames and logs once a second; `onExtensionUnloaded` logs.
- [ ] **Step 2: Implement** `arcadeProbeBase.lua`: `loadGame(name)` calls `extensions.load(name)` and logs `[arcade-probe] load <name> ok=<bool>`; `unloadGame(name)` calls `extensions.unload(name)` and logs; `show(text)` calls `guihooks.trigger("ArcadeProbe", { text = text })`; `versions()` logs, for each entry the mod manager reports (`core_modmanager`), its name and version, or `[arcade-probe] versions missing <reason>` when the API isn't there (the probe's job is to find the right call: log the keys `core_modmanager` exposes first).
- [ ] **Step 3: Implement** the app: on `ArcadeProbe` it replaces its text; on mount it logs `[arcade-probe] app mounted` through `bngApi.engineLua('log("I","arcade-probe","app mounted")')`.
- [ ] **Step 4: Run** `luajit -bl` on both extensions — expect no output; check `app.json` with `python3 -m json.tool`.
- [ ] **Step 5: Commit** `probes: client extensions and app for load, unload, content and versions`.

### Task 3: Install script, check target and run sheet

**Files:**
- Create: `probes/engine/install.sh`, `probes/engine/README.md`
- Modify: `Makefile` (target `probes-check`)
- Test: `probes/engine/tests/install_test.sh`

**Interfaces:**
- Consumes: the folders from Tasks 1 and 2.
- Produces: `probes/engine/install.sh <test-server-dir>` copies the four server folders to `<dir>/Resources/Server/` and zips `probes/engine/client/` to `<dir>/Resources/Client/ArcadeProbe.zip`; `install.sh --remove <dir>` deletes exactly those; it refuses a directory without `Resources/Server`.
- Produces: `make probes-check` runs the collect test and `luac -p` on server files (5.3 versions when installed, as in Global Constraints), `luajit -bl` on client files, `bash -n` on the script, and the install test.

- [ ] **Step 1: Write the failing test** `install_test.sh`: in a temp dir with `Resources/Server/Other/` and `Resources/Client/other.zip`, install then check the four probe folders and `ArcadeProbe.zip` exist; `--remove` then check they're gone and `Other/` and `other.zip` remain; a dir without `Resources/Server` makes `install.sh` exit 1.
- [ ] **Step 2: Run** `bash probes/engine/tests/install_test.sh` — expect failure: `install.sh` missing.
- [ ] **Step 3: Implement** `install.sh` (`set -euo pipefail`, zip with `cd probes/engine/client && zip -qr`), the `probes-check` target, and `README.md` with one section per probe: setup, the action (server restart, a hot reload by touching `ArcadeProbeBase/main.lua`, one comment-free GE console line per client action, such as `arcadeProbeBase.loadGame("arcadeProbeGame")`), the log lines that mean pass, the uncertainty it resolves, and the spec fallback that applies if it fails. Probe 2's pass condition: after the touch, `onInit inits` goes up by one, `loads` goes up by one, and each game is required once more without errors.
- [ ] **Step 4: Run** `make probes-check` — expect every part to pass; run `make test` — expect it unchanged.
- [ ] **Step 5: Commit** `probes: install script, check target and run sheet`.

### Task 4: Run the probes and record the results (maintainer)

- [ ] **Step 1:** The maintainer runs `probes/engine/install.sh "<repo>/.testserver"` from a trusted checkout, restarts the local BeamMP server, joins, and follows `probes/engine/README.md`.
- [ ] **Step 2:** The maintainer shares the `[arcade-probe]` lines from the server log and `beamng.log`.
- [ ] **Step 3:** Record the results on arcade-base#1: each probe pass or fail, and for each failure the spec fallback that now applies.
- [ ] **Step 4:** Remove the probes from the test server with `install.sh --remove`, and delete `probes/engine/` and the `probes-check` target in the next plan's first task.
