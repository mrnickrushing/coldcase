--!strict
-- COLD CASE · per-map lighting mood. Each scene gets its own colour grade and
-- bloom, applied as its map loads and reset to a neutral lobby look on return.
--
-- It only ever touches the ColorCorrection "Grade" and Bloom "Glow" that
-- BuildLighting created - never Brightness, Ambient or ClockTime, which
-- EventService captures once and restores after Lights Out. So a blackout is
-- unaffected, and moods are kept subtle to protect the readability the whole
-- game is built on.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LightingMood = {}

export type Profile = {
    tint: Color3,
    contrast: number,
    saturation: number,
    bloom: number,
    bloomSize: number,
    bloomThreshold: number,
}

-- Lobby matches BuildLighting's neutral warm base. The three scenes lean:
-- Blackwood warm and golden, the Pier cool and hazy, the Archive crisp and
-- cool-white. Contrast and saturation stay moderate so nothing hurts to read.
local PROFILES: { [string]: Profile } = {
    Lobby = {
        tint = Color3.fromRGB(255, 252, 245),
        contrast = 0.10,
        saturation = 0.18,
        bloom = 0.30,
        bloomSize = 24,
        bloomThreshold = 1.8,
    },
    BlackwoodManor = {
        tint = Color3.fromRGB(255, 244, 224),
        contrast = 0.16,
        saturation = 0.22,
        bloom = 0.42,
        bloomSize = 28,
        bloomThreshold = 1.6,
    },
    RustedPier = {
        tint = Color3.fromRGB(232, 242, 255),
        contrast = 0.08,
        saturation = 0.10,
        bloom = 0.35,
        bloomSize = 30,
        bloomThreshold = 1.9,
    },
    CityArchive = {
        tint = Color3.fromRGB(246, 248, 255),
        contrast = 0.20,
        saturation = 0.14,
        bloom = 0.22,
        bloomSize = 20,
        bloomThreshold = 2.0,
    },
}

local INFO = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function LightingMood.Apply(name: string)
    local p = PROFILES[name] or PROFILES.Lobby
    local grade = Lighting:FindFirstChild("Grade")
    local glow = Lighting:FindFirstChild("Glow")
    if grade and grade:IsA("ColorCorrectionEffect") then
        TweenService:Create(grade, INFO, {
            TintColor = p.tint,
            Contrast = p.contrast,
            Saturation = p.saturation,
        }):Play()
    end
    if glow and glow:IsA("BloomEffect") then
        TweenService:Create(glow, INFO, {
            Intensity = p.bloom,
            Size = p.bloomSize,
            Threshold = p.bloomThreshold,
        }):Play()
    end
end

return LightingMood
