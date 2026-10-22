--!strict
-- Vector helpers the skating modules share.

local Vectors = {}

-- Below this length a vector has no usable direction.
Vectors.EPSILON = 1e-6

-- `vector` without its part along the unit `normal`: what lies on the surface.
function Vectors.alongSurface(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

-- `from` turned toward `to` (both unit vectors) by at most `maxAngle` radians, about `fallbackAxis` when they are
-- exactly opposite.
function Vectors.rotateToward(from: Vector3, to: Vector3, maxAngle: number, fallbackAxis: Vector3): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= maxAngle then
		return to
	end
	local axis = from:Cross(to)
	axis = if axis.Magnitude > Vectors.EPSILON then axis.Unit else fallbackAxis
	local cos, sin = math.cos(maxAngle), math.sin(maxAngle)
	return from * cos + axis:Cross(from) * sin + axis * (axis:Dot(from) * (1 - cos))
end

return table.freeze(Vectors)
