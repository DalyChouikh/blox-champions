--!strict
-- Names of the attributes the server sets on Player and character instances; Roblox replicates them to every
-- client.

return table.freeze({
	-- "Blue" or "Orange" while the player has a seat; absent while they spectate.
	Team = "Team",
	-- On a seated player's character: whether they are pumping and braking, so every client can pose them.
	Pumping = "Pumping",
	Braking = "Braking",
	-- On a character: knocked down by a strike (no control, cannot catch), set and cleared by the server.
	KnockedDown = "KnockedDown",
	-- On a character: the action it is running (a Config.Actions name) until that action's recovery; absent otherwise.
	Action = "Action",
	-- On a character: calling for a pass, for Actions.callPassWindow or until they get the ball.
	CallingPass = "CallingPass",
})
