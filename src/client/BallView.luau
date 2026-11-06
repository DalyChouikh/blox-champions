--!strict
-- Where this screen draws the ball (spec §9.3, #311, #316), first each frame before anything that reads it (the
-- markers, the carrier's beam).
-- - Loose: where the server's last state (the BallState stream) says it is now. Roblox's own replication drew it 0.19 s
--   late and unevenly (46-248 studs/s a frame for a steady 90, measured in a 2-player test), and other screens drew a
--   thrown ball still for 0.29 s. A state is carried on to now (Ball/Shown), falling only while nothing bears its
--   weight: the server says when a lift or the ground does (#337: carried on falling, a ball lying on the floor sank up
--   to its radius into it between the quarter-second states of a ball at rest, and snapped back). The drawn ball closes
--   on it over Network.ballStream.correctionSeconds, or jumps across a wider gap than snapStuds (a drop-in, a respawn).
--   Between states it is never drawn through the arena: the server's ball has bounced, and its next state says how.
--   With no state since it was let go, Roblox's spot stands. A state older than the newest, or from before the last
--   catch this screen saw, is stale: the stream is unreliable, and the catch reaches the screen by another road.
-- - Caught: the server welds it at the carry spot at once, but that weld can reach this screen while it still draws the
--   ball short of the hand (36.6 studs, measured), so the pull is drawn here (the owner, Q91, Q131, Q132): the weld's
--   C0 is written here (a client's write stays on its client, and the server never writes it again) from where this
--   screen last drew the ball, in the carrier's root frame, to the server's carry spot over Ball.pickupPullSeconds
--   (Ball/Pull); then the server's C0 again. A weld places its part at once.
-- - Its look (#400: the ball mesh in its skin, Ball/Look) goes wherever the ball is drawn, loose or carried, and turns
--   as the ball turns (#401, the owner's Q276: the band rolls with it). This screen's ball part never turns once it is
--   drawn here (measured in Play), so each state carries the server's physics spin and the look is turned by it, up to
--   Ball.lookSpinLimit (Q287: a fast ball's ~40 turns a second could not be followed), while the ball is drawn loose,
--   until its state is older than the stream carries on; carried, the look takes the ball part's turn (welded at the
--   carrier's root, it turns with the skater), and a ball let go turns on from there.
-- Idle and carried it allocates nothing; drawing a loose ball casts one ray a frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPart = require(script.Parent.BallPart)
local Config = require(ReplicatedStorage.Shared.Config)
local Pull = require(ReplicatedStorage.Shared.Ball.Pull)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Shown = require(ReplicatedStorage.Shared.Ball.Shown)
local Spin = require(ReplicatedStorage.Shared.Ball.Spin)

-- The arena's solid parts, as RideSurfaces keeps them.
type Surfaces = { solid: RaycastParams }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallView = {
	name: string,
	dependencies: { string },
	init: (self: BallView, deps: { [string]: any }) -> (),
	start: (self: BallView) -> (),
	-- The server's state of the loose ball (#316), kept when it is the newest and from after the last catch.
	receive: (
		self: BallView,
		position: Vector3,
		velocity: Vector3,
		supported: boolean,
		time: number,
		spin: Vector3
	) -> (),
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
	_spinLimit: number,
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
	_stateSupported: boolean,
	_stateTime: number,
	_stateSpin: Vector3,
	-- The server's time when this screen last saw a catch.
	_caughtAt: number,
	-- The ball's look last drawn, where, and turned how (#400, #401).
	_look: BasePart?,
	_lookAt: Vector3,
	_turnedAt: Vector3,
	-- The look's turn, changed in place (Ball/Spin).
	_turn: Spin.Quat,
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
	local gravity = if self._stateSupported then Vector3.zero else self._gravity
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

-- How the look is turned now (#401): with the ball part while carried, kept so a ball let go turns on from the hand;
-- loose, by the latest state's spin (up to the limit) over `dt` while the stream still carries that state on.
local function turned(self: BallView, part: BasePart, dt: number): Vector3
	if self._weld ~= nil then
		local held = part.Orientation
		Spin.setOrientation(self._turn, held)
		return held
	end
	if self._hasState and self._serverTime() - self._stateTime <= self._maxAge then
		Spin.turn(self._turn, self._stateSpin, dt, self._spinLimit)
	end
	return Spin.orientation(self._turn)
end

-- The ball's look where this screen drew the ball (#400), turned as the ball turns (#401). The ball part is unseen, and
-- nothing else puts its look there: the server never moves the look, and this screen's writes to the ball part carry
-- no part joined to it (19 studs apart, measured in Play). A new look starts from the turn it was built with. Each of
-- its spot and its turn is written only when it changed, or for a new look; Orientation, a Vector3, is written rather
-- than a CFrame, which would be a new object each frame.
local function place(self: BallView, part: BasePart, shown: Vector3, dt: number)
	local look = self._ballPart:look()
	if look == nil then
		return
	end
	local fresh = look ~= self._look
	if fresh then
		self._look = look
		Spin.setOrientation(self._turn, look.Orientation)
	end
	if fresh or shown ~= self._lookAt then
		look.Position = shown
		self._lookAt = shown
	end
	local orientation = turned(self, part, dt)
	if fresh or orientation ~= self._turnedAt then
		look.Orientation = orientation
		self._turnedAt = orientation
	end
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
	_spinLimit = 0,
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
	_stateSupported = false,
	_stateTime = 0,
	_stateSpin = Vector3.zero,
	_caughtAt = -math.huge,
	_look = nil,
	_lookAt = Vector3.zero,
	_turnedAt = Vector3.zero,
	_turn = Spin.new(),

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
		self._spinLimit = config.Ball.lookSpinLimit
		self._part = nil
		self._weld = nil
		self._shown = nil
		self._pulling = false
		self._hasState = false
		self._caughtAt = -math.huge
	end,

	start = function(self: BallView)
		Remotes.getStream(ReplicatedStorage, Remotes.streams.BallState).OnClientEvent
			:Connect(function(position: Vector3, velocity: Vector3, supported: boolean, time: number, spin: Vector3)
				self:receive(position, velocity, supported, time, spin)
			end)
	end,

	receive = function(
		self: BallView,
		position: Vector3,
		velocity: Vector3,
		supported: boolean,
		time: number,
		spin: Vector3
	)
		if time < self._caughtAt or (self._hasState and time <= self._stateTime) then
			return
		end
		self._hasState = true
		self._statePosition = position
		self._stateVelocity = velocity
		self._stateSupported = supported
		self._stateTime = time
		self._stateSpin = spin
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
		place(self, part, self._shown :: Vector3, dt)
	end,
}

return BallView
