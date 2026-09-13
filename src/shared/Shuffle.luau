--!strict
-- Fisher-Yates, once, instead of four hand-written copies.
-- Pure module: requires nothing, so Lune can test it.
--
-- Both functions take an optional Random. Pass one where the result has to be
-- reproducible - BuildMaps seeds off the map name so the same map always
-- dresses itself the same way - and leave it out for ordinary gameplay
-- randomness, which uses math.random as before.
local Shuffle = {}

-- Anything that can draw an integer in a range. Only NextInteger is ever
-- called, so a Roblox Random and a plain table are interchangeable here -
-- production seeds a real Random off the map name, and the tests pass a stub
-- because Lune has no Random datatype.
--
-- Deliberately structural rather than `Random | Generator`: a union of two
-- function types is uncallable ("unable to determine the appropriate result
-- type"), so the one caller holding a real Random casts at its call site.
export type Generator = { NextInteger: (any, number, number) -> number }

-- Shuffles in place and returns the same table, so it can be used either way.
function Shuffle.Shuffle<T>(t: { T }, rng: Generator?): { T }
    for i = #t, 2, -1 do
        local j = if rng then rng:NextInteger(1, i) else math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Leaves the original untouched.
function Shuffle.Shuffled<T>(t: { T }, rng: Generator?): { T }
    return Shuffle.Shuffle(table.clone(t), rng)
end

return Shuffle
