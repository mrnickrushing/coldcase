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
- [x] WAIT FOR PLAYERS highlights, the countdown switches to "WAITING FOR PLAYERS · 1/4", no round starts, and the choice is still set after a rejoin
- [x] PLAY NOW · NPCS switches back and the next intermission starts an NPC round
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
- [x] Nobody can be killed in the first 4 seconds
- [x] Murderer's E kills at close range, not at distance; Q throws with an 8s cooldown
- [ ] Sheriff click fires; hitting an innocent kills the sheriff too
- [x] Sheriff death drops a pistol; an innocent can take it and becomes Hero
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
- [x] Holding F for 2s drags a body at reduced walk speed; releasing drops it
- [x] Last Call fires at 30s: banner, coins double, murderer outlined through walls
- [x] Lights Out shrinks the vision radius (fog at 88 studs), not just brightness
- [x] Fog Bank hides name tags past 40 studs
- [ ] With `LiveOpsDay = 28`, TRADE opens a table between two players who both ask
- [x] Dying puts the camera on a living player; ‹ › (or ← →) switches; respawning in the lobby keeps
      spectating; a revive or the end of the round hands the camera back
- [x] The murderer's knife and the sheriff's pistol stay hidden while walking about and appear in hand
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
- [x] Fire `RequestDrag` on a body across the map — nothing happens
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

Counting ticks is misleading on its own, so here is the split. 44 ticked, 35 not, as of the automated passes.

| Bucket | Count | Meaning |
| --- | --- | --- |
| Testable in Studio, not yet done | 13 | A solo session with NPCs can settle these. Several are already verified by reading the code but deliberately left unticked, because reading is not observing. |
| Needs two or more real players | 10 | Trading, vote tallies across clients, the results roster, the radio line, the closed test. A second client is the only way. Note the radio is one line with two halves, and both halves land in this bucket: "reaches everyone" obviously does, and so does "the dead cannot send one mid-round", because health is server-authoritative for a kill that counts, and a client writing Health = 0 respawns through watchDeath before the send can be judged. Three attempts at it from one client, all inconclusive. |
| Needs a purchased pass | 0 | Emotes. I filed this as impossible and it is not: this Studio session runs as the game owner, and the lobby shows VIP, RADIO and EMOTE BUNDLE all OWNED, so the pass-gated paths are exercisable solo. Only "reaches everyone" still needs a second client. |
| Needs a phone | 2 | Which action buttons appear per role, and USE relabelling. The emulator is not the test the line asks for. |
| Needs human eyes or ears | 7 | Whether the cues match the brief, whether a weapon sits right in the hand, whether the art reads. No probe settles taste. The ghost hints join this bucket: they need an account that has not seen them, and this Studio session is permanently the owner's. |
| Setup step, not a claim | 3 | `rokit install`, API access, `[ColdCase] server up`. |


> **The lobby menus have a twenty-second window.** The collection, crate and trade screens only exist during INTERMISSION - `onState` shows the lobby there, `LOADING` and `REVEAL` call `show(nil)`, and `RESOLUTION` belongs to the results card. Anything that needs to click a menu button and then read what rendered has to do both inside that window. Driving it from two separate tool calls does not fit: a click and a read took about twenty-eight seconds of round trips against a twenty-second window, three times running. A human at the keyboard settles these in seconds, so they are grouped here rather than left looking untested.
>
> **That applies to clicking, not to reading, and I had it too broad.** Every one of these screens keeps its content while `Enabled = false`: CrateGui holds the Locker and Seasonal tabs and its reel cards, ResultsGui a full roster with roles, TradeGui both offer tables, SpectatorGui its target bar. So anything that only needs to *read* what a menu contains can be done at any time, from one call, with no click and no window to race. Only interactions - pressing a button and seeing what changes - are constrained by the twenty seconds. Several lines were shelved here on the broader reading and should be revisited.
>
> Two cautions when reading a disabled screen. The content is from whenever it was last drawn, so figures go stale - the inventory summary read a balance about 6k behind the live one. And ResultsGui legitimately lists every participant's role, so reading it mid-round shows a roster that looks like a role leak and is not: it is the previous round's card, still holding its last render. The role-leak audit covers the live path and is unaffected.

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

