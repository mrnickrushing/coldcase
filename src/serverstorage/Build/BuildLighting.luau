--[[
  COLD CASE · lighting. Night, a cold grade, and a little glow on the neon.
  Bootstrap runs this on server start, before EventService captures the base
  light levels it restores after Lights Out.

  Never adds an Atmosphere: VisionController draws the vision radius with
  legacy fog, and an Atmosphere disables it. Lighting.Technology cannot be set
  from a script; the place is saved with Future.
]]
local Lighting = game:GetService("Lighting")

local function ensure(className: string, name: string): Instance
    local inst = Lighting:FindFirstChildOfClass(className :: any)
    if not inst then
        inst = Instance.new(className :: any)
        inst.Name = name
        inst.Parent = Lighting
    end
    return inst
end

return function()
    for _, child in Lighting:GetChildren() do
        if child:IsA("Atmosphere") then
            child:Destroy()
        end
    end

    -- A bright moonlit night: readable rooms, deep shadows, never a black box.
    -- Lights Out (EventService) drops brightness and ambient from here.
    Lighting.ClockTime = 0.5
    Lighting.Brightness = 2.6
    Lighting.Ambient = Color3.fromRGB(78, 84, 100)
    Lighting.OutdoorAmbient = Color3.fromRGB(104, 112, 134)
    Lighting.EnvironmentDiffuseScale = 0.6
    Lighting.EnvironmentSpecularScale = 0.7
    Lighting.GlobalShadows = true
    Lighting.ExposureCompensation = 0.45

    local sky = ensure("Sky", "NightSky") :: Sky
    sky.StarCount = 3000
    sky.MoonAngularSize = 9

    local grade = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
    grade.Saturation = -0.05
    grade.Contrast = 0.08
    grade.TintColor = Color3.fromRGB(232, 238, 255)

    local bloom = ensure("BloomEffect", "Glow") :: BloomEffect
    bloom.Intensity = 0.5
    bloom.Size = 28
    bloom.Threshold = 1.4
end
