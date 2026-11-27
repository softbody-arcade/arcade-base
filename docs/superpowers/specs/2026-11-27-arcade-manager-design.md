# Arcade manager: how games run on the base

Status: draft for the maintainer's review, 2026-11-27. Ticket: [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1); the decisions it rests on are comments there. Cops and Robbers' side of the move: [cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56).

This spec is for the person deciding how games use the base. It describes the manager, what a game provides, how the two are loaded and talk, and the order in which Cops and Robbers moves onto it. It is the base's first version; the plan that follows breaks it into tasks.

## Why

Softbody Arcade will run several minigames on one BeamMP server, switching between them without a restart. Cops and Robbers already has most of what every game needs (a lobby, spectating, a settings app, car picking, a leaderboard, a HUD, round conditions, road search), but it is woven into one game: `server/CopsAndRobbers/main.lua` (1,671 lines) and `client/lua/ge/extensions/copsAndRobbers.lua` (1,385 lines) mix the lobby, the panel, cars, the leaderboard and config with runner and cop rules in about a dozen places. A second game would either copy all of that or wait for it to be shared. The base is where it becomes shared once.

## Goals

- One manager runs the session for every game: who is on the server, which game is active, the lobby, ready-up, sit out and spectating, settings, switching, the leaderboard store and cleaning up after a round.
- A game is a plugin: it provides its rules and its content, and gets everything above for free.
- Players see one set of apps for every game, and switching games feels the same whatever the game.
- Cops and Robbers moves onto the base without players losing anything they have today, through steps that can each be playtested.
- Street racing (with Upgrade racing and Wheel racing) can be built next without changing the manager's model.

## Non-goals

