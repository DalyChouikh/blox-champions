--!strict
-- Poses every character this client can see (spec §7.1, plan decision 10): the lean into a turn, a crouch while
-- pumping, a lean back while braking, a tuck in the air and the arm that carries the ball. The local skater's state
-- comes from SkateController; everyone else's from their character's attributes and the ground under them. The joints
-- it writes are local to this client: the server never sees them, and every client poses its own view.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Pose = require(ReplicatedStorage.Shared.Skate.Pose)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

type PlayerId = Types.PlayerId
-- A Motor6D or an AnimationConstraint: both take a Transform.
type Joint = Instance & { Transform: CFrame }
-- One joint of one character, with the pose role it takes.
-- `axes` is the joint frame's turn and `inverse` its inverse, both nil when the frame lines up with the body (R15):
-- an R6 joint frame is turned, so the body-axes pose is carried into it.
type JointEntry = { role: Pose.Role, joint: Joint, axes: CFrame?, inverse: CFrame? }

-- One character this client poses. Its pose records are shared by every character, see `self._input`.
type Tracked = {
	character: Model,
	root: BasePart,
	isLocal: boolean,
	playerId: PlayerId?,
	bodyOffset: number,
	joints: { JointEntry },
	heading: number?,
	lean: number,
}

-- The local skater's state, as SkateController publishes it.
type LocalSkate = { skater: SkateMath.Skater?, pumping: boolean, braking: boolean }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type PoseController = {
	name: string,
	dependencies: { string },
	init: (self: PoseController, deps: { [string]: any }) -> (),
	start: (self: PoseController) -> (),
	-- Starts posing a character. `isLocal` marks this player's own character, which reads SkateController's state.
	track: (self: PoseController, character: Model, isLocal: boolean) -> (),
	untrack: (self: PoseController, character: Model) -> (),
	-- The player carrying the ball, or nil while it is loose.
	setCarrier: (self: PoseController, player: PlayerId?) -> (),
	step: (self: PoseController, dt: number) -> (),
	_config: any,
	_skate: LocalSkate,
	_gravity: number,
	_playerIdOf: (character: Model) -> PlayerId?,
	_carrier: PlayerId?,
	_tracked: { [Model]: Tracked },
	_surfaces: RaycastParams,
	-- Records reused for every character, one at a time: each is composed and written before the next starts.
	_input: Pose.PoseInput,
	_out: Pose.Frame,
}

local function refreshSurfaces(self: PoseController)
	self._surfaces.FilterDescendantsInstances = CollectionService:GetTagged(Tags.RideSurface)
end

-- Standing height is what the avatar's feet stand: half the root plus the hips, and an R6 adds its leg.
local function standingHeight(character: Model, humanoid: Humanoid, root: BasePart): number
	local height = 0.5 * root.Size.Y + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leftLeg = character:FindFirstChild(SkaterRig.leftLeg) :: BasePart?
		if leftLeg ~= nil then
			height += leftLeg.Size.Y
		end
	end
	return height
end

-- The turn of the frame a joint's Transform works in, in the axes of the part it hangs from: a Motor6D's C0, an
-- AnimationConstraint's first attachment.
local function frameOf(joint: Instance): CFrame
	if joint:IsA("Motor6D") then
		return joint.C0.Rotation
	elseif joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		return if attachment ~= nil then attachment.CFrame.Rotation else CFrame.identity
	end
	return CFrame.identity
end

local function alignsWithBody(axes: CFrame): boolean
	return (axes.XVector - Vector3.xAxis).Magnitude < Vectors.EPSILON
		and (axes.YVector - Vector3.yAxis).Magnitude < Vectors.EPSILON
end

-- Each joint of this rig type that the character has, paired with its role.
local function findJoints(character: Model, humanoid: Humanoid): { JointEntry }
	local names: { [Pose.Role]: string } = if humanoid.RigType == Enum.HumanoidRigType.R6
		then SkaterRig.joints.R6
		else SkaterRig.joints.R15
	local entries: { JointEntry } = {}
	for role: Pose.Role, name in names do
		local joint = character:FindFirstChild(name, true)
		if joint ~= nil and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			local axes = frameOf(joint)
			local turned = not alignsWithBody(axes)
			table.insert(entries, {
				role = role,
				joint = joint :: Joint,
				axes = if turned then axes else nil,
				inverse = if turned then axes:Inverse() else nil,
			})
		end
	end
	return entries
end

-- Turns an angle difference into the range (-pi, pi], so a heading that wraps past pi reads as a small turn.
local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Eases the lean toward the lean its turn calls for, and returns the new lean.
local function updateLean(self: PoseController, tracked: Tracked, velocity: Vector3, dt: number): number
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	-- Heading 0 is the world's -Z, and positive heading turns toward +X, which is right from that heading.
	local heading = math.atan2(flat.X, -flat.Z)
	local turnRate = 0
	local previous = tracked.heading
	if previous ~= nil and dt > 0 then
		turnRate = wrapAngle(heading - previous) / dt
	end
	tracked.heading = heading
	local pose = self._config.Pose
	local target = Pose.leanDeg(pose, flat.Magnitude, turnRate, self._gravity)
	tracked.lean += (target - tracked.lean) * (1 - math.exp(-pose.leanSmoothing * dt))
	return tracked.lean
