# Cold Case

> One of you has a knife. Nobody knows who.

Cold Case is a round-based social deduction game for Roblox. 8–12 players, 90–150 second rounds,
one murderer, one sheriff, and a room full of people who have no idea which is which. The twist:
**bodies remember**. Every kill writes real evidence — the direction of the wound, a fibre from the
killer's coat, a time of death — and reading it fast is how innocents win instead of guessing.

**Status:** grey-box vertical slice, feature-complete in code. Three blockout maps, the full round
loop, evidence, medic revive and body drag, Last Call, economy with crates, crafting, direct buys and
Robux products, every menu screen, and the Production Handbook systems. No art and no audio assets
yet.

Design lives in Claude Design (project *Murder Mystery 2 Game Design*): the **Design Bible**,
**Production Handbook**, **Map Blockouts**, the interactive prototype, and a `studio/` folder of
reference Luau. This repo implements them; where they disagree, see
[Open design questions](#open-design-questions).

---

## Quick start

Requires [Rokit](https://github.com/rojo-rbx/rokit) and Roblox Studio with the Rojo plugin.

```bash
rokit install              # rojo, stylua, selene, luau-lsp, lune (pinned in rokit.toml)
rojo serve                 # then Connect from the Rojo plugin in Studio
# or build a place file
rojo build -o build/ColdCase.rbxlx
```

Nothing needs to be placed by hand, and no command-bar steps are needed. On server start
`Bootstrap` creates every RemoteEvent, builds the three grey-box maps into `ServerStorage.Maps` and a
`BodyTemplate`; each client builds its own HUD, menus and notices.

**Playtesting in Studio**

| To… | Do this |
| --- | --- |
| Save data between sessions | Game Settings → Security → *Enable Studio Access to API Services*. Without it ProfileStore uses its mock store and nothing persists. |
| Test solo | Set a number attribute `MinPlayers = 1` on `ServerStorage` (Studio only). |
| Preview a live-ops day | Set a number attribute `LiveOpsDay` on `ServerStorage`, e.g. `28` to open trading or `14` for Season One (Studio only). |
| Run a full round | Test → Clients and Servers → 4 players. |
| Sell Robux products | Put real ids in `src/shared/Products.luau`. An id of `0` is never shown or granted. |

See [docs/playtest.md](docs/playtest.md) for the vertical-slice checklist and exploit sweep.

## Controls

| Action | Keyboard / mouse | Touch | Who |
| --- | --- | --- | --- |
| Stab / examine / take pistol | E | USE | everyone (server decides) |
| Throw knife | Q | THROW | murderer |
| Shoot | Click | FIRE (aims at screen centre) | sheriff, hero |
| Revive a body | R | REVIVE | medic |
| Drag a body | hold F | hold DRAG | everyone |

## Project layout

```
default.project.json         Rojo tree
src/
  shared/                    → ReplicatedStorage.Shared
    Config.luau              every tuning number
    Theme.luau               every UI colour and font
    Catalog.luau             24 launch items + seasonal drops
    RarityTable.luau         published crate odds
    Shop.luau                direct-buy shelf, prices, effects
    Progression.luau         rank titles, rank-25 crate discount (unit tested)
    Products.luau            Robux gamepass and product ids
    FibreBands.luau          colour → fabric band for the fibre clue (unit tested)
    SoundCues.luau           the 22 sound cues, ranges and volumes
    LiveOps.luau             90-day calendar: seasons, trading unlock, boosts (unit tested)
    RateLimiter.luau         remote rate limiter (unit tested)
    RemoteSetup.luau         creates ReplicatedStorage.Remotes
    Build/                   BuildHud, BuildMenus, BuildNotices, ItemCard
  server/                    → ServerScriptService
    Bootstrap.server.luau    the only server entry point; wires every remote
    Services/                RoundService, RoleService, CombatService, EvidenceService,
                             AbilityService, EventService, EconomyService, ShopService,
                             CosmeticService, MonetizationService, CoinService, TradeService,
                             DataService, OnboardingService, AudioService, Analytics,
                             RemoteGuard, LiveOpsClock
  serverstorage/Build/       → ServerStorage.Build
    BuildMaps.luau           grey-box maps from the blockout data
  client/                    → StarterPlayerScripts
    ClientBootstrap.client.luau
    ClientState.luau         this client's role, data, prompt and screen
    Controllers/             HudController, MenuController, TradeController, InputController,
                             VisionController, NoticeController, SoundController, CoinController
vendor/ProfileStore.luau     MadStudio ProfileStore (Apache-2.0)
tests/                       Lune unit tests for pure modules
docs/                        store page, analytics, live-ops, playtest
```

## Architecture

**The server owns the truth.** The client never knows anyone else's role. `RoleAssigned` is always
`FireClient(player, role)` — never `FireAllClients`. Everything a client receives, an exploiter
reads.

```
INTERMISSION (20s)     lobby menus: map vote, crate, collection, trading
LOADING      (3s)      clone voted map, spawn with separation
REVEAL       (4s)      roles sent one player at a time, movement locked
ACTIVE       (90–150s) one map event at 45%, snitch reveal and Last Call at 30s left
RESOLUTION   (6s)      results screen: murderer, roster, kill timeline, payout
```

Rules the code follows, and new code should too:

- **Every client → server remote goes through `RemoteGuard.Connect`** in `Bootstrap`: 20 calls/sec
  per player, silent rejection, kick on sustained abuse. Handlers type-check their arguments and
  forward only what they expect.
- **The client sends intent, never outcomes.** Stabs, shots, throws, revives and drags are
  re-measured against real character positions. Coin pickups name a node; the server owns the node
  list and the amount. Prices come from shared modules but are charged on the server.
- **Positional sounds are sent only to players in range** (`AudioService:Emit`). A replicated
  `Sound` at the source would be a map of every knife swing.
- **Vision is local fog, name tags are local.** `VisionController` draws the radius with
  `Lighting.FogEnd`; the server never relies on it. Keep `Atmosphere` out of Lighting — it disables
  legacy fog.
- **Every tuning number lives in `Config`**, every colour and font in `Theme`.
- **Items enter an inventory in exactly one place** (`EconomyService:GiveItem`), which refuses
  starters and any seasonal item outside its season. A retired seasonal can never be minted again.
- **All deaths and revives go through `RoundService`** (`MarkDead`, `Revive`), so win conditions,
  the kill timeline and analytics see every one.
- **Robux receipts are idempotent.** Each `PurchaseId` is recorded in the profile and granted once.

## Production handbook → code

| § | Handbook section | Where |
| --- | --- | --- |
| 01 | HUD spec | `Build/BuildHud`, `HudController` |
| 02 | Onboarding + retention | `OnboardingService`, `RoleService` (forced innocent), `NoticeController` (hints), `MenuController` (free crate reel, locked crate, near-miss), `DataService` (streak), `EconomyService` (rank-5 gift, friend bonus) |
| 03 | Store page | [docs/store-page.md](docs/store-page.md) |
| 04 | Sound | `SoundCues`, `AudioService`, `SoundController` |
| 05 | Analytics | `Analytics`, [docs/analytics.md](docs/analytics.md) |
| 06 | Anti-exploit | `RemoteGuard`, `CombatService`, `CoinService`, `EvidenceService`, `AbilityService`, `TradeService`, `MonetizationService` |
| 07 | Live-ops | `LiveOps`, `LiveOpsClock`, crate screen countdown, [docs/live-ops.md](docs/live-ops.md) |

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

- **HUD tree.** The handbook lists `Top.State`, `Top.Timer`…; Claude Design's `BuildHud` wraps each
  in a pill (`Top.StateBox.Value`) and makes `RoleCard` the full-screen dim. The code follows the
  builder, with the handbook's numbers.
- **Murderer name tag.** The Design Bible gives the murderer "no name tag", but hiding only the
  murderer's tag identifies them to everyone. Not implemented; name tags follow the vision radius
  for every player instead.
- **Role colours in menus.** The HUD rule reserves amber, red, cyan and green for roles, but Claude
  Design's menu screens use amber and cyan for buttons. The menus follow their design.
- **Last Call** outlines the murderer for everyone, which names them in the last 30 seconds. That is
  the Design Bible's intent ("forces an ending"); flagging in case it proves too strong.
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

Not built yet: kill-cam, cosmetic models and effects for the 24 items (equipping works; nothing is
drawn), Radio and Emote pass perks (ownership is tracked), map preview images, report tooling,
audio assets, art.
