--!strict
-- Names of the attributes the server sets on Player and character instances; Roblox replicates them to every
-- client.

-- What KnockedDown holds: why the character is down. A strike's ("Hit") and a fall's ("Fall": a hard landing, or
-- touching down still posing, #245) knockdowns end once the skater has asked to get up (Get Up, #220) and
-- Actions.getUpAfter has passed, else after their seconds; a diver's own touchdown ("Dive") ends when the slide
-- stops (#242).
export type Knockdown = "Hit" | "Fall" | "Dive"

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
})
