-- StarterPlayerScripts/ClientBootstrap (LocalScript)
local Controllers = script.Parent:WaitForChild("Controllers")
for _, module in Controllers:GetChildren() do
    if module:IsA("ModuleScript") then
        task.spawn(function()
            local ok, err = pcall(require, module)
            if not ok then
                warn("[ColdCase] " .. module.Name .. ": " .. tostring(err))
            end
        end)
    end
end
