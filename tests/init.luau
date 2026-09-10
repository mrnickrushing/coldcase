-- Lune unit tests for the pure shared modules: `lune run tests`
-- In an init file, "./" resolves beside the tests folder, i.e. the repo root
local LiveOps = require("./src/shared/LiveOps")
local RateLimiter = require("./src/shared/RateLimiter")

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

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    error("tests failed")
end
