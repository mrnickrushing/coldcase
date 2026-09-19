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
                CombatFeel.Kick(0.15, 0.12)
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
        CombatFeel.Kick(0.26, 0.15)
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
        CombatFeel.Kick(0.19, 0.13)
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

---------------------------------------------------------------- Touch buttons
-- On-screen buttons are our own, not ContextActionService's. Its buttons take
-- fixed pixel offsets inside Roblox's touch frame, and on a large tablet the
-- jump button is bigger and sits further in, so fixed offsets land on top of
-- it. These are laid out from the real jump button's screen rectangle, in an
-- arc to its left, and laid out again whenever it or the viewport moves.
local touchGui: ScreenGui? = nil
local touchButtons: { [string]: TextButton } = {}
local touchOrder: { string } = {}
local heldInputs: { [InputObject]: () -> () } = {}
local watchedJump: GuiObject? = nil

local function isPress(input: InputObject): boolean
    return input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function touchRoot(): ScreenGui
    if touchGui then
        return touchGui
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ColdCaseTouch"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true -- so absolute screen coordinates map straight onto it
    gui.DisplayOrder = 5
    gui.Parent = plr:WaitForChild("PlayerGui")
    touchGui = gui
    return gui
end

local function jumpButton(): GuiObject?
    local pg = plr:FindFirstChild("PlayerGui")
    local touch = pg and pg:FindFirstChild("TouchGui")
    local frame = touch and touch:FindFirstChild("TouchControlFrame")
    local jump = frame and frame:FindFirstChild("JumpButton")
    return if jump and jump:IsA("GuiObject") then jump else nil
end

local layoutTouch -- defined below; the jump-button watcher calls it

local function watchJump(jump: GuiObject)
    if watchedJump == jump then
        return
    end
    watchedJump = jump
    jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        layoutTouch()
    end)
    jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        layoutTouch()
    end)
end

layoutTouch = function()
    local n = #touchOrder
    if n == 0 then
        return
    end
    local cam = workspace.CurrentCamera
    local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
    local jump = jumpButton()
    local centre: Vector2, jumpSize: number
    if jump and jump.AbsoluteSize.X > 0 then
        watchJump(jump)
        centre = jump.AbsolutePosition + jump.AbsoluteSize / 2
        jumpSize = jump.AbsoluteSize.X
    else
        -- Roblox's own sizes: 120px on a large screen, 70px on a phone
        jumpSize = if math.min(vp.X, vp.Y) > 600 then 120 else 70
        centre = Vector2.new(vp.X - 20 - jumpSize / 2, vp.Y - 20 - jumpSize / 2)
    end
    local gap = 12
    -- From due left of the jump button round to straight above it
    local step = if n > 1 then math.min(math.rad(50), math.rad(90) / (n - 1)) else 0
    local size = math.clamp(math.floor(jumpSize * 0.62), Theme.TAP_MIN, 80)
    local radius = 0
    while true do
        radius = jumpSize / 2 + size / 2 + gap
        if n > 1 then
            -- Never so tight that neighbours on the arc touch
            radius = math.max(radius, (size + gap) / (2 * math.sin(step / 2)))
        end
        -- The leftmost button stays inside the reach the social dock budgets for
        local reach = vp.X - (centre.X - radius - size / 2)
        if reach <= Theme.TOUCH_REACH or size <= Theme.TAP_MIN then
            break
        end
        size -= 2
    end
    for i, name in touchOrder do
        local button = touchButtons[name]
        if button then
            local angle = math.pi - (i - 1) * step
            local at = centre + Vector2.new(math.cos(angle), -math.sin(angle)) * radius
            button.Size = UDim2.fromOffset(size, size)
            button.Position = UDim2.fromOffset(math.round(at.X), math.round(at.Y))
            button.TextSize = math.floor(size * 0.22)
        end
    end
end

local function touchButton(name: string, title: string, onBegin, onEnd): TextButton
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = title
    b.FontFace = Theme.DISPLAY
    b.TextColor3 = Theme.INK
    b.BackgroundColor3 = Theme.GROUND
    b.BackgroundTransparency = 0.25
    b.AutoButtonColor = false
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = b
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.INK
    stroke.Transparency = 0.55
    stroke.Thickness = 2
    stroke.Parent = b
    b.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        b.BackgroundTransparency = 0.05
        if onEnd then
            heldInputs[input] = function()
                b.BackgroundTransparency = 0.25
                onEnd()
            end
        else
            task.delay(0.12, function()
                b.BackgroundTransparency = 0.25
            end)
        end
        onBegin()
    end)
    return b
end

-- A held button (DRAG) releases wherever the finger lifts, on the button or off it
UserInputService.InputEnded:Connect(function(input)
    local release = heldInputs[input]
    if release then
        heldInputs[input] = nil
        release()
    end
end)

local function setTouchTitle(name: string, title: string)
    local button = touchButtons[name]
    if button then
        button.Text = title
    end
end

---------------------------------------------------------------- Bindings
-- Keyboard and gamepad always; on-screen buttons only for the actions the
-- current role can take, sized to the 44px tap minimum.
local function bind(name: string, onBegin, onEnd, title: string, ...: Enum.KeyCode)
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
    end, false, ...)
    if UserInputService.TouchEnabled then
        local button = touchButton(name, title, onBegin, onEnd)
        button.Parent = touchRoot()
        touchButtons[name] = button
        table.insert(touchOrder, name)
    end
end

local ACTIONS = { "CC_Interact", "CC_Fire", "CC_Throw", "CC_Drag", "CC_Revive" }

local function refreshBindings()
    local role = ClientState.role
    for _, name in ACTIONS do
        ContextActionService:UnbindAction(name)
    end
    for _, button in touchButtons do
        button:Destroy()
    end
    touchButtons, touchOrder = {}, {}
    for input, release in heldInputs do
        heldInputs[input] = nil
        release()
    end
    if not role then
        return
    end
    bind("CC_Interact", interact, nil, "USE", Enum.KeyCode.E, Enum.KeyCode.ButtonX)
    bind("CC_Drag", dragStart, dragStop, "DRAG", Enum.KeyCode.F, Enum.KeyCode.ButtonB)
    if role == "sheriff" or role == "hero" then
        bind("CC_Fire", fire, nil, "FIRE", Enum.KeyCode.ButtonR2)
    elseif role == "murderer" then
        bind("CC_Throw", throw, nil, "THROW", Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
    elseif role == "medic" then
        bind("CC_Revive", revive, nil, "REVIVE", Enum.KeyCode.R, Enum.KeyCode.ButtonY)
    end
    layoutTouch()
end
ClientState.On("role", refreshBindings)

local camera = workspace.CurrentCamera
if camera then
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouch)
end
-- Roblox builds its touch frame after the character spawns, so lay out again
-- once the jump button exists
plr:WaitForChild("PlayerGui").DescendantAdded:Connect(function(d)
    if d.Name == "JumpButton" then
        task.defer(layoutTouch)
    end
end)

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
            setTouchTitle("CC_Interact", title)
        end
    end
end)

-- The server draws weapons when they are used. The hotbar would let a player
-- hold one out, and a knife in hand names the murderer.
pcall(function()
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

return InputController
