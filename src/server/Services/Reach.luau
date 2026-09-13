--!strict
-- One proximity check for the server-side actions that re-validate after a
-- yield. EvidenceService and AbilityService each had their own copy of this
-- with the same guards and the same constant under different names, and both
-- gate anti-cheat re-checks, so they must not drift apart.
--
-- Note what is NOT here: Config.PING_ALLOWANCE. That slack exists for the
-- reach checks a moving player disputes - knife swings, gun pickups, coins -
-- where the server's view of where they stood lags theirs. Examining a body
-- and reviving are done standing still, so they use the plain range.
local Reach = {}

function Reach.Within(plr: Player, model: Instance, range: number): boolean
    local char = plr.Character
    if not char or model.Parent == nil then
        return false
    end
    return (char:GetPivot().Position - (model :: Model):GetPivot().Position).Magnitude <= range
end

return Reach
