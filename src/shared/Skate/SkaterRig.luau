--!strict
-- Names of what the server adds to each skater's character (SkaterBody) and the client drives (SkateController), and
-- of the collision groups that keep avatars out of physics. Spelled only here.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local SkaterRig = {
	-- The one fixed-size ball every skater collides with, welded to the root.
	collider = "SkateCollider",
	-- On the root: the attachment both constraints use, the velocity the client sets and its facing.
	attachment = "SkateAttachment",
	velocity = "SkateVelocity",
	align = "SkateAlign",
	groups = {
		-- Avatar parts: they collide with nothing.
		body = "SkaterBody",
		-- The collider: it collides with the arena and the ball, not with other skaters.
		collider = "SkaterCollider",
	},
}

return Freeze.deep(SkaterRig)