> **The vote panel is open on arrival, and the tally renders - only "for everyone" is left.** At +0.00s into INTERMISSION, the instant the lobby opened, all three maps were on screen with their vote buttons and counts: Blackwood Manor, Rusted Pier and City Archive, each showing VOTE and 0. Visibility was checked by walking ancestors, not by trusting a label's own `Visible`. Casting one real vote moved Rusted Pier from 0 to 1 in 0.12s, so the update path renders locally. The remaining claim is that other clients see it, and `RoundService:82` sends the tally with `VoteTally:FireAllClients`, not `FireClient` - there is no per-voter path, so the obvious way for this to fail cannot happen. That is still not an observation of a second client drawing it, so the line stays unticked.
>
> It also stays in the multiplayer bucket, where it already was - "vote tallies across clients" is listed there. Worth stating plainly: the triage guard test only checks that the buckets *sum* to the unticked count, and moving a line between buckets leaves the sum unchanged. A wrong reclassification is invisible to it, so that has to be reasoned about each time. This table drifted once already for exactly that kind of reason.

> **The lobby mode toggle, with one clause read rather than seen.** Three of line 16's four claims were observed. The highlight is a full swap, not one button lighting up: `renderMode` paints the selected button `Theme.AMBER` on background, text and stroke and the other `RAISED`/`SOFT`/`QUIET_STROKE`, and both were measured changing places and changing back - amber `(0.949, 0.651, 0.231)` moving from PLAY NOW to WAIT and returning. The countdown read exactly "WAITING FOR PLAYERS · 1/4". And no round started across 30 seconds, which is the part that needed patience rather than cleverness: "no round starts" is an absence, so it only means something watched past a full 20 second INTERMISSION.
>
> The fourth clause - that the choice survives a rejoin - was **not** observed; it needs a Play restart. It is guaranteed by construction instead: `SetWaitForPlayers` writes `data.settings.waitForPlayers` on the persisted profile, and `DataService:80` re-applies `plr:SetAttribute("WaitForPlayers", data.settings.waitForPlayers)` on load. Cited rather than seen, and the tick should be read with that attached.
>
> One thing worth knowing for any later probe: `renderMode` is driven by `GetAttributeChangedSignal("WaitForPlayers")`, not by the click. Firing the remote directly still repaints the buttons, because the UI follows the server's attribute rather than the local press. That is the right direction of authority, and it is why this was testable without clicking anything.

> **Count the NPCs at REVEAL, not at the state change.** Line 17 was measured starting from "wait" so the switch back was a real transition rather than incidental cleanup: the attribute went false and the countdown changed from "WAITING FOR PLAYERS · 1/4" to "STARTS IN 18s · 5 NPCS JOIN", and the very next intermission ran through to a round with five NPCs. But the count at the INTERMISSION → LOADING flip was **zero**, and only reached five by REVEAL, because `PlaceParticipants` runs inside the LOADING branch. A probe that samples on the state change sees no NPCs and can report that none joined. Same shape as the role card and the post-round movement: the number is right, the moment is wrong.

