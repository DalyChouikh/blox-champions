--!strict
-- The match clock (spec §5.1): counts regulation time down, reports each warning mark once as the clock
-- reaches it, and counts up during golden-goal overtime. `runs` is the one rule for when it runs: the engine and the
-- HUD both follow it.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local MatchClock = {}
MatchClock.__index = MatchClock

type Fields = {
	secondsLeft: number,
	overtimeSeconds: number,
	inOvertime: boolean,
	_warnings: { number }, -- highest first
	_nextWarning: number, -- index of the next warning not yet reached
}

export type MatchClock = typeof(setmetatable({} :: Fields, MatchClock))

function MatchClock.new(durationSeconds: number, warnings: { number }): MatchClock
	-- A sorted copy: config lists are frozen and may be in any order.
	local sorted = table.clone(warnings)
	table.sort(sorted, function(a: number, b: number): boolean
		return a > b
	end)
	return setmetatable(
		{
			secondsLeft = durationSeconds,
			overtimeSeconds = 0,
			inOvertime = false,
			_warnings = sorted,
			_nextWarning = 1,
		} :: Fields,
		MatchClock
	)
end

-- Regulation: counts down, calls onWarning for each mark the clock moves past (from above it to at or below
-- it), highest first, and returns true only on the call that reaches 0. Overtime: counts up, returns false.
function MatchClock.advance(self: MatchClock, dt: number, onWarning: (secondsLeft: number) -> ()): boolean
	if self.inOvertime then
		self.overtimeSeconds += dt
		return false
	end
	local before = self.secondsLeft
	if before <= 0 then
		return false
	end
	local after = math.max(before - dt, 0)
	self.secondsLeft = after

	local warnings = self._warnings
	local index = self._nextWarning
	while index <= #warnings and warnings[index] >= after do
		local mark = warnings[index]
		-- Marks at or above the duration were never above the clock, so they never fire.
		if mark < before then
			onWarning(mark)
		end
		index += 1
	end
	self._nextWarning = index

	return after == 0
end

-- Whether the clock runs in `state`: while play is live, and through kickoff countdowns and celebrations unless
-- they pause it (Match.clockPausesDuringKickoff). Never before the match starts or after it ends.
function MatchClock.runs(match: Config.MatchConfig, state: Types.MatchState): boolean
	if state == "Live" then
		return true
	end
	return (state == "Kickoff" or state == "Celebration") and not match.clockPausesDuringKickoff
end

function MatchClock.startOvertime(self: MatchClock)
	self.inOvertime = true
end

return MatchClock
