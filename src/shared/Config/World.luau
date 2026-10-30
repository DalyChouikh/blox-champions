--!strict
-- The world everything moves in: the pull down that skating, poses, the ball and the rules read, and that Bootstrap
-- gives Roblox's own physics (workspace.Gravity).

local Validate = require(script.Parent.Validate)

export type WorldConfig = {
	-- The pull down, in studs/s², of the air, every surface and the ball. Two thirds of Roblox's default 196.2 (the
	-- owner, #279, Q44-Q46): timed by frames and read in body heights, never by a speedometer, Roller Champions' climb
	-- up an upright wall (as fast up as down), its jumps and its Uppercut all fit ~2/3 of ours (our skater stands 5.85
	-- studs: 196.2 is 33.5 body heights/s²); the owner played it (trial 7) and kept it. The jump, the Air Pose and the
	-- Uppercut push √(2/3) as hard, so they rise as high as before and hang longer.
	gravity: number,
}

local defaults: WorldConfig = {
	gravity = 130.8,
}

local schema = Validate.record({
	gravity = Validate.number({ above = 0 }),
})

return {
	defaults = defaults,
	schema = schema,
}
