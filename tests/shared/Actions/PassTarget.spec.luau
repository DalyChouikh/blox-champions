--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local PassTarget = require(ReplicatedStorage.Shared.Actions.PassTarget)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)

local pass = Config.defaults().Actions.Pass.pass :: Config.PassSettings
-- The passer stands off the origin, and the aim need not be unit: the crosshair's line along -Z.
local PASSER = Vector3.new(10, 3, 10)
local AIM = Vector3.new(0, 0, -5)

-- The surfaces that block a pass (the arena's, #315 Q155): the test folder's parts, none until a test adds some.
local folder: Folder
local blocking: RaycastParams

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "PassTargetTest"
	folder.Parent = workspace
	blocking = RaycastParams.new()
	blocking.FilterType = Enum.RaycastFilterType.Include
	blocking.FilterDescendantsInstances = { folder }
end)

afterEach(function()
	folder:Destroy()
end)

-- An anchored block of `size` centred `offset` from the passer, among the blocking surfaces.
local function block(offset: Vector3, size: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = CFrame.new(PASSER + offset)
	part.Parent = folder
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
	return PassTarget.choose(pass, PASSER, AIM, teammates, calls or {}, blocking)
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
	it("passes over a teammate the blocking surfaces hide from the passer, a caller too", function()
		local hidden = mate("Hidden", off(0, 50))
		local open = mate("Open", off(30, 40))
		-- The floor under them both (their roots stand above it) blocks nobody.
		block(Vector3.new(0, -3.5, -20), Vector3.new(200, 1, 200))
		expect(choose({ hidden, open })).toBe("Hidden")
		-- A pane across the aim 45 studs out, just short of Hidden (the whole line is looked along), 4 wide: Open, 34.6
		-- studs out along the aim, is short of its plane.
		block(off(0, 45), Vector3.new(4, 20, 0.5))
		expect(choose({ hidden, open })).toBe("Open")
		expect(choose({ hidden, open }, { Hidden = 2 })).toBe("Open")
		expect(choose({ hidden }, { Hidden = 2 })).toBeNil()
	end)
end)