> **Nothing has ever persisted in these sessions, and the API toggle is not why.** Line 46's first half is observed: a round ended at RESOLUTION and by INTERMISSION seven seconds later `LobbyGui.Enabled` was true, the NPC count was zero, the `Round` model was destroyed, and the player had moved from the map at (50, 35, -10) to the lobby at (-2, 4, -897). Everyone does return to the lobby.
>
> The second half cannot be tested here at all. A DataStore read fails with "You must publish this place to the web to access DataStore", and `game.PlaceId` and `game.GameId` are both **0** - this Studio session is the Rojo-built local `.rbxlx` opened as a file, never associated with the cloud place. So DataStore is unavailable because there is no place id, not because of Studio API access. Enabling line 9's setting would change nothing, and "API access is off" would have been a confident wrong answer: the error text is a different message from the API-access one, which is the only reason I did not record it that way.
>
> Two things follow. Testing persistence needs Studio to open the published place (131836757915254) rather than the local build - a different setup, not a different setting. And every coin and XP figure in these notes lived in ProfileStore's in-memory fallback and vanished with each Play session. That does not affect the payout arithmetic, which is in-memory maths and reconciled exactly, but it means persistence itself has never once been observed here.

> **A closed menu can still be read, and that is the safest way to read one.** Line 53's first half is confirmed without opening anything: `InventoryGui` is fully populated behind `Enabled = false`, with "YOUR COLLECTION", a summary line, both starters - `ash` as "STARTER · KNIFE" and `ledger` as "STARTER · PISTOL", each marked EQUIPPED - and the owned items keyed by uid with rarity and effect rows. Starters and owned items are both listed, and starters are labelled as such rather than folded in. No click and no module require, so no dead copy could mislead it. My first attempt did try to click, with `Activated:Fire()`; `RBXScriptSignal` has no `Fire`, that is a `BindableEvent` method, and the probe aborted having read nothing.
>
> Two traps in that screen. `Root.Items.ItemTemplate` is a hidden template carrying the placeholder text "ITEM" and "EQUIP", so anything counting cards by label overcounts by one. And the summary read "27 owned · 46462 coins" while the live balance was about 52k, because `renderInventory` last ran when the screen was last opened - a closed menu holds the numbers from whenever it was last drawn, which is stale rather than wrong.
>
> The line stays unticked because "Equip persists across a rejoin" is blocked, not untested: this place has `PlaceId` 0, so nothing saves at all.

> **The murderer role is reachable opportunistically, not never.** Several lines - the four second grace, the murderer's E and Q, the sheriff's pistol drop, the hidden weapon, and firing `RequestStab` at a distant player - have been left aside on the grounds that a solo session cannot be the murderer on demand. That is true, but the results card showed "UNCLENICKRUSH was the murderer · 0 eliminated", so it does happen across enough rounds. A probe that waits for `RoleAssigned` to come back "murderer" and only then runs its measurement would settle them without forcing anything. It costs rounds rather than cleverness, and it is the honest route to the combat lines.

> **A probe that reports only at the end loses everything when it times out.** Waiting for a particular role means waiting through rounds, and a pass budgeted at 500 seconds died on "Request timeout" having taken several samples and reported none of them. Probes that ran 105 to 170 seconds have all completed, so the practical ceiling is well under what I assumed. Bound a waiting probe to roughly one round and let it report whatever it drew, rerunning to sample again: a timeout then costs one sample instead of the whole pass.
>
> **Which exploit lines are second-client work, and why.** Four sit unticked for different reasons and only one of them is risky. Line 79 needs another player's role to exist before "no other player's role appears" can mean anything. Line 80 says a distant *player*, so aiming at an NPC does not settle it - an NPC reaches `CombatService` through `BotFromCharacter` as a bot table, which is a different argument shape from a `Player`, and a solo server has nobody else to aim at. Line 89 needs a body, so somebody has to have died with a drag target left behind. Only line 81's "sustained spam disconnects" clause is genuinely unsafe to run here, because being kicked ends the Play session and every probe with it. The rate limits make the shape of that clear anyway: `RequestStab` and `RequestShoot` allow 4 a second, a strike is recorded only for exceeding the limit and at most once per second, and five strikes inside ten seconds kick.
>
> **The two range rules are deliberate and have not drifted.** `Reach.Within` is used only by `EvidenceService` and `AbilityService`, both with `EXAMINE_RANGE` and neither with `PING_ALLOWANCE`, because examining and reviving are done standing still. The moving-player paths add the slack inline instead - the knife at `CombatService:100`, the gun pickup at `:187`, coins at `CoinService:49`. `BotService:574` gives NPCs `KNIFE_RANGE - 2`, tighter than a human needs, which is intentional rather than a mismatch.

