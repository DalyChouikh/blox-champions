--!strict
-- The ball in the arena (spec §9.3): one server-owned physics part, in its own model that streams to every client, that
-- BallState says what to do with. It is hidden (in ServerStorage, so its next spawn is never replicated early) until a
-- kickoff ends, then drops in from above (Ball/DropIn, #321). A ball that leaves the arena (the box inside the glass,
-- its top included: Bounds.inArena) drops in again whatever its state, a loose one resting a while on something
-- nobody skates (the goal's rim, #308) too, and one Roblox destroys (fallen past FallenPartsDestroyHeight) is rebuilt.
-- Each frame `step` reports how it really moved, a throw since the last frame, who caught it, and whose body it
-- touched. Jumps the server makes (a drop-in's start, the snap to a catcher's side, a carrier it moves, a drop it
-- places) are never reported as movement, so they can never cross a gate or the ring. A pass flies flat, its weight
-- cancelled, and homes on its target, until it touches anything or anyone or the target can no longer catch; a drop-in
-- falls steadily the lap's way, its weight cancelled too, until it touches anything or anyone; then either falls like
-- any ball. A ball passes through the player who let go of it until it is clear of them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local BallState = require(ReplicatedStorage.Shared.Ball.BallState)
local Bounds = require(ReplicatedStorage.Shared.Arena.Geometry.Bounds)
local Config = require(ReplicatedStorage.Shared.Config)
local DropIn = require(ReplicatedStorage.Shared.Ball.DropIn)
local Homing = require(ReplicatedStorage.Shared.Ball.Homing)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)
local Pickup = require(ReplicatedStorage.Shared.Ball.Pickup)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

type PlayerId = Types.PlayerId

-- A player on the field: their root decides the distance and carries the ball. Only one who `canCatch` (not knocked
-- down) catches it; anyone's body touches it but the thrower's, inside the rethrow delay.
export type Holder = { player: PlayerId, root: BasePart, canCatch: boolean }

-- One frame's report. `from`/`to` are valid when `moved`; `pickupPosition`/`pickupVelocity` when `picker` is set;
-- `touchPosition`/`touchVelocity` when `toucher` is set: the nearest body a free ball touched without being caught.
export type BallFrame = {
	moved: boolean,
	from: Vector3,
	to: Vector3,
	thrower: PlayerId?,
	picker: PlayerId?,
	pickupPosition: Vector3,
	pickupVelocity: Vector3,
	toucher: PlayerId?,
	touchPosition: Vector3,
	touchVelocity: Vector3,
	respawned: boolean,
}

