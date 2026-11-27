# Engine probes for the arcade manager

Temporary probes that answer the engine questions in the [arcade manager spec](../../docs/superpowers/specs/2026-11-27-arcade-manager-design.md) before the manager is built. Each probe decides whether the spec's main path holds or which fallback the plan takes. The whole folder and the `probes-check` target are deleted once the results are recorded on [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1).

Running them is maintainer-only: they need the maintainer's game and the local test server, which lives in the Cops and Robbers checkout at `<cops-and-robbers checkout>/.testserver`.

## What is installed

| Path on the test server | What it is |
|---|---|
| `Resources/Server/ArcadeProbeBase/` | The manager stand-in: logs, chat commands, the versions handler |
| `Resources/Server/ArcadeProbeAGame/`, `ArcadeProbeZGame/` | Two games sharing the base's Lua state (`LuaStateID`), each with a nested `rules.lua` |
| `Resources/Server/ArcadeProbeLoose/` | A loose module folder with no plugin config, for the fallback check |
| `Resources/Client/ArcadeProbe.zip` | The base client mod (version `0.0.1`): the `arcadeProbeBase` extension and the **Arcade Probe** app |
| `Resources/Client/ArcadeProbeGame.zip` | The game client mod (version `0.0.2`): the `arcadeProbeGame` extension |

Every probe line starts with `[arcade-probe]`: in the server console for server lines, in `current/beamng.log` for client lines.

## Install

From a trusted arcade-base checkout:

```sh
probes/engine/install.sh <cops-and-robbers checkout>/.testserver
```

`--no-game` leaves out the game client mod (probe 5 uses it). The installer refuses to touch a server that already has any probe path or an install record, and rolls back what it created if it fails or is stopped. Then restart the local BeamMP server and join.

`make probes-check` checks the probes without a game: the collect test, the server Lua with `luac -p`, the client Lua with `luajit -bl`, the version reading against BeamMP-style mod records, and the installer and its test.

## Probe 1: shared state

**Uncertainty:** whether game plugins with the same `LuaStateID` share globals and `require` with the manager, in BeamMP's alphabetical load order.

**Setup:** the probes installed, a fresh server start.

**Actions:** none; read the server console after the start.

**Pass lines:**

- exactly one `onInit` line after the start: `onInit inits=1 loads=1 registry=visible games=2`, and no `onInit inits=2` after it
- `shared require agame ok=true hello=agame v1`
- `shared require zgame ok=true hello=zgame v1`

The `base loaded … games=1` line before them is expected: folders load alphabetically, so `ArcadeProbeZGame` has not loaded yet when the base's file runs.

**Decides:** also read `loose ok=<bool>`.

- Shared state works → main path.
- Shared state fails and `loose ok=true` → the spec's first fallback: a game folder has no top-level script and the manager loads its modules with `require` into its own state.
- Both fail → the spec's last resort: separate plugins, with vehicle checks answered by the manager from rules the game declares in advance.

## Probe 2: reload

**Uncertainty:** what a file change does to a running round: whether the shared state survives a reload of the base or of a game's entry file, and whether a change to a nested module reaches the running code.

**Setup:** probe 1 passed. If probe 1 found no shared registry (`games=0` at `onInit`), this probe doesn't apply: record it as such.

**Actions:** in chat, `/probe start` (note the round id and its rule game), then `/probe rule` (expect `rule ok=true value=<game> v1`). Then three cases, one at a time.

BeamMP checks for changed files about every three seconds. After each change, wait for its reload line, at most 15 seconds, and any `onInit` line after it; then run `/probe state` and `/probe rule`. In (a) and (b), if no reload line appears within 15 seconds, record the case as inconclusive (no reload seen) and go on; those cases only count once their reload line was seen. In (c), run `/probe rule` and `/probe rule fresh` whether or not the reload line appeared: a missing `file changed` line is one of the outcomes this case decides. If a case ended the round, run `/probe start` again before the next.

- **(a)** `touch` `Resources/Server/ArcadeProbeBase/main.lua`. Reload line: any new `base loaded` line, whatever its `loads` value (a fresh state starts again at 1).
- **(b)** `touch` the round's game `entry.lua` (for example `Resources/Server/ArcadeProbeAGame/entry.lua`). Reload line: a new `entry <game> loaded`.
- **(c)** Edit that game's `arcade_probe_<game>/rules.lua` to return `"<game> v2"`. Reload line: `file changed …rules.lua`, then `cache cleared arcade_probe_<game>.rules`. Note whether they appeared, then run `/probe rule` and `/probe rule fresh`.

Record for each case: the round id before and after, `inits` and `loads` from `/probe state`, and the version `/probe rule` returned.

**Decides:**

