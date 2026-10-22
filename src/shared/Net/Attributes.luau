--!strict
-- Names of the attributes the server sets on Player instances; Roblox replicates them to every client.

return table.freeze({
	-- "Blue" or "Orange" while the player has a seat; absent while they spectate.
	Team = "Team",
})
