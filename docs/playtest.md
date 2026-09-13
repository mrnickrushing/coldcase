# Vertical slice checklist

Work top to bottom. Do not skip to art. (Adapted from Claude Design's `PLAYTEST.md` for the Rojo
workflow — no manual Studio setup is needed.)

## Setup

- [ ] `rokit install`, then `rojo serve` and connect, or open `build/ColdCase.rbxlx`
- [ ] Optional: Game Settings → Security → **Enable Studio Access to API Services** (without it data
      does not persist between sessions)
- [ ] Output shows `[ColdCase] server up`

## Solo with NPCs — press Play, no attributes

- [x] Lobby countdown reads "STARTS IN Ns · 5 NPCS JOIN" and the round starts with five NPCs
- [ ] WAIT FOR PLAYERS highlights, the countdown switches to "WAITING FOR PLAYERS · 1/4", no round starts, and the choice is still set after a rejoin
- [ ] PLAY NOW · NPCS switches back and the next intermission starts an NPC round
- [ ] With two players, one waiting: the other plays with NPCs, the waiter stays in the lobby and shows "WAITING" in the player list
- [x] NPCs walk the map on paths rather than into walls, climb the stairs to other floors, and stop when the round ends
- [ ] If the NPCs cannot be built, the lobby shows "The NPCs could not join" and no one is dropped into a round alone
- [ ] An NPC murderer waits at least 12s, then picks off whoever is alone
- [ ] An NPC sheriff shoots only a killer it saw, or the outlined murderer at Last Call
- [ ] Stabbing, shooting, spectating and examining work on NPCs; the fibre clue matches their shirt
- [x] Round rewards are paid in full with NPCs, and the NPCs are gone once everyone is back in the lobby

## First playtest — Test → Clients and Servers, 4 players

- [ ] Map vote panel is open on arrival; votes update for everyone
- [ ] A brand-new player gets a free Locker pull about five seconds after landing
- [x] Intermission counts down; the round starts; everyone teleports to separated spawns
- [x] Role card shows for 4s, movement locked during it
- [ ] A player on their first round is never murderer or sheriff (when veterans are present)
- [ ] Ghost hints appear once each: move, coins, examine — and not again after a rejoin
- [ ] Nobody can be killed in the first 4 seconds
- [ ] Murderer's E kills at close range, not at distance; Q throws with an 8s cooldown
- [ ] Sheriff click fires; hitting an innocent kills the sheriff too
- [ ] Sheriff death drops a pistol; an innocent can take it and becomes Hero
- [x] Body appears; E within 14 studs, after a 1.5s channel, returns three or four clue lines
- [x] Examining after 20s, or during Lights Out, returns "The trail has gone cold."
- [x] Walking over a coin collects it once; coins land on the HUD
- [x] Event fires at the 45% mark, once, banner fades in and out, lighting restores after
- [x] Round ends on murderer death, wipe, or timeout; results card names the murderer
- [x] When a murderer killed, the round ends on a 2.5s kill-cam circling the last kill, then results
- [ ] Results show "You were N coins short." when the balance is under 250
- [ ] Locker shows `coins / 250` and reads NEED N MORE until affordable
- [ ] Everyone returns to the lobby; coins and XP survive a rejoin (with API access on)
- [x] Results screen names the murderer, lists the roster with the dead struck through, shows the
      kill timeline and the payout
- [x] Crate reel spins and lands on the item the server actually granted; the free first crate
      opens the crate screen by itself
- [x] Published odds are visible on the crate screen, for the Locker and the seasonal crate
- [x] Direct-buy shelf charges 1.6× item value; effect re-roll always lands on a new effect
- [ ] Inventory lists starters and owned items; Equip persists across a rejoin
- [ ] Crafting five duplicates yields one item of the next tier
- [ ] Medic R revives an unexamined body once per round; moving during the 3s breaks it
- [ ] Holding F for 2s drags a body at reduced walk speed; releasing drops it
- [x] Last Call fires at 30s: banner, coins double, murderer outlined through walls
- [x] Lights Out shrinks the vision radius (fog at 88 studs), not just brightness
- [x] Fog Bank hides name tags past 40 studs
- [ ] With `LiveOpsDay = 28`, TRADE opens a table between two players who both ask
- [x] Dying puts the camera on a living player; ‹ › (or ← →) switches; respawning in the lobby keeps
      spectating; a revive or the end of the round hands the camera back
- [ ] The murderer's knife and the sheriff's pistol stay hidden while walking about and appear in hand
      only on a stab, throw or shot