-- Spelled out so the module is a Loader.LoadableModule (whose start is optional) and callers see its methods.
export type BallService = {
	name: string,
	dependencies: { string },
	init: (self: BallService, deps: { [string]: any }) -> (),
	start: ((self: BallService) -> ())?,
	-- Holds the part; ModelStreamingMode.Persistent, so clients always have the ball.
	model: Model,
	part: Part,
	state: BallState.BallState,
	hide: (self: BallService) -> (),
	spawn: (self: BallService) -> (),
	kill: (self: BallService) -> (),
	throw: (self: BallService, player: PlayerId, velocity: Vector3) -> (),
	-- A throw that flies flat and homes on `target`, or flies flat along `velocity` with none.
	pass: (self: BallService, player: PlayerId, velocity: Vector3, target: PlayerId?) -> (),
	-- A given velocity replaces the ball's (a knocked-down carrier's momentum). Either is held to the speed limit.
	drop: (self: BallService, velocity: Vector3?) -> (),
	-- Lets go of a carried ball, still, at `position`: where its carrier was last in the arena (MovementGuard).
	dropAt: (self: BallService, position: Vector3) -> (),
	-- The server moved the carrier, and the ball welded to them: the next step reports no movement.
	jumped: (self: BallService) -> (),
	onTouched: (self: BallService, hit: BasePart) -> (),
	step: (self: BallService, dt: number, holders: { Holder }) -> BallFrame,
	destroy: (self: BallService) -> (),
	_config: Config.GameConfig,
	_random: Random,
	_reach: number,
	-- How close a body is to touch the ball: the ball's and the collider's radii, plus the lag tolerance.
	_contact: number,
	_homingAccel: number,
	-- The fastest a ball leaving a carrier may keep moving: their client sets their velocity, and the ball's with it.
	_speedLimit: number,
	-- The pass's target while it homes.
	_passTarget: PlayerId?,
	-- While the ball drops in, until it first touches anything or anyone (#321).
	_droppingIn: boolean,
	-- The world's gravity, which a pass's lift cancels.
	_gravity: Vector3,
	_hidden: boolean,
	-- A jump made by the server since the last step: the next step reports no movement.
	_teleported: boolean,
	_last: Vector3,
	_pendingThrower: PlayerId?,
	_weld: Weld?,
	-- Built with each ball part. While enabled, its Part1 is the collider of the player who just let go of the ball,
	-- until the ball is clear of them.
	_grace: NoCollisionConstraint,
	-- Built with each ball part: the ball's weight, upward. Enabled while a pass or a drop-in flies, so a pass
	-- flies flat and a drop-in falls at its steady speed.
	_lift: VectorForce,
	_touched: RBXScriptConnection?,
	-- What a resting ball lies on: a ray into the arena only, from its center to a radius past its bottom (#308).
	_restParams: RaycastParams,
	_restReach: Vector3,
	-- How long the loose ball has rested on something nobody skates.
	_strandedSeconds: number,
	_canPickUp: (PlayerId) -> boolean,
	-- Whose body the ball can touch: anyone but its thrower inside the rethrow delay (the rules never count theirs).
	_canTouch: (PlayerId) -> boolean,
	-- Every holder this frame, and which of them can catch.
	_candidates: { Pickup.Candidate },
	_catchers: { [PlayerId]: boolean },
	_frame: BallFrame,
}

local function newBallPart(config: Config.GameConfig): Part
	local ball = config.Ball
	local skin = BallSkins.get(BallSkins.DEFAULT)
	local part = Instance.new("Part")
	part.Name = "Ball"
	part:AddTag(Tags.Ball)
	-- Before Size, and a uniform Size: a Ball part keeps whatever non-uniform size it is given.
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * (2 * ball.radius)
	part.CustomPhysicalProperties = PhysicalProperties.new(ball.density, ball.friction, ball.elasticity)
	part.Color = skin.color
	part.Material = skin.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- A new ball, hidden: its model in ServerStorage.
local function build(self: BallService)
	if self._touched ~= nil then
		self._touched:Disconnect()
	end
	local model = Instance.new("Model")
	model.Name = "Ball"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local part = newBallPart(self._config)
	part.Parent = model
	local grace = Instance.new("NoCollisionConstraint")
	grace.Part0 = part
	grace.Enabled = false
	grace.Parent = part
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Force = -self._gravity * part:GetMass()
	lift.Enabled = false
	lift.Parent = part
	model.Parent = ServerStorage
	self.model = model
	self.part = part
	self._weld = nil
	self._grace = grace
	self._lift = lift
	self._hidden = true
	self._teleported = true
	self._last = part.Position
	self._touched = part.Touched:Connect(function(hit: BasePart)
		self:onTouched(hit)
	end)
end

-- True (after building a new, hidden ball) when Roblox destroyed the ball.
local function rebuiltIfDestroyed(self: BallService): boolean
	if self.model.Parent ~= nil and self.part.Parent == self.model then
		return false
	end
	-- Roblox removes the model with its last part; one left behind empty is removed here.
	local old = self.model
	build(self)
	old:Destroy()
	return true
end

-- The pass or the drop-in is over, or never was: the ball falls, holds no drop-in's velocity, homes on no one.
local function endGuidance(self: BallService)
	self._passTarget = nil
	self._droppingIn = false
	self._lift.Enabled = false
end

-- Lets go of the ball if someone carries it: a free physics part again, simulated by the server. The weld goes
-- first: network ownership is set for a whole assembly, and while welded the ball is part of its carrier's. The ball
-- leaves from the carrier's side, within touch of their collider, so it passes through them until it is clear of
-- them: a throw across their body would otherwise bounce off it. It keeps the carrier's velocity, read while still
-- welded into their assembly, up to the speed limit.
local function release(self: BallService)
	local weld = self._weld
	if weld == nil then
		return
	end
	local part = self.part
	local carried = part.AssemblyLinearVelocity
	local root = weld.Part0
	local character = if root then root.Parent else nil
	local collider = if character then character:FindFirstChild(SkaterRig.collider) :: BasePart? else nil
	local grace = self._grace
	if collider then
		grace.Part1 = collider
		grace.Enabled = true
	else
		grace.Enabled = false
	end
	weld:Destroy()
	self._weld = nil
	part.Massless = false
	part.CanCollide = true
	part.CanTouch = true
	part.AssemblyLinearVelocity = Vectors.clampMagnitude(carried, self._speedLimit)
	if part:IsDescendantOf(workspace) then
		part:SetNetworkOwner(nil)
	end
end

-- Welds the ball at the carrier's side (Ball.carryOffset in their root's frame). A Weld with an explicit offset puts
-- it in the same place on every machine; while carried it is weightless and touches nothing.
local function attach(self: BallService, holder: Holder)
	endGuidance(self)
	local part = self.part
	local offset = CFrame.new(self._config.Ball.carryOffset)
	part.CFrame = holder.root.CFrame * offset
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	local weld = Instance.new("Weld")
	weld.Part0 = holder.root
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	self._weld = weld
	self._teleported = true
