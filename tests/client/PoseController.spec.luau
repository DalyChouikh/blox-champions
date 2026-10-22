--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PoseController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.PoseController)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local HOVER_CFRAME = CFrame.new(0, config.Movement.hoverHeight, 0)

local folder: Folder
-- The local skater's state, as SkateController would publish it.
local skate: { skater: any, pumping: boolean, braking: boolean }
-- Which rig belongs to which player: a rig has no Player in a test.
local playerIds: { [string]: string }

local function jointOf(model: Model, name: string): Motor6D
	return model:FindFirstChild(name, true) :: Motor6D
end

local function setup()
	PoseController:init({
		Config = config,
		SkateController = skate,
		Gravity = Fixtures.GRAVITY.Magnitude,
		PlayerIdOf = function(character: Model): string?
			return playerIds[character.Name]
		end,
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "PoseControllerTest"
	folder.Parent = workspace
	-- The floor is the only ride surface, so a skater standing on it is grounded.
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(400, 1, 400)
	floor.CFrame = CFrame.new(0, -0.5, 0)
	floor.Parent = folder
	CollectionService:AddTag(floor, Tags.RideSurface)
	skate = { skater = nil, pumping = false, braking = false }
	playerIds = {}
	setup()
end)
afterEach(function()
	folder:Destroy()
end)

describe("PoseController", function()
	it("lifts each avatar by its own standing height above hoverHeight, R15 and R6 alike", function()
		local avatar = Fixtures.jointedRig(folder, "R15", HOVER_CFRAME)
		PoseController:track(avatar, false)
		PoseController:step(1 / 60)
		-- R15 standing height: half the root (1) plus the hip height (2) = 3; minus hoverHeight 2.5.
		expect(jointOf(avatar, "Root").Transform.Position.Y).toBeCloseTo(0.5, 6)

		local r6 = Fixtures.rig(folder, "R6", HOVER_CFRAME, Enum.HumanoidRigType.R6)
		local rootJoint = Instance.new("Motor6D")
		rootJoint.Name = "RootJoint"
		rootJoint.Part0 = r6.PrimaryPart
		rootJoint.Part1 = r6:FindFirstChild("Left Leg") :: BasePart
		rootJoint.Parent = r6.PrimaryPart
		PoseController:track(r6, false)
		PoseController:step(1 / 60)
		-- R6 standing height: half the root (1) plus the leg (2) = 3.
		expect(jointOf(r6, "RootJoint").Transform.Position.Y).toBeCloseTo(0.5, 6)
	end)

	it("raises the carrier's arm and shows another player's pump from their character's attribute", function()
		local carrier = Fixtures.jointedRig(folder, "Carrier", HOVER_CFRAME)
		playerIds.Carrier = "7"
		PoseController:track(carrier, false)
		PoseController:setCarrier("7")
		carrier:SetAttribute(Attributes.Pumping, true)
		PoseController:step(1 / 60)
		local _, _, shoulderRoll = jointOf(carrier, "RightShoulder").Transform:ToEulerAnglesXYZ()
		expect(math.abs(math.deg(shoulderRoll))).toBeCloseTo(75, 3)
		local kneeBend = jointOf(carrier, "RightKnee").Transform:ToEulerAnglesXYZ()
		expect(math.abs(math.deg(kneeBend))).toBeCloseTo(60, 3)
	end)

	it("leans a character into the turn its velocity makes", function()
		local turner = Fixtures.jointedRig(folder, "Turner", HOVER_CFRAME)
		local root = turner.PrimaryPart :: BasePart
		PoseController:track(turner, false)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, -30)
		PoseController:step(1 / 60)
		-- Turning right at 1 rad/s: the heading moves by 1/60 rad in one frame.
		root.AssemblyLinearVelocity = Vector3.new(30 * math.sin(1 / 60), 0, -30 * math.cos(1 / 60))
		PoseController:step(1 / 60)
		local _, _, roll = jointOf(turner, "Root").Transform:ToEulerAnglesXYZ()
		-- The target lean is 8.6935°, reached by 1 - e^(-10/60) of the gap in one frame.
		expect(math.abs(math.deg(roll))).toBeCloseTo(1.3347, 3)
	end)

	it("poses six skaters in under 0.3 ms a frame", function()
		for index = 1, 6 do
			local name = `Skater{index}`
			local avatar = Fixtures.jointedRig(folder, name, HOVER_CFRAME + Vector3.new(index * 4, 0, 0))
			local root = avatar.PrimaryPart :: BasePart
			root.AssemblyLinearVelocity = Vector3.new(0, 0, -30)
			avatar:SetAttribute(Attributes.Pumping, index <= 2)
			playerIds[name] = tostring(index)
			PoseController:track(avatar, false)
		end
		PoseController:setCarrier("3")
		local frames = 600
		local started = os.clock()
		for _ = 1, frames do
			PoseController:step(1 / 60)
		end
		local meanSeconds = (os.clock() - started) / frames
		expect(meanSeconds).toBeLessThan(0.0003)
	end)
end)