- [ ] With the Radio pass a message reaches everyone; the dead cannot send one mid-round
- [x] With the Emote pass the five emotes show over the player's head within 40 studs
- [ ] REPORT on a lobby row asks to confirm; reporting the same player twice is refused

## Mobile pass — test on a phone, not the emulator

- [ ] FIRE / THROW / REVIVE appear only for the roles that can use them
- [ ] USE relabels to STAB / EXAMINE / TAKE as the context changes
- [x] Every button is comfortably thumb-sized, and the radio and emote dock covers none of them

## Exploit sweep — before any public test

Run from a LocalScript or the client command bar.

- [ ] Print every value the client holds. **No other player's role appears.**
- [ ] Fire `RequestStab` at a distant player — nothing happens
- [ ] Fire `RequestShoot` 50× in a second — at most one shot lands; sustained spam disconnects
- [x] Fire `RequestExamine` on a body across the map — nothing returns, not even "cold"
- [x] Fire `RequestCoin` for every node id from one spot — only nodes within range pay
- [x] Fire `RequestCrate` with 0 coins, and with `"seasonal"` outside the season — nothing granted
- [x] Fire `RequestShoot` with a NaN vector — ignored, no server error
- [x] Offer a uid you do not own, or the same uid twice, in a trade — rejected
- [x] Change an offer after both locked — both locks and confirms reset
- [x] Fire `RequestRevive` as a non-medic, or on an examined body — nothing happens
- [ ] Fire `RequestDrag` on a body across the map — nothing happens
- [x] Fire `RequestEquip` with a uid you do not own — nothing changes
- [x] Fire `RequestBuy` for an item not on the shelf, or without the coins — nothing granted
- [x] Deliver the same developer-product receipt twice — coins granted once
- [x] Fire `RequestStab` 10× in a second — at most 4 reach the handler (`Config.REMOTE_LIMITS`)
- [x] Fire `RequestRadio` without the pass, or while dead mid-round — nothing is broadcast
- [x] Fire `RequestReport` at the same player repeatedly — one report counted
- [ ] Regional policy: until `PlayerPolicy` resolves (and wherever PolicyService restricts), crates,
      seasonal keys, crafting and re-rolls are refused with a message, and TRADE shows N/A. Test a
      restricted player with a VPN or an account in a restricted region; attributes set by hand only
      change the UI, the server keeps its own cache

> **Testing coins is trickier than it looks.** `CoinService:Arm` only creates nodes during `ACTIVE`
> and `Disarm` destroys them all at the end of the round, so a probe that stages on the server and
> fires from the client goes vacuous whenever the round rolls over in between — it then proves only
> that `armed = false` rejects the call. `CoinController` also collects any node within range by
> itself every 0.15s, so standing on one to "test the exploit" just takes it legitimately first. Do
> the whole thing in one client call: wait for `ACTIVE`, confirm nodes exist, move well out of
> range, re-check the round still holds, *then* fire every id.

## Only after all of the above passes

- [x] Walk each map floor by floor: every staircase climbs smoothly with no lip at the top, railings stop a stumble into a stairwell, doorways fit a running player
- [x] Lockdown shuts some room doors but every room still has a way out
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

## What a Studio session can and cannot settle

Counting ticks is misleading on its own, so here is the split. 36 ticked, 43 not, as of the automated passes.

| Bucket | Count | Meaning |
| --- | --- | --- |
| Testable in Studio, not yet done | 23 | A solo session with NPCs can settle these. Several are already verified by reading the code but deliberately left unticked, because reading is not observing. |
| Needs two or more real players | 8 | Trading, vote tallies across clients, the results roster, the radio line, the closed test. A second client is the only way. Note the radio is one line with two halves, and both halves land in this bucket: "reaches everyone" obviously does, and so does "the dead cannot send one mid-round", because health is server-authoritative for a kill that counts, and a client writing Health = 0 respawns through watchDeath before the send can be judged. Three attempts at it from one client, all inconclusive. |
| Needs a purchased pass | 0 | Emotes. I filed this as impossible and it is not: this Studio session runs as the game owner, and the lobby shows VIP, RADIO and EMOTE BUNDLE all OWNED, so the pass-gated paths are exercisable solo. Only "reaches everyone" still needs a second client. |
| Needs a phone | 2 | Which action buttons appear per role, and USE relabelling. The emulator is not the test the line asks for. |
| Needs human eyes or ears | 7 | Whether the cues match the brief, whether a weapon sits right in the hand, whether the art reads. No probe settles taste. The ghost hints join this bucket: they need an account that has not seen them, and this Studio session is permanently the owner's. |
| Setup step, not a claim | 3 | `rokit install`, API access, `[ColdCase] server up`. |


