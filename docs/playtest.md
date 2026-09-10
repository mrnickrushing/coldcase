# Vertical slice checklist

Work top to bottom. Do not skip to art. (Adapted from Claude Design's `PLAYTEST.md` for the Rojo
workflow — no manual Studio setup is needed.)

## Setup

- [ ] `rokit install`, then `rojo serve` and connect, or open `build/ColdCase.rbxlx`
- [ ] Optional: Game Settings → Security → **Enable Studio Access to API Services** (without it data
      does not persist between sessions)
- [ ] Output shows `[ColdCase] server up`

## First playtest — Test → Clients and Servers, 4 players

- [ ] Map vote panel is open on arrival; votes update for everyone
- [ ] A brand-new player gets a free Locker pull about five seconds after landing
- [ ] Intermission counts down; the round starts; everyone teleports to separated spawns
- [ ] Role card shows for 4s, movement locked during it
- [ ] A player on their first round is never murderer or sheriff (when veterans are present)
- [ ] Ghost hints appear once each: move, coins, examine — and not again after a rejoin
- [ ] Nobody can be killed in the first 4 seconds
- [ ] Murderer's E kills at close range, not at distance; Q throws with an 8s cooldown
- [ ] Sheriff click fires; hitting an innocent kills the sheriff too
- [ ] Sheriff death drops a pistol; an innocent can take it and becomes Hero
- [ ] Body appears; E within 14 studs, after a 1.5s channel, returns three or four clue lines
- [ ] Examining after 20s, or during Lights Out, returns "The trail has gone cold."
- [ ] Walking over a coin collects it once; coins land on the HUD
- [ ] Event fires at the 45% mark, once, banner fades in and out, lighting restores after
- [ ] Round ends on murderer death, wipe, or timeout; results card names the murderer
- [ ] Results show "You were N coins short." when the balance is under 250
- [ ] Locker shows `coins / 250` and reads NEED N MORE until affordable
- [ ] Everyone returns to the lobby; coins and XP survive a rejoin (with API access on)
- [ ] Results screen names the murderer, lists the roster with the dead struck through, shows the
      kill timeline and the payout
- [ ] Crate reel spins and lands on the item the server actually granted; the free first crate
      opens the crate screen by itself
- [ ] Published odds are visible on the crate screen, for the Locker and the seasonal crate
- [ ] Direct-buy shelf charges 1.6× item value; effect re-roll always lands on a new effect
- [ ] Inventory lists starters and owned items; Equip persists across a rejoin
- [ ] Crafting five duplicates yields one item of the next tier
- [ ] Medic R revives an unexamined body once per round; moving during the 3s breaks it
- [ ] Holding F for 2s drags a body at reduced walk speed; releasing drops it
- [ ] Last Call fires at 30s: banner, coins double, murderer outlined through walls
- [ ] Lights Out shrinks the vision radius (fog at 88 studs), not just brightness
- [ ] Fog Bank hides name tags past 40 studs
- [ ] With `LiveOpsDay = 28`, TRADE opens a table between two players who both ask

## Exploit sweep — before any public test

Run from a LocalScript or the client command bar.

- [ ] Print every value the client holds. **No other player's role appears.**
- [ ] Fire `RequestStab` at a distant player — nothing happens
- [ ] Fire `RequestShoot` 50× in a second — at most one shot lands; sustained spam disconnects
- [ ] Fire `RequestExamine` on a body across the map — nothing returns, not even "cold"
- [ ] Fire `RequestCoin` for every node id from one spot — only nodes within range pay
- [ ] Fire `RequestCrate` with 0 coins, and with `"seasonal"` outside the season — nothing granted
- [ ] Fire `RequestShoot` with a NaN vector — ignored, no server error
- [ ] Offer a uid you do not own, or the same uid twice, in a trade — rejected
- [ ] Change an offer after both locked — both locks and confirms reset
- [ ] Fire `RequestRevive` as a non-medic, or on an examined body — nothing happens
- [ ] Fire `RequestDrag` on a body across the map — nothing happens
- [ ] Fire `RequestEquip` with a uid you do not own — nothing changes
- [ ] Fire `RequestBuy` for an item not on the shelf, or without the coins — nothing granted
- [ ] Deliver the same developer-product receipt twice — coins granted once

## Only after all of the above passes

- [ ] Art pass on one map
- [ ] Sound assets into `SoundCues`
- [ ] Store page assets ([store-page.md](store-page.md))
- [ ] 30-stranger closed test

Every hour spent on art before the exploit sweep is an hour you will spend again.
