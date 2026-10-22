--!strict
-- Ground normals the skater can trust (spec §7.1). Every arena part is a slab behind the riding surface, so one ray
-- exactly on a seam can hit a slab's side face and report a normal far from the surface's. A sharp turn is trusted
-- only when a second ray in a row agrees with it; smaller turns are smoothed.

local Vectors = require(script.Parent.Parent.Util.Vectors)

local NormalFilter = {}
NormalFilter.__index = NormalFilter

type Fields = {
	normal: Vector3,
	_turnCos: number,
	_smoothing: number,
	-- The last sharp turn, waiting for a second ray to agree.
	_pending: Vector3?,
}

export type NormalFilter = typeof(setmetatable({} :: Fields, NormalFilter))

function NormalFilter.new(settings: { maxTurnDeg: number, smoothing: number }, initial: Vector3): NormalFilter
	local self: Fields = {
		normal = initial.Unit,
		_turnCos = math.cos(math.rad(settings.maxTurnDeg)),
		_smoothing = settings.smoothing,
		_pending = nil,
	}
	return setmetatable(self, NormalFilter)
end

-- The filtered unit normal after this ray's (also in `normal`).
function NormalFilter.update(self: NormalFilter, raw: Vector3, dt: number): Vector3
	local normal = raw.Unit
	local filtered = self.normal
	local cos = normal:Dot(filtered)
	if cos < self._turnCos then
		local pending = self._pending
		if pending ~= nil and normal:Dot(pending) >= self._turnCos then
			self.normal = normal
			self._pending = nil
		else
			self._pending = normal
		end
	else
		self._pending = nil
		local angle = math.acos(math.clamp(cos, -1, 1))
		local turn = angle * (1 - math.exp(-self._smoothing * dt))
		-- A small turn is never between opposite normals, so the fallback axis is never used.
		self.normal = Vectors.rotateToward(filtered, normal, turn, Vector3.xAxis)
	end
	return self.normal
end

function NormalFilter.reset(self: NormalFilter, normal: Vector3)
	self.normal = normal.Unit
	self._pending = nil
end

return NormalFilter
