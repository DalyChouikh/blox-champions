--!strict
-- The local player's skating (spec §7.1). Every physics step it:
-- - reads the keys and casts the ground ray against the ride surfaces only;
-- - filters the ray's normal;
-- - works out the draft and the attach;
-- - steps SkateMath and writes the result into the skater body the server built.
-- This client owns its character's physics, so what it writes moves the character for everyone. It turns the
-- humanoid's state machine off here, on the owning client only: the server keeps it on so deaths still fire Died.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attach = require(ReplicatedStorage.Shared.Skate.Attach)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Draft = require(ReplicatedStorage.Shared.Skate.Draft)
local InputController = require(script.Parent.InputController)
local NormalFilter = require(ReplicatedStorage.Shared.Skate.NormalFilter)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local SkateTypes = require(ReplicatedStorage.Shared.Skate.Types)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

type PlayerId = Types.PlayerId

-- Another player's skater, as this client sees it.
export type SkaterView = { player: PlayerId, team: string?, root: BasePart }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type SkateController = {
	name: string,
	dependencies: { string },
	init: (self: SkateController, deps: { [string]: any }) -> (),
	start: (self: SkateController) -> (),
	-- Takes control of a character: waits for its skater body, turns its state machine off.
	bind: (self: SkateController, character: Model) -> (),
	step: (self: SkateController, dt: number) -> (),
	-- The bound character's skater; PoseController reads its mode.
	skater: SkateMath.Skater?,
	pumping: boolean,
	braking: boolean,
	_config: Config.GameConfig,
	_inputController: InputController.InputController,
	_camera: { CFrame: CFrame },
	_skaters: () -> { SkaterView },
	_sendSkateState: (pump: boolean, brake: boolean) -> (),
	-- Keeps the sends within the server's rate limit for SkateState (os.clock; a fake in tests).
	_stateLimiter: RateLimiter.RateLimiter,
	_clock: () -> number,
	-- A pump or brake change the limit has not let out yet.
	_statePending: boolean,
	_team: () -> string?,
	_gravity: Vector3,
	-- workspace:Raycast; a fake in tests, which can then hand the controller a seam's side face.
	_raycast: (origin: Vector3, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	_root: BasePart?,
	_velocity: LinearVelocity?,
	_align: AlignOrientation?,
	_filter: NormalFilter.NormalFilter,
	_attach: Attach.Attach,
	_rayParams: RaycastParams,
	-- Records reused every step, so a step allocates nothing.
	_keys: InputController.SkateKeys,
	_input: SkateTypes.SkateInput,
	_ground: SkateTypes.Ground,
	_sources: { Draft.Source },
	_teammates: { Attach.Candidate },
	_views: { SkaterView },
	-- The game's players, followed from start on.
	_playerList: PlayerList.PlayerList?,
}

-- Who playersAround walks before start.
local NO_PLAYERS: { Player } = table.freeze({})

local function worldUp(self: SkateController): Vector3
	return -self._gravity.Unit
end

-- Rays hit only what the arena tags as ride surfaces: never gates, markers, the goal, characters or the ball.
local function refreshSurfaces(self: SkateController)
	self._rayParams.FilterDescendantsInstances = CollectionService:GetTagged(Tags.RideSurface)
end

-- Every other player's character with a root, into one reused list of reused records.
local function playersAround(self: SkateController): { SkaterView }
	local views = self._views
	local count = 0
	local localPlayer = Players.LocalPlayer
	local playerList = self._playerList
	local players: { Player } = if playerList ~= nil then playerList.list else NO_PLAYERS
	for _, player in players do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild(SkaterRig.root) :: BasePart? else nil
		if player ~= localPlayer and root ~= nil then
			count += 1
			local view = views[count]
			local team = player:GetAttribute(Attributes.Team) :: string?
			if view == nil then
				views[count] = { player = PlayerIds.of(player), team = team, root = root }
			else
				view.player = PlayerIds.of(player)
				view.team = team
				view.root = root
			end
		end
	end
	for index = #views, count + 1, -1 do
		views[index] = nil
	end
	return views
end

-- Fills the reused draft sources (everyone) and attach candidates (teammates) from the other skaters.
local function gatherOthers(self: SkateController)
	local sources, teammates = self._sources, self._teammates
	local team = self._team()
	local sourceCount, teammateCount = 0, 0
	for _, view in self._skaters() do
		local position = view.root.Position
		local velocity = view.root.AssemblyLinearVelocity
		sourceCount += 1
		local source = sources[sourceCount]
		if source == nil then
			sources[sourceCount] = { position = position, velocity = velocity }
		else
			source.position = position
			source.velocity = velocity
		end
		if team ~= nil and view.team == team then
			teammateCount += 1
			local forward = view.root.CFrame.LookVector
			local candidate = teammates[teammateCount]
			if candidate == nil then
				teammates[teammateCount] =
					{ player = view.player, position = position, velocity = velocity, forward = forward }
			else
				candidate.player = view.player
				candidate.position = position
				candidate.velocity = velocity
				candidate.forward = forward
			end
		end
	end
	for index = #sources, sourceCount + 1, -1 do
		sources[index] = nil
	end
	for index = #teammates, teammateCount + 1, -1 do
		teammates[index] = nil
	end
end

local function currentLeader(self: SkateController): Attach.Candidate?
	local leader = self._attach.leader
	for _, candidate in self._teammates do
		if candidate.player == leader then
			return candidate
		end
	end
	return nil
end

-- The stick as a world direction from the camera, level with the ground.
local function stickDirection(self: SkateController, stick: Vector2): Vector3
	local camera = self._camera.CFrame
	local right = Vectors.alongSurface(camera.RightVector, worldUp(self))
	local forward = Vectors.alongSurface(camera.LookVector, worldUp(self))
	if right.Magnitude > Vectors.EPSILON then
		right = right.Unit
	end
	if forward.Magnitude > Vectors.EPSILON then
		forward = forward.Unit
	end
	return right * stick.X + forward * stick.Y
end

local function castGround(self: SkateController, root: BasePart, skater: SkateMath.Skater, dt: number)
	local ground = self._ground
	local direction = -skater.up * self._config.Movement.groundProbeLength
	local result = self._raycast(root.Position, direction, self._rayParams)
	if result == nil then
		ground.hit = false
		return
	end
	ground.hit = true
	ground.normal = self._filter:update(result.Normal, dt)
	ground.distance = result.Distance
end

local function moveSkater(self: SkateController, root: BasePart, skater: SkateMath.Skater, dt: number)
	local movement = self._config.Movement
	local keys = self._keys
	local attach = self._attach
	local leader: Attach.Candidate? = if attach.leader ~= nil
		then currentLeader(self)
		elseif keys.attach then Attach.findLeader(movement, root.Position, self._teammates)
		else nil
	local change = attach:update(dt, keys.attach, leader)
	if attach.leader ~= nil and leader ~= nil then
		skater:follow(Attach.target(movement, leader), root.Position, leader.velocity, leader.forward)
		return
	end
	if change == "Released" then
		skater:release(attach.releaseDirection)
	end
	skater:step(self._input, self._ground, dt)
end

local function apply(self: SkateController, skater: SkateMath.Skater)
	(self._velocity :: LinearVelocity).VectorVelocity = skater.velocity
	-- A facing along the up vector (flying straight off a wall) has no right: keep the last orientation.
	local right = skater.forward:Cross(skater.up)
	if right.Magnitude > Vectors.EPSILON then
		local align = self._align :: AlignOrientation
		align.PrimaryAxis = right.Unit
		align.SecondaryAxis = skater.up
	end
end

-- Sends pump and brake when they change, within the server's rate limit: a change the limit holds back goes out as
-- the latest state once it may, since the server would drop it and nothing would send it again.
local function shareState(self: SkateController)
	local keys = self._keys
	if keys.pump ~= self.pumping or keys.brake ~= self.braking then
		self.pumping = keys.pump
		self.braking = keys.brake
		self._statePending = true
	end
	if self._statePending and self._stateLimiter:allow(Remotes.names.SkateState, self._clock()) then
		self._statePending = false
		self._sendSkateState(self.pumping, self.braking)
	end
end

-- The kickoff freeze (the server anchors every root while it places them): the skater starts from rest, upright and
-- facing where the server put them, with no attach held over and no jump pressed during the countdown. Pump and brake
-- are still shared, so other players see what this one holds.
local function freeze(self: SkateController, root: BasePart, skater: SkateMath.Skater)
	self._inputController:read(self._keys)
	skater:stop()
	local up = worldUp(self)
	skater.up = up
	local facing = Vectors.alongSurface(root.CFrame.LookVector, up)
	if facing.Magnitude > Vectors.EPSILON then
		skater.forward = facing.Unit
	end
	self._filter:reset(up)
	self._attach:reset()
	apply(self, skater)
	shareState(self)
end

local SkateController: SkateController = {
	name = "SkateController",
	dependencies = { "Config", "InputController" },
	skater = nil,
	pumping = false,
	braking = false,
	_config = nil :: any,
	_inputController = nil :: any,
	_camera = nil :: any,
	_skaters = function(): { SkaterView }
		return {}
	end,
	_sendSkateState = function(_pump: boolean, _brake: boolean) end,
	_stateLimiter = nil :: any,
	_clock = os.clock,
	_statePending = false,
	_team = function(): string?
		return nil
	end,
	_gravity = Vector3.zero,
	_raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
		return nil
	end,
	_root = nil,
	_velocity = nil,
	_align = nil,
	_filter = nil :: any,
	_attach = nil :: any,
	_rayParams = nil :: any,
	_keys = nil :: any,
	_input = nil :: any,
	_ground = nil :: any,
	_sources = {},
	_teammates = {},
	_views = {},
	_playerList = nil,

	-- deps.Camera, deps.Skaters, deps.SendSkateState, deps.Clock, deps.Gravity, deps.Team and deps.Raycast replace
	-- the live game in tests.
	init = function(self: SkateController, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._inputController = deps.InputController
		self._camera = deps.Camera or workspace.CurrentCamera
		self._skaters = deps.Skaters or function(): { SkaterView }
			return playersAround(self)
		end
		self._sendSkateState = deps.SendSkateState
			or function(pump: boolean, brake: boolean)
				Remotes.get(ReplicatedStorage, Remotes.names.SkateState):FireServer({ pump = pump, brake = brake })
			end
		self._stateLimiter = RateLimiter.new(config.Network.maxSkateStatesPerSecond)
		self._clock = deps.Clock or os.clock
		self._statePending = false
		self._team = deps.Team
			or function(): string?
				return (Players.LocalPlayer :: Player):GetAttribute(Attributes.Team) :: string?
			end
		self._gravity = deps.Gravity or Vector3.new(0, -workspace.Gravity, 0)
		self._raycast = deps.Raycast
			or function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Raycast(origin, direction, params)
			end
		self._filter = NormalFilter.new(config.Movement.normalFilter, worldUp(self))
		self._attach = Attach.new(config.Movement)
		self._rayParams = RaycastParams.new()
		self._rayParams.FilterType = Enum.RaycastFilterType.Include
		refreshSurfaces(self)
		self._keys = InputController.newKeys()
		self._input = { move = Vector3.zero, pump = false, brake = false, jump = false, draftAccel = 0 }
		self._ground = { hit = false, normal = worldUp(self), distance = 0 }
		self._sources = {}
		self._teammates = {}
		self._views = {}
		self.skater = nil
		self._root = nil
		self.pumping = false
		self.braking = false
	end,

	start = function(self: SkateController)
		self._playerList = PlayerList.new(Players)
		CollectionService:GetInstanceAddedSignal(Tags.RideSurface):Connect(function()
			refreshSurfaces(self)
		end)
		CollectionService:GetInstanceRemovedSignal(Tags.RideSurface):Connect(function()
			refreshSurfaces(self)
		end)
		local player = Players.LocalPlayer :: Player
		player.CharacterAdded:Connect(function(character: Model)
			self:bind(character)
		end)
		local character = player.Character
		if character ~= nil then
			task.spawn(function()
				self:bind(character)
			end)
		end
		RunService.PreSimulation:Connect(function(dt: number)
			self:step(dt)
		end)
	end,

	bind = function(self: SkateController, character: Model)
		local humanoid = character:WaitForChild(SkaterRig.humanoid) :: Humanoid
		local root = character:WaitForChild(SkaterRig.root) :: BasePart
		local velocity = root:WaitForChild(SkaterRig.velocity) :: LinearVelocity
		local align = root:WaitForChild(SkaterRig.align) :: AlignOrientation
		humanoid.EvaluateStateMachine = false
		local skater = SkateMath.new(self._config.Movement, self._gravity)
		skater.forward = root.CFrame.LookVector
		self.skater = skater
		self._root = root
		self._velocity = velocity
		self._align = align
		self._filter:reset(worldUp(self))
		self._attach = Attach.new(self._config.Movement)
		-- Jump presses made while there was no character to jump are spent here, not on the new one.
		self._inputController:read(self._keys)
		self.pumping = false
		self.braking = false
		self._statePending = false
	end,

	step = function(self: SkateController, dt: number)
		local skater = self.skater
		local root = self._root
		if skater == nil or root == nil or root.Parent == nil then
			return
		end
		if root.Anchored then
			freeze(self, root, skater)
			return
		end

		local keys = self._keys
		self._inputController:read(keys)
		local input = self._input
		input.move = stickDirection(self, keys.move)
		input.pump = keys.pump
		input.brake = keys.brake
		input.jump = keys.jump
		castGround(self, root, skater, dt)
		gatherOthers(self)
		input.draftAccel = Draft.accel(self._config.Movement, root.Position, self._sources)
		moveSkater(self, root, skater, dt)
		apply(self, skater)
		shareState(self)
	end,
}

return SkateController
