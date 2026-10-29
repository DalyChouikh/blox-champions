--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PoseController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.PoseController)
local RideSurfaces = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.RideSurfaces)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local HOVER_CFRAME = CFrame.new(0, config.Movement.hoverHeight, 0)

local folder: Folder
-- The local skater's state, as SkateController would publish it.
local skate: { skater: any, pumping: boolean, braking: boolean }
-- Which rig belongs to which player: a rig has no Player in a test.
local playerIds: { [string]: string }
-- The local skater's running action's pose, as ActionController would give it.
local actions: { current: string, pose: (self: any) -> string }

local function jointOf(model: Model, name: string): Motor6D
	return model:FindFirstChild(name, true) :: Motor6D
end

-- R6's joint frames as Roblox builds them: the RootJoint's up axis is the body's back, the hips are turned 90°.
local R6_ROOT_FRAME = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
local R6_RIGHT_HIP_FRAME = CFrame.fromMatrix(Vector3.new(1, -1, 0), Vector3.new(0, 0, -1), Vector3.yAxis)

-- A Motor6D from the R6 rig's root to its leg, with the frame an R6 joint of that name has.
local function r6Joint(model: Model, name: string, frame: CFrame): Motor6D
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = Fixtures.root(model)
	joint.Part1 = model:FindFirstChild("Left Leg") :: BasePart
	joint.C0 = frame
	joint.Parent = Fixtures.root(model)
	return joint
end

-- What a joint's Transform does, seen in the axes of the part it hangs from.
local function inParentAxes(joint: Motor6D): CFrame
	local axes = joint.C0.Rotation
	return axes * joint.Transform * axes:Inverse()
end