end

-- The local skater is airborne when SkateMath says so. Anyone else is airborne when no ride surface lies under them
-- within hoverHeight plus the probe.
local function isAirborne(self: PoseController, tracked: Tracked): boolean
	if tracked.isLocal then
		local skater = self._skate.skater
		return skater ~= nil and skater.mode == "Airborne"
	end
	local movement = self._config.Movement
	local reach = movement.hoverHeight + self._config.Pose.airborneProbe
	local down = -tracked.root.CFrame.UpVector * reach
	return workspace:Raycast(tracked.root.Position, down, self._surfaces) == nil
end

local function poseOne(self: PoseController, tracked: Tracked, dt: number)
	local input = self._input
	local skate = self._skate
	input.lean = updateLean(self, tracked, tracked.root.AssemblyLinearVelocity, dt)
	input.bodyOffset = tracked.bodyOffset
	input.airborne = isAirborne(self, tracked)
	if tracked.isLocal then
		input.pumping = skate.pumping
		input.braking = skate.braking
	else
		input.pumping = tracked.character:GetAttribute(Attributes.Pumping) == true
		input.braking = tracked.character:GetAttribute(Attributes.Braking) == true
	end
	local playerId = tracked.playerId
	input.carrying = playerId ~= nil and playerId == self._carrier

	local out = self._out
	Pose.compute(self._config.Pose, input, out)
	for _, entry in tracked.joints do
		local turn = out[entry.role]
		local axes, inverse = entry.axes, entry.inverse
		entry.joint.Transform = if axes ~= nil and inverse ~= nil then inverse * turn * axes else turn
	end
end

local function listen(self: PoseController, player: Player)
	local isLocal = player == Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		self:track(character, isLocal)
	end)
	player.CharacterRemoving:Connect(function(character: Model)
		self:untrack(character)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(function()
			self:track(character, isLocal)
		end)
	end
end

local PoseController: PoseController = {
	name = "PoseController",
	dependencies = { "Config", "SkateController" },
	_config = nil :: any,
	_skate = nil :: any,
	_gravity = 0,
	_playerIdOf = function(_character: Model): PlayerId?
		return nil
	end,
	_carrier = nil,
	_tracked = {},
	_surfaces = nil :: any,
	_input = nil :: any,
	_out = {} :: Pose.Frame,

	-- deps.PlayerIdOf and deps.Gravity replace the live game in tests: a test rig has no Player.
	init = function(self: PoseController, deps: { [string]: any })
		self._config = deps.Config
		self._skate = deps.SkateController
		self._gravity = deps.Gravity or workspace.Gravity
		self._playerIdOf = deps.PlayerIdOf
			or function(character: Model): PlayerId?
				local player = Players:GetPlayerFromCharacter(character)
				return if player ~= nil then PlayerIds.of(player) else nil
			end
		self._carrier = nil
		self._tracked = {}
		self._out = {} :: Pose.Frame
		self._input = {
			lean = 0,
			airborne = false,
			pumping = false,
			braking = false,
			carrying = false,
			lunging = false,
			knockedDown = false,
			bodyOffset = 0,
		}
		self._surfaces = RaycastParams.new()
		self._surfaces.FilterType = Enum.RaycastFilterType.Include
		refreshSurfaces(self)
	end,

	start = function(self: PoseController)
		CollectionService:GetInstanceAddedSignal(Tags.RideSurface):Connect(function()
			refreshSurfaces(self)
		end)
		CollectionService:GetInstanceRemovedSignal(Tags.RideSurface):Connect(function()
			refreshSurfaces(self)
		end)
		Remotes.get(ReplicatedStorage, Remotes.names.BallCarrier).OnClientEvent:Connect(function(payload: {
			carrier: PlayerId?,
		})
			self:setCarrier(payload.carrier)
		end)
		for _, player in Players:GetPlayers() do
			listen(self, player)
		end
		Players.PlayerAdded:Connect(function(player: Player)
			listen(self, player)
		end)
		RunService.PreSimulation:Connect(function(dt: number)
			self:step(dt)
		end)
	end,

	track = function(self: PoseController, character: Model, isLocal: boolean)
		local humanoid = character:WaitForChild(SkaterRig.humanoid) :: Humanoid
		local root = character:WaitForChild(SkaterRig.root) :: BasePart
		self._tracked[character] = {
			character = character,
			root = root,
			isLocal = isLocal,
			playerId = self._playerIdOf(character),
			bodyOffset = standingHeight(character, humanoid, root) - self._config.Movement.hoverHeight,
			joints = findJoints(character, humanoid),
			heading = nil,
			lean = 0,
		}
	end,

	untrack = function(self: PoseController, character: Model)
		self._tracked[character] = nil
	end,

	setCarrier = function(self: PoseController, player: PlayerId?)
		self._carrier = player
	end,

	step = function(self: PoseController, dt: number)
		for character, tracked in self._tracked do
			-- A character can leave without CharacterRemoving (destroyed, or removed while track waited for it).
			if character.Parent == nil then
				self._tracked[character] = nil
			else
				poseOne(self, tracked, dt)
			end
		end
	end,
}

return PoseController
