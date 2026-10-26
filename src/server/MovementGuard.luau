--!strict
-- Catches a client that moves faster than skating allows (spec §10), and any skater found outside the arena. Every
-- guardSampleSeconds it samples each seated skater's root, stepped by MatchService before the ball, so the ball sees
-- the guard's moves in the same frame. A move beyond the allowance is a strike, and a run of strikes (or one move far
-- beyond it) returns the skater to their last valid place, a carrier with the ball. Otherwise a root outside the
-- arena (Bounds.inArena, by more than guardOutsideMargin) is put back on its team's spawn: nothing else would ever
-- bring it back (#177, #181). A carrier first lets go of the ball where they were last inside the arena (owner,
-- 2026-10-25), so leaving the arena never takes the ball home. The ball is told of every move of a carrier, so none
-- counts as the ball crossing a gate. Anchored roots are reset, not judged, and every server placement starts the
-- skater over, so the server's own jumps and the kickoff freeze never count.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallService = require(script.Parent.BallService)
local Bounds = require(ReplicatedStorage.Shared.Arena.Geometry.Bounds)
local Config = require(ReplicatedStorage.Shared.Config)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type MovementGuard = {
	name: string,
	dependencies: { string },
	init: (self: MovementGuard, deps: { [string]: any }) -> (),
	-- None: MatchService steps the guard in the server's one frame order.
	start: ((self: MovementGuard) -> ())?,
	step: (self: MovementGuard, dt: number) -> (),
	_check: MovementCheck.MovementCheck,
	_arena: Config.ArenaConfig,
	_outsideMargin: number,
	_sampleSeconds: number,
	_elapsed: number,
	_ball: BallService.BallService,
	-- Where each skater's root was at their last sample inside the arena.
	_inside: { [string]: Vector3 },
	_holders: () -> { BallService.Holder },
	-- Stands a seated player's character on their team's spawn (CharacterService), unfrozen.
	_place: (player: string) -> (),
	_clock: () -> number,
	_log: (line: string) -> (),
}

local function logLine(line: string)
	warn(line)
end

local function forget(self: MovementGuard, player: string)
	self._check:forget(player)
	self._inside[player] = nil
end

-- Moves a character back to its skater's last valid place, keeping the way it faces.
local function returnToValid(self: MovementGuard, holder: BallService.Holder)
	local valid = self._check:lastValid(holder.player)
	local character = holder.root.Parent
	if valid == nil or character == nil or not character:IsA("Model") then
		return
	end
	character:PivotTo(CFrame.new(valid) * holder.root.CFrame.Rotation)
	if self._ball.state.carrier == holder.player then
		self._ball:jumped()
	end
	self._log(`[BloxChampions] MovementGuard: returned {holder.player}`)
end

-- Puts a skater found outside the arena on their spawn, their ball left where they were last inside (or, with no
-- such place known, where they are: then the ball's own out-of-bounds rule respawns it).
local function placeOutside(self: MovementGuard, holder: BallService.Holder)
	local player = holder.player
	if self._ball.state.carrier == player then
		self._ball:dropAt(self._inside[player] or holder.root.Position)
	end
	-- The placement starts the skater over (CharacterService.placed).
	self._place(player)
	self._log(`[BloxChampions] MovementGuard: {player} was outside the arena, placed on their spawn`)
end

local MovementGuard: MovementGuard = {
	name = "MovementGuard",
	dependencies = { "Config", "CharacterService", "BallService" },
	_check = nil :: any,
	_arena = nil :: any,
	_outsideMargin = 0,
	_sampleSeconds = 0,
	_elapsed = 0,
	_ball = nil :: any,
	_inside = {},
	_holders = function(): { BallService.Holder }
		return {}
	end,
	_place = function(_player: string) end,
	_clock = os.clock,
	_log = logLine,

	-- deps.Log and deps.Clock replace the console and os.clock in tests.
	init = function(self: MovementGuard, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local characters = deps.CharacterService
		self._check = MovementCheck.new(config.Movement, config.Network)
		self._arena = config.Arena
		self._outsideMargin = config.Network.guardOutsideMargin
		self._sampleSeconds = config.Network.guardSampleSeconds
		self._elapsed = 0
		self._ball = deps.BallService
		self._inside = {}
		self._holders = function(): { BallService.Holder }
			return characters:holders()
		end
		self._place = function(player: string)
			characters:place(player, false)
		end
		self._clock = deps.Clock or os.clock
		self._log = deps.Log or logLine
		characters.placed:Connect(function(player: string)
			forget(self, player)
		end)
		characters.characterRemoved:Connect(function(player: string)
			forget(self, player)
		end)
	end,

	step = function(self: MovementGuard, dt: number)
		self._elapsed += dt
		if self._elapsed < self._sampleSeconds then
			return
		end
		self._elapsed = 0
		local now = self._clock()
		for _, holder in self._holders() do
			local player = holder.player
			local position = holder.root.Position
			if holder.root.Anchored then
				self._check:reset(player, position, now)
			elseif self._check:sample(player, position, now) == "Return" then
				returnToValid(self, holder)
			elseif not Bounds.inArena(self._arena, position, self._outsideMargin) then
				placeOutside(self, holder)
			else
				self._inside[player] = position
			end
		end
	end,
}

return MovementGuard
