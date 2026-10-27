--!strict
-- One player's actions (spec §8.1): runs the action in progress through its windup, active and recovery phases,
-- counts every action's cooldown down, and decides whether a new action may start. The client and the server each run
-- one per player, by the same rules. Allocates only in `new`.

local Actions = require(script.Parent.Parent.Config.Actions)

export type Phase = "Windup" | "Active" | "Recovery"
-- What the player is doing as an action starts. `airborne` is nil where the air can't be told from the ground (the
-- server, whose view of a jump lags the client's): an action needing either may start.
export type Context = { hasBall: boolean, airborne: boolean?, knockedDown: boolean }
export type Verdict = "Started" | "Busy" | "CoolingDown" | "NotAllowed"

local ActionRunner = {}
ActionRunner.__index = ActionRunner

type Fields = {
	-- The running action and its phase; nil when none runs.
	action: Actions.ActionName?,
	phase: Phase?,
	-- The action whose active phase the last `step` ended in, or skipped whole in one long step (the action may have
	-- ended since); nil otherwise. A step that only leaves the active phase does not count: the step before saw it.
	lastActive: Actions.ActionName?,
	_actions: Actions.ActionsConfig,
	_phaseIndex: number,
	_phaseLeft: number,
	-- Seconds until each action may start again.
	_cooldowns: { [string]: number },
}

export type Runner = typeof(setmetatable({} :: Fields, ActionRunner))

local PHASES: { Phase } = { "Windup", "Active", "Recovery" }
local PHASE_INDEX: { Windup: number, Active: number, Recovery: number } = { Windup = 1, Active = 2, Recovery = 3 }

local function phaseLength(phases: Actions.Phases, index: number): number
	if index == 1 then
		return phases.windup
	elseif index == 2 then
		return phases.active
	end
	return phases.recovery
end

-- Seconds from an action's start to the start of phase `index` (past the last phase: to its end).
local function phaseStart(phases: Actions.Phases, index: number): number
	local at = 0
	for before = 1, index - 1 do
		at += phaseLength(phases, before)
	end
	return at
end

-- Seconds since the running action started.
local function elapsed(self: Runner, phases: Actions.Phases): number
	local index = self._phaseIndex
	return phaseStart(phases, index) + phaseLength(phases, index) - self._phaseLeft
end

-- Whether an action's ball requirement lets a player who holds the ball (or doesn't) start it.
function ActionRunner.ballFits(ball: Actions.BallRequirement, hasBall: boolean): boolean
	return ball == "any" or (ball == "with") == hasBall
end

-- Whether an action with these requirements may start in this context.
function ActionRunner.allows(requires: Actions.Requires, context: Context): boolean
	if requires.notKnockedDown and context.knockedDown then
		return false
	end
	if not ActionRunner.ballFits(requires.ball, context.hasBall) then
		return false
	end
	local grounded, airborne = requires.grounded, context.airborne
	return grounded == "any" or airborne == nil or (grounded == "airborne") == airborne
end

local function stop(self: Runner)
	self.action = nil
	self.phase = nil
end

-- Enters phase `index` of the running action with `carried` seconds of it already spent, skipping every phase that
-- time covers (zero-length ones included), and ends the action past the last phase.
local function advance(self: Runner, action: Actions.ActionName, index: number, carried: number)
	local phases = self._actions[action].phases
	while index <= #PHASES do
		local left = phaseLength(phases, index) - carried
		if left > 0 then
			self.phase = PHASES[index]
			self._phaseIndex = index
			self._phaseLeft = left
			return
		end
		carried = -left
		index += 1
	end
	stop(self)
end

function ActionRunner.new(actions: Actions.ActionsConfig): Runner
	local cooldowns: { [string]: number } = {}
	for _, name in Actions.names do
		cooldowns[name] = 0
	end
	local self: Fields = {
		action = nil,
		phase = nil,
		lastActive = nil,
		_actions = actions,
		_phaseIndex = 0,
		_phaseLeft = 0,
		_cooldowns = cooldowns,
	}
	return setmetatable(self, ActionRunner)
end

-- Starts `name` when the context allows it, nothing else runs and its cooldown is over. `tolerance` (the server's
-- allowance for network jitter) moves each of those edges by that many seconds: a cooldown or a running action that
-- ends within it counts as over. Anything but "Started" changes nothing.
function ActionRunner.start(self: Runner, name: Actions.ActionName, context: Context, tolerance: number?): Verdict
	local config = self._actions[name]
	if not ActionRunner.allows(config.requires, context) then
		return "NotAllowed"
	end
	local slack = tolerance or 0
	local running: Actions.ActionName? = self.action
	if running ~= nil then
		local phases = self._actions[running].phases
		if elapsed(self, phases) < phaseStart(phases, #PHASES + 1) - slack then
			return "Busy"
		end
	end
	if self._cooldowns[name] > slack then
		return "CoolingDown"
	end
	self._cooldowns[name] = config.cooldown
	self.action = name
	advance(self, name, 1, 0)
	return "Started"
end

-- Advances the running action's phase, carrying leftover time into the next one, and every cooldown.
function ActionRunner.step(self: Runner, dt: number)
	local cooldowns = self._cooldowns
	for _, name in Actions.names do
		local left = cooldowns[name]
		if left > 0 then
			cooldowns[name] = math.max(left - dt, 0)
		end
	end
	self.lastActive = nil
	local action: Actions.ActionName? = self.action
	if action ~= nil then
		local before = self._phaseIndex
		local left = self._phaseLeft - dt
		if left > 0 then
			self._phaseLeft = left
		else
			advance(self, action, before + 1, -left)
		end
		local after = if self.action == nil then #PHASES + 1 else self._phaseIndex
		local active = PHASE_INDEX.Active
		local skipped = before < active and after > active
		if (after == active or skipped) and self._actions[action].phases.active > 0 then
			self.lastActive = action
		end
	end
end

function ActionRunner.cooldownLeft(self: Runner, name: Actions.ActionName): number
	return self._cooldowns[name]
end

-- Stops `name` if it is the running action and, with `refund`, clears its cooldown (the server refused it). An
-- instant action never stays running, so only its cooldown can be refunded.
function ActionRunner.cancel(self: Runner, name: Actions.ActionName, refund: boolean)
	if self.action == name then
		stop(self)
	end
	if self.lastActive == name then
		self.lastActive = nil
	end
	if refund then
		self._cooldowns[name] = 0
	end
end

-- No action runs and every cooldown is over (the kickoff).
function ActionRunner.reset(self: Runner)
	stop(self)
	self.lastActive = nil
	local cooldowns = self._cooldowns
	for _, name in Actions.names do
		cooldowns[name] = 0
	end
end

return ActionRunner
