--!strict
-- Leaves `part` only drawing: nothing collides with it, touches it or finds it by a ray (a look, a glow, a marker, a
-- tag-only part). The rest of it, anchoring, shadow and transparency, is the caller's.

return function(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end
