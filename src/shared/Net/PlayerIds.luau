--!strict
-- The one way a Roblox player becomes a PlayerId and back: the decimal UserId, which a returning player keeps. Rule
-- events, remotes and every server service name players this way.

local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Rules.Types)

local PlayerIds = {}

function PlayerIds.of(player: Player): Types.PlayerId
	return tostring(player.UserId)
end

-- The player in this server with that id, or nil.
function PlayerIds.player(id: Types.PlayerId): Player?
	local userId = tonumber(id)
	return if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
end

return table.freeze(PlayerIds)
