# Live-ops

From the Production Handbook §07. A social game dies in silence: something must change every two
weeks, and players must see it changing.

## Launch day

Set `LiveOps.LAUNCH_UTC` in `src/shared/LiveOps.luau` to the launch moment and publish. Until then
every gate reads day 0. In Studio, set a number attribute `LiveOpsDay` on `ServerStorage` to preview
any day.

## Calendar

| Day | What | In code? |
| --- | --- | --- |
| 0 | **Launch.** Three maps, 24 items, one crate. Watch `first_session_exit` hourly for 48 hours and fix whatever it points at first. | — |
| 7 | **First balance patch.** Expect the Archive to favour the murderer — widen two aisles rather than nerfing the knife. | Map geometry in `BuildMaps` |
| 14 | **Season One opens.** The Long Night: four seasonal items, a 600-coin seasonal crate, and a visible countdown. | `LiveOps.SEASONS`; Seasonal tab and "retires forever in N days" countdown on the crate screen. Seasonal keys (Robux) open it instead of coins. |
| 28 | **Trading unlocks.** Held back so the market has scarcity to trade. | `LiveOps.TRADING_UNLOCK_DAY` gates `TradeService` |
| 45 | **Fourth map.** Community-voted setting, teased two weeks ahead. | Add to `Config.MAPS` and `ServerStorage.Maps` |
| 60 | **Double coin weekend** (days 60–62). Notify lapsed players; measure returning-player D1 separately. | `LiveOps.COIN_BOOSTS` |
| 76 / 90 | **Season One closes.** Seasonal items retire permanently. | `closesDay = 90` — see note |
| 90 | **Season Two + Duos.** Two murderers who know each other against everyone else. | `LiveOps.DUOS_DAY` reserved; mode not built |

**Note:** the handbook gives both "Day 76 · Season One closes" and "retired forever on day 90" (a
76-day countdown from day 14). The code uses day 90. Change `closesDay` if 76 is intended.

## Season One · The Long Night

| Item | Kind | Rarity | Brief |
| --- | --- | --- | --- |
| Vigil | Knife | Seasonal · Rare | A candle-lit blade. The flame gutters when another player is within 20 studs — a tell its owner must learn to manage. |
| Hoarfrost | Pistol | Seasonal · Rare | Frosted barrel that clears as it cools between shots. The frost tells you the cooldown at a glance. |
| The Long Night | Effect | Seasonal · Legendary | Footsteps leave brief frost prints that fade over four seconds. Beautiful, and a liability. |
| Nightwatch | Pet | Seasonal · Legendary | A lantern that drifts behind you and dims during Lights Out instead of helping. Pure atmosphere. |

The seasonal crate draws only from these four, using the Locker's Rare and Legendary weights
renormalised (≈70% Rare, ≈30% Legendary). Publish those odds with the crate. Seasonal item values in
`Catalog` are placeholders.

## Never re-release a retired seasonal

The trade economy rests on scarcity being real. One re-release and every high-value item loses its
floor. This is enforced in code: `giveItem` refuses a seasonal item unless its own season is open,
and nothing can reopen a closed season short of editing `LiveOps.SEASONS` — which should never
happen. Existing copies keep trading forever.