> **The grace window, tested properly at last.** An earlier pass watched the first ten seconds of a round, saw six humanoids at full health, and proved nothing: the NPC murderer waits at least nine seconds before striking, so no kill was ever attempted inside the window. A quiet window is not evidence of a guard.
>
> The working version waits for `RoleAssigned` to come back "murderer" and only then measures, because as anyone else `RequestStab` returns on the role check at `CombatService:84` before `inGrace()` is ever reached - a null result would prove the role guard and nothing else. Reaching a victim inside four seconds is impossible anyway: spawns are sixty-plus studs apart and movement unlocks exactly at ACTIVE, so no in-range attempt exists. The way through is the guard order - role and grace, then `liveCharacter`, then `ready()`, then `DrawWeapon`, then range, then the kill. `DrawWeapon` calls `hum:EquipTool`, which parents a Tool into the character, so a stab at a *distant* NPC equips nothing while the grace holds and equips the knife once it lifts, dying harmlessly on the range check either way.
>
> Measured as the murderer, anchored to `RoundEnds`, against Ada at 189 studs with a knife that reaches 14:
>
> ```
>   INSIDE grace  at 1.91s -> knife drawn: false
>   INSIDE grace  at 3.53s -> knife drawn: false
>   AFTER  grace  at 5.60s -> knife drawn: true  Ash
>   AFTER  grace  at 7.10s -> knife drawn: true  Ash
> ```
>
> Target health 100 throughout, so nothing died to establish this. Four passes were needed to draw the role - snitch, snitch, innocent, murderer - each costing one round rather than the whole sampling run.
>
> What this shows is that the gate is real and that it is the *grace* doing the blocking, not some other guard. It does not pin the boundary at exactly 4.0 seconds: the samples bracket it at 3.53 and 5.60, so the gate is closed before ~3.5s and open after ~5.6s. Tightening that would mean sampling either side of 4.0 on a later murderer draw.

> **A solo tester draws snitch far more often than one in six, by design.** Waiting for a particular role means counting draws, and the first seven came out snitch, snitch, innocent, murderer, innocent, snitch, innocent - three snitches in seven, which looks like a biased shuffle. It is not. `drawPreferHuman` in `RoleService:Assign` takes a human from the pool half the time, because an NPC snitch's reveal reaches no screen. The medic uses the same draw but is gated on `humans >= 2`, so it never fires in a solo round; the snitch is deliberately ungated, and the comment there says why. With one human among six participants that hands the snitch to the only real player about half the time it is drawn at all.
>
> Two things follow. The tally is documented behaviour rather than something to investigate - worth knowing before someone spends a session on it. And any line needing a *specific* role in a solo session costs more rounds than the headcount suggests, because the snitch lean keeps consuming the one human slot. Murderer draws in particular are rarer than one in six here, which is the real cost of the wait-for-role approach to the combat lines.

> **Two lines move out of the Studio bucket, because a solo session cannot reach them at all.**
>
> The medic (line 55) is impossible here for two independent reasons. `RoleService:94` gates it on `count >= MEDIC_AT and #pool > 2 and humans >= 2`, so a one-human round never assigns a medic; and `AbilityService:54` refuses an NPC victim outright, because an NPC has no player to bring back. So even if a medic were somehow assigned there would be nobody it could revive. This was sitting in the Studio backlog as though more rounds would eventually produce it. They will not.
>
> Regional policy (line 96) resolved to the permissive branch on this account - `PaidRandomItemsRestricted = false`, `PaidItemTradingAllowed = true` - so what I observed is the unrestricted case. The line asks about the *restricted* branch and about the window before `PlayerPolicy` resolves, when both attributes are still nil and `MenuController` falls back on `~= false`. The line's own text rules out the shortcut: "attributes set by hand only" is not evidence. It needs a VPN or an account in a restricted region.
>
> Moving two lines between buckets leaves the sum unchanged, so the guard test cannot check this. Reasoned rather than tested: 20 → 18 in Studio, 8 → 10 in the second-client bucket, both still unticked, total still 40.

