-- Buckets a colour into a broad fabric band for the fibre clue.
-- A clue must narrow the field, never name one person.
-- Pure module: takes HSV in 0..1 (Color3:ToHSV), no Roblox services.
local FibreBands = {}

type Band = { name: string, h: { number }, s: { number }, v: { number } }

-- First match wins, so the achromatic bands come before the hued ones
FibreBands.BANDS = {
    { name = "black", h = { 0, 360 }, s = { 0, 1 }, v = { 0, 0.12 } },
    { name = "dark grey", h = { 0, 360 }, s = { 0, 0.15 }, v = { 0.12, 0.45 } },
    { name = "mid grey", h = { 0, 360 }, s = { 0, 0.15 }, v = { 0.45, 0.75 } },
    { name = "off-white", h = { 0, 360 }, s = { 0, 0.15 }, v = { 0.75, 1 } },
    { name = "deep navy", h = { 200, 260 }, s = { 0.15, 1 }, v = { 0.12, 0.5 } },
    { name = "rust red", h = { 340, 20 }, s = { 0.15, 1 }, v = { 0.12, 0.8 } },
    { name = "warm brown", h = { 20, 45 }, s = { 0.15, 1 }, v = { 0.12, 0.65 } },
    { name = "olive", h = { 60, 150 }, s = { 0.15, 1 }, v = { 0.12, 0.65 } },
} :: { Band }

local function within(x: number, range: { number }): boolean
    return x >= range[1] and x <= range[2]
end

function FibreBands.Describe(h: number, s: number, v: number): string
    local deg = (h % 1) * 360
    for _, band in FibreBands.BANDS do
        local lo, hi = band.h[1], band.h[2]
        -- A range like 340..20 wraps through red
        local inHue = if lo <= hi then deg >= lo and deg <= hi else deg >= lo or deg <= hi
        if inHue and within(s, band.s) and within(v, band.v) then
            return band.name .. " fabric"
        end
    end
    return (v < 0.4 and "dark" or "light") .. " fabric"
end

return FibreBands
