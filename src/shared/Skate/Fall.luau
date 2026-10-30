--!strict
-- A skater's falls, as the server judges them (#222). A landing is hard when the skater falls Movement.hardLanding.drop
-- or more, from the top of their last rise to the height they come to rest at (hoverHeight over the ground), onto
-- ground flatter than wallAngle: landing on a wall or a bank is safe. Any rise (a jump, an Air Pose's hop, a ride up
-- the glass) carries the top up with it, and so does riding the ground, so an Air Pose breaks a fall. Heights are
-- along world up (Roblox's gravity pulls along -Y). Fed one frame at a time with the root's height and what a ray
-- along the skater's down found; a placement starts the fall over. Allocates only in `new`.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local Fall = {}
Fall.__index = Fall

type Fields = {
	_movement: Config.MovementConfig,
	-- A ground normal whose up component is at least this is flatter than wallAngle.
	_flatCos: number,
	-- The root's height last frame, nil before the first and after a placement.
	_last: number?,
	-- The top of the last rise, or where the skater last rode the ground.
	_top: number,
}

export type Fall = typeof(setmetatable({} :: Fields, Fall))

function Fall.new(movement: Config.MovementConfig): Fall
	local self: Fields = {
		_movement = movement,
		_flatCos = math.cos(math.rad(movement.wallAngle)),
		_last = nil,
		_top = 0,
	}
	return setmetatable(self, Fall)
end

-- One frame with the root at `height` over `ground`. True on the frame of a hard landing: ground within reach, after
-- falling that far from the top. Riding the ground moves the top every frame, so only a fall through the air does.
function Fall.step(self: Fall, height: number, ground: Types.Ground): boolean
	local last = self._last
	self._last = height
	if last == nil or height > last then
		self._top = height
	end
	if not ground.hit then
		return false
	end
	local top = self._top
	self._top = height
	if ground.normal.Y < self._flatCos then
		return false
	end
	local movement = self._movement
	local rest = height - (ground.distance - movement.hoverHeight)
	return top - rest >= movement.hardLanding.drop
end

-- A placement (a kickoff, a return to the spawn): the fall starts over from the next frame's height.
function Fall.reset(self: Fall)
	self._last = nil
end

return Fall