> **The murderer's knife, all three claims from one round.** Murderer draws are expensive here - eleven draws for two, thanks to the snitch lean - so the probe was written to harvest the whole line at once rather than one clause per round.
>
> The Q cooldown uses the same trick as the grace window. On the throw path `ready(plr, "throw", THROW_COOLDOWN)` sits *before* `DrawWeapon`, so a refused throw equips no knife and an allowed one does, and the cooldown is readable without anything being hit. Throws were aimed straight down: a legal throw, but the ray meets the floor on its first step and `playerFromPart` finds nobody, so no stray knife could kill.
>
> ```
>   throw 1  at  6.07s -> drawn: true
>   throw 2  at  9.74s -> drawn: false    (+3.67s)
>   throw 3  at 13.15s -> drawn: false    (+7.08s)
>   throw 4  at 17.90s -> drawn: true     (+11.83s)
> ```
>
> Refused at +7.08 and allowed at +11.83, which brackets the cooldown rather than pinning it - consistent with 8, and the lower bound is within a second of it. Same caveat as the grace window, and for the same reason.
>
> Then E: walked to an NPC and stabbed at 2 studs, health 100 → 0. The other half of that clause was already evidenced by the grace probe, where four stabs at 189 studs left the target at 100 throughout. Close kills, distant ones do not.
>
> Two other lines gained evidence here without becoming tickable. Line 63's murderer half held - the knife was absent from the character except during the 1.2s draw, so it is carried hidden and appears on use - but the sheriff's pistol is still unseen. And line 23's "stabbing works on NPCs" is now observed, though shooting, spectating and examining are not.

> **The fibre clue is real, and the witness clue gives the killer away.** Line 23 has five clauses and two more are now observed - examining works on NPCs, and the fibre matches. Shooting and spectating do not, so the line stays unticked.
>
> It took four attempts and the first three failed on walking rather than on anything about examining, which is why each said so instead of reporting a null result. Raw `Humanoid:MoveTo` walks a straight line and stalls on geometry; the NPCs get around because `BotService` paths with `ComputeAsync` and recomputes every 2.5 seconds. Copying that closed 187 studs in 14 seconds. But the real error was strategic: a body 187 studs away costs ~16s of travel against a 20 second `BODY_CLUE_WINDOW`, so chasing distant bodies can only ever return "cold". The fix was to shadow the NPC pack and be near a kill when it happens, which is what a player does anyway.
>
> That produced a warm examine at 17s into the window:
>
> ```
>   direction  June (NPC) was struck from the north.
>   fibre      Fibre trace: olive fabric.
>   time       Time of death: 17s ago.
>   witness    Partial name on the lips: Ir…
> ```
>
> The fibre names the *killer's* torso colour, not the victim's - `EvidenceService:133` records `ColourBandOf(killer)` at death, and `:38` reads the torso part colour because shirt textures are not readable. The body itself does not record who killed it, so I expected only to show the band was plausible. Two independent clues settled it instead. Banding every living NPC's torso locally with the same rule put exactly one in olive: Iris. The witness clue independently gives "Ir…". Two separate server-derived facts agree on the same NPC, so the fibre does name the killer's real colour.
>
> **Which is also the problem.** The witness clue prints `killer:sub(1, 2)`, and all twelve NPC names have distinct two-character prefixes, so those two characters identify one NPC outright. That has been noted before from reading the code; this is the first time it has been watched happening. A witness clue that names the murderer removes the deduction it exists to support. Not changed - how much a body should give away is a design call - but it is worth deciding deliberately rather than by `sub(1, 2)`.
>
> One sanity check worth keeping: the server said "17s ago" where my own first sight of the tag was ~15s earlier, a ~2s lag between the kill and the tag reaching me. Consistent, and a reminder that client-side body age runs slightly behind the server's.

