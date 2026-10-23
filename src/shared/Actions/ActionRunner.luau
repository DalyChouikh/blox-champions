--!strict
-- One player's actions (spec §8.1): runs the action in progress through its windup, active and recovery phases,
-- counts every action's cooldown down, and decides whether a new action may start. The client and the server each run
-- one per player, by the same rules. Allocates only in `new`.

local Actions = require(script.Parent.Parent.Config.Actions)

export type Phase = "Windup" | "Active" | "Recovery"
-- What the player is doing as an action starts.
export type Context = { hasBall: boolean, airborne: boolean, knockedDown: boolean }
export type Verdict = "Started" | "Busy" | "CoolingDown" | "NotAllowed"

local ActionRunner = {}
ActionRunner.__index = ActionRunner

type Fields = {
	-- The running action and its phase; nil when none runs.
	action: Actions.ActionName?,
	phase: Phase?,
	_actions: Actions.ActionsConfig,
	_phaseIndex: number,
	_phaseLeft: number,
	-- Seconds until each action may start again.
	_cooldowns: { [string]: number },
}

export type Runner = typeof(setmetatable({} :: Fields, ActionRunner))

local PHASES: { Phase } = { "Windup", "Active", "Recovery" }

local function phaseLength(phases: Actions.Phases, index: number): number
	if index == 1 then
		return phases.windup
	elseif index == 2 then
		return phases.active
	end
	return phases.recovery
end

local function allows(requires: Actions.Requires, context: Context): boolean
	if requires.notKnockedDown and context.knockedDown then
		return false
	end
	local ball = requires.ball
	if (ball == "with" and not context.hasBall) or (ball == "without" and context.hasBall) then
		return false
	end
	local grounded = requires.grounded
	return grounded == "any" or (grounded == "airborne") == context.airborne
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
		_actions = actions,
		_phaseIndex = 0,
		_phaseLeft = 0,
		_cooldowns = cooldowns,
	}
	return setmetatable(self, ActionRunner)
end

-- Starts `name` when the context allows it, nothing else runs (or it is the running action's follow-up, in its
-- window) and its cooldown is over, or within `tolerance` seconds of over. Anything but "Started" changes nothing.
function ActionRunner.start(self: Runner, name: Actions.ActionName, context: Context, tolerance: number?): Verdict
	local config = self._actions[name]
	if not allows(config.requires, context) then
		return "NotAllowed"
	end
	local running = self.action
	if running ~= nil then
		local followUp = self._actions[running].followUp
		if followUp == nil or followUp.action ~= name or self.phase ~= followUp.window then
			return "Busy"
		end
	end
	if self._cooldowns[name] > (tolerance or 0) then
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
	local action: Actions.ActionName? = self.action
	if action ~= nil then
		local left = self._phaseLeft - dt
		if left > 0 then
			self._phaseLeft = left
		else
			advance(self, action, self._phaseIndex + 1, -left)
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
	if refund then
		self._cooldowns[name] = 0
	end
end

-- No action runs and every cooldown is over (the kickoff).
function ActionRunner.reset(self: Runner)
	stop(self)
	local cooldowns = self._cooldowns
	for _, name in Actions.names do
		cooldowns[name] = 0
	end
end

return ActionRunner
