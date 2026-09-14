-- Lune unit tests for the pure shared modules: `lune run tests`
-- In an init file, "./" resolves beside the tests folder, i.e. the repo root
local LiveOps = require("./src/shared/LiveOps")
local RateLimiter = require("./src/shared/RateLimiter")
local FibreBands = require("./src/shared/FibreBands")
local Progression = require("./src/shared/Progression")
local Lobby = require("./src/shared/Lobby")
local MapPlan = require("./src/shared/MapPlan")
local Catalog = require("./src/shared/Catalog")
local SoundCues = require("./src/shared/SoundCues")
local Products = require("./src/shared/Products")
local Config = require("./src/shared/Config")
local Shuffle = require("./src/shared/Shuffle")
local fs = require("@lune/fs")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if ok then
        passed += 1
    else
        failed += 1
        print(("FAIL  %s\n      %s"):format(name, tostring(err)))
    end
end

local function eq(actual: any, expected: any, label: string?)
    if actual ~= expected then
        error(
            ("%sexpected %s, got %s"):format(
                label and (label .. ": ") or "",
                tostring(expected),
                tostring(actual)
            ),
            2
        )
    end
end

---------------------------------------------------------------- LiveOps
test("pre-launch is always day 0", function()
    eq(LiveOps.DayAt(1e9, nil), 0)
    eq(LiveOps.DayAt(100, 200), 0)
end)

test("day counts whole days since launch", function()
    eq(LiveOps.DayAt(1000 + 86400 * 13.9, 1000), 13)
    eq(LiveOps.DayAt(1000 + 86400 * 14, 1000), 14)
end)

test("trading unlocks on day 28", function()
    eq(LiveOps.IsTradingOpen(27), false)
    eq(LiveOps.IsTradingOpen(28), true)
end)

test("season one is open from day 14 until it closes", function()
    local s1 = LiveOps.GetSeason("S1")
    assert(s1, "S1 exists")
    eq(LiveOps.ActiveSeason(13), nil, "day 13")
    eq(LiveOps.ActiveSeason(14), s1, "day 14")
    eq(LiveOps.ActiveSeason(s1.closesDay - 1), s1, "last day")
    eq(LiveOps.ActiveSeason(s1.closesDay), nil, "closing day")
end)

test("a closed season stays retired forever", function()
    local s1 = LiveOps.GetSeason("S1")
    assert(s1, "S1 exists")
    eq(LiveOps.IsRetired("S1", s1.closesDay - 1), false)
    eq(LiveOps.IsRetired("S1", s1.closesDay), true)
    eq(LiveOps.IsRetired("S1", 10000), true)
    eq(LiveOps.IsRetired("UNKNOWN", 0), true, "unknown season")
    eq(LiveOps.IsRetired(nil, 10000), false, "non-seasonal item")
end)

test("double coin weekend covers days 60 to 62 only", function()
    eq(LiveOps.CoinMultiplier(59), 1)
    eq(LiveOps.CoinMultiplier(60), 2)
    eq(LiveOps.CoinMultiplier(62), 2)
    eq(LiveOps.CoinMultiplier(63), 1)
end)

---------------------------------------------------------------- RateLimiter
test("allows up to the limit within one second", function()
    local rl = RateLimiter.new(20, 5, 10)
    for i = 1, 20 do
        local ok = rl:Hit("p", 100.5)
        eq(ok, true, "call " .. i)
    end
    local ok, kick = rl:Hit("p", 100.9)
    eq(ok, false, "21st call")
    eq(kick, false, "one strike does not kick")
end)

test("the window resets each second", function()
    local rl = RateLimiter.new(2, 5, 10)
    rl:Hit("p", 1.1)
    rl:Hit("p", 1.2)
    eq((rl:Hit("p", 1.3)), false)
    eq((rl:Hit("p", 2.0)), true)
end)

test("sustained abuse kicks; old strikes expire", function()
    local rl = RateLimiter.new(1, 3, 10)
    local function spam(sec: number)
        rl:Hit("p", sec)
        local _, kick = rl:Hit("p", sec + 0.5)
        return kick
    end
    eq(spam(1), false)
    eq(spam(2), false)
    eq(spam(3), true, "third strike inside window")

    local rl2 = RateLimiter.new(1, 3, 10)
    rl = rl2
    eq(spam(1), false)
    eq(spam(2), false)
    eq(spam(20), false, "earlier strikes expired")
end)

test("players are limited independently", function()
    local rl = RateLimiter.new(1, 5, 10)
    rl:Hit("a", 1)
    eq((rl:Hit("a", 1)), false)
    eq((rl:Hit("b", 1)), true)
    rl:Remove("a")
    eq((rl:Hit("a", 1)), true, "state cleared on Remove")
end)

---------------------------------------------------------------- FibreBands
test("fibre bands name broad colours, never exact ones", function()
    eq(FibreBands.Describe(0, 0, 0.05), "black fabric")
    eq(FibreBands.Describe(0.5, 0.05, 0.3), "dark grey fabric")
    eq(FibreBands.Describe(0.5, 0.05, 0.6), "mid grey fabric")
    eq(FibreBands.Describe(0.5, 0.05, 0.9), "off-white fabric")
    eq(FibreBands.Describe(230 / 360, 0.7, 0.3), "deep navy fabric")
    eq(FibreBands.Describe(30 / 360, 0.6, 0.4), "warm brown fabric")
    eq(FibreBands.Describe(100 / 360, 0.5, 0.4), "olive fabric")
end)

test("rust red wraps through 0 degrees", function()
    eq(FibreBands.Describe(355 / 360, 0.8, 0.6), "rust red fabric")
    eq(FibreBands.Describe(5 / 360, 0.8, 0.6), "rust red fabric")
end)

test("colours outside every band fall back to dark or light", function()
    eq(FibreBands.Describe(55 / 360, 0.9, 0.95), "light fabric")
    eq(FibreBands.Describe(300 / 360, 0.9, 0.2), "dark fabric")
end)

