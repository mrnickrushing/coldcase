--!strict
-- StarterPlayerScripts/Controllers/ChatTagController
-- A gold [VIP] tag and gold name in chat for anyone who owns the VIP pass.
-- VIP is a public player attribute the server sets (MonetizationService); this
-- is cosmetic only and reads it the same way any client can.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local VIP_GOLD = "f2c14e"

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
    local source = message.TextSource
    if not source then
        return nil -- system lines have no sender
    end
    local sender = Players:GetPlayerByUserId(source.UserId)
    if not (sender and sender:GetAttribute("Vip")) then
        return nil
    end
    local props = Instance.new("TextChatMessageProperties")
    -- Prepend the tag and wrap the existing name prefix so both read gold
    props.PrefixText = ('<font color="#%s">[VIP] %s</font>'):format(VIP_GOLD, message.PrefixText)
    return props
end

return {}
