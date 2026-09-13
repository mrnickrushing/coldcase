--!strict
--[[
  COLD CASE · NoticeHud builder. Sits above every menu.
    Hint   (TextLabel)  onboarding ghost prompt
    Toast  (TextLabel)  short server notices
]]
local Theme = require(script.Parent.Parent.Theme)

local function label(name: string, parent: Instance, size: number): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Text = ""
    l.TextSize = size
    l.FontFace = Theme.MONO
    l.TextColor3 = Theme.INK
    l.BackgroundTransparency = 1
    l.TextTransparency = 1
    l.TextStrokeTransparency = 1
    l.Parent = parent
    return l
end

return function(parent: Instance?): ScreenGui
    parent = parent or game:GetService("StarterGui")
    local old = (parent :: Instance):FindFirstChild("NoticeHud")
    if old then
        old:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NoticeHud"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10

    local hint = label("Hint", gui, 18)
    hint.AnchorPoint = Vector2.new(0.5, 1)
    hint.Position = UDim2.new(0.5, 0, 1, -140)
    hint.Size = UDim2.new(0, 520, 0, 30)
    hint.TextColor3 = Theme.SOFT

    local toast = label("Toast", gui, 16)
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 0, 160)
    toast.Size = UDim2.new(0.9, 0, 0, 28)
    toast.TextWrapped = true

    gui.Parent = parent
    return gui
end
