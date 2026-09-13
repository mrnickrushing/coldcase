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

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    error("tests failed")
end
