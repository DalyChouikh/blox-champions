--!strict
-- Vector helpers the skating, action and ball modules share.

local Vectors = {}

-- Below this length a vector has no usable direction.
Vectors.EPSILON = 1e-6

-- `vector` without its part along the unit `normal`: what lies on the surface.
function Vectors.alongSurface(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

-- `vector` shortened to at most `max` long, keeping its direction.
function Vectors.clampMagnitude(vector: Vector3, max: number): Vector3
	local length = vector.Magnitude
	if length <= max then
		return vector
	end
	return vector * (max / length)
end

-- `vector` turned `angle` radians about the unit `axis`, right-handed (Rodrigues' rotation).
function Vectors.rotateAbout(vector: Vector3, axis: Vector3, angle: number): Vector3
	local cos, sin = math.cos(angle), math.sin(angle)
	return vector * cos + axis:Cross(vector) * sin + axis * (axis:Dot(vector) * (1 - cos))
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
	return Vectors.rotateAbout(from, axis, maxAngle)
end

return table.freeze(Vectors)