end

-- Into play from above at a random start (Ball/DropIn), holding the drop-in's velocity there, its weight cancelled.
local function dropIn(self: BallService)
	rebuiltIfDestroyed(self)
	release(self)
	endGuidance(self)
	local config = self._config
	local part = self.part
	local start = DropIn.pick(config.Arena, config.Ball, self._random)
	part.CFrame = CFrame.new(start)
	part.AssemblyLinearVelocity = DropIn.velocity(config.Arena, config.Ball, start)
	part.AssemblyAngularVelocity = Vector3.zero
	self.model.Parent = workspace
	part:SetNetworkOwner(nil)
	self._hidden = false
	self._teleported = true
	self._droppingIn = true
	self._lift.Enabled = true
end

-- Back into play by a drop-in from wherever it was, a carried ball taken from its carrier first.
local function respawn(self: BallService, frame: BallFrame)
	if self.state.status == "Carried" then
		release(self)
		self.state:drop()
	end
	dropIn(self)
	self.state:respawn()
	frame.respawned = true
end

local function isCharacterPart(hit: BasePart): boolean
	local model = hit:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function findHolder(holders: { Holder }, player: PlayerId): Holder?
	for _, holder in holders do
		if holder.player == player then
			return holder
		end
	end
	return nil
end

local function holderOf(holders: { Holder }, player: PlayerId): Holder
	local holder = findHolder(holders, player)
	if holder == nil then
		error(`BallService: no holder for player "{player}"`, 0)
	end
	return holder
end

