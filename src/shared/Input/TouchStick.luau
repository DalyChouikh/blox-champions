--!strict
-- The touch stick's math, as Roblox's own dynamic thumbstick does it: a touch's offset from where it began, in
-- pixels, read as a stick. Nothing within `deadZone` of the start; then the offset's direction, its length growing
-- to full tilt at `radius`. Screen y grows downward, so it is turned over: up the screen is forward.

local TouchStick = {}

function TouchStick.vector(origin: Vector2, position: Vector2, deadZone: number, radius: number): Vector2
	local offset = position - origin
	local length = offset.Magnitude
	if length < deadZone or length == 0 then
		return Vector2.zero
	end
	local tilt = math.min(1, length / radius) / length
	return Vector2.new(offset.X * tilt, -offset.Y * tilt)
end

return TouchStick
