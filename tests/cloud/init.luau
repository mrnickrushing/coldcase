--!strict
-- Engine tests: the half of the suite that needs a real Roblox VM.
--
-- The Lune suite (tests/init.luau) covers pure modules fast and locally, but it
-- has no Color3/Vector3/CFrame/Instance and cannot load a server Service (they
-- reach for the datamodel). This script runs inside a real Roblox VM through the
-- Open Cloud Luau Execution API (see scripts/cloud-test.sh), so it can:
--   * smoke-load every server Service - catching require cycles and typos that
--     otherwise only surface when Studio is launched, and
--   * test the modules built on Roblox datatypes (CosmeticFx auras and knife
--     effects, which the Lune suite cannot even require).
-- It returns { passed, failed, failures } - the runner reads that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local passed, failed = 0, 0
local failures: { string } = {}

local function test(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if ok then
        passed += 1
    else
        failed += 1
        table.insert(failures, ("%s -- %s"):format(name, tostring(err)))
    end
end

local function assertf(cond: any, msg: string)
    if not cond then
        error(msg, 2)
    end
end

-- The Remotes folder is what every Service expects to exist; the place's own
-- Bootstrap has not run in this bare datamodel, so create it first.
test("RemoteSetup builds the Remotes folder", function()
    require(Shared.RemoteSetup)()
    assertf(
        ReplicatedStorage:FindFirstChild("Remotes") ~= nil,
        "no Remotes folder after RemoteSetup"
    )
end)

-- Every server Service loads clean. A require cycle, a renamed module or a
-- missing service fails here in ~2s instead of at the next Studio launch.
test("every server Service require()s without error", function()
    local bad = {}
    for _, m in ipairs(ServerScriptService.Services:GetChildren()) do
        if m:IsA("ModuleScript") then
            local ok, err = pcall(require, m)
            if not ok then
                table.insert(bad, ("%s (%s)"):format(m.Name, tostring(err)))
            end
        end
    end
    assertf(#bad == 0, "services failed to load: " .. table.concat(bad, "; "))
end)

-- CosmeticFx is built entirely from Color3/NumberRange/Vector3, so the Lune
-- suite cannot touch it. Validate the shape of every particle look.
local Catalog = require(Shared.Catalog)
local CosmeticFx = require(Shared.CosmeticFx)

local function validFx(label: string, fx: any)
    assertf(typeof(fx.texture) == "string" and fx.texture ~= "", label .. " has no texture")
    assertf(typeof(fx.colour) == "Color3", label .. " colour is not a Color3")
    assertf(typeof(fx.rate) == "number" and fx.rate > 0, label .. " rate must be positive")
    assertf(typeof(fx.lifetime) == "NumberRange", label .. " lifetime is not a NumberRange")
    assertf(typeof(fx.size) == "number" and fx.size > 0, label .. " size must be positive")
    assertf(typeof(fx.speed) == "NumberRange", label .. " speed is not a NumberRange")
    -- Design rule: a cosmetic never lights the scene (no Lights Out edge).
    assertf(fx.LightEmission == nil, label .. " must not set LightEmission")
end

test("every CosmeticFx aura and knife effect is well formed", function()
    for id, fx in pairs(CosmeticFx.AURA) do
        validFx("AURA." .. id, fx)
    end
    for id, fx in pairs(CosmeticFx.KNIFE) do
        validFx("KNIFE." .. id, fx)
    end
end)

-- An Effect item with no aura would equip to nothing, so every one must have a
-- look - including the VIP-exclusive Regalia.
test("every Effect item has an aura look", function()
    for id, item in pairs(Catalog) do
        if item.kind == "Effect" then
            assertf(CosmeticFx.AURA[id] ~= nil, ("Effect %q has no CosmeticFx.AURA"):format(id))
        end
    end
end)

-- BuildAssets rebuilds the meshes from the manifest. Every knife/pistol/pet must
-- end up with a preview model, or it renders as a bare diamond in the crate and
-- shop instead of the real weapon. Catches a missing manifest entry headlessly.
test("BuildAssets gives every knife, pistol and pet a preview model", function()
    require(game:GetService("ServerStorage").Build.BuildAssets)()
    local pv = ReplicatedStorage:FindFirstChild("PreviewModels")
    assertf(pv ~= nil, "no PreviewModels folder after BuildAssets")
    local missing = {}
    for id, item in pairs(Catalog) do
        if item.kind == "Knife" or item.kind == "Pistol" or item.kind == "Pet" then
            if not pv:FindFirstChild(id) then
                table.insert(missing, id)
            end
        end
    end
    assertf(#missing == 0, "no preview model for: " .. table.concat(missing, ", "))
end)

-- FibreBands turns the killer's torso colour into the fibre clue; exercise it
-- with real Color3 HSV values the Lune suite cannot construct.
test("FibreBands.Describe names a band for any colour", function()
    local FibreBands = require(Shared.FibreBands)
    for _, c in ipairs({ Color3.new(0, 0, 0), Color3.new(1, 1, 1), Color3.fromRGB(120, 40, 40) }) do
        local band = FibreBands.Describe(c:ToHSV())
        assertf(typeof(band) == "string" and band ~= "", "FibreBands.Describe returned no band")
    end
end)

return { passed = passed, failed = failed, failures = failures }
