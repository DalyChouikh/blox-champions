--!strict
-- The call's badge over a name tag (NameTags, #358; the owner's Q198 H4 Badge + ripple, Q240-Q241's E2 glove): where
-- each part of the glove sits once turned, and how the call moves at a moment. Pure: the config and the time come in.

local Config = require(script.Parent.Parent.Config)

-- A glove part as Roblox draws it: its middle (x, y) and size in pixels from the glove's middle, its corners' radius,
-- and its turn in degrees, clockwise round that middle.
export type Placed = { x: number, y: number, width: number, height: number, corner: number, rotation: number }

local CallBadge = {}

-- `part` at `unit` pixels a glove unit, grown `grow` units all round (the ink pass: the same middle). The page turns a
-- part round the middle of its bottom edge, Roblox turns a frame round its own middle, so the middle moves: half the
-- part's height up from that point, turned with it.
function CallBadge.place(part: Config.GlovePart, unit: number, grow: number): Placed
	local turn = math.rad(part.turn)
	local half = part.height / 2
	return {
		x = (part.x + part.width / 2 + half * math.sin(turn)) * unit,
		y = (part.y + part.height - half * math.cos(turn)) * unit,
		width = (part.width + 2 * grow) * unit,
		height = (part.height + 2 * grow) * unit,
		corner = (part.corner + grow) * unit,
		rotation = part.turn,
	}
end

-- The glove's turn `seconds` into a call, in degrees: waveDegrees each way at waveRate radians a second.
function CallBadge.wave(call: Config.CallMotion, seconds: number): number
	return call.waveDegrees * math.sin(call.waveRate * seconds)
end

-- How far the ring has rippled out `seconds` into a call: 0 at each rippleSeconds' start, growing to 1.
function CallBadge.ripple(call: Config.CallMotion, seconds: number): number
	return (seconds % call.rippleSeconds) / call.rippleSeconds
end

return table.freeze(CallBadge)
