--!strict
-- Assist credit (spec §6.2): the last different teammate who held the ball before the scorer, when the scorer
-- received it no more than the window before scoring. The engine resets it on every possession change and
-- kickoff, so every holder it remembers is on the possessing team.

local Types = require(script.Parent.Types)

local AssistTracker = {}
AssistTracker.__index = AssistTracker

type Fields = {
	_windowSeconds: number,
	_current: Types.PlayerId?,
	_previous: Types.PlayerId?,
	_receivedAt: number,
}

export type AssistTracker = typeof(setmetatable({} :: Fields, AssistTracker))

function AssistTracker.new(windowSeconds: number): AssistTracker
	return setmetatable(
		{
			_windowSeconds = windowSeconds,
			_current = nil,
			_previous = nil,
			_receivedAt = 0,
		} :: Fields,
		AssistTracker
	)
end

function AssistTracker.pickedUp(self: AssistTracker, player: Types.PlayerId, now: number)
	-- Re-picking up your own loose ball is not a new handoff.
	if player == self._current then
		return
	end
	self._previous = self._current
	self._current = player
	self._receivedAt = now
end

function AssistTracker.assister(self: AssistTracker, scorer: Types.PlayerId, now: number): Types.PlayerId?
	if scorer ~= self._current or now - self._receivedAt > self._windowSeconds then
		return nil
	end
	return self._previous
end

function AssistTracker.reset(self: AssistTracker)
	self._current = nil
	self._previous = nil
	self._receivedAt = 0
end

return AssistTracker
