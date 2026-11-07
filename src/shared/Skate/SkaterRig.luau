--!strict
-- Names of what the server adds to each skater's character (SkaterBody) and the client drives (SkateController), of
-- the avatar parts and scripts Roblox gives every character, and of the collision groups that keep avatars out of
-- physics. Spelled only here.

local Freeze = require(script.Parent.Parent.Util.Freeze)
local Pose = require(script.Parent.Pose)

local LEFT_LEG = "Left Leg"

local SkaterRig = {
	-- What Roblox names in every character: the root part, the humanoid, the R6 left leg (which sets an R6 avatar's
	-- standing height) and the default animation script.
	root = "HumanoidRootPart",
	humanoid = "Humanoid",
	leftLeg = LEFT_LEG,
	animate = "Animate",
	-- The one fixed-size ball every skater collides with, welded to the root.
	collider = "SkateCollider",
	-- On the root: the attachment both constraints use, the velocity the client sets and its facing.
	attachment = "SkateAttachment",
	velocity = "SkateVelocity",
	align = "SkateAlign",
	-- The avatar's joints by pose role, for each rig type. The R6 rig has no waist or knees.
	joints = {
		R15 = {
			root = "Root",
			waist = "Waist",
			leftHip = "LeftHip",
			rightHip = "RightHip",
			leftKnee = "LeftKnee",
			rightKnee = "RightKnee",
			rightShoulder = "RightShoulder",
		},
		R6 = {
			root = "RootJoint",
			leftHip = "Left Hip",
			rightHip = "Right Hip",
			rightShoulder = "Right Shoulder",
		},
	} :: { R15: { [Pose.Role]: string }, R6: { [Pose.Role]: string } },
	-- The parts each skate's fire trails from (SkateFire), for each rig type: an R15 avatar's feet, an R6 one's legs.
	feet = { R15 = { "LeftFoot", "RightFoot" }, R6 = { LEFT_LEG, "Right Leg" } },
	groups = {
		-- Avatar parts: they collide with nothing.
		body = "SkaterBody",
		-- The collider: it collides with the arena and the ball, not with other skaters.
		collider = "SkaterCollider",
		-- Roblox's group for every part not given one: the arena and the ball.
		arena = "Default",
	},
}

return Freeze.deep(SkaterRig)
