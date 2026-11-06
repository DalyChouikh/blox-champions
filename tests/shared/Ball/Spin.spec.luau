--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Spin = require(ReplicatedStorage.Shared.Ball.Spin)

-- No limit on the turn's rate: the tests of the turn itself.
local UNLIMITED = math.huge

-- The quaternion as Roblox's own rotation, for comparing with Roblox's maths.
local function rotation(q: Spin.Quat): CFrame
	return CFrame.new(0, 0, 0, q.x, q.y, q.z, q.w)
end

local function expectSame(actual: CFrame, expected: CFrame)
	for _, axis in { "XVector", "YVector", "ZVector" } do
		local a: Vector3 = (actual :: any)[axis]
		local b: Vector3 = (expected :: any)[axis]
		expect((a - b).Magnitude).toBeLessThan(1e-5)
	end
end

-- Roblox's Orientation: degrees about X, Y and Z, applied Y, then X, then Z.
local function fromOrientation(degrees: Vector3): CFrame
	return CFrame.fromOrientation(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

local ORIENTATIONS = {
	Vector3.new(0, 0, 0),
	Vector3.new(30, 0, 0),
	Vector3.new(0, -120, 0),
	Vector3.new(0, 0, 75),
	Vector3.new(-40, 150, -20),
	Vector3.new(89, 10, 33),
	Vector3.new(-89.9, -170, 179),
	-- Straight up and down about X: Y and Z then turn about the same line.
	Vector3.new(90, 40, 25),
	Vector3.new(-90, -60, 10),
}

-- #401 (the owner's Q276): the ball's look turns as the ball spins, kept as a quaternion in four numbers so a frame's
-- turn allocates nothing.
describe("Spin", function()
	it("starts with no turn", function()
		local q = Spin.new()
		expectSame(rotation(q), CFrame.identity)
		expect(Spin.orientation(q)).toEqual(Vector3.zero)
	end)

	it("reads and writes Roblox's Orientation, as CFrame.fromOrientation does", function()
		local q = Spin.new()
		for _, degrees in ORIENTATIONS do
			Spin.setOrientation(q, degrees)
			expectSame(rotation(q), fromOrientation(degrees))
			expectSame(fromOrientation(Spin.orientation(q)), fromOrientation(degrees))
		end
	end)

	it("turns about the spin's axis by its rate times the time, in the world's frame", function()
		local q = Spin.new()
		local start = Vector3.new(-40, 150, -20)
		Spin.setOrientation(q, start)
		Spin.turn(q, Vector3.new(0, math.pi, 0), 0.5, UNLIMITED)
		expectSame(rotation(q), CFrame.fromAxisAngle(Vector3.yAxis, math.pi / 2) * fromOrientation(start))
		local spin = Vector3.new(3, -1, 2)
		local before = rotation(q)
		Spin.turn(q, spin, 0.1, UNLIMITED)
		expectSame(rotation(q), CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * 0.1) * before)
	end)

	-- The owner's Q283/Q287: a fast ball's band turned too fast to follow; it turns at most 2.5 turns a second.
	it("turns no faster than its limit, about the spin's own axis, and in full under it", function()
		local q = Spin.new()
		local start = Vector3.new(10, -60, 35)
		Spin.setOrientation(q, start)
		local fast = Vector3.new(-12, 30, 20)
		Spin.turn(q, fast, 0.1, 15)
		expectSame(rotation(q), CFrame.fromAxisAngle(fast.Unit, 15 * 0.1) * fromOrientation(start))
		local slow = Vector3.new(0, 0, 14)
		local before = rotation(q)
		Spin.turn(q, slow, 0.1, 15)
		expectSame(rotation(q), CFrame.fromAxisAngle(Vector3.zAxis, 14 * 0.1) * before)
	end)

	it("leaves the turn as it is with no spin or no time", function()
		local q = Spin.new()
		Spin.setOrientation(q, Vector3.new(10, 20, 30))
		local w, x, y, z = q.w, q.x, q.y, q.z
		Spin.turn(q, Vector3.zero, 1 / 60, 15)
		Spin.turn(q, Vector3.new(5, 0, 0), 0, 15)
		expect({ q.w, q.x, q.y, q.z }).toEqual({ w, x, y, z })
	end)

	it("stays a pure turn over many frames", function()
		local q = Spin.new()
		for _ = 1, 100000 do
			Spin.turn(q, Vector3.new(7, -3, 11), 1 / 60, UNLIMITED)
		end
		expect(math.abs(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z - 1)).toBeLessThan(1e-9)
	end)
end)
