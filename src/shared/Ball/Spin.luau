--!strict
-- How the ball's look is turned (spec §9.4, #401, the owner's Q276: the band turns as the ball rolls and spins). The
-- turn is a unit quaternion kept in a table of four numbers that is changed in place, and read out as Roblox's
-- Orientation (a Vector3), so turning the look each frame allocates nothing (a CFrame is a new object each time).

export type Quat = { w: number, x: number, y: number, z: number }

local Spin = {}

function Spin.new(): Quat
	return { w = 1, x = 0, y = 0, z = 0 }
end

-- Turns `q` in the world's frame by `spin` (radians a second about its direction), at most `limit` radians a second,
-- over `dt` seconds.
function Spin.turn(q: Quat, spin: Vector3, dt: number, limit: number)
	local rate = spin.Magnitude
	local angle = math.min(rate, limit) * dt
	if angle == 0 then
		return
	end
	local s = math.sin(angle / 2) / rate
	local dw, dx, dy, dz = math.cos(angle / 2), spin.X * s, spin.Y * s, spin.Z * s
	local w, x, y, z = q.w, q.x, q.y, q.z
	-- d * q, then back to unit length so many small turns never drift.
	local nw = dw * w - dx * x - dy * y - dz * z
	local nx = dw * x + dx * w + dy * z - dz * y
	local ny = dw * y - dx * z + dy * w + dz * x
	local nz = dw * z + dx * y - dy * x + dz * w
	local length = math.sqrt(nw * nw + nx * nx + ny * ny + nz * nz)
	q.w, q.x, q.y, q.z = nw / length, nx / length, ny / length, nz / length
end

-- Sets `q` to Roblox's Orientation `degrees`: about Y, then X, then Z (CFrame.fromOrientation's order).
function Spin.setOrientation(q: Quat, degrees: Vector3)
	local hx, hy, hz = math.rad(degrees.X) / 2, math.rad(degrees.Y) / 2, math.rad(degrees.Z) / 2
	local cx, sx, cy, sy, cz, sz = math.cos(hx), math.sin(hx), math.cos(hy), math.sin(hy), math.cos(hz), math.sin(hz)
	-- (about Y) * (about X) * (about Z)
	q.w = cy * cx * cz + sy * sx * sz
	q.x = cy * sx * cz + sy * cx * sz
	q.y = sy * cx * cz - cy * sx * sz
	q.z = cy * cx * sz - sy * sx * cz
end

-- `q` as Roblox's Orientation, in degrees.
function Spin.orientation(q: Quat): Vector3
	local w, x, y, z = q.w, q.x, q.y, q.z
	-- The rotation's matrix entries that Y-X-Z angles are read from.
	local m12 = 2 * (y * z - w * x)
	local m02 = 2 * (x * z + w * y)
	local m22 = 1 - 2 * (x * x + y * y)
	local m10 = 2 * (x * y + w * z)
	local m11 = 1 - 2 * (x * x + z * z)
	local ax = math.asin(math.clamp(-m12, -1, 1))
	if math.abs(m12) < 1 - 1e-9 then
		return Vector3.new(math.deg(ax), math.deg(math.atan2(m02, m22)), math.deg(math.atan2(m10, m11)))
	end
	-- Straight up or down about X: Y and Z turn about the same line, so Z is taken as none.
	local m00 = 1 - 2 * (y * y + z * z)
	local m20 = 2 * (x * z - w * y)
	return Vector3.new(math.deg(ax), math.deg(math.atan2(-m20, m00)), 0)
end

return table.freeze(Spin)
