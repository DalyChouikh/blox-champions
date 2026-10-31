--!strict
-- A caught ball's flight into its carrier's hand on this screen (spec §9.3; the owner's trial #311, Q91, Q131, Q132).
-- The server hands the ball over at once and welds it at the carry spot, but that weld can reach this screen while it
-- still shows the ball flying short of the hand (36.6 studs short, measured in a 2-player test): the ball snapped. So
-- each screen draws the pull itself: the moment a new weld holds the ball, this module writes that weld's C0 here (a
-- client's write stays on its client, and the server never writes it again) from where this screen last showed the
-- ball, in the carrier's root frame, to the server's carry spot, over Ball.pickupPullSeconds (Ball/Pull); then the
-- server's C0 again. Stepped each physics step after the poses (FrameController), so the pulled spot is the one drawn.
-- Idle, a step allocates nothing; a pull writes one C0 a step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPart = require(script.Parent.BallPart)
local Config = require(ReplicatedStorage.Shared.Config)
local Pull = require(ReplicatedStorage.Shared.Ball.Pull)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallPull = {
	name: string,
	dependencies: { string },
	init: (self: BallPull, deps: { [string]: any }) -> (),
	start: ((self: BallPull) -> ())?,
	step: (self: BallPull, dt: number) -> (),
	_ballPart: BallPart.BallPart,
	_seconds: number,
	-- The ball part and the weld holding it at the last step: a new one of either starts over.
	_part: BasePart?,
	_weld: Weld?,
	-- Where this screen showed the ball at the last step; nil until it has shown this ball part.
	_shown: Vector3?,
	-- The pull under way: from and to in the carrier's root frame, the server's C0 to give back, its age.
	_pulling: boolean,
	_from: Vector3,
	_to: Vector3,
	_serverC0: CFrame,
	_elapsed: number,
}

-- A new weld holds the ball: its pull starts from where this screen last showed the ball, if it has shown it (a pull
-- that takes no time ends at its first step).
local function begin(self: BallPull, weld: Weld)
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

local function advance(self: BallPull, weld: Weld, dt: number)
	self._elapsed += dt
	if Pull.over(self._elapsed, self._seconds) then
		weld.C0 = self._serverC0
		self._pulling = false
		return
	end
	weld.C0 = CFrame.new(Pull.offset(self._from, self._to, self._elapsed, self._seconds))
end

local BallPull: BallPull = {
	name = "BallPull",
	dependencies = { "Config", "BallPart" },
	_ballPart = nil :: any,
	_seconds = 0,
	_part = nil,
	_weld = nil,
	_shown = nil,
	_pulling = false,
	_from = Vector3.zero,
	_to = Vector3.zero,
	_serverC0 = CFrame.identity,
	_elapsed = 0,

	init = function(self: BallPull, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._ballPart = deps.BallPart
		self._seconds = config.Ball.pickupPullSeconds
		self._part = nil
		self._weld = nil
		self._shown = nil
		self._pulling = false
	end,

	step = function(self: BallPull, dt: number)
		local part = self._ballPart:get()
		if part ~= self._part then
			-- A rebuilt ball, or none: nothing this screen showed of the old one carries over.
			self._part = part
			self._weld = nil
			self._shown = nil
			self._pulling = false
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
		if weld ~= nil and self._pulling then
			advance(self, weld, dt)
		end
		-- A weld places its part at once, so this is where the ball is drawn now.
		self._shown = part.Position
	end,
}

return BallPull
