--!strict
-- Catches a client that moves faster than skating allows (spec §10). Every guardSampleSeconds it samples each seated
-- skater's root. A move beyond the allowance is a strike, and a run of strikes returns the skater to their last valid
-- place. Anchored roots are reset, not judged, and every server placement starts the skater over, so the server's own
-- jumps and the kickoff freeze never count.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BallService = require(script.Parent.BallService)
local Config = require(ReplicatedStorage.Shared.Config)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type MovementGuard = {
	name: string,
	dependencies: { string },
	init: (self: MovementGuard, deps: { [string]: any }) -> (),
	start: (self: MovementGuard) -> (),
	step: (self: MovementGuard, dt: number) -> (),
	_check: MovementCheck.MovementCheck,
	_sampleSeconds: number,
	_elapsed: number,
	_holders: () -> { BallService.Holder },
	_clock: () -> number,
	_log: (line: string) -> (),
}

local function logLine(line: string)
	warn(line)
end

-- Moves a character back to its skater's last valid place, keeping the way it faces.
local function returnToValid(self: MovementGuard, holder: BallService.Holder)
	local valid = self._check:lastValid(holder.player)
	local character = holder.root.Parent
	if valid == nil or character == nil or not character:IsA("Model") then
		return
	end
	character:PivotTo(CFrame.new(valid) * holder.root.CFrame.Rotation)
	self._log(`[BloxChampions] MovementGuard: returned {holder.player}`)
end

local MovementGuard: MovementGuard = {
	name = "MovementGuard",
	dependencies = { "Config", "CharacterService" },
	_check = nil :: any,
	_sampleSeconds = 0,
	_elapsed = 0,
	_holders = function(): { BallService.Holder }
		return {}
	end,
	_clock = os.clock,
	_log = logLine,

	-- deps.Log and deps.Clock replace the console and os.clock in tests.
	init = function(self: MovementGuard, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local characters = deps.CharacterService
		self._check = MovementCheck.new(config.Movement, config.Network)
		self._sampleSeconds = config.Network.guardSampleSeconds
		self._elapsed = 0
		self._holders = function(): { BallService.Holder }
			return characters:holders()
		end
		self._clock = deps.Clock or os.clock
		self._log = deps.Log or logLine
		characters.placed:Connect(function(player: string)
			self._check:forget(player)
		end)
		characters.characterRemoved:Connect(function(player: string)
			self._check:forget(player)
		end)
	end,

	start = function(self: MovementGuard)
		RunService.Heartbeat:Connect(function(dt: number)
			self:step(dt)
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
			if holder.root.Anchored then
				self._check:reset(holder.player, holder.root.Position, now)
			elseif self._check:sample(holder.player, holder.root.Position, now) == "Return" then
				returnToValid(self, holder)
			end
		end
	end,
}

return MovementGuard
