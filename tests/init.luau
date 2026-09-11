-- Lune unit tests for the pure shared modules: `lune run tests`
-- In an init file, "./" resolves beside the tests folder, i.e. the repo root
local LiveOps = require("./src/shared/LiveOps")
local RateLimiter = require("./src/shared/RateLimiter")
local FibreBands = require("./src/shared/FibreBands")
local Progression = require("./src/shared/Progression")
local Lobby = require("./src/shared/Lobby")

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

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    error("tests failed")
end
