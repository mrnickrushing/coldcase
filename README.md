# Cold Case

> One of you has a knife. Nobody knows who.

Cold Case is a round-based social deduction game for Roblox. 8–12 players, 90–150 second rounds,
one murderer, one sheriff, and a room full of people who have no idea which is which. The twist:
**bodies remember**. Every kill writes real evidence — the direction of the wound, a fibre from the
killer's coat, a time of death — and reading it fast is how innocents win instead of guessing.

**Status:** grey-box vertical slice. Three blockout maps, the full round loop, evidence, economy,
onboarding and the production-handbook systems are in code. No art, no audio assets yet.

Design lives in Claude Design (project *Murder Mystery 2 Game Design*): the **Design Bible**,
**Production Handbook**, **Map Blockouts** and the interactive prototype. This repo implements them;
where the two disagree, see [Open design questions](#open-design-questions).

---

## Quick start

Requires [Rokit](https://github.com/rojo-rbx/rokit) and Roblox Studio with the Rojo plugin.

```bash
rokit install              # rojo, stylua, selene, luau-lsp, lune (pinned in rokit.toml)
rojo serve                 # then Connect from the Rojo plugin in Studio
# or build a place file
rojo build -o build/ColdCase.rbxlx
```

Nothing needs to be placed by hand. On server start `Bootstrap` creates every RemoteEvent, builds
the three grey-box maps into `ServerStorage.Maps` and a `BodyTemplate`; each client builds its own
`RoundHud` and `LobbyHud`.

**Playtesting in Studio**

| To… | Do this |
| --- | --- |
| Save data between sessions | Game Settings → Security → *Enable Studio Access to API Services*. Without it ProfileStore uses its mock store and nothing persists. |
| Test solo | Set a number attribute `MinPlayers = 1` on `ServerStorage` (Studio only). |
| Preview a live-ops day | Set a number attribute `LiveOpsDay` on `ServerStorage`, e.g. `28` to open trading or `14` for Season One (Studio only). |
| Run a full round | Test → Clients and Servers → 4 players. |

See [docs/playtest.md](docs/playtest.md) for the vertical-slice checklist and exploit sweep.

## Project layout

```
default.project.json         Rojo tree
src/
  shared/                    → ReplicatedStorage.Shared
    Config.luau              every tuning number
    Theme.luau               every UI colour and font
    Catalog.luau             24 launch items + seasonal drops
    RarityTable.luau         published crate odds
    SoundCues.luau           the 22 sound cues, ranges and volumes
    LiveOps.luau             90-day calendar: seasons, trading unlock, boosts
    RateLimiter.luau         pure rate limiter (unit tested)
    RemoteSetup.luau         creates ReplicatedStorage.Remotes
    Build/BuildHud.luau      RoundHud instance tree (handbook §01)
    Build/BuildLobby.luau    vote, locker, results, hints, toasts
  server/                    → ServerScriptService
    Bootstrap.server.luau    the only server entry point; wires every remote
    Services/                RoundService, RoleService, CombatService, EvidenceService,
                             EventService, EconomyService, CoinService, TradeService,
                             DataService, OnboardingService, AudioService, Analytics,
                             RemoteGuard, LiveOpsClock
  serverstorage/Build/       → ServerStorage.Build
    BuildMaps.luau           grey-box maps from the blockout data
  client/                    → StarterPlayerScripts
    ClientBootstrap.client.luau
    ClientState.luau         this client's role, data and prompt
    Controllers/             HudController, InputController, LobbyController,
                             SoundController, CoinController
vendor/ProfileStore.luau     MadStudio ProfileStore (Apache-2.0)
tests/                       Lune unit tests for pure modules
docs/                        store page, analytics, live-ops, playtest
```

## Architecture

**The server owns the truth.** The client never knows anyone else's role. `RoleAssigned` is always
`FireClient(player, role)` — never `FireAllClients`. Everything a client receives, an exploiter
reads.

```
INTERMISSION (20s)   map vote open, Locker, trading
LOADING      (3s)    clone voted map, spawn with separation
REVEAL       (4s)    roles sent one player at a time, movement locked
ACTIVE       (90–150s) one map event at 45%, snitch reveal at 30s left
RESOLUTION   (6s)    murderer revealed, payouts, near-miss message
```

Rules the code follows, and new code should too:

- **Every client → server remote goes through `RemoteGuard.Connect`** in `Bootstrap`: 20 calls/sec
  per player, silent rejection, kick on sustained abuse. Handlers type-check their arguments and
  forward only what they expect.
- **The client sends intent, never outcomes.** Stabs, shots and throws are re-measured against real
  character positions. Coin pickups name a node; the server owns the node list and the amount.
- **Positional sounds are sent only to players in range** (`AudioService:Emit`). A replicated
  `Sound` at the source would be a map of every knife swing.
- **Every tuning number lives in `Config`**, every colour and font in `Theme`. Two fonts, one colour
  per role, used nowhere else.
- **Items enter an inventory in exactly one place** (`giveItem` in `EconomyService`), which refuses
  seasonal items outside their season. A retired seasonal can never be minted again.
- **All deaths go through `RoundService:MarkDead`** — kills, misfires, resets and leavers alike —
  so win conditions and analytics see every one.

## Production handbook → code

| § | Handbook section | Where |
| --- | --- | --- |
| 01 | HUD spec | `Build/BuildHud`, `HudController` |
| 02 | Onboarding + retention | `OnboardingService`, `RoleService` (forced innocent), `LobbyController`, `DataService` (streak), `EconomyService` (rank-5 gift, friend bonus, near-miss) |
| 03 | Store page | [docs/store-page.md](docs/store-page.md) |
| 04 | Sound | `SoundCues`, `AudioService`, `SoundController` |
| 05 | Analytics | `Analytics`, [docs/analytics.md](docs/analytics.md) |
| 06 | Anti-exploit | `RemoteGuard`, `CombatService`, `CoinService`, `EvidenceService`, `TradeService` |
| 07 | Live-ops | `LiveOps`, `LiveOpsClock`, [docs/live-ops.md](docs/live-ops.md) |

## Checks

```bash
stylua --check src tests
selene src tests
rojo sourcemap -o sourcemap.json
luau-lsp analyze --definitions=types/globalTypes.d.luau --sourcemap=sourcemap.json --ignore="vendor/**" src
lune run tests
```

CI runs the same on every push and pull request.

## Open design questions

Places where the design documents disagree with each other, and what the code does today:

- **HUD tree.** The handbook lists `Top.State`, `Top.Timer`…; Claude Design's own `BuildHud` wraps
  each in a pill (`Top.StateBox.Value`) and makes `RoleCard` the full-screen dim. The code follows
  the builder, with the handbook's numbers (420px top bar, 10px gaps, 0.6 dim, 500px collapse).
- **Season One end.** The handbook says both "retired forever on day 90" and "Day 76 · Season One
  closes". Code uses day 90 (`LiveOps.SEASONS`).
- **Starting coins.** The design template starts players at 300 coins, which makes the "second crate
  visible but locked" moment impossible. `Config.STARTING_COINS` is 100.
- **Item names.** Rare knife *Longnight* and Season One effect *The Long Night* will read as the
  same item in trades.
- **Fonts.** Big Shoulders Display and IBM Plex Mono are not on the Creator Store; `Theme` uses
  Oswald and Roboto Mono until the faces are uploaded.
- **Map events.** The blockouts assign one event per map; `EventService` draws by weight as the
  Design Bible describes.

Not built yet: medic revive, body drag, Last Call, spectator camera, inventory/equip UI, trade UI,
seasonal crate button, Robux products, audio assets.
