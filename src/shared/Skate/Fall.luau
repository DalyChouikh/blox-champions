--!strict
-- A skater's falls and landings, as the server judges them (#222, #245, #258). A skater lands on the first frame that
-- finds ground in reach after a frame that found none. A landing onto ground flatter than wallAngle is hard when the
-- skater fell Movement.hardLanding.drop or more, from the top of their last rise to the height they come to rest at
-- (hoverHeight over the ground); any other is soft, onto a wall or a bank too (the slope carries them on): still a
-- fall for one who touches down posing (#245, #258). Any rise (a jump, an Air Pose's hop, a ride up the glass)
-- carries the top up with it, and so does riding the ground, so an Air Pose breaks a fall. Heights are along world up
-- (Roblox's gravity pulls along -Y). Fed one frame at a time with the root's height and what a ray along the skater's
-- down found; a placement starts the fall over. Allocates only in `new`.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

-- What one frame's look at the ground found.
export type Landing = "None" | "Soft" | "Hard"

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
	-- Whether the last frame found no ground in reach (false before the first and after a placement).
	_aloft: boolean,
}

export type Fall = typeof(setmetatable({} :: Fields, Fall))

function Fall.new(movement: Config.MovementConfig): Fall
	local self: Fields = {
		_movement = movement,
		_flatCos = math.cos(math.rad(movement.wallAngle)),
		_last = nil,
		_top = 0,
		_aloft = false,
	}
	return setmetatable(self, Fall)
end

-- One frame with the root at `height` over `ground`: "Hard" on the frame of a hard landing (ground within reach after
-- falling that far from the top: riding the ground moves the top every frame, so only a fall through the air does),
-- "Soft" on the frame of any other landing, "None" otherwise.
function Fall.step(self: Fall, height: number, ground: Types.Ground): Landing
	local last = self._last
	self._last = height
	if last == nil or height > last then
		self._top = height
	end
	local aloft = self._aloft
	self._aloft = not ground.hit
	if not ground.hit then
		return "None"
	end
	local top = self._top
	self._top = height
	local movement = self._movement
	local rest = height - (ground.distance - movement.hoverHeight)
	if ground.normal.Y >= self._flatCos and top - rest >= movement.hardLanding.drop then
		return "Hard"
	end
	return if aloft then "Soft" else "None"
end

-- A placement (a kickoff, a return to the spawn): the fall starts over from the next frame's height, and lands only
-- after a frame in the air.
function Fall.reset(self: Fall)
	self._last = nil
	self._aloft = false
end

return Fall