---------------------------------------------------------------- Progression
test("rank titles step up at their thresholds", function()
    eq(Progression.TitleFor(1), "Bystander")
    eq(Progression.TitleFor(4), "Bystander")
    eq(Progression.TitleFor(5), "Witness")
    eq(Progression.TitleFor(30), "Detective")
    eq(Progression.TitleFor(250), "Cold Case")
end)

test("crate discount applies from its rank and never goes negative", function()
    eq(Progression.CratePrice(250, 24, 25, 25), 250)
    eq(Progression.CratePrice(250, 25, 25, 25), 225)
    eq(Progression.CratePrice(10, 99, 25, 25), 0)
end)

---------------------------------------------------------------- Lobby
test("enough real players start a full round with no NPCs", function()
    local plan = Lobby.Plan(4, 0, 4, 6, true)
    eq(plan.start, true, "start")
    eq(plan.full, true, "full")
    eq(plan.npcs, 0, "npcs")
end)

test("a solo player who plays now gets NPCs to fill the round", function()
    local plan = Lobby.Plan(1, 1, 4, 6, true)
    eq(plan.start, true, "start")
    eq(plan.full, false, "full")
    eq(plan.npcs, 5, "npcs")
end)

test("a solo player who chose to wait keeps waiting", function()
    eq(Lobby.Plan(1, 0, 4, 6, true).start, false)
end)

test("NPC seats count only the players who chose to play now", function()
    local plan = Lobby.Plan(3, 1, 4, 6, true)
    eq(plan.start, true, "start")
    eq(plan.npcs, 5, "npcs")
end)

test("with NPCs disabled a quiet server waits", function()
    eq(Lobby.Plan(2, 2, 4, 6, false).start, false)
end)

