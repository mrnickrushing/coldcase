# Assets

What the game uses that is not code, where it came from, and where it lives.

## Sound

All 22 cues in `src/shared/SoundCues.luau`, from the Roblox Creator Store. Almost all come from the
two libraries Roblox licenses for every experience: **Pro Sound Effects** (`ProSoundEffects`) and
**APM Music** (`APMOfficial`). Uploads ripped from other games were passed over. Every id was
preloaded in Studio and loads.

| Cue | Asset id | Library | Clip |
| --- | --- | --- | --- |
| `round_reveal` | 9038130941 | APM Music | New West Low Piano and Bell Hit |
| `round_start` | 9043340902 | APM Music | Ambient Boom 04 |
| `timer_30` | 9120098166 | Pro Sound Effects | Toggle Switch, Metal Industrial Equipment 64 |
| `round_win` | 94590027038118 | APM Music | Victorious Journey Sting |
| `round_lose` | 1837830084 | APM Music | Sub Boom 05 |
| `knife_swing` | 9120972444 | Pro Sound Effects | Wood Whoosh, Slicing Air, Quick Swings 1 |
| `knife_hit` | 9113480915 | Pro Sound Effects | Body Fall Thud 2 |
| `knife_throw` | 9114156616 | Pro Sound Effects | Doppler Whooshes, Crackly Airy Bursts 1 |
| `gun_fire` | 17761500292 | DocInk (own upload) | Realistic Handgun Shot |
| `gun_pickup` | 9113104176 | Pro Sound Effects | Ammo Magazine 1 |
| `misfire_death` | 9125626779 | Pro Sound Effects | Light Cone Suck, Synth and Reverse Cymbal Build |
| `body_drop` | 9113480917 | Pro Sound Effects | Body Fall Thud 1 |
| `examine_start` | 9117233449 | Pro Sound Effects | Paper Tear, Heavy Paper Bag Rustle 4 |
| `clue_found` | 1841210107 | APM Music | Marimba Chimes |
| `trail_cold` | 9120887046 | Pro Sound Effects | Wood Hit, Piano Bench 7 |
| `body_drag` | 9125883698 | Pro Sound Effects | Rock Scrape on Concrete, Constant Dragging 3 |
| `lights_out` | 9113112330 | Pro Sound Effects | Amp Hum Buzz 1 |
| `power_surge` | 9114237487 | Pro Sound Effects | Electric Arcing 4 |
| `lockdown` | 9114143852 | Pro Sound Effects | Door Lock, Turn Deadbolt 3 |
| `crate_spin` | 9116784575 | Pro Sound Effects | Metal Ratchet, Small Ratchet Clicks 7 |
| `crate_godly` | 1841760054 | APM Music | Quid Sum Miser (sting b) |
| `trade_complete` | 9114144264 | Pro Sound Effects | Door Lock, Turn Deadbolt 10 |

Closest fits, not exact matches to the handbook brief: `timer_30` is a click rather than a clock,
`lights_out` is an amp cutting out, and `round_reveal` (12s) and `crate_godly` (8s) run long. Swap an id
in `SoundCues` when a better clip turns up; nothing else changes.

## Models (in the place file, not the repo)

Generated in Studio with Roblox's AI mesh generation, so they are original to this game. Rojo does
not sync them. They exist only in the published place, and a fresh `rojo build` runs without them:
props are skipped, and weapons fall back to rarity-tinted blockouts.

| Where | What | Used by |
| --- | --- | --- |
| `ServerStorage.Cosmetics.knife` | Steel kitchen knife | `CosmeticService`: every knife, rarity shown as an outline |
| `ServerStorage.Cosmetics.gun` | Six-shooter revolver | `CosmeticService`: every pistol |
| `ServerStorage.Props.Bookshelf` | Victorian bookshelf | Blackwood Manor, City Archive |
| `ServerStorage.Props.Armchair` | Red velvet armchair | Blackwood Manor |
| `ServerStorage.Props.GrandfatherClock` | Grandfather clock | Blackwood Manor |
| `ServerStorage.Props.CrateStack` | Shipping crates | Rusted Pier |
| `ServerStorage.Props.Barrel` | Oil drum | Rusted Pier |
| `ServerStorage.Props.FilingCabinet` | Filing cabinet | City Archive |
| `ServerStorage.Cosmetics.verdict`, `cinder`, `coldsnap`, `vigil` | Per-item knives | `CosmeticService`: those items instead of the generic knife |
| `ServerStorage.Cosmetics.nightjar`, `thealibi`, `hoarfrost` | Per-item pistols | `CosmeticService`: those items instead of the generic revolver |
| `ReplicatedStorage.PetModels.moth` | Pale moth | `PetController`: the Moth pet |
| `ReplicatedStorage.PetModels.widowspeak` | Cartoon spider | `PetController`: Widow's Peak |
| `ReplicatedStorage.PetModels.nightwatch` | Brass lantern with a candle light | `PetController`: Nightwatch, dims in Lights Out |

Pets live in ReplicatedStorage because every client draws them; a pet without a model is a small
rarity-coloured orb.

To add a per-item weapon, put a Tool named after the catalog id (e.g. `Cosmetics.coldsnap`) with a
`Handle`. To add furniture, put a Model in `ServerStorage.Props` (pivot at its bounding-box centre,
front facing −Z) and add its name to that map's `props` list in `BuildMaps`. Scripts inside either are
stripped when they are cloned.

## Images

| Asset id | What | Used by |
| --- | --- | --- |
| 129394148205070 | Blackwood Manor floor plan | Lobby vote card (`Config.MAP_IMAGES`) |
| 109064086969317 | Rusted Pier floor plan | Lobby vote card |
| 76726369092912 | City Archive floor plan | Lobby vote card |

Rendered from the blockout data in `BuildMaps` (walls, lockdown doors dashed, spawns in cyan, coins in
amber) and uploaded to the owner's account. Regenerate them if a map's layout changes.

## Built in code

Materials, lamps and furniture placement live in `src/serverstorage/Build/BuildMaps.luau`. The night
sky, colour grade and bloom live in `BuildLighting.luau`, and the lobby room in `BuildLobby.luau`.
Effect items and knife effects are particles defined in `src/shared/CosmeticFx.luau`, using Roblox's
built-in particle textures. Store art lives in [store-art](store-art/README.md).