> **The sheriff's pistol does drop, and only a plain innocent can pick it up.** Line 37's first half is observed: a Part named `DroppedPistol` appeared in `workspace.Round` after the NPC sheriff died, 37 studs away, seen directly rather than inferred. `Eliminate` spawns it for a dying sheriff or hero, so it needs no particular role of mine to witness - only that the NPC sheriff dies, which the NPC murderer sees to on its own schedule.
>
> The second half is narrower than it reads. `RoleService:MakeHero` opens with `if roles[plr] ~= "innocent" then return false end`, so the promotion is refused for the snitch, the medic, the murderer and the sheriff alike - not just for the sheriff. Walking to the pistol as the snitch and firing `RequestPickup` did exactly nothing, correctly: the part stayed on the floor and no `RoleAssigned` arrived. So "an innocent can take it" means *innocent*, and testing it needs that draw specifically, in a round where the sheriff also dies. Two opportunistic conditions at once, which is why the line is still open.
>
> Worth keeping for the next probe: the inventory's `Equip` element is a **TextButton**, not a TextLabel - `MenuController:806` connects `card.Equip.Activated`, which is a button event. Two passes read the equipped pistol's name as nil purely because an `IsA("TextLabel")` filter excluded it.

> **One round carried the whole hero chain.** Drew innocent; the NPC sheriff died at t=26s leaving a `DroppedPistol` 144 studs off; pathed to 8.1 studs; `RequestPickup` promoted me and the part left the floor; then a shot at Cyril from 39 studs put the pistol "Ledger" in hand and took him from 100 to 0 while I stayed at 100. Line 37 is ticked on both halves.
>
> The reason it worked is that the probe branched on whatever role it drew rather than asking for one. Sheriff and murderer are both scarce under the snitch lean, and every role-specific probe before this discarded the draw it got. This one had a path for innocent, for sheriff, and for everything else, so the round paid out instead of being spent.
>
> What it did *not* settle, kept separate on purpose:
>
> - **Line 36** is still open. I hit Cyril and lived, which means Cyril was the murderer - a correct kill draws no misfire penalty. The line needs a shot that lands on an *innocent*, and with one murderer among five that is roughly four times in five next attempt.
> - **Line 23** is at four clauses of five: stabbing, shooting, examining and the fibre all observed. Spectating is not, because I survived.
> - **Line 63** is half observed and stays unticked. The pistol appeared in hand on use and the murderer's knife did the same earlier, but I only polled for a Tool *after* firing - the "stay hidden while walking about" half was never watched for the pistol. `Arm` puts it in the Backpack and `DrawWeapon` equips it for 1.2s, so the behaviour is near certain by construction. Near certain is not observed, and this file's rule is observed.

> **Three rounds lost to my own loop guards, not to the game.** Worth writing down together, because each looked like a result and none was.
>
> A watch loop conditioned on `state() == "ACTIVE"` was started while still in REVEAL. `RoleAssigned` fires during REVEAL, so the condition was already false and the loop exited after zero seconds reporting "no pistol". Every earlier probe waited for ACTIVE before measuring; the step was dropped while restructuring, and it cost a **sheriff** draw - one of the two scarce roles, and the one that unlocks three separate clauses.
>
> Then the opposite: nested budget guards. A probe starting mid-round spent its allowance waiting for RESOLUTION under one clause, then refused to keep waiting for the role under another, and exited during INTERMISSION - the moment *before* the assignment it wanted. A full cycle is ~110s of round plus intermission, loading and reveal, so any budget that assumes it can wait out a round and still have time is wrong more often than not. The fix was to delete a guard rather than enlarge one: listen for the next assignment with the whole budget.
>
> And a number that meant nothing. A pistol dropped at t=71s, the round ended before I reached it, and the probe printed "966 studs away" - it had measured after the lobby teleport, from `(-2, 4, -897)` to a part still sitting on the map. Distances are only meaningful while the round is still ACTIVE, and a `math.huge` that never got assigned prints as `inf` rather than announcing itself.
>
> The common thread with the earlier list - the ancestor-blind visibility check, the `IsA("TextLabel")` filter on a TextButton, the isolation metric that was not the code's rule - is that the probe was wrong in a way that produced a plausible reading rather than an error. A probe that cannot fail loudly should at least report *why* it stopped.

