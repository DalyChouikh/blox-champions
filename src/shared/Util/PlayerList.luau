--!strict
-- The players in the game as one list, kept current by the join and leave events. Players:GetPlayers() builds a new
-- table on every call; a walk over this list each frame allocates nothing.

type Connection = { Disconnect: (self: any) -> () }
type PlayerSignal = { Connect: (self: any, handler: (player: Player) -> ()) -> Connection }

-- What the list reads from the Players service, so tests can pass a fake.
export type PlayersService = {
	GetPlayers: (self: any) -> { Player },
	PlayerAdded: PlayerSignal,
	PlayerRemoving: PlayerSignal,
}

type Fields = {
	-- The players, in join order. Always this table: callers may hold it.
	list: { Player },
	_connections: { Connection },
}

local PlayerList = {}
PlayerList.__index = PlayerList

export type PlayerList = typeof(setmetatable({} :: Fields, PlayerList))

function PlayerList.new(players: PlayersService): PlayerList
	local list = players:GetPlayers()
	local self: Fields = {
		list = list,
		_connections = {
			-- Roblox defers events, so a join can arrive after GetPlayers already listed the player.
			players.PlayerAdded:Connect(function(player: Player)
				if table.find(list, player) == nil then
					table.insert(list, player)
				end
			end),
			players.PlayerRemoving:Connect(function(player: Player)
				local index = table.find(list, player)
				if index ~= nil then
					table.remove(list, index)
				end
			end),
		},
	}
	return setmetatable(self, PlayerList)
end

-- Stops following the game; the list keeps the players it had.
function PlayerList.destroy(self: PlayerList)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return PlayerList
