--!strict
-- Any triangle as two WedgeParts. A WedgePart's cross-section is a right triangle: in object space the right angle
-- is at the back-bottom edge (y = −sy/2, z = +sz/2), the top corner at (+sy/2, +sz/2) and the front corner at
-- (−sy/2, −sz/2), extruded along X (verified in Studio). Splitting a triangle at the foot of the height on its
-- longest edge gives two right triangles, each one wedge.

local Types = require(script.Parent.Types)

type Piece = Types.Piece

-- Roblox's smallest part size per axis.
local MIN_SIZE = 0.001

local Triangles = {}

-- Two wedges whose faces exactly cover abc on the side `normal` points to, each a slab `thickness` thick behind it;
-- {} for a triangle too thin for a part.
function Triangles.wedges(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, thickness: number): { Piece }
	-- Name the longest edge AB so the foot of the height from C falls inside it.
	local A, B, C = a, b, c
	local longest = (b - a).Magnitude
	if (c - b).Magnitude > longest then
		A, B, C, longest = b, c, a, (c - b).Magnitude
	end
	if (a - c).Magnitude > longest then
		A, B, C, longest = c, a, b, (a - c).Magnitude
	end
	if longest < MIN_SIZE then
		return {}
	end

	local along = (B - A).Unit
	local foot = A + along * (C - A):Dot(along)
	local rise = C - foot
	if rise.Magnitude < MIN_SIZE then
		return {}
	end
	local up = rise.Unit
	-- `normal` only picks the side: each slab hangs behind the triangle's own plane, so its face lies on the triangle
	-- even when the triangle is half of a twisted quad.
	local plane = along:Cross(up)
	local front = if plane:Dot(normal) >= 0 then plane else -plane

	local wedges: { Piece } = {}
	for _, from in { A, B } do
		local run = foot - from
		if run.Magnitude >= MIN_SIZE then
			local back = run.Unit
			table.insert(wedges, {
				shape = "Wedge",
				cframe = CFrame.fromMatrix((C + from) / 2 - front * (thickness / 2), up:Cross(back), up, back),
				size = Vector3.new(thickness, rise.Magnitude, run.Magnitude),
			})
		end
	end
	return wedges
end

return Triangles
