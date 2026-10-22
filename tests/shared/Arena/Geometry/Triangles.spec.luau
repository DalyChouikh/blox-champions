--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Triangles = require(ReplicatedStorage.Shared.Arena.Geometry.Triangles)
local Types = require(ReplicatedStorage.Shared.Arena.Geometry.Types)

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

-- The triangular face of a wedge on the side `normal` points to: right-angle corner, top corner, front corner.
local function face(piece: Types.Piece, normal: Vector3): { Vector3 }
	local half = piece.size / 2
	local side = if piece.cframe.RightVector:Dot(normal) > 0 then half.X else -half.X
	return {
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, -half.Z)),
	}
end

describe("Triangles.wedges", function()
	local a, b, c = Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(3, 0, 4)

	it("covers the triangle with two wedges that meet at the foot of its height", function()
		local wedges = Triangles.wedges(a, b, c, Vector3.yAxis, 1)
		expect(#wedges).toBe(2)
		local fronts: { Vector3 } = {}
		for _, wedge in wedges do
			local corners = face(wedge, Vector3.yAxis)
			near(corners[1], Vector3.new(3, 0, 0))
			near(corners[2], c)
			table.insert(fronts, corners[3])
		end
		table.sort(fronts, function(left: Vector3, right: Vector3): boolean
			return left.X < right.X
		end)
		near(fronts[1], a)
		near(fronts[2], b)
	end)

	it("hangs each wedge's slab behind the face, away from the normal", function()
		for _, wedge in Triangles.wedges(a, b, c, Vector3.yAxis, 1) do
			expect(wedge.shape).toBe("Wedge")
			expect(wedge.size.X).toBeCloseTo(1, 4)
			expect(wedge.cframe.Position.Y).toBeCloseTo(-0.5, 4)
		end
	end)

	it("works on a tilted plane and returns nothing for a degenerate triangle", function()
		local normal = Vector3.new(1, 1, 0).Unit
		local wedges = Triangles.wedges(Vector3.zero, Vector3.new(5, -5, 0), Vector3.new(1, -1, 6), normal, 0.5)
		expect(#wedges).toBe(2)
		for _, wedge in wedges do
			for _, corner in face(wedge, normal) do
				expect(math.abs(corner:Dot(normal))).toBeLessThan(1e-3)
			end
		end
		expect(Triangles.wedges(a, b, Vector3.new(20, 0, 0), Vector3.yAxis, 1)).toEqual({})
	end)

	-- A twisted quad's two triangles each lean away from the quad's normal; their faces must still lie on them.
	it("lays each face exactly on the triangle when the given normal only picks its side", function()
		local leaning = Vector3.new(0.2, 1, 0).Unit
		for _, wedge in Triangles.wedges(a, b, c, leaning, 1) do
			local corners = face(wedge, leaning)
			near(corners[1], Vector3.new(3, 0, 0))
			near(corners[2], c)
			expect(math.abs(corners[3].Y)).toBeLessThan(1e-3)
			expect(wedge.cframe.Position.Y).toBeCloseTo(-0.5, 4)
		end
	end)
end)