- Street racing itself, and any other new game. The spec only checks that they fit.
- The board bot (arcade-base#19) and other repo tooling.
- A defined host role. Every player can use the settings app, as today; a host role is a separate idea (arcade-base#22).
- Carrying 2.x data over: Cops and Robbers 3.0.0 starts fresh (decision on #1).
- A combined install bundle. A server installs the base plus one mod per game (decision on #1).

## Anti-goals

These would spoil the base even if the code worked:

- **One game's rules in the manager.** If the manager knows about runners, cops, catches or races, the second game pays for the first one's shape. Evolving mode is the example: its tools are the base's, its name and rules are Cops and Robbers' (decision on #1).
- **A game that can leave the server broken.** After a game fails or is switched away from, no player may be left with locked inputs, a frozen camera, a changed sky, parked cars or AI from the previous game.
- **A different set of screens per game.** Players learn one panel, one HUD, one leaderboard and one player-settings card.
- **A big-bang move.** No single release where everything changes at once and nothing could be playtested before.

## Decisions (the maintainer's)

All are comments on [#1](https://github.com/softbody-arcade/arcade-base/issues/1) unless noted.

1. **The base runs the session; games are plugins that provide the game logic.** Rejected: the base as only a toolbox.
2. **One server, one game at a time, switched without a restart.** Any player switches in the settings app between rounds, with no vote. A switch resets ready states, cancels a pending automatic next round and tells everyone. At server start the last-played game is active.
3. **Series.** While a game's series runs, switching is blocked; players can end the series early, with the standings so far counting, and then switch. The series itself is the game's.
4. **Settings.** Global settings apply to every game; a game can override them. Settings only one game has are that game's (the car mode exists only in Cops and Robbers).
5. **Player settings.** A player's colour and preferences are shared across games. The player-settings card gets a global section and a section per game.
6. **UI apps.** Games can't ship their own apps. The manager defines the set of apps and a game provides content for them (its alerts, settings, leaderboard views, HUD parts).
7. **Car changes.** The base has the tools (apply a part change to cars, rebuild them, report missing parts). Evolving mode, with its name and rules, is Cops and Robbers'.
8. **Order.** Cops and Robbers first splits its manager half from its game half in its own repo, in 2.x releases that are playtested step by step. Moving the manager half into the base is then mostly moving files, and Cops and Robbers 3.0.0 is the switch.
9. **Stability.** The base stays at 0.x while one game uses it: any 0.x release may change the contract and a game pins an exact base version. The rule "a minor release never breaks a game" starts at 1.0, once a second game runs on it.
10. **Existing data.** Cops and Robbers 3.0.0 starts fresh.
11. **Installing and versions** (earlier decisions): a server installs the base plus one mod per game; games include the base as a submodule at `base/` pinned to a release; the base checks every installed game's required version at start and leaves out games that don't match, saying why.
12. **Round conditions.** All of Cops and Robbers' conditions move to the base as manager services any game uses: time of day and day length, weather and its changes during a round, rain grip, wind, lightning, street lights and traffic. Cops and Robbers keeps only what is about its rules, such as how weather affects cop sight.
13. **Server version.** The base requires BeamMP Server 3.9.3 or newer and checks it at start.

## How it works

### Who owns what

| Concern | Manager (base) | Game |
|---|---|---|
| Players on the server, joins, leaves, reconnects | Owns the roster; passes joins and leaves to the active game | Reacts during its own phases |
| Active game, switching | Owns; refuses while the game says "don't switch now" (series, round running) | Says when switching is blocked |
| Lobby, ready-up, sit out | Owns the screens and states | May add lines to the lobby card (for example who runs next) |
| Spectating | Owns the camera cycling, the spectating card, late joiners watching | Says who is in a round and what to follow |
| Round phases | Knows only: lobby, the game's round, results | Owns every phase inside its round (Cops and Robbers: preparation, head start, chase; Street racing: grid, race) |
| Preparation and car picking | Supplies the tools: spawning, placing, picking a car (random, chosen, limits, mod and excluded cars) | Decides who picks what and when, and where cars go |
| Car changes | Tools: apply a change, rebuild, report missing parts | Rules: when, who, what (evolving mode, upgrades, wheel results) |
| Settings | Global settings, the settings app, saving, locking during a round, a snapshot at round start | Declares its settings and its overrides of global ones |
| Player settings | Colour and global preferences, the card | Declares its own section (siren, route to the runner, …) |
| Leaderboard | Stores round records per game; the app | Writes its round records; supplies how they are ranked and shown |
| HUD, announcements, alerts | The apps and their layout; generic parts (timers, notices, countdowns) | Content: its HUD parts, alerts, How to play text |
| Round conditions (time, day length, weather and its changes, rain grip, wind, lightning, street lights) and traffic | Services with state: the manager sets them for a round from the settings snapshot and restores them after | Reads them; may ask for changes through the service (Cops and Robbers' sight uses them) |
| Road search | A plain module any game calls | Calls it |
| Starting a round | Any player presses Start in the panel, or automatic rounds start the next one; the manager checks the game's minimum players | Declares its minimum players; may refuse to start with a reason (for example no runner chosen) |
| World changes outside the services (scene objects, vehicle decorations, extra cameras) | A registry: the game creates them through the manager, which removes them on cleanup | Uses the registry; never changes the world directly |
| Vehicle spawn and edit checks | Receives the BeamMP events; asks the active game | Answers allow or refuse, synchronously |
| Cleanup | Owns it: after every round, switch or failure, returns every player to the lobby state on server and client | Cleans up its own state; the manager doesn't rely on it |

### The cycle

The manager knows three states: **lobby**, **in a round** and **results**. Everything inside a round belongs to the game. A game that runs a series (Street racing) keeps the series between rounds itself and tells the manager to block switching until it ends. Practice rounds, AI and watch-only practice are Cops and Robbers' features inside its rounds.

Gameplay examples:
- **Success:** a Cops and Robbers round ends; the results show; a player opens the settings app and picks Street racing. Ready states reset, everyone sees "Street racing is next", and the lobby card shows Street racing's lines. Nobody's camera, inputs, sky or traffic stays as Cops and Robbers left it.
- **Success:** in the third race of a five-race Upgrade series, a player tries to switch. The switcher is greyed out with "A series is running: end it first". They end the series early; standings after three races count; the switch works.
- **Failure the design prevents:** a game errors halfway through a chase. The manager ends the round with a notice, releases inputs and the camera, removes the round's AI and traffic, restores the sky, and returns everyone to the lobby, without calling into the failed game again for the cleanup.

### Settings

- **Global settings** (the manager's): those any game can use. **Proposed:** round conditions (time of day, weather, lightning, traffic), automatic rounds and the wait between them, and the car lists (allowed mod cars and excluded cars).
- **Per-game settings**: a game's own (Cops and Robbers: car mode, catch time, head start, helicopter, …) and its overrides of global ones.
- **Proposed storage:** the manager stores settings outside the folders an install replaces, in one file per server for the global settings and one per game, so updating a mod never resets them.
- **Proposed snapshot:** a round uses the settings as they were when it started; changes wait for the next round (today's "locked during a round", kept).

### Player settings

The card has a **global** section (**proposed:** colour, auto headlights, hiding the HUD) and a section **per game** for options only that game has (Cops and Robbers: siren, searchlight beam, helicopter sound and model, lightning flashes, route to the runner). Where each existing option goes is listed in the plan; the rule is that an option belongs to a game when only that game uses it.

### Apps

The manager defines the apps, as today: panel (settings, game switcher, round controls), HUD, announcements, leaderboard, How to play and the player-settings card. A game provides content as data the apps know how to show:

- **Settings:** a declared list of settings with type, range, choices, default and help line; the panel draws them.
- **Leaderboard:** the game's views (tabs, columns, ranking) computed by the game from its stored records; the app draws tables.
- **HUD:** generic parts (lines, timers, bars, distances, role chips) the game fills; the manager places them.
- **Alerts and announcements:** the game's own texts and styles from a fixed set.
- **How to play:** the game's text.
- **Actions:** buttons and cards with buttons the game defines (for example Cops and Robbers' runner picker, its queued evolving change with Apply, its practice buttons); pressing one calls the game's handler through the manager, which checks the session number and who may press it.

The panel keeps its tabs as manager tabs filled by the game: **Round** (Start, End, the game switcher, the game's round actions), **Car** (the manager's car picking, plus the game's section, such as the evolving build), **Map** (the game's map content, such as Cops and Robbers' gas stations, using the base's road search) and **Settings** (global settings, then the game's). The HUD's change card is the game's content drawn with the generic parts and actions.

**Proposed:** during the 2.x split the apps keep their current ids and are made data-driven step by step; they get the manager's names at 3.0.0. Players' saved app placements reset then, which fits the fresh start (decision 10).

**Choice left to the builder:** the exact list of HUD parts and alert styles, as long as Cops and Robbers' current HUD and announcements can be drawn from them.

### Leaderboard

The manager stores **round records per game**: one record per round, with the game's id and mode, a schema version, the players and their results as the game reports them. The game supplies the functions that turn records into its views: Cops and Robbers' runner times, catches, assists and per-player stats; Street racing's series standings. Declaring columns alone can't express cop assists or series standings, so the game computes, the manager stores and draws.

### Cars

The base offers tools: spawn and place a car, pick one (random from the allowed list, chosen by the player, within limits), apply a part change to a set of cars and rebuild them, and report which players miss parts. A game decides policy: who picks, when changes happen, whose car changes. Cops and Robbers' evolving mode, Street racing's per-player upgrades and Wheel racing's changes for everyone except last place all use the same tools. **Proposed:** the tools keep a car's build keyed by game and, where a game wants, by player.

### Switching and stale events

- Switching happens only in the lobby or results state, and not while the active game blocks it.
- **Proposed:** every round and every switch get a session number; every event between manager, game and client carries it; the manager drops events from an earlier session. A late GO, vehicle acknowledgement or settings save from the previous game then can't affect the next one.
- On join or reconnect, a player gets a full snapshot of the current state.

### Failure and cleanup

- Every call from the manager into a game is protected (`pcall` on the server; the same on the client). An error ends the round with a notice and the manager's own cleanup.
- **The manager's cleanup doesn't depend on the game:** on the server it stops the round's timers and removes its AI and traffic; on each client it releases input and spawn locks, frees the camera, resets the round-condition services (time, sky, weather, wind, grip, lightning, street lights), removes everything in the world-change registry, removes the round's HUD parts and returns the player to the lobby.
- **Proposed rule:** a game changes shared world state only through the manager's services and registry, so everything it changed can be undone. The plan lists every side effect in today's Cops and Robbers code (lightning scene objects, wind, surface grip, street lights, helicopter objects, own lights and light bars, …) and where each one goes.
- **Proposed:** a game that failed stays selectable; the error is in the server log and in the notice, and the maintainer decides what to fix. A hang (a game that never returns) is not caught by `pcall`; the builder keeps game calls short and the tick budget is checked in tests.

## Loading

### Server

BeamMP runs each folder in `Resources/Server` as a plugin with its own Lua state, and plugins only talk through events; a global event is asynchronous and drops values it can't serialise. Vehicle spawn and edit checks need a synchronous answer from the active game, so manager and games share one Lua state.

**Proposed** (both architecture reviewers, from the BeamMP Server v3.9.3 source): each folder carries a `PluginConfig.toml` with the same `LuaStateID`, so BeamMP runs the base's folder and every game's folder in one state and adds each folder to `package.path`. Each game keeps a small top-level entry file that only registers its manifest (id, name, version, the base version it needs, its modules); the manager collects the manifests in `onInit`, after every plugin has loaded, so folder order doesn't matter. Module names and global handler names get the game's prefix, because the state is shared. Only the manager registers BeamMP's own events and passes them on.

**Rejected:** a game folder without a top-level script, loaded by the manager with `require` (works, but depends on BeamMP's folder handling and path order); separate plugins talking through events (no synchronous answers for vehicle checks, and every exchange becomes a wait).

### Client

All mods on the server are downloaded by every player, and all GE extensions share one Lua state. **Proposed:** the base's extension is the only one that starts on load; it loads the active game's extension when the game becomes active and unloads it when the game is switched away, so an inactive game can't hook inputs, place apps or change the sky. Only the manager places apps and holds input locks, spawn locks, name tags and sky changes; a game asks the manager for them.

### Versions

- The base stays 0.x until a second game runs on it; a game pins an exact base version (decision 9).
- A game's manifest declares the base version it needs; at start the manager leaves out a game that doesn't match and says why in the server log and the panel.
- **Proposed:** each client reports the versions of the base and game mods it loaded on join; a mismatch with the server is shown to that player, as Cops and Robbers' outdated-mod warning does today.
- The manager checks the BeamMP Server version at start and refuses to run below 3.9.3 (decision 13).
- Shared Lua runs on the server under Lua 5.3 and on the client under LuaJIT, so modules used on both sides stay within what both support, and the base's tests run them under both.

## Order of work

Decision 8 sets the order. Each step is its own ticket and release.

0. **Probe the engine first** (below), on the local test server, before the split commits to a seam. Each probe has a fallback, so a failed probe changes the plan, not the decisions.
1. **Cops and Robbers 2.x: split along the seam, in its own repo.** Behind the contract in this spec, separate the manager half (roster, lobby, ready-up, sit out, spectating, settings and their storage, round-condition services and traffic, car tools, leaderboard store, cleanup) from the game half (round phases, roles, catch, sight, helicopter, evolving mode's rules, its settings and HUD content). Rename events to a manager prefix and a game prefix. Each step is a 2.x release with a playtest. Before the first step, record event traces of scripted rounds, and compare after each step.
2. **arcade-base 0.x: the manager half moves in**, with a small test-only second game that has two rounds per series, to prove switching, series blocking and cleanup aren't shaped by Cops and Robbers. Packaging and staging for two mods.
3. **Cops and Robbers 3.0.0: the switch.** Its manager half is removed and it runs as a game on the base, pinned to that base release. A clean install (a leftover 2.x `main.lua` would otherwise still run), fresh data.
4. **Player-settings card redesign and the game switcher UI** come after the move, not in it.

**Proposed:** once the manager half has moved into the base (step 2), Cops and Robbers 2.x freezes its copy: manager fixes go to the base, and only an urgent fix for players is made in both until 3.0.0.

## Engine assumptions to check

Each is a probe on the local test server before the code depends on it:

1. Two plugin folders with the same `LuaStateID` share one state; a module in one folder can be `require`d from the other; `onInit` fires once after both have loaded. **Fallback:** the game's folder has no top-level script and the manager loads its modules with `require` into its own state (also synchronous). If neither works: separate plugins, and vehicle checks answered by the manager from rules the game declares in advance.
2. What a hot reload of either folder does in the shared state, mid-round. **Fallback:** document that reloads end the round; the manager cleans up.
3. A GE extension can be loaded and unloaded at runtime by another extension, with its hooks and UI bindings gone after unloading. **Fallback:** every game's extension stays loaded but dormant: it does nothing until the manager activates it, and it only reaches inputs, apps and the world through the manager's services.
4. The manager's apps can show game-provided content (data, not code) and switch to another game's content without a client restart. **Fallback:** the manager re-sends a full snapshot and the apps redraw from it, as they do today on join.
5. A player's client can report which mod versions it loaded. **Fallback:** the outdated-mod check stays as Cops and Robbers does it today, moved into the manager.

## Automated acceptance

- The manager's tests drive a fake game through a session: join, ready, a round, results, a switch, a blocked switch during a series, an error in the game with the cleanup that follows, late events from a previous session dropped.
- A test-only second game runs on the same manager as Cops and Robbers' contract tests.
- Cops and Robbers' existing behaviour tests keep passing through every 2.x step; event traces of scripted rounds match before and after each step.
- Shared modules run under Lua 5.3 and LuaJIT.
- A game whose manifest asks for another base version is left out, with the reason.

## In-game checks

For the maintainer, after each step that changes what a player sees:

- A full Cops and Robbers round, practice, and a late joiner spectating, with nothing different from the release before.
- A switch to the test game and back: nothing left over (inputs, camera, sky, traffic, HUD).
- A game error in the middle of a round: everyone back in the lobby with a notice.

## Choices left to the builder

- The exact module layout and names inside the base, the contract's function names, and the prefix scheme.
- The list of HUD parts and alert styles, as long as Cops and Robbers' current screens can be drawn from them.
- How settings files are named and where outside the install folders they live, as long as an update never resets them.
- How the 2.x split is cut into steps, as long as each is playtestable and its event traces match.

## Approaches considered

| Choice | Picked | Not picked, and why |
|---|---|---|
| Who runs the session | The manager | A toolbox: no one would own the roster, settings and switcher between games |
| Server loading | One shared Lua state through `LuaStateID`, manifests collected in `onInit` | A folder without a script loaded by `require` (relies on folder handling and order); separate plugins and events (no synchronous vehicle checks) |
| Apps | The manager's fixed set, game content as data | Apps per game (players relearn screens; the client manages many apps) |
| Order | Split Cops and Robbers first, in playtestable 2.x steps | Base first and one move (all in-game risk in one release) |
| Stability | 0.x and exact pins until a second game | The minor/major promise from 0.1.0 (a second game's findings would each cost a major release) |