- (a) and (b), each with its reload line seen: the round id survives both → main path. It doesn't (`round=none`, or a new `loads=1`) → the spec's fallback: reloads end the round.
- (c): the `file changed` and `cache cleared` lines appeared and the ordinary `/probe rule` returns `v2` with the round id unchanged → main path: the manager clears the module cache from `onFileChanged`. No `file changed` line, or `/probe rule` still `v1`, while `/probe rule fresh` gives `v2` → the event doesn't arrive or arrives too late, so nested edits need the manager's own reload; record it for the plan. Both `v1` → nested edits need a server restart.

## Probe 3: extension load and unload

**Uncertainty:** whether the base can load and unload a game's client extension at run time, cleanly, with hooks and UI calls reaching it exactly once while loaded and never after unloading.

**Setup:** both client mods installed; joined; the **Arcade Probe** app placed on the UI (`app mounted` in `beamng.log`).

**Actions:** one line at a time in the GE Lua console (`~`), and the app's **Ping game** button where named:

1. `arcadeProbeBase.loadGame()` twice. Expect `load ok=true` both times, no error, and then a `game onUpdate n=…` line about once a second (the control: frame updates reach the loaded game).
2. `arcadeProbeBase.ping()`, then **Ping game**. Expect exactly one `game ping n=…` and one `game ui ping n=…`.
3. `arcadeProbeBase.unloadGame()`. Expect `game unloaded`, and no `game onUpdate` line in the next three seconds.
4. `arcadeProbeBase.ping()`, then **Ping game**. Expect neither `game ping` nor `game ui ping`.
5. `arcadeProbeBase.unloadGame()` again. Expect no error.
6. `arcadeProbeBase.loadGame()`. Expect `game onUpdate n=…` lines again, about once a second. Then `arcadeProbeBase.ping()` and **Ping game**: expect exactly one of each again.

**Decides:** `game onUpdate` lines while loaded, none after unloading, and again after reloading, with one, zero, one answer per trigger → main path. Any answer or `game onUpdate` line after unloading, or two per trigger after reloading → fallback: game extensions stay loaded and go dormant between rounds. No `game onUpdate` line in step 1 → the frame hook never reached the game, so step 3 proves nothing about updates; record it for the plan.

## Probe 4: app content

**Uncertainty:** whether a manager-defined app can change its content per game through a plain update, or needs a full snapshot on every game switch.

**Setup:** the **Arcade Probe** app placed; `app mounted` in `beamng.log`. Take a screenshot after each step.

**Actions:** in the GE Lua console:

1. `arcadeProbeBase.show({game="A", extra="only in A"})`. The app shows `redraw: 0`, `game: A` and `extra: only in A`.
2. `arcadeProbeBase.show({game="B"})`.

**Decides:**

- The app shows `game: B` without `extra`, with no client restart → main path.
- `extra` is still shown → run `arcadeProbeBase.snapshot({game="B"})`. A snapshot rebuilds the app's content from scratch, and `redraw` goes up by one. If that clears `extra` → the spec's fallback: a full snapshot on every game switch. If `redraw` went up and `extra` is still shown, or `redraw` didn't change → a failure; record it for the plan.

## Probe 5: versions

**Uncertainty:** whether the client can read the installed versions of the base and game mods and report them to the server, for the manager's version check.

**Setup:** both client mods installed.

**Actions:**

1. Join. The server console shows `versions from <name>: {…}` with the mod manager's reading (`base`, `game`, `source`) and the packaged files' reading (`base_file`, `game_file`). The mod manager's reading counts a mod only when its record says it is active or mounted; a record that says neither shows as `unconfirmed <version>`, which doesn't count as installed. `beamng.log` has a `mod <name> as=<base|game> evidence=…` line per record it found.
2. Leave the server. Run `probes/engine/install.sh --remove <test server>`, then `probes/engine/install.sh --no-game <test server>`, restart the server and join again. Expect game `missing` and base still `0.0.1`.

**Decides:**

- Either reading gives base `0.0.1` and game `0.0.2` (and `missing` without the game mod) → main path, using that reading.
- A report arrives but neither reading has the versions → fallback: the outdated-mod check as Cops and Robbers does it today.
- No `versions from` line after joining → run `arcadeProbeBase.versions()` once in the GE Lua console and check the server console again. A line now → reporting works but the automatic report on join didn't fire (BeamMP can rejoin the same map without a new level load); record it as a timing note for the plan. Still none → the client-to-server event failed; record it as a failure for the plan.

## Remove

```sh
probes/engine/install.sh --remove <cops-and-robbers checkout>/.testserver
```

It deletes only the paths in its install record, after checking every line is a probe path. Then restart the test server, and reconnect or quit the client: BeamMP stops watching deleted files but keeps their plugin state loaded until a restart.

## Recording the results

Share the `[arcade-probe]` lines from the server console and `current/beamng.log`, and the probe 4 screenshots. Each probe's outcome and the spec path it decides go on [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1).
