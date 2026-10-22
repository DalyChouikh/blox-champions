--!strict
-- Names of the attributes the server sets on Player and character instances; Roblox replicates them to every
-- client.

return table.freeze({
	-- "Blue" or "Orange" while the player has a seat; absent while they spectate.
	Team = "Team",
	-- On a seated player's character: whether they are pumping and braking, so every client can pose them.
	Pumping = "Pumping",
	Braking = "Braking",
})
