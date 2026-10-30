--!strict
-- Names of the attributes the server sets on Player and character instances; Roblox replicates them to every
-- client.

local SkateTypes = require(script.Parent.Parent.Skate.Types)

-- What KnockedDown holds: why the character is down (the skating's own Knockdown).
export type Knockdown = SkateTypes.Knockdown

return table.freeze({
	-- "Blue" or "Orange" while the player has a seat; absent while they spectate.
	Team = "Team",
	-- On a seated player's character: whether they are pumping, braking and striking the Air Pose, so every client can
	-- pose them.
	Pumping = "Pumping",
	Braking = "Braking",
	AirPosing = "AirPosing",
	-- On a character: knocked down (no control, cannot catch), set to its Knockdown and cleared by the server.
	KnockedDown = "KnockedDown",
	-- On a character: the action it is running (a Config.Actions name) until that action's recovery; absent otherwise.
	Action = "Action",
	-- On a character: calling for a pass, for Actions.callPassWindow or until they get the ball.
	CallingPass = "CallingPass",
	-- On a character: how many times the server has placed it (on its spawn at each kickoff, or back inside the
	-- arena); each new count tells its client to start the skater over from rest there.
	Placed = "Placed",
})