local function setup()
	RideSurfaces:init({})
	PoseController:init({
		Config = config,
		RideSurfaces = RideSurfaces,
		SkateController = skate,
		BallCarrier = BallCarrier,
		ActionController = actions,
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
	actions = {
		current = "None",
		pose = function(self: any): string
			return self.current
		end,
	}
	BallCarrier:init({})
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
		local rootJoint = r6Joint(r6, "RootJoint", R6_ROOT_FRAME)
		PoseController:track(r6, false)
		PoseController:step(1 / 60)
		-- R6 standing height: half the root (1) plus the leg (2) = 3. The lift is up in the root part's own axes.
		Fixtures.expectNear(inParentAxes(rootJoint).Position, Vector3.new(0, 0.5, 0))
	end)

	-- R6 joint frames are turned (read from a Roblox R6 rig): the pose must still bend the body, not the joint's axes.
	it("bends an R6 body the way it bends an R15 one, whatever way the R6 joints' frames are turned", function()
		local r6 = Fixtures.rig(folder, "R6", HOVER_CFRAME, Enum.HumanoidRigType.R6)
		local rootJoint = r6Joint(r6, "RootJoint", R6_ROOT_FRAME)
		local rightHip = r6Joint(r6, "Right Hip", R6_RIGHT_HIP_FRAME)
		r6:SetAttribute(Attributes.Pumping, true)
		PoseController:track(r6, false)
		PoseController:step(1 / 60)
		expect((inParentAxes(rootJoint).Rotation * Vector3.yAxis).Z).toBeLessThan(0) -- the body leans forward
		expect((inParentAxes(rightHip).Rotation * -Vector3.yAxis).Z).toBeLessThan(0) -- the thigh comes forward
	end)

	it("raises the carrier's arm and shows another player's pump from their character's attribute", function()
		local carrier = Fixtures.jointedRig(folder, "Carrier", HOVER_CFRAME)
		playerIds.Carrier = "7"
		PoseController:track(carrier, false)
		BallCarrier:set("7")
		carrier:SetAttribute(Attributes.Pumping, true)
		PoseController:step(1 / 60)
		local _, _, shoulderRoll = jointOf(carrier, "RightShoulder").Transform:ToEulerAnglesXYZ()
		expect(math.abs(math.deg(shoulderRoll))).toBeCloseTo(75, 3)
		local kneeBend = jointOf(carrier, "RightKnee").Transform:ToEulerAnglesXYZ()
		expect(math.abs(math.deg(kneeBend))).toBeCloseTo(60, 3)
	end)

	it("stops posing a character that is gone, even one that left without CharacterRemoving", function()
		local gone = Fixtures.jointedRig(folder, "Gone", HOVER_CFRAME)
		gone:SetAttribute(Attributes.Pumping, true)
		PoseController:track(gone, false)
		gone.Parent = nil
		PoseController:step(1 / 60)
		expect(jointOf(gone, "RightKnee").Transform == CFrame.identity).toBe(true)
		gone:Destroy()
	end)

	it("leans a character into the turn its velocity makes", function()
		local turner = Fixtures.jointedRig(folder, "Turner", HOVER_CFRAME)
		local root = Fixtures.root(turner)
		PoseController:track(turner, false)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, -30)
		PoseController:step(1 / 60)
		-- Turning right at 1 rad/s: the heading moves by 1/60 rad in one frame.
		root.AssemblyLinearVelocity = Vector3.new(30 * math.sin(1 / 60), 0, -30 * math.cos(1 / 60))
		PoseController:step(1 / 60)
		local _, _, roll = jointOf(turner, "Root").Transform:ToEulerAnglesXYZ()
		-- The target lean is atan(30 × 1 / 130.8) = 12.9178° at the world's gravity, reached by 1 - e^(-10/60) of
		-- the gap in one frame.
		expect(math.abs(math.deg(roll))).toBeCloseTo(1.9831, 3)
	end)

	-- The owner (#246): riding backwards, the body faces against its way round the turn, so it leans its other side
	-- to lean into the turn.
	it("leans a character riding backwards into the turn too", function()
		local function rolled(name: string, facing: CFrame): number
			local rig = Fixtures.jointedRig(folder, name, HOVER_CFRAME * facing)
			local root = Fixtures.root(rig)
			PoseController:track(rig, false)
			root.AssemblyLinearVelocity = Vector3.new(0, 0, -30)
			PoseController:step(1 / 60)
			root.AssemblyLinearVelocity = Vector3.new(30 * math.sin(1 / 60), 0, -30 * math.cos(1 / 60))
			PoseController:step(1 / 60)
			local _, _, roll = jointOf(rig, "Root").Transform:ToEulerAnglesXYZ()
			return math.deg(roll)
		end
		local ahead = rolled("Ahead", CFrame.identity)
		expect(math.abs(ahead)).toBeCloseTo(1.9831, 3)
		expect(rolled("Backwards", CFrame.Angles(0, math.pi, 0))).toBeCloseTo(-ahead, 3)
	end)

	it("poses another skater's lunge and knockdown from their attributes", function()
		local other = Fixtures.jointedRig(folder, "Other", HOVER_CFRAME)
		PoseController:track(other, false)
		-- One step as long as a knockdown's ease: all the way down, or back up.
		local function pitch(): number
			PoseController:step(config.Pose.knockdownEaseSeconds)
			return jointOf(other, "Root").Transform.LookVector.Y
		end
		other:SetAttribute(Attributes.Action, "Tackle")
		expect(pitch()).toBeCloseTo(-math.sin(math.rad(config.Pose.lungeDeg)), 5)
		other:SetAttribute(Attributes.KnockedDown, "Hit")
		expect(pitch()).toBeCloseTo(math.sin(math.rad(config.Pose.knockdownTiltDeg)), 5)
		-- An action that is not a lunge poses nothing.
		other:SetAttribute(Attributes.KnockedDown, nil)
		other:SetAttribute(Attributes.Action, "Uppercut")
		expect(pitch()).toBeCloseTo(0, 5)
	end)

	-- The owner (#243): a knockdown eases down and back up over knockdownEaseSeconds, each character on its own, and a
	-- diver goes face-down (RC, Video 4).
	it("eases each character into and out of its own knockdown, a diver's face-down", function()
		local pose = config.Pose
		local hit = Fixtures.jointedRig(folder, "Hit", HOVER_CFRAME)
		local diver = Fixtures.jointedRig(folder, "Diver", HOVER_CFRAME + Vector3.new(6, 0, 0))
		PoseController:track(hit, false)
		PoseController:track(diver, false)
		local function pitchOf(rig: Model): number
			return jointOf(rig, "Root").Transform.LookVector.Y
		end
		-- Half the ease a step: halfway is smoothstep(0.5) = 0.5 of the pose.
		local half = pose.knockdownEaseSeconds / 2
		hit:SetAttribute(Attributes.KnockedDown, "Hit")
		PoseController:step(half)
		expect(pitchOf(hit)).toBeCloseTo(math.sin(math.rad(pose.knockdownTiltDeg / 2)), 5)
		expect(pitchOf(diver)).toBeCloseTo(0, 5)
		diver:SetAttribute(Attributes.KnockedDown, "Dive")
		PoseController:step(half)
		expect(pitchOf(hit)).toBeCloseTo(math.sin(math.rad(pose.knockdownTiltDeg)), 5)
		expect(pitchOf(diver)).toBeCloseTo(-math.sin(math.rad(pose.diveDeg / 2)), 5)
		PoseController:step(half)
		expect(pitchOf(diver)).toBeCloseTo(-math.sin(math.rad(pose.diveDeg)), 5)
		-- Up again: the diver rises from face-down, easing back upright.
		diver:SetAttribute(Attributes.KnockedDown, nil)
		PoseController:step(half)
		expect(pitchOf(diver)).toBeCloseTo(-math.sin(math.rad(pose.diveDeg / 2)), 5)
		PoseController:step(half)
		expect(pitchOf(diver)).toBeCloseTo(0, 5)
		expect(pitchOf(hit)).toBeCloseTo(math.sin(math.rad(pose.knockdownTiltDeg)), 5)
	end)

	-- The Air Pose (#218): the local skater's from its own skater at once, another's from the attribute the server
	-- sets.
	it("strikes the Air Pose: the local skater's from its own skater, another's from their attribute", function()
		local tipped = -math.sin(math.rad(config.Pose.airPoseDeg))
		local own = Fixtures.jointedRig(folder, "Own", HOVER_CFRAME)
		PoseController:track(own, true)
		skate.skater = { mode = "Airborne", airPosing = true }
		local other = Fixtures.jointedRig(folder, "Other", HOVER_CFRAME)
		PoseController:track(other, false)
		other:SetAttribute(Attributes.AirPosing, true)
		PoseController:step(1 / 60)
		expect(jointOf(own, "Root").Transform.LookVector.Y).toBeCloseTo(tipped, 5)
		expect(jointOf(other, "Root").Transform.LookVector.Y).toBeCloseTo(tipped, 5)
	end)

	it("poses the local skater's lunge from its own actions", function()
		local own = Fixtures.jointedRig(folder, "Own", HOVER_CFRAME)
		PoseController:track(own, true)
		-- The attribute arrives later from the server; the local skater lunges at once.
		actions.current = "Lunge"
		PoseController:step(1 / 60)
		expect(jointOf(own, "Root").Transform.LookVector.Y).toBeCloseTo(-math.sin(math.rad(config.Pose.lungeDeg)), 5)
	end)

	it("poses six skaters in under 0.3 ms a frame", function()
		for index = 1, 6 do
			local name = `Skater{index}`
			local avatar = Fixtures.jointedRig(folder, name, HOVER_CFRAME + Vector3.new(index * 4, 0, 0))
			local root = Fixtures.root(avatar)
			root.AssemblyLinearVelocity = Vector3.new(0, 0, -30)
			avatar:SetAttribute(Attributes.Pumping, index <= 2)
			playerIds[name] = tostring(index)
			PoseController:track(avatar, false)
		end
		BallCarrier:set("3")
		local frames = 600
		local started = os.clock()
		for _ = 1, frames do
			PoseController:step(1 / 60)
		end
		local meanSeconds = (os.clock() - started) / frames
		expect(meanSeconds).toBeLessThan(0.0003)
	end)
end)