> **The lobby menus have a twenty-second window.** The collection, crate and trade screens only exist during INTERMISSION - `onState` shows the lobby there, `LOADING` and `REVEAL` call `show(nil)`, and `RESOLUTION` belongs to the results card. Anything that needs to click a menu button and then read what rendered has to do both inside that window. Driving it from two separate tool calls does not fit: a click and a read took about twenty-eight seconds of round trips against a twenty-second window, three times running. A human at the keyboard settles these in seconds, so they are grouped here rather than left looking untested.

> **The ghost hints need an account that has not seen them.** Whether the three prompts appear once each is held in two places a probe cannot read: `shown`, a local table inside NoticeController, and `hintsSeen` on the profile. Requiring either module from a command context returns a fresh copy that looks alive - it connects the same remotes, so live values keep arriving - while every field filled before the probe attached sits at its default. A copied `ClientState` read `loaded=true` with correct coins and role, and an empty inventory against a HUD showing 27 owned. The only trustworthy evidence is `NoticeHud.Hint.Text` and its transparency, and watching those across a full ACTIVE → RESOLUTION → INTERMISSION → LOADING → REVEAL → ACTIVE cycle gave zero appearances. That is what an account which has already seen all three looks like - the label still holds "Tap USE to examine a body" from an earlier session - so it settles nothing either way. A fresh account is the test.

> **Reading NPC movement needs the walk speed column.** Two passes over the bots looked like faults and were not. NPCs that travel far less than their neighbours are not failing to path: `steer` sets speed by role, so the murderer runs at 16 and everyone else at 11, and distance tracks that almost exactly - 438 studs against 233 over comparable samples. And NPCs that appear to move after the round ends are carrying out a `MoveTo` issued just before the state flipped. Timestamping the samples against the state change settled it: every post-round event belonged to one bot within the first 3.2 seconds of RESOLUTION, in steps of about two studs, against a six second RESOLUTION and a `BotService:Clear()` that follows. Without the timestamps the same data reads as three bots still walking.

> **A round payout is never just the base numbers.** Checking that rewards are paid in full means reconciling the whole multiplier, and the pieces are spread across three files. `Grant` applies one combined factor with `math.floor(coins * mult + 0.5)`, not a chain of separate roundings, and `CoinMultiplier` builds it from the live-ops boost, the friend bonus, VIP, and Last Call. Two observed payouts: a win with survival, `COINS_WIN 90 + COINS_SURVIVE 40 = 130`, paid 325; a loss, `COINS_LOSS 30`, paid 75. Both are exactly 2.5x, which is VIP's 1.25 times Last Call's 2 - the double-coin weekend is days 60-62 and the server is on day 3, so it contributes nothing. An unexplained payout is worth chasing to an exact figure before ticking anything: the first guess here was the coin boost, and it was wrong.
>
> **The settlement payout inherits Last Call's doubling.** `PayOut` is called at `RoundService:541`, one line before `SetLastCall(false)` at 542, so the end-of-round win/loss/survive coins are granted while `lastCall` is still set - and `round` is listed in `LAST_CALL_SOURCES` alongside pickup, examine and revive. It is deliberate by the letter of the code, but it has a consequence worth a design decision: `lastCallFired` resets every round, so a round that ends before the thirty-second mark settles at 1.25x while the same win in a longer round settles at 2.5x. Identical outcomes pay double based only on how long the round ran. Not changed - which way that should go is a call about the economy, not a bug to fix.

> **The spawn separation was measured at six, and six is the only headcount reachable alone.** At REVEAL - the first moment everyone is placed, and before anyone has walked, since movement is locked - all fifteen pairs cleared the sixty stud minimum, closest 63.2. The placements also spanned three Y bands, 3.0, 19.2 and 35.2, so participants start on different floors rather than in one cluster. That is the good case and it is the only one a solo session produces: `Lobby.Plan` fills to `BOT_FILL_TO`, so an NPC round is six. The separation is known to fail at twelve, where the pads cannot deliver it at all - measured exactly in the spawn commits - and that headcount needs twelve humans, so it is not reachable here.