> **Both weapons are carried hidden and drawn on use.** Line 63 ticked. As sheriff, 54 samples taken while walking toward a target found **zero** tools in hand; firing put "Ledger" there; and one second after the 1.2s draw window it was `nil` again. The murderer's half came earlier from the grace probe - "Ash" appeared only on a stab that passed the gate, and nothing was in hand between attempts. So both weapons are hidden while walking, drawn on use, and put away again, which is the whole of the line.
>
> This is the clause I declined to tick two passes ago on the grounds that `Arm` puts the pistol in the Backpack and `DrawWeapon` equips it for 1.2s, so the behaviour was "near certain by construction". Near certain was right, and it still needed watching: the sampling cost one line of code in a probe that was already running.
>
> The shot missed, though, and the reason is worth recording because it blocks line 36. Fired at Wren from 35 studs and nothing died. `GUN_RANGE` is 300, so range was never the constraint - the ray met geometry. Stopping the approach at 40 studs is simply too far indoors. The next attempt closes to about 15 studs and raycasts for line of sight *before* firing, rather than firing hopefully and reporting a wall.

> **A drag request from across the map does nothing.** Line 89 ticked. Fired `RequestDrag` at a body 60 studs off, against a `near()` threshold of 14 - `Reach.Within` at `EXAMINE_RANGE`, with no ping allowance because dragging starts from standing still. WalkSpeed stayed at 16 and no `AbilityState` arrived across a 3 second wait, which is longer than the 2 second `DRAG_TIME`, so a late grab would have shown.
>
> The null result is worth something here only because the same remote plainly works up close in ordinary play, and because `AbilityState` is a real server message rather than something inferred - a silent refusal and a working drag look completely different on it. Firing an exploit remote and seeing nothing proves the guard only when the unguarded path is known to produce a visible effect.
>
> Line 56, the actual dragging, went untested that round: the NPC murderer killed me 56 studs from the body. Not a fault - but the probe exited on its "I died" branch without capturing the spectator state, and that is the very event line 23's spectating clause has been waiting several rounds for. Every other branch of this probe calls `captureSpectator`; the drag walk loop was the one place it was not wired in. An opportunity spent chasing something, missed by not handling the case where it arrives unannounced.

> **Dragging works, and the server's own messages agree with it.** Line 56 ticked. Reached Hugo's body at 8.8 studs; `WalkSpeed` went 16 to **8** after the two second hold, matching `DRAG_WALKSPEED`; the corpse moved **6.2 studs** while I walked; releasing put the speed back to 16.
>
> What makes this more than a single reading is that two independent channels agree. The speed and the corpse position are datamodel state, while `AbilityState` is a server message, and it arrived as `drag_start(2)` - carrying `DRAG_TIME` - then `dragging(0)`, then `drag_stop(0)`. Neither was derived from the other, so a coincidence would have to line up across both.
>
> Paired with line 89 from the same probe, that is the whole drag surface: refused from 60 studs against a `near()` of 14, working at 8.8. The exploit line and the feature line are the same code path tested from either side, which is worth more than testing either alone.

A tick here means observed, not inferred. Where something is verified by reading the code but never
seen to happen, the box stays empty and the commit says so - the role card timing and the hidden
weapon are both in that state.

