--!strict
-- The ball in the arena (spec §9.3): one server-owned physics part that BallState says what to do with. It is hidden
-- (in ServerStorage, so its next spawn is never replicated early) until a kickoff ends, then spawns at a random ball
-- spawn. Each frame `step` reports how it really moved, a throw since the last frame, and who caught it. Jumps the
-- server makes (a spawn, a respawn, the snap into a catcher's hand) are never reported as movement, so they can never
-- cross a gate or the ring.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local BallState = require(ReplicatedStorage.Shared.Ball.BallState)
local Bounds = require(ReplicatedStorage.Shared.Arena.Geometry.Bounds)
local Config = require(ReplicatedStorage.Shared.Config)
local Pickup = require(ReplicatedStorage.Shared.Ball.Pickup)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- A player who can catch: their root decides the distance, the ball is held in their hand.
export type Holder = { player: PlayerId, root: BasePart, hand: BasePart }

-- One frame's report. `from`/`to` are valid when `moved`; `pickupPosition`/`pickupVelocity` when `picker` is set.
export type BallFrame = {
	moved: boolean,
	from: Vector3,
	to: Vector3,
	thrower: PlayerId?,
	picker: PlayerId?,
	pickupPosition: Vector3,
	pickupVelocity: Vector3,
	respawned: boolean,
}

-- Spelled out so the module is a Loader.LoadableModule (whose start is optional) and callers see its methods.
export type BallService = {
	name: string,
	dependencies: { string },
	init: (self: BallService, deps: { [string]: any }) -> (),
	start: ((self: BallService) -> ())?,
	part: Part,
	state: BallState.BallState,
	hide: (self: BallService) -> (),
	spawn: (self: BallService) -> (),
	kill: (self: BallService) -> (),
	throw: (self: BallService, player: PlayerId, velocity: Vector3) -> (),
	drop: (self: BallService) -> (),
	onTouched: (self: BallService, hit: BasePart) -> (),
	step: (self: BallService, dt: number, holders: { Holder }) -> BallFrame,
	destroy: (self: BallService) -> (),
	_config: Config.GameConfig,
	_spawns: { CFrame },
	_random: Random,
	_reach: number,
	_hidden: boolean,
	-- A jump made by the server since the last step: the next step reports no movement.
	_teleported: boolean,
	_last: Vector3,
	_pendingThrower: PlayerId?,
	_weld: WeldConstraint?,
	_touched: RBXScriptConnection?,
	_canPickUp: (PlayerId) -> boolean,
	_candidates: { Pickup.Candidate },
	_frame: BallFrame,
}

local function newBallPart(config: Config.GameConfig): Part
	local ball = config.Ball
	local skin = BallSkins.get(BallSkins.DEFAULT)
	local part = Instance.new("Part")
	part.Name = "Ball"
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

-- Lets go of the ball if someone carries it: a free physics part again, simulated by the server. The weld goes
-- first: network ownership cannot be set on a part welded to an anchored one (a frozen character).
local function release(self: BallService)
	local weld = self._weld
	if weld == nil then
		return
	end
	weld:Destroy()
	self._weld = nil
	local part = self.part
	part.Massless = false
	part.CanCollide = true
	part:SetNetworkOwner(nil)
end

local function attach(self: BallService, holder: Holder)
	local part = self.part
	part.CFrame = holder.hand.CFrame * CFrame.new(0, -self._config.Ball.radius, 0)
	part.Massless = true
	part.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = holder.hand
	weld.Part1 = part
	weld.Parent = part
	self._weld = weld
	self._teleported = true
end

local function placeAtRandomSpawn(self: BallService)
	release(self)
	local part = self.part
	part.CFrame = self._spawns[self._random:NextInteger(1, #self._spawns)]
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.Parent = workspace
	part:SetNetworkOwner(nil)
	self._hidden = false
	self._teleported = true
end

local function isCharacterPart(hit: BasePart): boolean
	local model = hit:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function holderOf(holders: { Holder }, player: PlayerId): Holder
	for _, holder in holders do
		if holder.player == player then
			return holder
		end
	end
	error(`BallService: no holder for player "{player}"`, 0)
end

-- Fills the reused candidate list from this frame's holders.
local function candidatesFrom(self: BallService, holders: { Holder }): { Pickup.Candidate }
	local candidates = self._candidates
	for index, holder in holders do
		local candidate = candidates[index]
		if candidate == nil then
			candidates[index] = { player = holder.player, position = holder.root.Position }
		else
			candidate.player = holder.player
			candidate.position = holder.root.Position
		end
	end
	for index = #candidates, #holders + 1, -1 do
		candidates[index] = nil
	end
	return candidates
end

local BallService: BallService = {
	name = "BallService",
	dependencies = { "Config", "ArenaService" },
	part = nil :: any,
	state = nil :: any,
	_config = nil :: any,
	_spawns = {},
	_random = Random.new(),
	_reach = 0,
	_hidden = true,
	_teleported = true,
	_last = Vector3.zero,
	_candidates = {},
	_canPickUp = function(_player: PlayerId): boolean
		return false
	end,
	_frame = nil :: any,

	-- deps.Random makes the spawn choice repeatable in tests.
	init = function(self: BallService, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._spawns = deps.ArenaService.arena.ballSpawns
		self._random = deps.Random or Random.new()
		self._reach = config.Ball.pickupRadius + config.Network.pickupLagToleranceStuds
		self.state = BallState.new(config.Ball.rethrowPickupDelay)
		self._canPickUp = function(player: PlayerId): boolean
			return self.state:canPickUp(player)
		end
		self._candidates = {}
		self._frame = {
			moved = false,
			from = Vector3.zero,
			to = Vector3.zero,
			thrower = nil,
			picker = nil,
			pickupPosition = Vector3.zero,
			pickupVelocity = Vector3.zero,
			respawned = false,
		}
		self._weld = nil
		self._pendingThrower = nil
		local part = newBallPart(config)
		part.Parent = ServerStorage
		self.part = part
		self._hidden = true
		self._teleported = true
		self._last = part.Position
		self._touched = part.Touched:Connect(function(hit: BasePart)
			self:onTouched(hit)
		end)
	end,

	hide = function(self: BallService)
		release(self)
		self.state:kill()
		self.part.Parent = ServerStorage
		self._hidden = true
		self._teleported = true
	end,

	spawn = function(self: BallService)
		placeAtRandomSpawn(self)
		if self.state.status == "Dead" then
			self.state:release()
		else
			self.state:respawn()
		end
	end,

	kill = function(self: BallService)
		release(self)
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

	drop = function(self: BallService)
		release(self)
		self.state:drop()
	end,

	onTouched = function(self: BallService, hit: BasePart)
		if self.state.status == "Flying" and not isCharacterPart(hit) then
			self.state:land()
		end
	end,

	step = function(self: BallService, dt: number, holders: { Holder }): BallFrame
		local frame = self._frame
		frame.moved = false
		frame.thrower = nil
		frame.picker = nil
		frame.respawned = false
		if self._hidden then
			return frame
		end

		local position = self.part.Position
		if self._teleported then
			self._teleported = false
		else
			frame.moved = true
			frame.from = self._last
			frame.to = position
		end
		self._last = position

		local state = self.state
		state:tick(dt)
		frame.thrower = self._pendingThrower
		self._pendingThrower = nil

		if state.status ~= "Loose" and state.status ~= "Flying" then
			return frame
		end
		local ball = self._config.Ball
		if
			Bounds.isOut(self._config.Arena, position, ball.outOfBoundsMargin)
			or state.looseSeconds >= ball.ballIdleResetSeconds
		then
			placeAtRandomSpawn(self)
			state:respawn()
			frame.respawned = true
			return frame
		end

		local picker = Pickup.choose(position, candidatesFrom(self, holders), self._reach, self._canPickUp)
		if picker ~= nil then
			frame.picker = picker
			frame.pickupPosition = position
			frame.pickupVelocity = self.part.AssemblyLinearVelocity
			attach(self, holderOf(holders, picker))
			state:pickUp(picker)
		end
		return frame
	end,

	destroy = function(self: BallService)
		if self._touched ~= nil then
			self._touched:Disconnect()
			self._touched = nil
		end
		local part: Part? = self.part
		if part ~= nil then
			part:Destroy()
		end
		self._weld = nil
	end,
}

return BallService
