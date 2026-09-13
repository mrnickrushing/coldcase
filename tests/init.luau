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
    -- A full server is 12. With only 10 pads the placement loop ran out and
    -- left the rest standing in the lobby while the round played on without
    -- them, which is exactly what happened at the advertised player count.
    local FULL_SERVER = 12
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

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    error("tests failed")
end
