--!strict
-- Ground normals the skater can trust (spec §7.1). Every arena part is a slab behind the riding surface, so one ray
-- exactly on a seam can hit a slab's side face and report a normal far from the surface's. A turn sharper than a
-- corner (Movement.cornerDeg) is trusted only when a second ray in a row agrees with it; smaller turns pass through as
-- they are, since the skating must follow the surface itself (#255: smoothing them lagged the skating behind curved
-- walls and added energy on every wall visit).

local NormalFilter = {}
NormalFilter.__index = NormalFilter

type Fields = {
	normal: Vector3,
	_cornerCos: number,
	-- The last sharp turn, waiting for a second ray to agree.
	_pending: Vector3?,
}

export type NormalFilter = typeof(setmetatable({} :: Fields, NormalFilter))

function NormalFilter.new(cornerDeg: number, initial: Vector3): NormalFilter
	local self: Fields = {
		normal = initial.Unit,
		_cornerCos = math.cos(math.rad(cornerDeg)),
		_pending = nil,
	}
	return setmetatable(self, NormalFilter)
end

-- The trusted unit normal after this ray's (also in `normal`).
function NormalFilter.update(self: NormalFilter, raw: Vector3): Vector3
	local normal = raw.Unit
	local cornerCos = self._cornerCos
	local pending = self._pending
	if normal:Dot(self.normal) >= cornerCos or (pending ~= nil and normal:Dot(pending) >= cornerCos) then
		self.normal = normal
		self._pending = nil
	else
		self._pending = normal
	end
	return self.normal
end

function NormalFilter.reset(self: NormalFilter, normal: Vector3)
	self.normal = normal.Unit
	self._pending = nil
end

return NormalFilter