> **Timing a state window needs the `RoundEnds` anchor, not a poll.** The role card took three passes, and all three failures were the probe's, not the game's - each one looked like a defect first. Polling for the `LOADING -> REVEAL` edge put `t=0` about 1.3 seconds late, which made a correct 4.0s movement lock read as an early release at 2.69s. `RoundEnds` is set to `GetServerTimeNow() + duration` as the state begins, so `RoundEnds - REVEAL_TIME` recovers the true start however late the probe notices, and the observer's latency cancels out. Then visibility: `roleCard.Visible = false` hides the parent frame and leaves the child label's own `Visible` and transparency untouched, so a check on the label alone reports a card that never goes away. Walk the ancestors. And finally the names - `BuildHud` creates a `RoleName` inside `RoleTag`, the small persistent top-right tag, and a second `RoleName` inside `RoleCard`, the full-screen reveal. A search by name finds the tag, which stays up all round by design, and reports the card as stuck. Measured properly: card up through 4.09s, lock released at 4.09s, both against a `REVEAL_TIME` of 4.

> **The lobby countdown and the server can disagree in Studio only.** `MenuController` says it "mirrors RoundService, which decides with the same `Lobby.Plan`", and it does call the same function - but not with the same arguments. The server passes `minPlayers()`, which returns `ServerStorage.MinPlayers` when that attribute is set and `RunService:IsStudio()`, falling back to `Config.MIN_PLAYERS`; the client always passes the constant. Outside Studio the override cannot exist and the two agree exactly, which is why this is a note and not a fix. Inside Studio with `MinPlayers` set, the countdown can advertise a plan the server will not act on - worth knowing before treating a lobby that says one thing and does another as a bug. Observed with no override: the label read "STARTS IN 20s · 5 NPCS JOIN" and exactly five NPCs were placed.
>
> The headcount argument differs too, and that one is not Studio-only. The client counts `Players:GetPlayers()`; the server counts `GetEligible()`, which keeps only players who have a Character *and* loaded data. So someone still spawning or still waiting on their profile is in the client's count and out of the server's. With one player it cannot show. On a filling server it can: the countdown quotes a headcount, and an NPC count derived from it, that the server will not honour until those players finish loading. It resolves itself within a second or two of them landing, so it is a transient cosmetic mismatch rather than a broken round - but it is the client's label that is wrong in that window, not the server's decision.

> **Line 21's "at least 12s" is not what the code says.** The NPC murderer's opening wait is `BOT_FIRST_HUNT`, a range of `{9, 16}` seconds, so the floor is nine. The 12 in Config is `BOT_CHASE_GIVE_UP` - how long a murderer chases one target before giving up - which is a different thing entirely. The wait is also applied lazily: `brain.nextHunt = brain.nextHunt or now + between(Config.BOT_FIRST_HUNT)` starts counting on the first `hunt()` tick, and once it elapses the bot still has to reach someone, so observed first kills sit well above the floor. One was measured at 31.8s from the start of ACTIVE, which clears nine and twelve alike - and that is the trouble with checking a floor by observation. A sample far above it refutes nothing and confirms nothing; only a kill *under* nine seconds would be evidence, and the wait is randomised so that would take many rounds to catch. Neither number is pinned by a test.

> **The NPC murderer hunts the nearest, not the loneliest.** Line 21 says it "picks off whoever is alone", and `BotService`'s own comment says it "stalks whoever is most alone". The implementation scores every candidate as `(pos - root.Position).Magnitude + crowd * 60 + math.random() * 30` and takes the lowest, where `crowd` counts living participants within 25 studs of that candidate. So isolation is a threshold worth sixty studs a head, not a ranking, and raw distance from the murderer dominates whenever the crowding ties. A player alone a hundred studs away scores about 100; a pair thirty studs away scores about 90, and the pair gets hunted first. The jitter adds up to thirty studs on top, and a target the murderer just gave up on carries +80 so it does not immediately re-lock. Murderers never target each other. None of this is pinned by a test. It is defensible behaviour - a killer that ignores someone standing next to it to cross the map would read as stupid - but it is not what the line or the comment describe, and "whoever is alone" sets an expectation the code does not meet.
>
> One kill was measured against it, with isolation read from six seconds before the death rather than from the moment of it - at the instant of a kill the victim is standing next to the murderer, so measuring then would rank every victim as the least isolated person on the map. The victim's nearest neighbour was 56 studs away, so `crowd` was 0 and they were alone in the only sense the code uses. Four of the six participants were alone by that measure (gaps of 91, 56, 56 and 49); the remaining two stood 2 studs apart and each carried the +60 penalty, and neither was chosen. Consistent with the rule, but it confirms only the crowding term: the murderer's own position was not recorded, so the distance term that actually decides between equally-alone candidates is untested, and this is one kill. Ranked by continuous isolation the victim came third of six, which under a naive "the victim should be the most isolated" reading looks like a failure and is not one.

A tick here means observed, not inferred.

A tick here means observed, not inferred. Where something is verified by reading the code but never
seen to happen, the box stays empty and the commit says so - the role card timing and the hidden
weapon are both in that state.

