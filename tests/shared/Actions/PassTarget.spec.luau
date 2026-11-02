--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PassTarget = require(ReplicatedStorage.Shared.Actions.PassTarget)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)

local pass = Config.defaults().Actions.Pass.pass :: Config.PassSettings
-- The passer stands off the origin, and the aim need not be unit: the crosshair's line along -Z.
local PASSER = Vector3.new(10, 3, 10)
local AIM = Vector3.new(0, 0, -5)

-- The arena (#315 Q155) as these tests stand it in: it hides every teammate standing at a spot in `hidden`, and
-- `asked` keeps the end of every line `choose` asked about. The server and the client cast along their ride surfaces.
local hidden: { Vector3 } = {}
local asked: { Vector3 } = {}

beforeEach(function()
	table.clear(hidden)
	table.clear(asked)
end)

local function inTheOpen(from: Vector3, offset: Vector3): boolean
	assert(from == PASSER, "a line starts at the passer")
	local to = from + offset
	table.insert(asked, to)
	for _, spot in hidden do
		if (to - spot).Magnitude < 1e-3 then
			return false
		end
	end
	return true
end

-- A teammate `offset` from the passer.
local function mate(player: string, offset: Vector3): Reach.Candidate
	return { player = player, position = PASSER + offset }
end

-- `degrees` off the aim's line, `distance` from the passer, across the ground.
local function off(degrees: number, distance: number): Vector3
	return Vector3.new(math.sin(math.rad(degrees)), 0, -math.cos(math.rad(degrees))) * distance
end

local function choose(teammates: { Reach.Candidate }, calls: { [string]: number }?): string?
	return PassTarget.choose(pass, PASSER, AIM, teammates, calls or {}, inTheOpen)
end

-- Magnetic Pass, RC's way (#315, the owner: Q103, Q105): a teammate in the aim's direction, a caller first.
describe("PassTarget.choose", function()
	it("goes to the teammate nearest the aim's line within the cone and the range", function()
		-- Far: 11.3 deg off the aim, 102 studs away. Near: 18.4 deg off, 15.8 studs away. The old score (0.6 of the
		-- angle, 0.4 of the distance) picked the near one (0.789 against 0.563).
		local far = mate("Far", Vector3.new(20, 0, -100))
		local near = mate("Near", Vector3.new(5, 0, -15))
		expect(choose({ near, far })).toBe("Far")
		expect(choose({ near })).toBe("Near")
	end)

	it("finds nobody outside the cone or past the range", function()
		local wide = mate("Wide", off(pass.coneDeg + 1, 100))
		local far = mate("Far", off(0, pass.maxRange + 0.01))
		expect(choose({ wide, far })).toBeNil()
		expect(choose({ wide, mate("In", off(pass.coneDeg - 1, 100)) })).toBe("In")
		expect(choose({ far, mate("Edge", off(0, pass.maxRange - 0.01)) })).toBe("Edge")
		expect(choose({})).toBeNil()
	end)

	it("goes to a caller in the cone first, the latest caller of two", function()
		local teammates = { mate("OnLine", off(0, 50)), mate("Right", off(45, 40)), mate("Left", off(-45, 40)) }
		expect(choose(teammates, { Right = 1 })).toBe("Right")
		expect(choose(teammates, { Right = 1, Left = 2 })).toBe("Left")
		expect(choose(teammates, { Right = 2, Left = 1 })).toBe("Right")
	end)

	-- The pass needs the aim toward a teammate (Q103): a call alone no longer sends the ball behind the passer.
	it("passes over a caller outside the cone or past the range", function()
		local ahead = mate("Ahead", off(0, 40))
		local behind = mate("Behind", off(180, 40))
		local far = mate("Far", off(0, 130))
		expect(choose({ ahead, behind, far }, { Behind = 2, Far = 3 })).toBe("Ahead")
		expect(choose({ behind, far }, { Behind = 2, Far = 3 })).toBeNil()
	end)

	it("goes to the earlier of two teammates as near the aim's line, and of two callers called at once", function()
		local left = mate("Left", off(-30, 40))
		local right = mate("Right", off(30, 40))
		expect(choose({ left, right })).toBe("Left")
		expect(choose({ right, left })).toBe("Right")
		expect(choose({ right, left }, { Left = 1, Right = 1 })).toBe("Right")
	end)

	-- The owner (Q155): no pass through the middle glass, nor anything else of the arena between the two skaters.
	it("passes over a teammate the arena hides from the passer, a caller too", function()
		local behindGlass = mate("Hidden", off(0, 50))
		local open = mate("Open", off(30, 40))
		expect(choose({ behindGlass, open })).toBe("Hidden")
		table.insert(hidden, behindGlass.position)
		expect(choose({ behindGlass, open })).toBe("Open")
		expect(choose({ behindGlass, open }, { Hidden = 2 })).toBe("Open")
		expect(choose({ behindGlass }, { Hidden = 2 })).toBeNil()
	end)

	-- A cast that hits allocates its result (~80 B, #315): the arena is asked about a teammate only once they are in
	-- the cone and the range, along the whole line from the passer to them.
	it("asks the arena only about teammates in the cone and the range, along the line to each", function()
		local inCone = mate("In", off(10, 40))
		choose({ mate("Wide", off(pass.coneDeg + 1, 40)), mate("Far", off(0, pass.maxRange + 1)), inCone })
		expect(#asked).toBe(1)
		Fixtures.expectNear(asked[1], inCone.position, 1e-4)
	end)
end)
