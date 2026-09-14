-- StarterPlayerScripts/Controllers/InputController
-- The client only asks; the server decides. Client cooldowns here are
-- cosmetic — they exist so honest players never brush the remote rate limit.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local CombatFeel = require(script.Parent.CombatFeelController)

local plr = Players.LocalPlayer
local InputController = {}
local lastUse: { [string]: number } = {}
local ability: { text: string, untilTime: number }? = nil

local function isTouch(): boolean
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function cooled(action: string, cooldown: number): boolean
    local t = os.clock()
    if t - (lastUse[action] or 0) < cooldown then
        return false
    end
    lastUse[action] = t
    return true
end

local function myPosition(): Vector3?
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return nil
    end
    return (char :: Model):GetPivot().Position
end

local function inRound(): boolean
    return ClientState.GetRoundState() == "ACTIVE" and ClientState.role ~= nil
end

-- A Player, or an NPC's character model (the server resolves either)
local function nearestTarget(origin: Vector3): Instance?
    local best, bestDist = nil, Config.KNIFE_RANGE
    local function consider(target: Instance, char: Model?)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local d = ((char :: Model):GetPivot().Position - origin).Magnitude
            if d < bestDist then
                best, bestDist = target, d
            end
        end
    end
    for _, other in Players:GetPlayers() do
        if other ~= plr then
            consider(other, other.Character)
        end
    end
    for _, model in CollectionService:GetTagged("BotCharacter") do
        if model:IsA("Model") then
            consider(model, model)
        end
    end
    return best
end

local function nearestTagged(tag: string, origin: Vector3, range: number): Instance?
    local best, bestDist = nil, range
    for _, inst in CollectionService:GetTagged(tag) do
        if inst:IsDescendantOf(workspace) then
            local pos = if inst:IsA("Model")
                then inst:GetPivot().Position
                else (inst :: BasePart).Position
            local d = (pos - origin).Magnitude
            if d < bestDist then
                best, bestDist = inst, d
            end
        end
    end
    return best
end

local function aimAt(screenX: number, screenY: number): Vector3
    local cam = workspace.CurrentCamera
    local ray = cam:ViewportPointToRay(screenX, screenY)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { plr.Character :: Model }
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    return hit and hit.Position or (ray.Origin + ray.Direction * 1000)
end

local function aimPoint(): Vector3
    if isTouch() then
        local vp = workspace.CurrentCamera.ViewportSize
        return aimAt(vp.X / 2, vp.Y / 2)
    end
    local m = UserInputService:GetMouseLocation()
    return aimAt(m.X, m.Y)
end

---------------------------------------------------------------- Actions
local function interact()
    local pos = myPosition()
    if not (pos and inRound()) then
        return
    end
    local role = ClientState.role
    if role == "murderer" then
        local target = nearestTarget(pos)
        if target then
            if cooled("knife", Config.KNIFE_COOLDOWN) then
                Remotes.RequestStab:FireServer(target)
                CombatFeel.Kick(0.22, 0.12)
            end
            return
        end
    end
    local body = nearestTagged("Body", pos, Config.EXAMINE_RANGE)
    if body then
        if cooled("examine", Config.EXAMINE_TIME) then
            Remotes.RequestExamine:FireServer(body)
        end
        return
    end
    if role == "innocent" and nearestTagged("DroppedPistol", pos, Config.GUN_PICKUP_RANGE) then
        if cooled("pickup", 0.5) then
            Remotes.RequestPickup:FireServer()
        end
    end
end

local function fire()
    local role = ClientState.role
    if
        (role == "sheriff" or role == "hero")
        and inRound()
        and myPosition()
        and cooled("gun", Config.GUN_COOLDOWN)
    then
        Remotes.RequestShoot:FireServer(aimPoint())
        CombatFeel.Kick(0.4, 0.16)
    end
end

local function throw()
    if
        ClientState.role == "murderer"
        and inRound()
        and myPosition()
        and cooled("throw", Config.THROW_COOLDOWN)
    then
        Remotes.RequestThrow:FireServer(aimPoint())
        CombatFeel.Kick(0.28, 0.13)
    end
end

local function revive()
    local pos = myPosition()
    if ClientState.role ~= "medic" or not (pos and inRound()) then
        return
    end
    local body = nearestTagged("Body", pos, Config.EXAMINE_RANGE)
    if body and cooled("revive", 1) then
        Remotes.RequestRevive:FireServer(body)
    end
end

local function dragStart()
    local pos = myPosition()
    if not (pos and inRound()) then
        return
    end
    local body = nearestTagged("Body", pos, Config.EXAMINE_RANGE)
    if body and cooled("drag", 0.3) then
        Remotes.RequestDrag:FireServer(body, false)
    end
end

local function dragStop()
    Remotes.RequestDrag:FireServer(nil, true)
end

