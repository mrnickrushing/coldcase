# Analytics

From the Production Handbook §05: log these from the first playtest. Implemented in
`src/server/Services/Analytics.luau`. In Studio every event is also printed as `[Analytics] …`.

Roblox custom events take one numeric **value** and at most three custom **fields**, and each event
is capped at 8,000 unique field combinations. The player is always the event's player argument, so
`playerId` is never a field. Continuous numbers are the value, or bucketed when they have to be a
field.

## The ten events

| Event | Handbook fields | Value | Field 1 | Field 2 | Field 3 | Why |
| --- | --- | --- | --- | --- | --- | --- |
| `round_complete` | map, winner, duration, playerCount, event | duration (s) | map | winner | `EVENT\|players` bucket | Win rate per map per role finds balance problems. Logged once per round against one participant. |
| `role_assigned` | role, playerId, rank | rank | role | rank bucket | is first round | Proves the anti-repeat weighting and the forced-innocent first round. |
| `player_death` | role, killerRole, timeAlive, map, position | time alive (s) | role | killer role (`murderer`, `sheriff`, `hero`, `self`, `reset`, `left`) | `map:x,z` in 80-stud cells | Heatmaps find death-trap corners. Fix geometry, not numbers. |
| `evidence_examined` | clueCount, timeSinceDeath, playerRank | seconds since death | clue count | rank bucket | — | If low ranks never examine, onboarding failed. |
| `crate_opened` | crateId, rarity, itemId, coinsAfter | coins after | crate id | rarity | item id | Actual pulls vs published odds. Audit monthly. |
| `coins_earned` | source, amount, sessionTotal | economy event (Source) | session-total bucket | — | — | Faucet balance. Sources: `round`, `pickup`, `examine`, `revive`, `streak`, `robux`. |
| `coins_spent` | sink, amount, balanceAfter | economy event (Sink) | — | — | — | Sink balance. Sinks: `locker`, `seasonal`, `craft`, `shop`, `reroll`. |
| `trade_complete` | valueA, valueB, ratio, itemIds | ratio | value A bucket | value B bucket | ratio bucket | Lopsided ratios flag scams and dupes. |
| `session_end` | duration, roundsPlayed, coinsEarned, isNew | duration (s) | rounds bucket | coins bucket | is new | Rounds per session is the health metric. |
| `first_session_exit` | lastScreen, secondsPlayed, roundsPlayed | seconds played | last screen (`INTERMISSION`, `ACTIVE`, `SPECTATING`, …) | rounds bucket | — | Exactly where new players quit. |

`coins_earned` and `coins_spent` use `LogEconomyEvent`, so they also appear in the Economy dashboard
with the source or sink as the item SKU.

**Not logged:** trade `itemIds`. A list of item ids cannot fit the field cardinality cap. If scam or
dupe investigation needs them, add a server-side trade ledger (DataStore keyed by trade id) rather
than an analytics field.

## Also logged

| Event | Value | Field 1 | Field 2 | Why |
| --- | --- | --- | --- | --- |
| `player_report` | reports against that player on this server | reason (`exploiting`, `harassment`, `other`) | report-count bucket | Roblox's own report flow does the moderation; this shows whether reports cluster on one player. The reported player is never a field. |

## Onboarding funnel

Logged with `LogOnboardingFunnelStepEvent`, once per new player, in order:

1. `joined` · 2. `voted` · 3. `free_crate` · 4. `first_round_start` · 5. `first_round_end` ·
6. `second_round_start`

## KPI targets

| KPI | Target | Note |
| --- | --- | --- |
| D1 retention | 28% | Below 20% and paid traffic will never pay back. This decides whether to scale. |
| Rounds per session | 4.5 | Under 3 means the loop is not gripping. Look at round length before blaming content. |
| Crate conversion | 12% | Sessions with at least one pull. Under 8% means coins are too slow or crates too dull. |
| Avg session | 14 min | About six rounds plus lobby. Engagement beats duration. |
