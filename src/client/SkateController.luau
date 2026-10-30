--!strict
-- The local player's skating (spec §7.1). Every physics step, first (FrameController), it:
-- - reads the keys and casts the ground ray against the ride surfaces only;
-- - filters the ray's normal;
-- - works out the draft and the attach;
-- - steps SkateMath, slides the skater along any ride surface in its way, and writes the result into the skater body
--   the server built.
-- It holds the skater still during the kickoff freeze and until the arena has reached this client. A knocked-down
-- skater (the server's KnockedDown attribute) lets go of any attach and only slides, and asks the server to get up
-- (GetUp) once per knockdown, as soon as the stick moves: the server decides when. A diver (`diving`) is held the same
-- way until that knockdown. While Roblox's menu holds the keys the skater lets go of any attach too, with no release
-- boost. Actions push the skater through `push`.
-- This client owns its character's physics, so what it writes moves the character for everyone. It turns the
-- humanoid's state machine off here, on the owning client only: the server keeps it on so deaths still fire Died.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attach = require(ReplicatedStorage.Shared.Skate.Attach)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Draft = require(ReplicatedStorage.Shared.Skate.Draft)
local InputController = require(script.Parent.InputController)
local NormalFilter = require(ReplicatedStorage.Shared.Skate.NormalFilter)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local RideSurfaces = require(script.Parent.RideSurfaces)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local SkateTypes = require(ReplicatedStorage.Shared.Skate.Types)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
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
	-- The bound character's root; the camera follows it.
	root: BasePart?,
	-- Whether the player skates now: a skater is bound to a character still in the world. A spectator, or a player
	-- whose character is gone before the next is bound, has none.
	hasSkater: (self: SkateController) -> boolean,
	pumping: boolean,
	braking: boolean,
	-- The last step's stick as a world direction (length 0..1).
	move: Vector3,
	-- Read each step: the character's KnockedDown attribute, and whether the skater is held still: the root anchored
	-- (the kickoff freeze), or no arena on this client yet (RideSurfaces.ready), where the skater would fall through
	-- the floor to come (#177).
	knockedDown: boolean,
	frozen: boolean,
	-- Set by ActionController when a dive (an action with a landing) starts: the skater does nothing more until the
	-- server's knockdown at their touchdown, which ends it, as do a freeze and a new character. Meanwhile the input
	-- locks as a knockdown's does, so the belly slide starts the moment they touch down, and in the air they fly down
	-- the fall line (SkateMath, #241).
	diving: boolean,
	-- Set each step: attached, or right behind a teammate with no cooldown, so holding Attach would attach.
	attachable: boolean,
	-- An action's push, written to the skater body at once; `launch` leaves the ground.
	push: (self: SkateController, change: Vector3, launch: boolean) -> (),
	_config: Config.GameConfig,
	_inputController: InputController.InputController,
	_camera: { CFrame: CFrame },
	_skaters: () -> { SkaterView },
	_sendSkateState: (pump: boolean, brake: boolean, airPose: boolean) -> (),
	-- Keeps the sends within the server's rate limit for SkateState (os.clock; a fake in tests).
	_stateLimiter: RateLimiter.RateLimiter,
	_clock: () -> number,
	-- A pump, brake or Air Pose change the limit has not let out yet.
	_statePending: boolean,
	-- The Air Pose as the server last heard it.
	_airPosing: boolean,
	_sendGetUp: () -> (),
	-- This knockdown's GetUp went out.
	_askedToGetUp: boolean,
	_team: () -> string?,
	_gravity: Vector3,
	-- workspace:Raycast; a fake in tests, which can then hand the controller a seam's side face.
	_raycast: (origin: Vector3, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	-- workspace:Spherecast, the collider's sweep; a fake in tests.
	_spherecast: (origin: Vector3, radius: number, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	_character: Model?,
	_velocity: LinearVelocity?,
	_align: AlignOrientation?,
	_filter: NormalFilter.NormalFilter,
	_attach: Attach.Attach,
	-- The ride surfaces every ray goes through.
	_surfaces: RideSurfaces.RideSurfaces,
	-- The last physics step's length: an action's push comes during a step and holds until the next.
	_stepSeconds: number,
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
-- How many surfaces one step slides along: a wall or a barrier, the floor it meets, and a third at a corner.
local CONTACT_PASSES = 3

local function worldUp(self: SkateController): Vector3
	return -self._gravity.Unit
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

-- The stick as a direction on the surface the skater rides, as the camera shows it: the camera rolls with that surface
-- (CameraController), so on a wall the stick's right is the screen's right along the wall.
local function stickDirection(self: SkateController, stick: Vector2, up: Vector3): Vector3
	local camera = self._camera.CFrame
	local right = Vectors.alongSurface(camera.RightVector, up)
	local forward = Vectors.alongSurface(camera.LookVector, up)
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
	local result = self._raycast(root.Position, direction, self._surfaces.params)
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
	if self._input.knockedDown or self._inputController.paused then
		if attach.leader ~= nil then
			attach:reset()
			skater:release(Vector3.zero)
		end
		skater:step(self._input, self._ground, dt)
		return
	end
	local found: Attach.Candidate? = if attach.leader == nil
		then Attach.findLeader(movement, root.Position, self._teammates)
		else nil
	local leader: Attach.Candidate? = if attach.leader ~= nil
		then currentLeader(self)
		elseif keys.attach then found
		else nil
	local change = attach:update(dt, keys.attach, leader, self._input.move)
	self.attachable = attach.leader ~= nil or (found ~= nil and attach.cooldownLeft == 0)
	if attach.leader ~= nil and leader ~= nil then
		skater:follow(Attach.target(movement, leader), root.Position, leader.velocity, leader.forward)
		return
	end
	if change == "Released" then
		skater:release(attach.releaseDirection)
	end
	skater:step(self._input, self._ground, dt)
end

-- The skater body's velocity has no force limit, so a skater moving into a surface pressed its collider through it
-- (measured: through the arena's 1-stud wall at 120 studs/s and over, #176). So each ride surface or barrier
-- (RideSurfaces.solid, A7) the collider touches, or reaches before the next step, takes its part of the velocity, and
-- the skater slides along it. A sphere cast misses a part it starts touching (measured), so the collider is swept from
-- a radius behind the root. A cast that meets an edge reports a normal from the edge, and sliding along a wall it
-- presses into, the collider meets the next slab's edge at their seam (measured: normal (-0.49, 0, 0.87), and 120
-- studs/s along the wall became 28). So the skater slides along the face that a ray from its root, along the cast's
-- normal, meets: at a seam, the wall itself.
local function collide(self: SkateController, root: BasePart, skater: SkateMath.Skater, dt: number)
	local radius = self._config.Movement.colliderDiameter / 2
	for _ = 1, CONTACT_PASSES do
		local velocity = skater.velocity
		local speed = velocity.Magnitude
		if speed <= Vectors.EPSILON then
			return
		end
		local direction = velocity / speed
		local origin = root.Position - direction * radius
		local travel = radius + speed * dt
		local params = self._surfaces.solid
		local hit = self._spherecast(origin, radius, direction * travel, params)
		if hit == nil then
			return
		end
		local face = self._raycast(root.Position, -hit.Normal * (radius + travel), params)
		if face == nil or not skater:block(face.Normal) then
			return
		end
	end
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

-- Sends pump, brake and the Air Pose when they change, within the server's rate limit: a change the limit holds back
-- goes out as the latest state once it may, since the server would drop it and nothing would send it again.
local function shareState(self: SkateController)
	local keys = self._keys
	local posing = (self.skater :: SkateMath.Skater).airPosing
	if keys.pump ~= self.pumping or keys.brake ~= self.braking or posing ~= self._airPosing then
		self.pumping = keys.pump
		self.braking = keys.brake
		self._airPosing = posing
		self._statePending = true
	end
	if self._statePending and self._stateLimiter:allow(Remotes.names.SkateState, self._clock()) then
		self._statePending = false
		self._sendSkateState(self.pumping, self.braking, self._airPosing)
	end
end

-- A stick held through the knockdown asks at once: the server gets the skater up no sooner than Actions.getUpAfter.
local function askToGetUp(self: SkateController)
	if not self.knockedDown then
		self._askedToGetUp = false
	elseif not self._askedToGetUp and self._keys.move.Magnitude > 0 then
		self._askedToGetUp = true
		self._sendGetUp()
	end
end

-- The kickoff freeze (the server anchors every root while it places them), and the wait for the arena: the skater
-- starts from rest, upright and facing where the server put them, with no attach held over, no dive and no jump pressed
-- during the countdown. Pump and brake are still shared, so other players see what this one holds.
local function freeze(self: SkateController, root: BasePart, skater: SkateMath.Skater)
	self._inputController:read(self._keys)
	skater:stop()
	self.diving = false
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
	dependencies = { "Config", "InputController", "RideSurfaces" },
	skater = nil,
	pumping = false,
	braking = false,
	move = Vector3.zero,
	knockedDown = false,
	frozen = false,
	diving = false,
	attachable = false,
	_config = nil :: any,
	_inputController = nil :: any,
	_camera = nil :: any,
	_skaters = function(): { SkaterView }
		return {}
	end,
	_sendSkateState = function(_pump: boolean, _brake: boolean, _airPose: boolean) end,
	_stateLimiter = nil :: any,
	_clock = os.clock,
	_statePending = false,
	_airPosing = false,
	_sendGetUp = function() end,
	_askedToGetUp = false,
	_team = function(): string?
		return nil
	end,
	_gravity = Vector3.zero,
	_raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
		return nil
	end,
	_spherecast = function(
		_origin: Vector3,
		_radius: number,
		_direction: Vector3,
		_params: RaycastParams
	): RaycastResult?
		return nil
	end,
	_character = nil,
	root = nil,
	_velocity = nil,
	_align = nil,
	_filter = nil :: any,
	_attach = nil :: any,
	_surfaces = nil :: any,
	_stepSeconds = 0,
	_keys = nil :: any,
	_input = nil :: any,
	_ground = nil :: any,
	_sources = {},
	_teammates = {},
	_views = {},
	_playerList = nil,

	-- deps.Camera, deps.Skaters, deps.SendSkateState, deps.SendGetUp, deps.Clock, deps.Gravity, deps.Team, deps.Raycast
	-- and deps.Spherecast replace the live game in tests.
	init = function(self: SkateController, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._inputController = deps.InputController
		self._camera = deps.Camera or workspace.CurrentCamera
		self._skaters = deps.Skaters or function(): { SkaterView }
			return playersAround(self)
		end
		self._sendSkateState = deps.SendSkateState
			or function(pump: boolean, brake: boolean, airPose: boolean)
				Remotes.get(ReplicatedStorage, Remotes.names.SkateState)
					:FireServer({ pump = pump, brake = brake, airPose = airPose })
			end
		self._stateLimiter = RateLimiter.new(config.Network.maxSkateStatesPerSecond)
		self._clock = deps.Clock or os.clock
		self._statePending = false
		self._airPosing = false
		self._sendGetUp = deps.SendGetUp
			or function()
				Remotes.get(ReplicatedStorage, Remotes.names.GetUp):FireServer({})
			end
		self._askedToGetUp = false
		self._team = deps.Team
			or function(): string?
				return (Players.LocalPlayer :: Player):GetAttribute(Attributes.Team) :: string?
			end
		self._gravity = deps.Gravity or Vector3.new(0, -workspace.Gravity, 0)
		self._raycast = deps.Raycast
			or function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Raycast(origin, direction, params)
			end
		self._spherecast = deps.Spherecast
			or function(origin: Vector3, radius: number, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Spherecast(origin, radius, direction, params)
			end
		self._filter = NormalFilter.new(config.Movement.normalFilter, worldUp(self))
		self._attach = Attach.new(config.Movement)
		self._surfaces = deps.RideSurfaces
		self._stepSeconds = 0
		self._keys = InputController.newKeys()
		self._input = {
			move = Vector3.zero,
			pump = false,
			brake = false,
			jump = false,
			draftAccel = 0,
			knockedDown = false,
			diving = false,
		}
		self._ground = { hit = false, normal = worldUp(self), distance = 0 }
		self._sources = {}
		self._teammates = {}
		self._views = {}
		self.skater = nil
		self._character = nil
		self.root = nil
		self.pumping = false
		self.braking = false
		self.move = Vector3.zero
		self.knockedDown = false
		self.frozen = false
		self.diving = false
		self.attachable = false
	end,

	start = function(self: SkateController)
		self._playerList = PlayerList.new(Players)
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
		self._character = character
		self.root = root
		self._velocity = velocity
		self._align = align
		self._filter:reset(worldUp(self))
		self._attach = Attach.new(self._config.Movement)
		-- Jump presses made while there was no character to jump are spent here, not on the new one.
		self._inputController:read(self._keys)
		self.pumping = false
		self.braking = false
		self.diving = false
		self._airPosing = false
		self._statePending = false
	end,

	hasSkater = function(self: SkateController): boolean
		local root = self.root
		return self.skater ~= nil and root ~= nil and root.Parent ~= nil
	end,

	step = function(self: SkateController, dt: number)
		-- Only a free skater's step finds a teammate to attach behind.
		self.attachable = false
		if not self:hasSkater() then
			return
		end
		local skater = self.skater :: SkateMath.Skater
		local root = self.root :: BasePart
		local character = self._character :: Model
		self.knockedDown = character:GetAttribute(Attributes.KnockedDown) == true
		if self.knockedDown then
			self.diving = false
		end
		self.frozen = root.Anchored or not self._surfaces.ready
		if self.frozen then
			freeze(self, root, skater)
			return
		end

		local keys = self._keys
		self._inputController:read(keys)
		local input = self._input
		input.move = stickDirection(self, keys.move, skater.up)
		input.pump = keys.pump
		input.brake = keys.brake
		input.jump = keys.jump
		input.knockedDown = self.knockedDown or self.diving
		input.diving = self.diving
		self.move = input.move
		castGround(self, root, skater, dt)
		gatherOthers(self)
		input.draftAccel = Draft.accel(self._config.Movement, root.Position, self._sources)
		moveSkater(self, root, skater, dt)
		self._stepSeconds = dt
		collide(self, root, skater, dt)
		apply(self, skater)
		shareState(self)
		askToGetUp(self)
	end,

	push = function(self: SkateController, change: Vector3, launch: boolean)
		local skater = self.skater
		local root = self.root
		if skater ~= nil and root ~= nil and self._velocity ~= nil then
			skater:push(change, launch)
			collide(self, root, skater, self._stepSeconds)
			apply(self, skater)
		end
	end,
}

return SkateController
