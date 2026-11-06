--!strict
-- A part made only to be drawn (a glow, a marker, a holder for a trail): in `shape`, which is set first so a size given
-- after it stays as given; anchored, casting no shadow, only drawing (DrawOnly), and hidden until its owner shows it.
-- Where it goes is the caller's.

local DrawOnly = require(script.Parent.DrawOnly)

local HIDDEN = 1

return function(name: string, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Shape = shape
	DrawOnly(part)
	part.Name = name
	part.Anchored = true
	part.CastShadow = false
	part.Transparency = HIDDEN
	return part
end
