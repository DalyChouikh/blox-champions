--!strict
-- Shared test data. Not a spec file, so Jest never runs it as a test.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)
local GeometryTypes = require(ReplicatedStorage.Shared.Arena.Geometry.Types)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)

local Fixtures = {}

-- Roblox's default workspace.Gravity, pointing down.
Fixtures.GRAVITY = Vector3.new(0, -196.2, 0)

-- Asserts two vectors are within `tolerance` (default 1e-3) of each other.
function Fixtures.expectNear(actual: Vector3, expected: Vector3, tolerance: number?)
	JestGlobals.expect((actual - expected).Magnitude).toBeLessThan(tolerance or 1e-3)
end

-- A binding tests can drive with Fire, added to an input action.
function Fixtures.scriptedBinding(action: InputAction): InputBinding
	local binding = Instance.new("InputBinding")
	binding.Type = Enum.InputBindingType.Scriptable
	binding.Parent = action
	return binding
end

local GATE_SPACING = 100
local GATE_SIZE = 40

function Fixtures.mode(overrides: { [string]: any }?): Config.Mode
	return { id = "Test", displayName = "Test", itemsEnabled = false, overrides = overrides or {} }
end

function Fixtures.config(overrides: { [string]: any }?): Config.GameConfig
	return Config.forMode(Fixtures.mode(overrides))
end

-- A straight synthetic "track": every gate faces +X, so a segment moving +X crosses it forward.
function Fixtures.gate(x: number): Crossing.Rectangle
	local position = Vector3.new(x, 0, 0)
	return { frame = CFrame.lookAt(position, position + Vector3.xAxis), width = GATE_SIZE, height = GATE_SIZE }
end

function Fixtures.gates(): { Crossing.Rectangle }
	local gates = {}
	for index = 1, 4 do
		table.insert(gates, Fixtures.gate(GATE_SPACING * index))
	end
	return gates
end

-- Like the arena's goal at Gate 2: on Gate 2's plane, raised, and inside its rectangle.
function Fixtures.ring(): Crossing.Disc
	local position = Vector3.new(2 * GATE_SPACING, 15, 0)
	return { frame = CFrame.lookAt(position, position + Vector3.xAxis), radius = 3 }
end

function Fixtures.arena(): MatchEngine.ArenaLayout
	return { gates = Fixtures.gates(), goal = Fixtures.ring() }
end

function Fixtures.throughGate(index: number): (Vector3, Vector3)
	local x = GATE_SPACING * index
	return Vector3.new(x - 1, 0, 0), Vector3.new(x + 1, 0, 0)
end

-- The triangular face of a wedge piece on the side `normal` points to: right-angle corner, top corner, front corner.
function Fixtures.wedgeFace(piece: GeometryTypes.Piece, normal: Vector3): { Vector3 }
	local half = piece.size / 2
	local side = if piece.cframe.RightVector:Dot(normal) > 0 then half.X else -half.X
	return {
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, -half.Z)),
	}
end

-- A stand-in for a Player: Roblox cannot create one in Edit, so it has just the members the services use.
function Fixtures.stubPlayer(userId: number): any
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
	}
end

-- A stand-in for a player's character: a Humanoid rig whose hand is welded to its root, R15 unless R6 is asked
-- for. R15: RightHand, HipHeight 2. R6: Right Arm and Left Leg, HipHeight 0. Nothing is anchored.
function Fixtures.rig(parent: Instance, name: string, cframe: CFrame, rigType: Enum.HumanoidRigType?): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = cframe
	root.Parent = model
	local function limb(limbName: string, size: Vector3, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = limbName
		part.Size = size
		part.CFrame = cframe * offset
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	if rigType == Enum.HumanoidRigType.R6 then
		limb("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0))
		limb("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0))
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.HipHeight = 0
	else
		limb("RightHand", Vector3.new(1, 1, 1), CFrame.new(1.5, -0.5, -0.5))
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.HipHeight = 2
	end
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = parent
	return model
end

-- An R15 rig whose joints are Motor6Ds, named as the avatar's own joints are. The parts all sit on `cframe`: only the
-- joints matter to the tests that use it.
function Fixtures.jointedRig(parent: Instance, name: string, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name
	local parts: { [string]: BasePart } = {}
	for _, partName in
		{
			"HumanoidRootPart",
			"LowerTorso",
			"UpperTorso",
			"LeftUpperLeg",
			"LeftLowerLeg",
			"RightUpperLeg",
			"RightLowerLeg",
			"RightUpperArm",
		}
	do
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = if partName == "HumanoidRootPart" then Vector3.new(2, 2, 1) else Vector3.new(1, 1, 1)
		part.CFrame = cframe
		part.Parent = model
		parts[partName] = part
	end
	local joints = {
		{ name = "Root", from = "HumanoidRootPart", to = "LowerTorso" },
		{ name = "Waist", from = "LowerTorso", to = "UpperTorso" },
		{ name = "LeftHip", from = "LowerTorso", to = "LeftUpperLeg" },
		{ name = "LeftKnee", from = "LeftUpperLeg", to = "LeftLowerLeg" },
		{ name = "RightHip", from = "LowerTorso", to = "RightUpperLeg" },
		{ name = "RightKnee", from = "RightUpperLeg", to = "RightLowerLeg" },
		{ name = "RightShoulder", from = "UpperTorso", to = "RightUpperArm" },
	}
	for _, joint in joints do
		local motor = Instance.new("Motor6D")
		motor.Name = joint.name
		motor.Part0 = parts[joint.from]
		motor.Part1 = parts[joint.to]
		motor.Parent = parts[joint.from]
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = parts.HumanoidRootPart
	model.Parent = parent
	return model
end

-- Also crosses Gate 2, whose rectangle contains the ring.
function Fixtures.throughRing(): (Vector3, Vector3)
	local x = 2 * GATE_SPACING
	return Vector3.new(x - 1, 15, 0), Vector3.new(x + 1, 15, 0)
end

return Fixtures
