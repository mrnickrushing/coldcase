# Vertical slice checklist

Work top to bottom. Do not skip to art. (Adapted from Claude Design's `PLAYTEST.md` for the Rojo
workflow — no manual Studio setup is needed.)

## Setup

- [ ] `rokit install`, then `rojo serve` and connect, or open `build/ColdCase.rbxlx`
- [ ] Optional: Game Settings → Security → **Enable Studio Access to API Services** (without it data
      does not persist between sessions)
- [ ] Output shows `[ColdCase] server up`

## Solo with NPCs — press Play, no attributes

- [ ] Lobby countdown reads "STARTS IN Ns · 5 NPCS JOIN" and the round starts with five NPCs
- [ ] WAIT FOR PLAYERS highlights, the countdown switches to "WAITING FOR PLAYERS · 1/4", no round starts, and the choice is still set after a rejoin
- [ ] PLAY NOW · NPCS switches back and the next intermission starts an NPC round
- [ ] With two players, one waiting: the other plays with NPCs, the waiter stays in the lobby and shows "WAITING" in the player list
- [ ] NPCs walk the map on paths rather than into walls, climb the stairs to other floors, and stop when the round ends
- [ ] If the NPCs cannot be built, the lobby shows "The NPCs could not join" and no one is dropped into a round alone
- [ ] An NPC murderer waits at least 12s, then picks off whoever is alone
- [ ] An NPC sheriff shoots only a killer it saw, or the outlined murderer at Last Call
- [ ] Stabbing, shooting, spectating and examining work on NPCs; the fibre clue matches their shirt
- [ ] Round rewards are paid in full with NPCs, and the NPCs are gone once everyone is back in the lobby

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
- [ ] When a murderer killed, the round ends on a 2.5s kill-cam circling the last kill, then results
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
- [ ] Dying puts the camera on a living player; ‹ › (or ← →) switches; respawning in the lobby keeps
      spectating; a revive or the end of the round hands the camera back
- [ ] The murderer's knife and the sheriff's pistol stay hidden while walking about and appear in hand
      only on a stab, throw or shot
- [ ] With the Radio pass a message reaches everyone; the dead cannot send one mid-round
- [ ] With the Emote pass the five emotes show over the player's head within 40 studs
- [ ] REPORT on a lobby row asks to confirm; reporting the same player twice is refused

## Mobile pass — test on a phone, not the emulator

- [ ] FIRE / THROW / REVIVE appear only for the roles that can use them
- [ ] USE relabels to STAB / EXAMINE / TAKE as the context changes
- [ ] Every button is comfortably thumb-sized, and the radio and emote dock covers none of them

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
- [ ] Fire `RequestStab` 10× in a second — at most 4 reach the handler (`Config.REMOTE_LIMITS`)
- [ ] Fire `RequestRadio` without the pass, or while dead mid-round — nothing is broadcast
- [ ] Fire `RequestReport` at the same player repeatedly — one report counted
- [ ] Regional policy: until `PlayerPolicy` resolves (and wherever PolicyService restricts), crates,
      seasonal keys, crafting and re-rolls are refused with a message, and TRADE shows N/A. Test a
      restricted player with a VPN or an account in a restricted region; attributes set by hand only
      change the UI, the server keeps its own cache

## Only after all of the above passes

- [ ] Walk each map floor by floor: every staircase climbs smoothly with no lip at the top, railings stop a stumble into a stairwell, doorways fit a running player
- [ ] Lockdown shuts some room doors but every room still has a way out
- [ ] Walk each map: lamps light the rooms and go dark for Lights Out, furniture blocks no route,
      spawn or coin
- [ ] Listen to all 22 cues in a round; swap any that miss the brief ([assets](assets.md))
- [ ] Weapons sit right in the hand when drawn
- [ ] Equip an Effect item: particles at the feet, dark in Lights Out; a knife with an effect shows it
      when drawn
- [ ] Equip a pet: it follows at the shoulder, hides when its owner dies, Nightwatch dims in Lights Out
- [ ] Store page assets ([store-page.md](store-page.md))
- [ ] 30-stranger closed test

Every hour spent on art before the exploit sweep is an hour you will spend again.
