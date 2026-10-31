--!strict
-- Where this screen draws the ball (spec §9.3, #311, #316), first each frame before anything that reads it (the
-- markers, the carrier's beam).
-- - Loose: where the server's last state (the BallState stream) says it is now. Roblox's own replication drew it 0.19 s
--   late and unevenly (46-248 studs/s a frame for a steady 90, measured in a 2-player test), and other screens drew a
--   thrown ball still for 0.29 s. A state is carried on to now (Ball/Shown) and the drawn ball closes on it over
--   Network.ballStream.correctionSeconds, or jumps across a wider gap than snapStuds (a drop-in, a respawn). Between
--   states it is never drawn through the arena: the server's ball has bounced, and its next state says how. With no
--   state since it was let go, Roblox's spot stands. A state older than the newest, or from before the last catch this
--   screen saw, is stale: the stream is unreliable, and the catch reaches the screen by another road.
-- - Caught: the server welds it at the carry spot at once, but that weld can reach this screen while it still draws the
--   ball short of the hand (36.6 studs, measured), so the pull is drawn here (the owner, Q91, Q131, Q132): the weld's
--   C0 is written here (a client's write stays on its client, and the server never writes it again) from where this
--   screen last drew the ball, in the carrier's root frame, to the server's carry spot over Ball.pickupPullSeconds
--   (Ball/Pull); then the server's C0 again. A weld places its part at once.
-- Idle and carried it allocates nothing; drawing a loose ball casts one ray a frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPart = require(script.Parent.BallPart)
local Config = require(ReplicatedStorage.Shared.Config)
local Pull = require(ReplicatedStorage.Shared.Ball.Pull)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Shown = require(ReplicatedStorage.Shared.Ball.Shown)

-- The arena's solid parts, as RideSurfaces keeps them.
type Surfaces = { solid: RaycastParams }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallView = {
	name: string,
	dependencies: { string },
	init: (self: BallView, deps: { [string]: any }) -> (),
	start: (self: BallView) -> (),
	-- The server's state of the loose ball (#316), kept when it is the newest and from after the last catch.
	receive: (self: BallView, position: Vector3, velocity: Vector3, lifted: boolean, time: number) -> (),
	step: (self: BallView, dt: number) -> (),
	_ballPart: BallPart.BallPart,
	_surfaces: Surfaces,
	_serverTime: () -> number,
	_pullSeconds: number,
	_correctionSeconds: number,
	_snapStuds: number,
	_maxAge: number,
	_gravity: Vector3,
	_radius: number,
	-- The ball part and the weld holding it at the last step: a new one of either starts over.
	_part: BasePart?,
	_weld: Weld?,
	-- Where this screen drew the ball at the last step; nil until it has drawn this ball part.
	_shown: Vector3?,
	-- The pull under way: from and to in the carrier's root frame, the server's C0 to give back, its age.
	_pulling: boolean,
	_from: Vector3,
	_to: Vector3,
	_serverC0: CFrame,
	_elapsed: number,
	-- The server's last state of the loose ball, if one has come since the last catch.
	_hasState: boolean,
	_statePosition: Vector3,
	_stateVelocity: Vector3,
	_stateLifted: boolean,
	_stateTime: number,
	-- The server's time when this screen last saw a catch.
	_caughtAt: number,
}

-- A new weld holds the ball: its pull starts from where this screen last drew the ball, if it has drawn it (a pull
-- that takes no time ends at its first step). States from before it are stale from now on.
local function begin(self: BallView, weld: Weld)
	self._hasState = false
	self._caughtAt = self._serverTime()
	local root = weld.Part0
	local shown = self._shown
	if root == nil or shown == nil then
		return
	end
	self._from = root.CFrame:PointToObjectSpace(shown)
	self._serverC0 = weld.C0
	self._to = self._serverC0.Position
	self._elapsed = 0
	self._pulling = true
end

local function advance(self: BallView, weld: Weld, dt: number)
	self._elapsed += dt
	if Pull.over(self._elapsed, self._pullSeconds) then
		weld.C0 = self._serverC0
		self._pulling = false
		return
	end
	weld.C0 = CFrame.new(Pull.offset(self._from, self._to, self._elapsed, self._pullSeconds))
end

-- The loose ball, drawn from the server's last state carried on to now.
local function draw(self: BallView, part: BasePart, dt: number)
	local age = math.clamp(self._serverTime() - self._stateTime, 0, self._maxAge)
	local gravity = if self._stateLifted then Vector3.zero else self._gravity
	local target, velocity = Shown.predict(self._statePosition, self._stateVelocity, gravity, age)
	local from = self._shown or part.Position
	local drawn, jumped = Shown.follow(from, target, velocity, dt, self._correctionSeconds, self._snapStuds)
	if not jumped then
		local hit = workspace:Raycast(from, drawn - from, self._surfaces.solid)
		if hit ~= nil then
			drawn = hit.Position + hit.Normal * self._radius
		end
	end
	self._shown = drawn
	part.Position = drawn
end

local BallView: BallView = {
	name = "BallView",
	dependencies = { "Config", "BallPart", "RideSurfaces" },
	_ballPart = nil :: any,
	_surfaces = nil :: any,
	_serverTime = function(): number
		return 0
	end,
	_pullSeconds = 0,
	_correctionSeconds = 1,
	_snapStuds = 0,
	_maxAge = 0,
	_gravity = Vector3.zero,
	_radius = 0,
	_part = nil,
	_weld = nil,
	_shown = nil,
	_pulling = false,
	_from = Vector3.zero,
	_to = Vector3.zero,
	_serverC0 = CFrame.identity,
	_elapsed = 0,
	_hasState = false,
	_statePosition = Vector3.zero,
	_stateVelocity = Vector3.zero,
	_stateLifted = false,
	_stateTime = 0,
	_caughtAt = -math.huge,

	-- deps.ServerClock replaces workspace:GetServerTimeNow in tests.
	init = function(self: BallView, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local stream = config.Network.ballStream
		self._ballPart = deps.BallPart
		self._surfaces = deps.RideSurfaces
		self._serverTime = deps.ServerClock or function(): number
			return workspace:GetServerTimeNow()
		end
		self._pullSeconds = config.Ball.pickupPullSeconds
		self._correctionSeconds = stream.correctionSeconds
		self._snapStuds = stream.snapStuds
		self._maxAge = stream.maxAgeSeconds
		self._gravity = Config.gravity(config)
		self._radius = config.Ball.radius
		self._part = nil
		self._weld = nil
		self._shown = nil
		self._pulling = false
		self._hasState = false
		self._caughtAt = -math.huge
	end,

	start = function(self: BallView)
		Remotes.getStream(ReplicatedStorage, Remotes.streams.BallState).OnClientEvent
			:Connect(function(position: Vector3, velocity: Vector3, lifted: boolean, time: number)
				self:receive(position, velocity, lifted, time)
			end)
	end,

	receive = function(self: BallView, position: Vector3, velocity: Vector3, lifted: boolean, time: number)
		if time < self._caughtAt or (self._hasState and time <= self._stateTime) then
			return
		end
		self._hasState = true
		self._statePosition = position
		self._stateVelocity = velocity
		self._stateLifted = lifted
		self._stateTime = time
	end,

	step = function(self: BallView, dt: number)
		local part = self._ballPart:get()
		if part ~= self._part then
			-- A rebuilt ball, or none: nothing this screen drew of the old one, nor its states, carries over.
			self._part = part
			self._weld = nil
			self._shown = nil
			self._pulling = false
			self._hasState = false
		end
		if part == nil then
			return
		end
		local weld = part:FindFirstChildOfClass("Weld")
		if weld ~= self._weld then
			self._weld = weld
			self._pulling = false
			if weld ~= nil then
				begin(self, weld)
			end
		end
		if weld ~= nil then
			if self._pulling then
				advance(self, weld, dt)
			end
			self._shown = part.Position
		elseif self._hasState then
			draw(self, part, dt)
		else
			self._shown = part.Position
		end
	end,
}

return BallView