---------------------------------------------------------------- Bindings
-- Keyboard and gamepad always; on-screen buttons only for the actions the
-- current role can take, sized to the 44px tap minimum.
local function bind(name: string, onBegin, onEnd, title: string, position: UDim2, ...: Enum.KeyCode)
    ContextActionService:BindAction(name, function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            onBegin()
        elseif
            onEnd
            and (inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel)
        then
            onEnd()
        end
        return Enum.ContextActionResult.Sink
    end, true, ...)
    ContextActionService:SetTitle(name, title)
    ContextActionService:SetPosition(name, position)
    local button = ContextActionService:GetButton(name)
    if button then
        local size = math.max(Theme.TAP_MIN, 64)
        button.Size = UDim2.fromOffset(size, size)
    end
end

local ACTIONS = { "CC_Interact", "CC_Fire", "CC_Throw", "CC_Drag", "CC_Revive" }

local function refreshBindings()
    local role = ClientState.role
    for _, name in ACTIONS do
        ContextActionService:UnbindAction(name)
    end
    if not role then
        return
    end
    bind(
        "CC_Interact",
        interact,
        nil,
        "USE",
        UDim2.new(1, -170, 1, -190),
        Enum.KeyCode.E,
        Enum.KeyCode.ButtonX
    )
    bind(
        "CC_Drag",
        dragStart,
        dragStop,
        "DRAG",
        UDim2.new(1, -250, 1, -120),
        Enum.KeyCode.F,
        Enum.KeyCode.ButtonB
    )
    if role == "sheriff" or role == "hero" then
        bind("CC_Fire", fire, nil, "FIRE", UDim2.new(1, -95, 1, -250), Enum.KeyCode.ButtonR2)
    elseif role == "murderer" then
        bind(
            "CC_Throw",
            throw,
            nil,
            "THROW",
            UDim2.new(1, -95, 1, -250),
            Enum.KeyCode.Q,
            Enum.KeyCode.ButtonY
        )
    elseif role == "medic" then
        bind(
            "CC_Revive",
            revive,
            nil,
            "REVIVE",
            UDim2.new(1, -95, 1, -250),
            Enum.KeyCode.R,
            Enum.KeyCode.ButtonY
        )
    end
end
ClientState.On("role", refreshBindings)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
        fire()
    end
end)

---------------------------------------------------------------- Ability feedback
Remotes.AbilityState.OnClientEvent:Connect(function(kind: string, duration: number)
    local now = os.clock()
    if kind == "revive_start" then
        ability = { text = "Reviving… hold still", untilTime = now + duration }
    elseif kind == "revive_failed" then
        ability = { text = "Revive broken — you moved", untilTime = now + 1.5 }
    elseif kind == "revive_done" then
        ability = { text = "Revived", untilTime = now + 1.5 }
    elseif kind == "drag_start" then
        ability = { text = "Taking hold…", untilTime = now + duration }
    elseif kind == "dragging" then
        ability = {
            text = (isTouch() and "Release DRAG" or "Release F") .. " · dragging",
            untilTime = math.huge,
        }
    elseif kind == "drag_stop" then
        ability = nil
    end
end)

---------------------------------------------------------------- Context prompt
-- The touch USE button relabels to what it will do, like the E prompt does
local shownTitle: string, shownFor: string? = "USE", nil

task.spawn(function()
    while true do
        task.wait(0.1)
        local text, title = "—", "USE"
        local pos = myPosition()
        local role = ClientState.role
        if ability and os.clock() > ability.untilTime then
            ability = nil
        end
        if not inRound() then
            ability = nil
        end

        if pos and role and inRound() then
            local touch = isTouch()
            local use = touch and "USE" or "E"
            local body = nearestTagged("Body", pos, Config.EXAMINE_RANGE)
            if role == "murderer" and nearestTarget(pos) then
                text, title = use .. " · stab", "STAB"
            elseif body and role == "medic" then
                text = ("%s · revive   %s · examine"):format(touch and "REVIVE" or "R", use)
                title = "EXAMINE"
            elseif body then
                text = ("%s · examine   %s · drag"):format(use, touch and "DRAG" or "F")
                title = "EXAMINE"
            elseif
                role == "innocent" and nearestTagged("DroppedPistol", pos, Config.GUN_PICKUP_RANGE)
            then
                text, title = use .. " · take pistol", "TAKE"
            elseif role == "sheriff" or role == "hero" then
                text = (touch and "FIRE" or "Click") .. " · shoot"
            elseif role == "murderer" then
                text = (touch and "THROW" or "Q") .. " · throw knife"
            end
        end
        if ability then
            text = ability.text
        end
        ClientState.Set("prompt", text)

        -- A role change rebinds the button, which resets it to USE
        if role ~= shownFor then
            shownFor, shownTitle = role, "USE"
        end
        if role and title ~= shownTitle then
            shownTitle = title
            ContextActionService:SetTitle("CC_Interact", title)
        end
    end
end)

-- The server draws weapons when they are used. The hotbar would let a player
-- hold one out, and a knife in hand names the murderer.
pcall(function()
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

return InputController
