# Arcade manager: how games run on the base

Status: approved by the maintainer, 2026-11-27. Ticket: [arcade-base#1](https://github.com/softbody-arcade/arcade-base/issues/1); the decisions it rests on are comments there. Cops and Robbers' side of the move: [cops-and-robbers#56](https://github.com/softbody-arcade/cops-and-robbers/issues/56).

This spec is for the person deciding how games use the base. It describes the manager, what a game provides, how the two are loaded and talk, and the order in which Cops and Robbers moves onto it. It is the base's first version; the plan that follows breaks it into tasks.

## Why

Softbody Arcade will run several minigames on one BeamMP server, switching between them without a restart. Cops and Robbers already has most of what every game needs (a lobby, spectating, a settings app, car picking, a leaderboard, a HUD, round conditions, road search), but it is woven into one game: `server/CopsAndRobbers/main.lua` (1,671 lines) and `client/lua/ge/extensions/copsAndRobbers.lua` (1,385 lines) mix the lobby, the panel, cars, the leaderboard and config with runner and cop rules in about a dozen places. A second game would either copy all of that or wait for it to be shared. The base is where it becomes shared once.

## Goals

- One manager runs the session for every game: who is on the server, which game is active, the lobby, ready-up, sit out and spectating, settings, switching, the leaderboard store and cleaning up after a round.
- A game is a plugin: it provides its rules and its content, and gets everything above for free.
- Players see one set of apps for every game, and switching games feels the same whatever the game.
- Cops and Robbers moves onto the base without losing any gameplay feature it has today (its data starts fresh at 3.0.0, decision 10), through steps that are each playtested.
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

Recorded as comments on [#1](https://github.com/softbody-arcade/arcade-base/issues/1), under its Constraints and known facts, or as noted.

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
11. **Installing and versions** (earlier decisions; under Constraints and known facts on #1, and the [submodule decision on #6](https://github.com/softbody-arcade/arcade-base/issues/6#issuecomment-7225308653)): a server installs the base plus one mod per game; games include the base as a submodule at `base/` pinned to a release; the base checks every installed game's required version at start and leaves out games that don't match, saying why.
12. **Round conditions.** All of Cops and Robbers' conditions move to the base as manager services any game uses: time of day and day length, weather and its changes during a round, rain grip, wind, lightning, street lights and traffic. Cops and Robbers keeps only what is about its rules, such as how weather affects cop sight.
13. **Server version.** The base requires BeamMP Server 3.9.3 or newer and checks it at start.

## How it works

### Who owns what

The table is the **proposed contract**: where it goes beyond the decisions above, it is a proposal for the maintainer to check.

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
| Cleanup | Owns it: when the server ends a round (normally, or after a server-side game error) or switches games, undoes the round's effects on the server and every client and gives players their lobby controls back; the session moves to results (after a round) or lobby (after a switch or a server-side failure). A single client's error is handled for that client only (see Failure and cleanup) | Cleans up its own state; the manager doesn't rely on it |

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

The card has a **global** section (**proposed:** colour, auto headlights, hiding the HUD, and lightning flashes, since lightning is a shared service and the shared lightning service honours it in every game) and a section **per game** for options only that game has (Cops and Robbers: siren, searchlight beam, helicopter sound and model, route to the runner). Where each existing option goes is listed in the plan; the rule is that an option belongs to a game when only that game uses it.

### Apps

The manager defines the apps, as today: panel (settings, game switcher, round controls), HUD, announcements, leaderboard, How to play and the player-settings card. A game provides content as data the apps know how to show:

- **Settings:** a declared list of settings with type, range, choices, default and help line; the panel draws them.
- **Leaderboard:** the game's views (tabs, columns, ranking) computed by the game from its stored records; the app draws tables. A view can declare filters (Cops and Robbers: map, car mode, traffic), detail views for a player or a round (with its timeline), and paging ("more rounds"); the app sends the chosen filter or page back and the game answers with the rows.
- **HUD:** generic parts (lines, timers, bars, distances, role chips) the game fills; the manager places them.
- **Alerts and announcements:** the game's own texts and styles from a fixed set.
- **How to play:** the game's text, with placeholders the manager fills from the active game's effective settings in the lobby and from the round's snapshot during a round (Cops and Robbers shows its current catch time and distances), and sections a game shows or hides by the active rules.
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
- **Proposed start-up fallback:** on a fresh install, or when the last-played game is no longer installed or no longer compatible, the manager starts with the first compatible game by name and says why in the server log and the panel. With no compatible game it stays in the lobby, and the panel lists every installed game with the reason it was left out.
- **Proposed:** the server decides the session number. Every round start, server-side round end and switch moves it on; a single client's error doesn't. Every message between manager, game and client carries it.
- **Transitions come from the server:** a session-change message or a full snapshot from the server carries the new number and phase, and a client accepts it when its number is newer than the one it has. Within a session, every message from the server also carries a sequence number that only goes up; a snapshot is accepted when its session is newer, or its session is the same and its sequence number is higher than the last one the client applied. A replayed older snapshot, transition or update is ignored, so a client can't be rolled back, also within a session (a lobby snapshot from before a player readied up can't undo the ready). A joining or reconnecting player starts from the snapshot it gets.
- **Everything else must match:** a receiver acts on any other message only when its session number is the current one and the session is in a phase that accepts it (a GO only during the game's round, a settings save only in the lobby or results); the rest is dropped and logged. A late GO, vehicle acknowledgement or settings save then can't affect the lobby or the next game.
- **BeamMP's own callbacks** (spawn, edit, delete, reset) carry no session number. The manager keeps the list of vehicles that belong to the current round (registered when the round spawns or assigns them, removed when the round ends). A callback can change game state only for a vehicle on that list; for one the manager is waiting on (a spawn it asked for, a rebuild it started) it completes that operation. A callback for any other vehicle, or where ownership is unclear, never reaches the game's scoring: the manager logs it and applies only its own rules (for example the spawn lock during a round).
- **Reused vehicle IDs.** BeamMP reuses free vehicle IDs ([Client.cpp, v3.9.3](https://github.com/BeamMP/BeamMP-Server/blob/v3.9.3/src/Client.cpp)), so a late callback from round A can carry the same player and vehicle ID as a car in round B, at any delay. **Proposed:** a native callback alone never changes a game's score or rules. A reset (or edit) counts for a round only when the player's own client reports it in a message tagged with the round's session and sequence number. The game scores from that report: its round, its time and its data. The native callback only confirms that the vehicle really was reset, and each callback confirms at most one waiting report, oldest first. If a late callback from round A confirms round B's waiting report, B's reset still happened and is scored once from B's own report, and B's own callback then finds nothing waiting and is ignored. A native callback with no waiting report is left unscored and logged, however late it arrives; the manager still applies its own safety rules to it (for example the spawn lock). A late reset from round A therefore can't count in round B, even with the same IDs and after round B's car is confirmed.
- On join or reconnect, a player gets a full snapshot of the current state.

### Failure and cleanup

- Every call from the manager into a game is protected (`pcall` on the server; the same on the client).
- **An error in the game's server code** ends the round for everyone, with a short notice to players and the details in the server log. **Proposed:** a running series ends with it, standings so far counting.
- **Proposed: an error in the game's code on one client** is handled for that client only: a client can't end a round or change the session for everyone. The manager cleans up that client, puts the player into spectating, logs the error on the server and tells only that player. It then tells the server-side game that this participant is lost, the same way as a disconnect, and the game applies its own rules: in Cops and Robbers a lost cop leaves the chase and a lost runner ends it (or cancels the round in preparation), as a disconnect does today. If the same player fails again in the next round, they sit out until they rejoin.
- **The manager's cleanup doesn't depend on the game:** on the server it stops the round's timers and removes its AI and traffic; on each client it stops the traffic controller, removes local AI and cancels any AI setup still pending, puts back spectators' parked cars, releases input and spawn locks, frees the camera, resets the round-condition services (time, sky, weather, wind, grip, lightning, street lights), removes everything in the world-change registry and the round's HUD parts, and gives the player their lobby controls back. The tests cover a failure while traffic is still spawning and while a spectator's car is parked.
- **Proposed rule:** a game changes shared world state only through the manager's services and registry, so everything it changed can be undone. The plan lists every side effect in today's Cops and Robbers code (lightning scene objects, wind, surface grip, street lights, helicopter objects, own lights and light bars, …) and where each one goes.
- **Proposed:** a game that failed stays selectable; the error is in the server log and in the notice, and the maintainer decides what to fix. A hang (a game that never returns) is not caught by `pcall`; the builder keeps game calls short and the tick budget is checked in tests.

## Loading

### Server

BeamMP runs each folder in `Resources/Server` as a plugin with its own Lua state, and plugins only talk through events; a global event is asynchronous and drops values it can't serialise ([BeamMP server reference](https://docs.beammp.com/scripting/server/latest-server-reference/); [TLuaEngine.cpp, v3.9.3](https://github.com/BeamMP/BeamMP-Server/blob/v3.9.3/src/TLuaEngine.cpp)). Vehicle spawn and edit checks need a synchronous answer from the active game, so manager and games share one Lua state.

**Proposed** (both architecture reviewers, from the BeamMP Server v3.9.3 source): each folder carries a `PluginConfig.toml` with the same `LuaStateID`, so BeamMP runs the base's folder and every game's folder in one state and adds each folder to `package.path`. Each game keeps a small top-level entry file that only registers its manifest (id, name, version, the base version it needs, its modules); the manager collects the manifests in `onInit`, after every plugin has loaded, so folder order doesn't matter. A hot reload re-runs a changed top-level file and can fire `onInit` again in that state ([TPluginMonitor.cpp, v3.9.3](https://github.com/BeamMP/BeamMP-Server/blob/v3.9.3/src/TPluginMonitor.cpp)), so collecting manifests must be safe to repeat (probe 2). Module names and global handler names get the game's prefix, because the state is shared. Only the manager registers BeamMP's own events and passes them on.

**Rejected:** a game folder without a top-level script, loaded by the manager (kept only as the fallback in probe 1: BeamMP adds a folder to the `package.path` of its own state only, so the manager would have to find the game folders under `Resources/Server` itself and add their paths); separate plugins talking through events (no synchronous answers for vehicle checks, and every exchange becomes a wait).

### Client

Every client mod (the ZIPs in `Resources/Client`) is downloaded by every player; server plugins stay on the server. All GE extensions share one Lua state. **Proposed:** the base's extension is the only one that starts on load; it loads the active game's extension when the game becomes active and unloads it when the game is switched away, so an inactive game can't hook inputs, place apps or change the sky. Only the manager places apps and holds input locks, spawn locks, name tags and sky changes; a game asks the manager for them.

### Versions

- The base stays 0.x until a second game runs on it; a game pins an exact base version (decision 9).
- A game's manifest declares the base version it needs; at start the manager leaves out a game that doesn't match and says why in the server log and the panel.
- **Proposed:** each client reports the versions of the base and game mods it loaded on join; a mismatch with the server is shown to that player, as Cops and Robbers' outdated-mod warning does today.
- The manager checks the BeamMP Server version at start and refuses to run below 3.9.3 (decision 13).
- Shared Lua runs on the server under Lua 5.3 (BeamMP Server 3.x) and on the client under LuaJIT (BeamNG.drive), as Cops and Robbers' `docs/DEPENDENCIES.md` records, so modules used on both sides stay within what both support, and the base's tests run them under both.

## Order of work

Decision 8 sets the order. Each step is its own ticket and release.

0. **Probe the engine first** (below), on the local test server, before the split commits to a seam. Each probe has a fallback, so a failed probe changes the plan, not the decisions.
1. **Cops and Robbers 2.x: split along the seam, in its own repo.** Behind the contract in this spec, separate the manager half (roster, lobby, ready-up, sit out, spectating, settings and their storage, round-condition services and traffic, car tools, leaderboard store, cleanup) from the game half (round phases, roles, catch, sight, helicopter, evolving mode's rules, its settings and HUD content). Events keep their current `cnr_` names through 2.x, so recorded traces stay comparable; the manager and game prefixes come at 3.0.0. Each step is a 2.x release with a playtest. Before the first step, record event traces of scripted rounds (recipients, order and payload fields that matter, with times and random choices fixed by the test), and compare after each step.
2. **arcade-base 0.x: the manager half moves in**, with a small test-only second game that has two rounds per series, to prove switching, series blocking and cleanup aren't shaped by Cops and Robbers. Packaging and staging for two mods.
3. **Cops and Robbers 3.0.0: the switch.** Its manager half is removed and it runs as a game on the base, pinned to that base release. A clean install (a leftover 2.x `main.lua` would otherwise still run), fresh data.
4. **The player-settings card redesign** (global and per-game sections) comes after the move, not in it.

The game switcher is part of the manager's panel from the first base release that runs two games (step 2, with the test game): a minimal one, a list of compatible games and a Switch button with the reason when it's blocked. Its look can be refined later; the behaviour players get (decision 2) is there from the start. The in-game check of switching runs from step 2 on, between the test game and a staging-only build of the split Cops and Robbers running on that base release (Cops and Robbers itself is released on the base in step 3).

**Agreed milestones** (decision 8): the split in Cops and Robbers 2.x, then the manager in the base, then Cops and Robbers 3.0.0. **Proposed delivery:** the numbered steps above, the probes first, the test game, and the switcher and card timing.

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
- A game whose manifest asks for another base version is left out, with the reason. Start-up picks the last-played game; on a fresh install, or when it's missing or incompatible, the first compatible game; with none, the lobby with every game's reason.
- Late messages are dropped right after a round's cleanup as well as after a switch; native vehicle callbacks outside an expected operation go to the game only during its round.
- A client-side game error puts only that player into spectating and reaches the game as a lost participant, without the manager changing the session itself. Tested by role: when a Cops and Robbers cop's client fails, the chase goes on, the session number stays, and another player's next message in the same round still goes through; when the runner's client fails, the game ends the chase (or cancels the round in preparation), which is a server-side round end, so the session moves on and every player gets the cleanup. A server-side error ends the round for everyone.
- A replayed older snapshot, transition or update can't roll a client back, across sessions and within one (a lobby snapshot from before a ready-up, replayed afterwards, changes nothing); a joining client takes the server's current session and sequence from its first snapshot.
- A delayed reset from round A, delivered after round B has started and after round B's car has been confirmed, carrying the same player and vehicle IDs as that car, changes nothing in round B, also when it arrives while one of round B's own reset reports is waiting (B's reset is then scored exactly once, from its report); a reset in round B with its tagged client report counts as before.
- **Note for the plan:** scoring a reset now needs the player's client to report it. A modified client could stop reporting its own resets; today's server-only reset rules have the same limit for anything else a client controls, and the plan should say whether the server-side callback count is kept as a cross-check.
- Parity with Cops and Robbers 2.x: the leaderboard's filters, player and round detail views and "more rounds", How to play's current values, the panel's tabs and the HUD's change card.

## In-game checks

For the maintainer, after each step that changes what a player sees:

- A full Cops and Robbers round, practice, and a late joiner spectating, with nothing different from the release before.
- A switch to the test game and back: nothing left over (inputs, camera, sky, traffic, HUD).
- A game error in the middle of a round: everyone back in the lobby with a notice (server side); a cop's client: that player spectating, the chase going on; the runner's client: the chase ends for everyone, as when the runner disconnects today (client side).

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