-- Fills the reused candidate list from this frame's holders, and which of them can catch.
local function candidatesFrom(self: BallService, holders: { Holder }): { Pickup.Candidate }
	local candidates = self._candidates
	local catchers = self._catchers
	table.clear(catchers)
	for index, holder in holders do
		catchers[holder.player] = holder.canCatch
		Pickup.setCandidate(candidates, index, holder.player, holder.root.Position)
	end
	Pickup.trimCandidates(candidates, #holders)
	return candidates
end

-- Once the ball is beyond touch distance of the player who let go of it, it can hit them again.
local function clearOfReleaser(self: BallService, position: Vector3)
	local grace = self._grace
	if grace.Enabled and (position - grace.Part1.Position).Magnitude > self._contact then
		grace.Enabled = false
	end
end

-- Steers a pass toward its target while it flies and the target can catch. Once either stops, the pass is over.
local function home(self: BallService, holders: { Holder }, position: Vector3, dt: number)
	local target = self._passTarget
	if target == nil then
		return
	end
	local holder = findHolder(holders, target)
	if self.state.status ~= "Flying" or holder == nil or not holder.canCatch then
		endGuidance(self)
		return
	end
	local part = self.part
	part.AssemblyLinearVelocity =
		Homing.step(position, part.AssemblyLinearVelocity, holder.root.Position, self._homingAccel, dt)
end

-- Holds a drop-in's velocity where the ball now is (Q116): the lap's way round a curved end too.
local function holdDropIn(self: BallService, position: Vector3)
	if self._droppingIn then
		local config = self._config
		self.part.AssemblyLinearVelocity = DropIn.velocity(config.Arena, config.Ball, position)
	end
end

-- Whether the loose ball has rested Ball.strandedSeconds on something nobody skates (#308, Q93): slower than
-- Ball.restSpeed on any part of the arena but a ride surface (the goal's rim). Any other frame, a carried ball's
-- included, starts the count over: a ball resting on a floor, a bank, a wall or the glass stays where it is.
local function stranded(self: BallService, position: Vector3, dt: number): boolean
	local ball = self._config.Ball
	local resting = self.state.status ~= "Carried" and self.part.AssemblyLinearVelocity.Magnitude < ball.restSpeed
	local under = if resting then workspace:Raycast(position, self._restReach, self._restParams) else nil
	if under == nil or TaggedLayout.isRideSurface(under.Instance) then
		self._strandedSeconds = 0
		return false
	end
	self._strandedSeconds += dt
	return self._strandedSeconds >= ball.strandedSeconds
end

local BallService: BallService = {
	name = "BallService",
	dependencies = { "Config", "ArenaService" },
	model = nil :: any,
	part = nil :: any,
	state = nil :: any,
	_config = nil :: any,
	_random = Random.new(),
	_reach = 0,
	_contact = 0,
	_homingAccel = 0,
	_speedLimit = 0,
	_passTarget = nil,
	_droppingIn = false,
	_gravity = Vector3.zero,
	_hidden = true,
	_teleported = true,
	_last = Vector3.zero,
	_grace = nil :: any,
	_lift = nil :: any,
	_candidates = {},
	_catchers = {},
	_restParams = nil :: any,
	_restReach = Vector3.zero,
	_strandedSeconds = 0,
	_canPickUp = function(_player: PlayerId): boolean
		return false
	end,
	_canTouch = function(_player: PlayerId): boolean
		return false
	end,
	_frame = nil :: any,

	-- deps.Random makes the drop-ins' spots repeatable in tests.
	init = function(self: BallService, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._random = deps.Random or Random.new()
		local lagTolerance = config.Network.pickupLagToleranceStuds
		self._reach = config.Ball.pickupRadius + lagTolerance
		self._contact = config.Ball.radius + config.Movement.colliderDiameter / 2 + lagTolerance
		self._homingAccel = (config.Actions.Pass.pass :: Config.PassSettings).homingAccel
		self._speedLimit = MovementCheck.speedLimit(config.Movement, config.Network)
		self._passTarget = nil
		self._droppingIn = false
		self._gravity = Config.gravity(config)
		self.state = BallState.new(config.Ball.rethrowPickupDelay)
		local restParams = RaycastParams.new()
		restParams.FilterType = Enum.RaycastFilterType.Include
		restParams.FilterDescendantsInstances = { deps.ArenaService.model }
		self._restParams = restParams
		self._restReach = Vector3.new(0, -2 * config.Ball.radius, 0)
		self._strandedSeconds = 0
		self._canPickUp = function(player: PlayerId): boolean
			return self._catchers[player] == true and self.state:canPickUp(player)
		end
		self._canTouch = function(player: PlayerId): boolean
			return self.state:canPickUp(player)
		end
		self._candidates = {}
		self._catchers = {}
		self._frame = {
			moved = false,
			from = Vector3.zero,
			to = Vector3.zero,
			thrower = nil,
			picker = nil,
			pickupPosition = Vector3.zero,
			pickupVelocity = Vector3.zero,
			toucher = nil,
			touchPosition = Vector3.zero,
			touchVelocity = Vector3.zero,
			respawned = false,
		}
		self._pendingThrower = nil
		self._touched = nil
		build(self)
	end,

	hide = function(self: BallService)
		rebuiltIfDestroyed(self)
		release(self)
		endGuidance(self)
		self.state:kill()
		self.model.Parent = ServerStorage
		self._hidden = true
		self._teleported = true
	end,

	spawn = function(self: BallService)
		dropIn(self)
		if self.state.status == "Dead" then
			self.state:release()
		else
			self.state:respawn()
		end
	end,

	kill = function(self: BallService)
		release(self)
		endGuidance(self)
		self.state:kill()
	end,

	throw = function(self: BallService, player: PlayerId, velocity: Vector3)
		local carrier = self.state.carrier
		if carrier ~= player then
			error(`BallService: only the carrier can throw (carrier: {carrier or "none"}, thrower: {player})`, 0)
		end
		release(self)
		self.part.AssemblyLinearVelocity = velocity
		self.state:throw()
		self._pendingThrower = player
	end,

	pass = function(self: BallService, player: PlayerId, velocity: Vector3, target: PlayerId?)
		self:throw(player, velocity)
		self._passTarget = target
		self._lift.Enabled = true
	end,

	drop = function(self: BallService, velocity: Vector3?)
		release(self)
		if velocity ~= nil then
			self.part.AssemblyLinearVelocity = Vectors.clampMagnitude(velocity, self._speedLimit)
		end
		self.state:drop()
	end,

	dropAt = function(self: BallService, position: Vector3)
		self:drop(Vector3.zero)
		local part = self.part
		part.CFrame = CFrame.new(position)
		part.AssemblyAngularVelocity = Vector3.zero
		self._teleported = true
	end,

	jumped = function(self: BallService)
		self._teleported = true
	end,

	onTouched = function(self: BallService, hit: BasePart)
		if isCharacterPart(hit) then
			return
		end
		if self.state.status == "Flying" then
			self.state:land()
		end
		endGuidance(self)
	end,

	step = function(self: BallService, dt: number, holders: { Holder }): BallFrame
		local frame = self._frame
		frame.moved = false
		frame.thrower = nil
		frame.picker = nil
		frame.toucher = nil
		frame.respawned = false
		if self._hidden then
			return frame
		end
		local state = self.state
		if rebuiltIfDestroyed(self) then
			if state.status ~= "Dead" then
				respawn(self, frame)
			end
			return frame
		end

		local position = self.part.Position
		clearOfReleaser(self, position)
		if self._teleported then
			self._teleported = false
		else
			frame.moved = true
			frame.from = self._last
			frame.to = position
		end
		self._last = position

		state:tick(dt)
		frame.thrower = self._pendingThrower
		self._pendingThrower = nil

		local ball = self._config.Ball
		local out = not Bounds.inArena(self._config.Arena, position, ball.outOfBoundsMargin)
		if state.status == "Dead" then
			-- Out of play anyway: parked until the next kickoff, before it can fall out of the world.
			if out then
				self:hide()
			end
			return frame
		end
		if out or stranded(self, position, dt) then
			respawn(self, frame)
			return frame
		end
		if state.status == "Carried" then
			return frame
		end

		local candidates = candidatesFrom(self, holders)
		local picker = Pickup.choose(position, candidates, self._reach, self._canPickUp)
		if picker ~= nil then
			frame.picker = picker
			frame.pickupPosition = position
			frame.pickupVelocity = self.part.AssemblyLinearVelocity
			attach(self, holderOf(holders, picker))
			state:pickUp(picker)
			return frame
		end
		local toucher = Pickup.choose(position, candidates, self._contact, self._canTouch)
		if toucher ~= nil then
			frame.toucher = toucher
			frame.touchPosition = position
			frame.touchVelocity = self.part.AssemblyLinearVelocity
			endGuidance(self)
		end
		home(self, holders, position, dt)
		holdDropIn(self, position)
		return frame
	end,

	destroy = function(self: BallService)
		if self._touched ~= nil then
			self._touched:Disconnect()
			self._touched = nil
		end
		local model: Model? = self.model
		if model ~= nil then
			model:Destroy()
		end
		self._weld = nil
	end,
}

return BallService