---------------------------------------------------------------- MapPlan
for name, plan in MapPlan.MAPS do
    test(name .. " plan has no problems", function()
        local analysis = MapPlan.Analyse(plan)
        eq(#analysis.problems, 0, table.concat(analysis.problems, "; "))
    end)

    test(name .. " every standable cell can be reached", function()
        local analysis = MapPlan.Analyse(plan)
        local reached, total, missing = MapPlan.Reachable(plan, analysis)
        eq(reached, total, "unreachable " .. table.concat(missing, ", "))
    end)

    test(name .. " a Lockdown shuts doors but seals no one in", function()
        local analysis = MapPlan.Analyse(plan)
        local shut = 0
        for _, edge in analysis.edges do
            if edge.lockdown then
                shut += 1
            end
        end
        assert(shut > 0, "no Lockdown doors")
        local reached, total, missing = MapPlan.Reachable(plan, analysis, true)
        eq(reached, total, "sealed in " .. table.concat(missing, ", "))
    end)

    test(name .. " a route leads from one end of the building to the other", function()
        local analysis = MapPlan.Analyse(plan)
        local cells = MapPlan.Standable(plan, analysis)
        local route = MapPlan.Route(plan, analysis, cells[1], cells[#cells])
        assert(route and #route > 0, "no route")
        eq(route[#route].f, cells[#cells].f, "ends on the right floor")
        eq(route[#route].x, cells[#cells].x, "ends on the right cell")
        local at = cells[1]
        for i, c in route do
            local stepped = c.f == at.f and math.abs(c.x - at.x) + math.abs(c.z - at.z) == 1
            local climbed = math.abs(c.f - at.f) == 1
            assert(
                stepped or climbed,
                ("step %d jumps from %d,%d,%d to %d,%d,%d"):format(
                    i,
                    at.f,
                    at.x,
                    at.z,
                    c.f,
                    c.x,
                    c.z
                )
            )
            at = c
        end
    end)

    test(name .. " spawns and coins reach every floor", function()
        local analysis = MapPlan.Analyse(plan)
        local points = MapPlan.Points(plan, analysis)
        eq(#points.spawns, MapPlan.SPAWNS, "spawns")
        eq(#points.coins, MapPlan.COINS, "coins")
        for f = 1, #plan.floors do
            local onFloor = false
            for _, c in points.coins do
                onFloor = onFloor or c.f == f
            end
            eq(onFloor, true, "a coin on floor " .. f)
        end
    end)
end

---------------------------------------------------------------- Data integrity
-- These cross-references fail silently at runtime: a style naming a prop that
-- does not exist just places nothing, and a cue id with no entry plays no
-- sound. Checking them here turns a silent gap into a failing test.

test("every catalogue item carries the fields the code reads", function()
    local kinds = { Knife = true, Pistol = true, Effect = true, Pet = true }
    local rarities = { Common = true, Uncommon = true, Rare = true, Legendary = true, Godly = true }
    for id, def in pairs(Catalog) do
        assert(type(def.name) == "string" and def.name ~= "", id .. " has no name")
        assert(kinds[def.kind], ("%s has an unknown kind %q"):format(id, tostring(def.kind)))
        assert(
            rarities[def.rarity],
            ("%s has an unknown rarity %q"):format(id, tostring(def.rarity))
        )
        assert(type(def.value) == "number" and def.value > 0, id .. " has no value")
    end
end)

test("catalogue item names are unique", function()
    local byName = {}
    for id, def in pairs(Catalog) do
        assert(
            not byName[def.name],
            ("%s and %s are both called %q"):format(id, tostring(byName[def.name]), def.name)
        )
        byName[def.name] = id
    end
end)

test("every sound cue has a group, a volume and an asset", function()
    local count = 0
    for id, cue in pairs(SoundCues.cues) do
        count += 1
        assert(type(cue.group) == "string" and cue.group ~= "", id .. " has no group")
        assert(type(cue.volume) == "number" and cue.volume > 0, id .. " has no volume")
        assert(
            type(cue.soundId) == "string" and cue.soundId:match("^rbxassetid://%d+$"),
            id .. " has no asset id"
        )
    end
    assert(count >= 20, ("only %d cues defined"):format(count))
end)

test("every role has a reveal pitch", function()
    for _, role in { "innocent", "sheriff", "murderer", "hero", "medic", "snitch" } do
        local pitch = SoundCues.ROLE_PITCH[role]
        assert(type(pitch) == "number" and pitch > 0, role .. " has no reveal pitch")
    end
end)

test("every purchasable product has an id and a price", function()
    for group, entries in pairs(Products) do
        if type(entries) == "table" then
            for key, def in pairs(entries) do
                if type(def) == "table" and def.price ~= nil then
                    assert(
                        type(def.name) == "string" and def.name ~= "",
                        ("%s.%s has no name"):format(group, key)
                    )
                    assert(type(def.id) == "number", ("%s.%s has no numeric id"):format(group, key))
                    assert(
                        type(def.price) == "number" and def.price > 0,
                        ("%s.%s has no price"):format(group, key)
                    )
                end
            end
        end
    end
end)

test("no analytics field value carries a character Roblox rejects", function()
    -- A comma, quote or apostrophe in a custom field makes Roblox discard the
    -- whole event. This bit us once: the death heatmap cell read "map:4,4" and
    -- every player_death was being thrown away.
    local function offending(value: string): string?
        for _, ch in { ",", '"', "'" } do
            if string.find(value, ch, 1, true) then
                return ch
            end
        end
        return nil
    end

    local sent = {}
    -- item ids, not display names: CrateOpened is called with entry.id, and
    -- "Widow's Peak" never reaches a field
    for id in pairs(Catalog) do
        table.insert(sent, id)
    end
    for _, map in Config.MAPS do
        table.insert(sent, map)
        table.insert(sent, ("%s:%dx%d"):format(map, 12, 7))
    end
    for _, reason in Config.REPORT_REASONS do
        table.insert(sent, reason)
    end
    for _, emote in Config.EMOTES do
        table.insert(sent, emote)
    end
    for _, role in
        { "innocent", "sheriff", "murderer", "hero", "medic", "snitch", "reset", "left", "self" }
    do
        table.insert(sent, role)
    end
    for _, event in { "LIGHTS_OUT", "POWER_SURGE", "LOCKDOWN", "FOG_BANK", "NONE" } do
        table.insert(sent, event .. "|6-8")
    end

    for _, value in sent do
        local ch = offending(value)
        assert(ch == nil, ("%q would be rejected: it contains %s"):format(value, tostring(ch)))
        assert(#value <= 50, ("%q is %d characters"):format(value, #value))
    end
end)

test("every map offers a spawn pad for a full server", function()
    -- With only 10 pads the placement loop ran out and left the rest standing
    -- in the lobby while the round played on without them, which is exactly
    -- what happened at the advertised player count. The cap is declared once,
    -- in Config, mirroring Players.MaxPlayers from default.project.json.
    local FULL_SERVER = Config.MAX_PLAYERS
    assert(
        MapPlan.SPAWNS >= FULL_SERVER,
        ("maps generate %d spawn pads, short of a full server of %d"):format(
            MapPlan.SPAWNS,
            FULL_SERVER
        )
    )
    for name, plan in MapPlan.MAPS do
        local analysis = MapPlan.Analyse(plan)
        local points = MapPlan.Points(plan, analysis)
        assert(
            #points.spawns >= FULL_SERVER,
            ("%s places only %d spawns for %d players"):format(name, #points.spawns, FULL_SERVER)
        )
    end
end)

---------------------------------------------------------------- Shuffle
test("a shuffle keeps every element exactly once", function()
    local source = {}
    for i = 1, 50 do
        source[i] = i
    end
    local out = Shuffle.Shuffled(source)
    eq(#out, #source, "length")
    local seen = {}
    for _, v in out do
        assert(not seen[v], "duplicated " .. tostring(v))
        seen[v] = true
    end
    for i = 1, 50 do
        assert(seen[i], "lost " .. tostring(i))
    end
end)

test("Shuffled leaves the original alone and Shuffle does not", function()
    local source = { "a", "b", "c", "d", "e", "f", "g", "h" }
    local copy = table.clone(source)
    Shuffle.Shuffled(source)
    eq(table.concat(source, ""), table.concat(copy, ""), "Shuffled must not touch its input")

    -- In place returns the same table, not a new one
    local same = Shuffle.Shuffle(source)
    assert(same == source, "Shuffle should return the table it shuffled")
end)

-- BuildMaps seeds off the map name so a map always dresses itself the same
-- way. If a seeded shuffle stopped being reproducible, maps would quietly
-- rebuild differently every server start.
--
-- Lune has no Random datatype, so this drives the same code path with a
-- deterministic stub. Shuffle only ever calls NextInteger, which is why it
-- takes a structural Generator rather than a Roblox Random.
local function seeded(seed: number)
    local state = seed
    return {
        NextInteger = function(_self, lo: number, hi: number): number
            state = (state * 1103515245 + 12345) % 2147483648
            return lo + state % (hi - lo + 1)
        end,
    }
end

test("a seeded shuffle is reproducible", function()
    local source = {}
    for i = 1, 30 do
        source[i] = i
    end
    local a = Shuffle.Shuffled(source, seeded(12345))
    local b = Shuffle.Shuffled(source, seeded(12345))
    local c = Shuffle.Shuffled(source, seeded(99999))
    eq(table.concat(a, ","), table.concat(b, ","), "same seed, same order")
    assert(table.concat(a, ",") ~= table.concat(c, ","), "different seeds should differ")
    eq(#a, #source, "length preserved")
end)

---------------------------------------------------------------- round results
-- The server picks a reason string and the client renders BLURB[reason]; an
-- unknown key renders an empty line, so a new reason can ship looking fine in
-- Studio and silently say nothing to players. These two lists must agree.
test("every round-over reason the server sends has a blurb", function()
    local server = fs.readFile("src/server/Services/RoundService.luau")
    local client = fs.readFile("src/client/Controllers/MenuController.luau")

    local blurbs = {}
    local table_ = client:match("local BLURB = {(.-)\n}")
    assert(table_, "could not find the BLURB table in MenuController")
    for key in table_:gmatch("(%w+)%s*=") do
        blurbs[key] = true
    end

    -- A reason is not always a literal argument: one call picks between two
    -- with an `and/or`, so read every string on the line and drop the winners.
    local winners = { innocents = true, murderer = true }
    local reasons, found = {}, 0
    for line in server:gmatch("[^\n]+") do
        if line:find("self:Resolve(", 1, true) then
            found += 1
            for literal in line:gmatch('"(%w+)"') do
                if not winners[literal] then
                    reasons[literal] = true
                end
            end
        end
    end
    assert(found > 0, "found no Resolve call sites to check - did the call shape change?")

    for reason in reasons do
        assert(
            blurbs[reason],
            ("the server resolves with %q but no blurb explains it"):format(reason)
        )
    end

    -- ...and nothing in the table is dead weight left over from an old reason
    for key in blurbs do
        assert(reasons[key], ("BLURB has %q but the server never sends it"):format(key))
    end
end)

-- The server charges season.crateCost (EconomyService) while the lobby quotes
-- Config.SEASONAL_COST until the attribute replicates. LiveOps cannot require
-- Config, so nothing but this test stops the two from drifting apart and
-- quoting players a price the server will not honour.
test("the seasonal crate costs the same on both sides", function()
    local season = LiveOps.GetSeason("S1")
    assert(season, "S1 exists")
    eq(season.crateCost, Config.SEASONAL_COST, "season price vs Config")
end)

---------------------------------------------------------------- onboarding funnel
-- Roblox's funnel report assumes a player reaches step N only after N-1, so
-- the numbers have to run 1..N with nothing missing and nothing repeated. A
-- gap reads as a cohort vanishing at a step that does not exist.
test("funnel steps are numbered from 1 with no gaps or repeats", function()
    local src = fs.readFile("src/server/Services/Analytics.luau")
    local block = src:match("Analytics%.FUNNEL = {(.-)\n}")
    assert(block, "could not find Analytics.FUNNEL - did the shape change?")

    local numbers, seen = {}, {}
    for num in block:gmatch("{%s*(%d+)%s*,") do
        local n = tonumber(num) :: number
        assert(not seen[n], ("step %d is used twice"):format(n))
        seen[n] = true
        table.insert(numbers, n)
    end
    assert(#numbers > 0, "found no funnel steps")

    table.sort(numbers)
    for i, n in numbers do
        eq(n, i, ("step in position %d"):format(i))
    end
end)

-- Removing a step leaves Analytics.FUNNEL.THAT_ONE as nil, and the funnel
-- helper immediately indexes it. luau-lsp does not flag a missing table field,
-- so nothing but this catches a call site left behind.
test("every funnel step the server references exists", function()
    local src = fs.readFile("src/server/Services/Analytics.luau")
    local block = src:match("Analytics%.FUNNEL = {(.-)\n}")
    assert(block, "could not find Analytics.FUNNEL")

    local keys = {}
    for key in block:gmatch("(%u[%u_]*)%s*=") do
        keys[key] = true
    end

    local paths = { "src/server/Bootstrap.server.luau" }
    for _, name in fs.readDir("src/server/Services") do
        table.insert(paths, "src/server/Services/" .. name)
    end

    local checked = 0
    for _, path in paths do
        if fs.isFile(path) then
            for key in fs.readFile(path):gmatch("Analytics%.FUNNEL%.(%u[%u_]*)") do
                checked += 1
                assert(keys[key], ("Analytics.FUNNEL.%s does not exist (%s)"):format(key, path))
            end
        end
    end
    assert(checked > 0, "found no funnel references to check")
end)

---------------------------------------------------------------- economy ordering
-- Every path that mints an item calls GiveItem, which can refuse: a starter,
-- or a seasonal whose season has closed. Anything irreversible - taking coins,
-- removing duplicates, burning a once-per-account flag - has to happen AFTER
-- that call succeeds, or the player pays and gets nothing. Today the standard
-- pool holds no id GiveItem would refuse, so this is latent; it goes live the
-- moment a starter or seasonal is added to a standard tier.
test("no economy path charges before its grant succeeds", function()
    local src = fs.readFile("src/server/Services/EconomyService.luau")

    -- Slice from a function's header to the next top-level declaration.
    -- Matching to an `end` with a non-greedy pattern does not work: these
    -- bodies contain nested blocks that end first, so the match stops early
    -- or fails outright.
    local lines = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end

    local function bodyOf(header: string): string
        local from
        for i, line in lines do
            if line:find(header, 1, true) == 1 then
                from = i
                break
            end
        end
        assert(from, "could not find " .. header)
        local out = {}
        for i = from + 1, #lines do
            local line = lines[i]
            if line:find("^function ") or line:find("^local function ") then
                break
            end
            table.insert(out, line)
        end
        return table.concat(out, "\n")
    end

    -- In each body, the GiveItem call must come before the irreversible bits.
    local cases = {
        {
            name = "Craft",
            body = bodyOf("function EconomyService:Craft"),
            after = { "data%.coins %-= Config%.CRAFT_FEE", "table%.remove%(data%.inventory" },
        },
        {
            name = "OpenCrate",
            body = bodyOf("function EconomyService:OpenCrate"),
            after = { "data%.coins %-= cost" },
        },
        {
            name = "giveRankGift",
            body = bodyOf("local function giveRankGift"),
            after = { "data%.onboarding%.rankGift = true" },
        },
    }

    for _, case in cases do
        local grantAt = case.body:find("GiveItem%(")
        assert(grantAt, ("%s no longer calls GiveItem - has it been renamed?"):format(case.name))
        for _, pattern in case.after do
            local at = case.body:find(pattern)
            assert(at, ("%s no longer contains %s"):format(case.name, pattern))
            assert(
                at > grantAt,
                ("%s does something irreversible (%s) before GiveItem can refuse"):format(
                    case.name,
                    pattern
                )
            )
        end
    end
end)

---------------------------------------------------------------- round events
-- One event fires per round, picked from the ones that suit the map. A map
-- whose pool holds a single event plays the same round every time, and an
-- empty pool would fire nothing at all.
test("every map has at least two round events to choose from", function()
    local src = fs.readFile("src/server/Services/EventService.luau")
    local block = src:match("local EVENTS = {(.-)\n}")
    assert(block, "could not find the EVENTS table")

    local events = {}
    for line in block:gmatch("[^\n]+") do
        local id = line:match('id = "(%u[%u_]*)"')
        if id then
            local weight = tonumber(line:match("weight = (%d+)"))
            assert(weight and weight > 0, ("%s has no usable weight"):format(id))
            table.insert(events, {
                id = id,
                weight = weight,
                anywhere = line:find("anywhere = true", 1, true) ~= nil,
                indoor = line:find("indoor = true", 1, true) ~= nil,
            })
        end
    end
    assert(#events > 0, "found no events")

    for _, indoors in { true, false } do
        local pool = {}
        for _, e in events do
            if e.anywhere or e.indoor == indoors then
                table.insert(pool, e.id)
            end
        end
        assert(
            #pool >= 2,
            ("%s maps would only ever see: %s"):format(
                indoors and "indoor" or "outdoor",
                table.concat(pool, ", ")
            )
        )
    end
end)

---------------------------------------------------------------- headcounts
-- A threshold above the server cap is dead configuration: the rule it guards
-- never fires and nobody notices, because nothing errors. SECOND_SHERIFF_AT
-- sat at 14 against a cap of 12, so a second sheriff never once appeared.
test("no headcount threshold is above the server cap", function()
    for _, name in
        {
            "MIN_PLAYERS",
            "SECOND_MURDERER_AT",
            "SECOND_SHERIFF_AT",
            "ROUND_LARGE_AT",
            "ROUND_SMALL_UNDER",
            "MEDIC_AT",
            "SNITCH_AT",
            "BOT_FILL_TO",
        }
    do
        local v = Config[name]
        assert(type(v) == "number", ("Config.%s is missing"):format(name))
        assert(
            v <= Config.MAX_PLAYERS,
            ("Config.%s = %d is above MAX_PLAYERS (%d), so it can never fire"):format(
                name,
                v,
                Config.MAX_PLAYERS
            )
        )
    end
end)

-- The playtest checklist promises an NPC murderer waits "at least 9s" before
-- its first strike. That floor is BOT_FIRST_HUNT[1]. The checklist once read
-- "12s" - the value of BOT_CHASE_GIVE_UP, an unrelated chase-timeout constant -
-- so pin the two apart: the floor is the range's low end, and it is not the
-- give-up timer. A behavioural round can only ever land above this floor
-- (the wait is randomised and the bot must then reach someone), so the floor
-- itself is the only part a test can hold still.
test("an NPC murderer's first-strike floor is 9s, not the chase timeout", function()
    local hunt = Config.BOT_FIRST_HUNT
    assert(type(hunt) == "table", "BOT_FIRST_HUNT must be a {min, max} range")
    eq(hunt[1], 9, "BOT_FIRST_HUNT floor")
    assert(hunt[2] >= hunt[1], "BOT_FIRST_HUNT max is below its min")
    assert(
        Config.BOT_CHASE_GIVE_UP ~= hunt[1],
        "the chase-timeout constant must stay distinct from the first-strike floor"
    )
end)

---------------------------------------------------------------- cosmetics
-- Cosmetics must never be worth an advantage. A particle emitter with
-- LightEmission above 0 glows in the dark, so an equipped effect would light
-- its owner's way through Lights Out - the one event whose whole point is that
-- nobody can see. That would be pay-to-win, and it would be invisible in
-- review: the item still looks like a cosmetic.
test("cosmetic particles never emit light", function()
    local src = fs.readFile("src/shared/CosmeticFx.luau")
    local body = src:match("function CosmeticFx%.Emitter.-\nend")
    assert(body, "could not find CosmeticFx.Emitter")

    local emission = body:match("LightEmission%s*=%s*([%d%.]+)")
    assert(emission, "Emitter no longer sets LightEmission at all")
    eq(tonumber(emission), 0, "LightEmission")

    -- LightInfluence 1 means the particle is lit by the scene rather than
    -- ignoring it, so it goes dark with everything else.
    local influence = body:match("LightInfluence%s*=%s*([%d%.]+)")
    assert(influence, "Emitter no longer sets LightInfluence")
    eq(tonumber(influence), 1, "LightInfluence")
end)

---------------------------------------------------------------- touch layout
-- The social dock is drawn bottom-left by SocialController; the touch action
-- buttons are anchored to the right edge by InputController. Neither file can
-- see the other, so the inset the dock budgets for has to match the real
-- leftmost button or they overlap on a short screen - which is exactly what
-- happened at 568x320, where the dock covered a corner of DRAG.
test("the dock is sized to clear the leftmost touch button", function()
    local input = fs.readFile("src/client/Controllers/InputController.luau")
    local social = fs.readFile("src/client/Controllers/SocialController.luau")

    local insets = {}
    for n in input:gmatch("UDim2%.new%(1, %-(%d+), 1, %-%d+%)") do
        table.insert(insets, tonumber(n))
    end
    assert(#insets > 0, "found no action button positions in InputController")
    table.sort(insets)
    local leftmost = insets[#insets] -- the biggest inset reaches furthest left

    local budget = tonumber(social:match("local maxWidth = width %- (%d+)"))
    assert(budget, "SocialController no longer budgets the dock against a button inset")
    eq(budget, leftmost, "dock width budget vs the leftmost button's inset")
end)

---------------------------------------------------------------- round loop
-- The round loop is a single coroutine. An uncaught error inside it ends that
-- coroutine permanently: the loop stops, and the server sits in whatever state
-- it was in until it shuts down, for every player on it. Nothing watches it,
-- so the tick has to be wrapped - and the wrapping is the kind of thing a
-- later refactor quietly drops, because nothing looks wrong without it.
-- KNOWN BLIND SPOT, found the hard way. This test was called "the round loop
-- cannot be killed by one bad tick", and a live server was then watched dying
-- with the test still passing:
--
--   Script timeout: exhausted allowed execution time
--   Script 'ServerScriptService.Services.RoundService', Line 379
--
-- Line 379 is the `while true` below. A thread that exhausts its execution
-- budget is not raising an error - it is terminated, so xpcall never returns
-- and recover() never runs. RoundState sat on LOADING for eight minutes with
-- the map cloned, three of five NPCs built and movement never locked, while
-- Heartbeat kept firing sixty times a second: the scheduler was fine, only
-- this coroutine was gone.
--
-- So what follows verifies that the guard is present and sits inside the loop.
-- It does NOT verify that the loop survives, and no static test can. Renamed
-- to say only what it checks, because the old name was a claim this file had
-- no business making.
test("the round loop guards each tick against errors", function()
    local src = fs.readFile("src/server/Services/RoundService.luau")

    local body = src:match("function RoundService:Start%(%)(.-)\nend")
    assert(body, "could not find RoundService:Start")

    assert(
        body:find("xpcall", 1, true) or body:find("pcall", 1, true),
        "Start's loop no longer guards its tick - one error would stop the round loop for good"
    )
    assert(
        body:find("debug.traceback", 1, true),
        "Start guards the tick but discards the traceback, which makes the failure unreadable"
    )
    -- and the guard has to be inside the loop, not around it: wrapping the
    -- whole `while true` would still exit for good on the first error.
    local loopAt = body:find("while true", 1, true)
    local guardAt = body:find("xpcall", 1, true) or body:find("pcall", 1, true)
    assert(loopAt and guardAt and guardAt > loopAt, "the guard sits outside the loop")

    assert(
        src:find("function RoundService:Tick", 1, true),
        "Start no longer calls out to a tick function"
    )
end)

------------------------------------------------------------ playtest triage
-- docs/playtest.md carries a triage table: a headline count of ticked and
-- unticked lines, then a split of everything not yet ticked into buckets by
-- what it would actually take to settle it. Both are maintained by hand, one
-- line at a time, and nothing about a wrong number looks wrong from the page.
-- The table drifted by one for several sessions and was caught by accident,
-- not by reading it - the radio line had been counted once in a bucket's list
-- and then a second time for its other half. A count that disagrees with the
-- checkboxes is worse than no count, because it gets quoted as progress.
test("the playtest triage table agrees with its own checkboxes", function()
    local doc = fs.readFile("docs/playtest.md")

    local ticked, unticked = 0, 0
    local buckets = {}
    for line in doc:gmatch("[^\n]+") do
        if line:find("^%- %[x%]") then
            ticked += 1
        elseif line:find("^%- %[ %]") then
            unticked += 1
        end
        -- The second column of a triage row is its count. The header row and
        -- the `| --- |` rule hold no digits there, so they skip themselves.
        local n = line:match("^| [^|]+ | (%d+) |")
        if n then
            table.insert(buckets, tonumber(n))
        end
    end

    local saidTicked, saidUnticked = doc:match("(%d+) ticked, (%d+) not")
    assert(saidTicked, "the triage headline no longer states a ticked/not split")
    eq(tonumber(saidTicked), ticked, "headline ticked count vs the real checkboxes")
    eq(tonumber(saidUnticked), unticked, "headline unticked count vs the real checkboxes")

    assert(#buckets > 0, "found no triage buckets to add up")
    local total = 0
    for _, n in buckets do
        total += n
    end
    -- Every unticked line sits in exactly one bucket, so the split has to
    -- account for all of them and no more.
    eq(total, unticked, "triage buckets summed vs the unticked lines")
end)

------------------------------------------------------------- weapon grace
-- Nobody can be killed for the first WEAPON_GRACE seconds. Two things have to
-- hold for that to mean anything, and neither looks wrong if it breaks.
--
-- First, roundStart is stamped by MarkRoundStart, and it has to be stamped as
-- the round goes ACTIVE. The call currently sits at the end of the REVEAL
-- branch, right before setState("ACTIVE", ...). Move it up into LOADING or the
-- start of REVEAL and the grace is measured from there instead - LOADING_TIME
-- plus REVEAL_TIME is 7 seconds against a 4 second grace, so the window would
-- be over before anyone could move, and every test of it would still pass
-- because the constant is untouched.
--
-- Second, every path that can kill has to consult it. There are three, and a
-- fourth added later would not announce itself.
test("the weapon grace is measured from the start of the round", function()
    local src = fs.readFile("src/server/Services/RoundService.luau")

    local reveal = src:match('elseif state == "REVEAL" then(.-)elseif state == "ACTIVE"')
    assert(reveal, "could not find the REVEAL branch of the round state machine")
    assert(
        reveal:find("CombatService:MarkRoundStart()", 1, true),
        "MarkRoundStart is no longer called as the round goes ACTIVE - the grace "
            .. "would be measured from whenever it is called instead"
    )

    -- and it must be stamped before the state flips, not after
    local markAt = reveal:find("CombatService:MarkRoundStart()", 1, true)
    local activeAt = reveal:find('setState("ACTIVE"', 1, true)
    assert(activeAt, "the REVEAL branch no longer sets the round ACTIVE")
    assert(markAt < activeAt, "the round goes ACTIVE before the grace clock is started")
end)

test("every lethal path checks the weapon grace", function()
    local src = fs.readFile("src/server/Services/CombatService.luau")

    assert(src:find("local function inGrace", 1, true), "CombatService no longer has a grace check")

    -- Each of these can end a life. Pickup cannot, and Eliminate is the
    -- internal executor the three below call once they have decided.
    for _, fn in { "RequestStab", "RequestThrow", "RequestShoot" } do
        local body = src:match("function CombatService:" .. fn .. "%(.-\nend")
        assert(body, "could not find CombatService:" .. fn)
        assert(body:find("inGrace()", 1, true), fn .. " can kill without checking the grace window")
    end
end)

-------------------------------------------------------------- witness clue
-- The witness clue prints the first two characters of the killer's name:
--   ("Partial name on the lips: %s…"):format(data.killer:sub(1, 2))
-- Every NPC name has a distinct two-character prefix, so those two characters
-- identify one NPC outright. Watched happening in a live round: a clue reading
-- "Ir…" alongside a fibre band that matched exactly one NPC, and both pointed
-- at Iris.
--
-- This test does NOT assert that prefixes should collide - that would be
-- pinning the problem in place as though it were intended. It asserts the
-- property that makes the clue name rather than narrow, so the decision stays
-- visible. If the prefix length changes, or the name pool gains a collision,
-- or the clue stops being a raw prefix, this fails and someone re-reads it.
test("the witness clue names one NPC rather than narrowing the field", function()
    local bot = fs.readFile("src/server/Services/BotService.luau")
    local evidence = fs.readFile("src/server/Services/EvidenceService.luau")

    local names = {}
    local block = bot:match("local NAMES = {(.-)}")
    assert(block, "could not find the NPC name pool")
    for name in block:gmatch('"([^"]+)"') do
        table.insert(names, name)
    end
    assert(#names > 1, "expected several NPC names, found " .. #names)

    local n = tonumber(evidence:match("data%.killer:sub%(1,%s*(%d+)%)"))
    assert(n, "the witness clue no longer takes a plain prefix of the killer's name")

    local seen, collisions = {}, 0
    for _, name in names do
        local prefix = name:sub(1, n)
        if seen[prefix] then
            collisions += 1
        end
        seen[prefix] = true
    end

    -- Pinned as it stands today: every prefix distinct, so the clue names one
    -- NPC. This passes now on purpose. A test that failed against shipping code
    -- would leave the suite permanently red, and a red suite gets ignored - it
    -- would cost more than the finding is worth, and the finding is already
    -- written down in docs/playtest.md with the round it was observed in.
    --
    -- What this catches is a silent change: a different prefix length, a name
    -- added that collides, or the clue ceasing to be a plain prefix. Any of
    -- those flips this and sends someone back to the design question, which is
    -- whether a body should give the murderer away outright.
    eq(collisions, 0, "NPC name prefix collisions at " .. n .. " characters")
    eq(#names, 12, "NPC name pool size")
    assert(
        n == 2,
        "the witness clue prefix length changed from 2 - re-read whether the clue "
            .. "still names one NPC outright, and update docs/playtest.md"
    )
end)

--------------------------------------------------------- NPC round payouts
-- The playtest checklist ticks "Round rewards are paid in full with NPCs" on
-- the strength of BOT_ROUND_REWARD being 1, which makes the withBots multiply
-- a no-op. Turn that constant down and the tick quietly becomes false: nothing
-- in the code looks wrong, and the doc still claims full pay.
--
-- Reconciled live once, so the claim is not only structural: a win with
-- survival paid floor((COINS_WIN + COINS_SURVIVE) * 2.5 + 0.5) = 325 with no
-- bot reduction anywhere in it.
test("a round against NPCs pays the same as one against people", function()
    eq(Config.BOT_ROUND_REWARD, 1, "BOT_ROUND_REWARD (1 = full pay)")

    -- The lever has to still be wired, or the constant means nothing.
    local src = fs.readFile("src/server/Services/EconomyService.luau")
    assert(
        src:find("Config.BOT_ROUND_REWARD", 1, true),
        "EconomyService no longer scales NPC-round pay, so the constant is dead"
    )
    assert(
        src:find("withBots", 1, true),
        "EconomyService no longer distinguishes a round containing NPCs"
    )
end)

------------------------------------------------------- Last Call settlement
-- Last Call doubles coins earned DURING the final thirty seconds - pickups,
-- examines, revives - but NOT the end-of-round settlement. `round` was
-- deliberately removed from LAST_CALL_SOURCES (owner decision): doubling the
-- settlement rewarded a round lasting past the thirty-second mark rather than
-- playing better, and since lastCallFired resets each round it made identical
-- wins pay 1.25x or 2.5x on length alone. This pins the fix: `round` must stay
-- out, and the in-round faucets must stay in.
test("Last Call doubles in-round faucets but not the settlement", function()
    local economy = fs.readFile("src/server/Services/EconomyService.luau")
    local sources = economy:match("LAST_CALL_SOURCES = {(.-)}")
    assert(sources, "could not find LAST_CALL_SOURCES")

    assert(
        not sources:find("round", 1, true),
        "`round` is back in LAST_CALL_SOURCES - the end-of-round settlement would "
            .. "double again during Last Call, paying identical wins 2.5x or 1.25x "
            .. "purely on how long the round ran. It was removed on purpose."
    )
    for _, faucet in { "pickup", "examine", "revive" } do
        assert(
            sources:find(faucet, 1, true),
            faucet
                .. " no longer doubles during Last Call - the in-round faucets "
                .. "are meant to, only the settlement is excluded"
        )
    end
end)

--------------------------------------------------- onboarding economy
-- Config calls STARTING_COINS "below CRATE_COST so the second crate is locked
-- in round two". The first crate is free - OnboardingService grants a Locker
-- pull five seconds after a new player lands - so what that comment protects
-- is that the *second* one has to be earned.
--
-- A brand-new profile does not hold STARTING_COINS alone. lastLogin starts at
-- 0, so ApplyLoginStreak sets the streak to 1 and pays STREAK_COINS_PER_DAY
-- before the player ever reaches the lobby. Watched live on a fresh session:
-- 150 coins, and the Locker reading "NEED 100 MORE" against a 250 crate.
--
-- Raise either number past the crate price and that opening beat disappears
-- with nothing looking wrong anywhere.
test("a new player cannot afford the second crate", function()
    assert(
        Config.STARTING_COINS < Config.CRATE_COST,
        ("STARTING_COINS %d is no longer below CRATE_COST %d, so the crate after "):format(
            Config.STARTING_COINS,
            Config.CRATE_COST
        ) .. "the free one is affordable immediately"
    )

    -- What a new player actually holds on their first day.
    local dayOne = Config.STARTING_COINS + Config.STREAK_COINS_PER_DAY
    assert(
        dayOne < Config.CRATE_COST,
        ("a new player holds %d on day one - STARTING_COINS %d plus a first streak of %d - "):format(
            dayOne,
            Config.STARTING_COINS,
            Config.STREAK_COINS_PER_DAY
        )
            .. ("which is not below CRATE_COST %d. The second crate is no longer locked, and "):format(
                Config.CRATE_COST
            )
            .. "the NEED N MORE state on the Locker becomes unreachable."
    )
end)

-------------------------------------------------- remote handler coverage
-- Every client -> server remote must have a server handler. RemoteSetup
-- declares the remotes in two blocks split by a "client -> server" comment;
-- the ones below it are player actions, and each is fired by the client. A
-- declared client->server remote with no RemoteGuard.Connect is a player
-- action the server silently ignores - a bug that looks like nothing.
-- (Verified live: all 21 currently have handlers, all in Bootstrap.)
test("every client-to-server remote has a server handler", function()
    local setup = fs.readFile("src/shared/RemoteSetup.luau")
    local boot = fs.readFile("src/server/Bootstrap.server.luau")

    local marker = setup:find("client %-> server")
    assert(marker, "RemoteSetup no longer marks its client->server block")
    local tail = setup:sub(marker)

    local missing = {}
    local n = 0
    for name in tail:gmatch('"(Request%w+)"') do
        n += 1
        if not boot:find('RemoteGuard.Connect("' .. name .. '"', 1, true) then
            table.insert(missing, name)
        end
    end
    -- HintSeen is the one client->server remote not named Request*
    if tail:find('"HintSeen"', 1, true) then
        n += 1
        if not boot:find('RemoteGuard.Connect("HintSeen"', 1, true) then
            table.insert(missing, "HintSeen")
        end
    end

    assert(n >= 20, "expected the full client->server block, found only " .. n)
    assert(
        #missing == 0,
        "client->server remotes with no server handler (fired by the client, "
            .. "ignored by the server): "
            .. table.concat(missing, ", ")
    )
end)

------------------------------------------------- rarity odds and integrity
-- Roblox requires accurate published odds on paid random items, and
-- RarityTable's own comment says so. The Locker's pull weights must sum to
-- 100, or the disclosed percentages the game shows are wrong - a compliance
-- problem, not just a balance one. Nothing pinned this.
--
-- RarityTable uses Color3.fromHex, which Lune has no datatype for, so it
-- cannot be required here; parse it as text instead. Catalog is pure data and
-- loads normally.
test("Locker pull weights sum to 100 and cover every rarity", function()
    local src = fs.readFile("src/shared/RarityTable.luau")

    local names, weights, total = {}, {}, 0
    for name, weight in src:gmatch('name = "(%w+)",%s*weight = ([%d.]+)') do
        names[name] = true
        weights[name] = tonumber(weight)
        total += tonumber(weight)
    end
    local n = 0
    for _ in pairs(names) do
        n += 1
    end
    assert(n >= 3, "parsed only " .. n .. " rarities from RarityTable - format changed?")

    -- floating point: 56 + 24 + 13 + 5.5 + 1.5 should be exactly 100
    assert(
        math.abs(total - 100) < 0.001,
        ("Locker pull weights sum to %.3f, not 100 - the published odds the game "):format(total)
            .. "discloses are now inaccurate, which Roblox requires to be correct"
    )

    -- every rarity an item can have must be a rarity that can be pulled/priced
    local unknown = {}
    for id, def in Catalog do
        if type(def) == "table" and def.rarity and not names[def.rarity] then
            table.insert(unknown, id .. "=" .. tostring(def.rarity))
        end
    end
    assert(
        #unknown == 0,
        "Catalog items with a rarity absent from RarityTable: " .. table.concat(unknown, ", ")
    )
end)

-- Crafting steps an item up one tier, so TIER_ORDER must list exactly the
-- rarities RarityTable defines, in ascending order. A rarity in one table but
-- not the other means crafting either dead-ends or skips a tier.
test("the crafting tier order matches the rarity table", function()
    local rt = fs.readFile("src/shared/RarityTable.luau")
    local eco = fs.readFile("src/server/Services/EconomyService.luau")

    local rarOrder = {}
    for name in rt:gmatch('name = "(%w+)"') do
        table.insert(rarOrder, name)
    end
    local tierBlock = eco:match("TIER_ORDER = {(.-)}")
    assert(tierBlock, "could not find TIER_ORDER in EconomyService")
    local tiers = {}
    for name in tierBlock:gmatch('"(%w+)"') do
        table.insert(tiers, name)
    end

    eq(#tiers, #rarOrder, "TIER_ORDER length vs RarityTable length")
    for i, name in rarOrder do
        eq(tiers[i], name, "tier " .. i)
    end
end)

------------------------------------------------------ snitch reveal (two murderers)
-- A full round can hold two murderers (SECOND_MURDERER_AT). RevealSnitch used
-- to keep a single `murderer` variable, which named only whichever the table
-- iterated last and left the other murderer unwarned. The fix collects all
-- murderers and reveals each. RoleService requires Roblox services and cannot
-- load under Lune, so this guards the shape in source: a plural collection and
-- a loop, never a lone assignment.
test("the snitch reveal handles more than one murderer", function()
    local src = fs.readFile("src/server/Services/RoleService.luau")
    local body = src:match("function RoleService:RevealSnitch%(%)(.-)\nend")
    assert(body, "could not find RoleService:RevealSnitch")

    assert(
        body:find("table.insert(murderers", 1, true),
        "RevealSnitch no longer collects every murderer - a single one would be "
            .. "revealed and the other left unwarned at twelve players"
    )
    -- it must loop to fire at each murderer, not fire once
    assert(
        body:find("for _, murderer in murderers", 1, true),
        "RevealSnitch no longer loops over the murderers to warn each of them"
    )
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    error("tests failed")
end
