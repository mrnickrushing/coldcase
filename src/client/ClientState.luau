--!strict
-- What this client knows about itself. Controllers read and subscribe here
-- instead of each listening to the same remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = {
    role = nil :: string?,
    loaded = false,
    data = {
        coins = 0,
        xp = 0,
        rank = 1,
        inventory = {},
        equipped = { knife = "ash", gun = "ledger" },
        hintsSeen = {},
    },
    prompt = "—",
    screen = nil :: string?,
    spectating = false,
    killcam = false,
}

local listeners: { [string]: { (any) -> () } } = {}

function ClientState.On(key: string, fn: (any) -> ())
    listeners[key] = listeners[key] or {}
    table.insert(listeners[key], fn)
end

function ClientState.Set(key: string, value: any)
    if ClientState[key] == value and type(value) ~= "table" then
        return
    end
    ClientState[key] = value
    local list = listeners[key]
    if not list then
        return
    end
    for _, fn in list do
        task.spawn(fn, value)
    end
end

function ClientState.GetRoundState(): string
    return ReplicatedStorage:GetAttribute("RoundState") or "INTERMISSION"
end

-- DataChanged carries either the full profile or a partial update
Remotes.DataChanged.OnClientEvent:Connect(function(patch)
    for k, v in patch do
        ClientState.data[k] = v
    end
    ClientState.loaded = true
    ClientState.Set("data", ClientState.data)
end)

Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
    ClientState.Set("role", role)
end)

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if ClientState.GetRoundState() == "INTERMISSION" then
        ClientState.Set("role", nil)
    end
end)

return ClientState
