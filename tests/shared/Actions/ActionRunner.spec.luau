--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ActionRunner = require(ReplicatedStorage.Shared.Actions.ActionRunner)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local actions = Config.defaults().Actions

local function context(hasBall: boolean?, airborne: boolean?, knockedDown: boolean?): ActionRunner.Context
	return { hasBall = hasBall == true, airborne = airborne == true, knockedDown = knockedDown == true }
end

describe("ActionRunner", function()
	it("runs a tackle through windup, active and recovery", function()
		local runner = ActionRunner.new(actions)
		expect(runner:start("Tackle", context())).toBe("Started")
		expect(runner.action).toBe("Tackle")
		expect(runner.phase).toBe("Windup")
		runner:step(0.05)
		expect(runner.phase).toBe("Active")
		runner:step(0.25)
		expect(runner.phase).toBe("Recovery")
		runner:step(0.35)
		expect(runner.action).toBe(nil)
		expect(runner.phase).toBe(nil)
	end)

	it("carries leftover time into the next phase", function()
		local runner = ActionRunner.new(actions)
		runner:start("Tackle", context())
		runner:step(0.2)
		expect(runner.phase).toBe("Active")
		runner:step(0.09)
		expect(runner.phase).toBe("Active")
		runner:step(0.02)
		expect(runner.phase).toBe("Recovery")
	end)

	it("keeps an action waiting for its cooldown, and allows it within the tolerance", function()
		local runner = ActionRunner.new(actions)
		runner:start("Tackle", context())
		runner:step(0.7)
		expect(runner.action).toBe(nil)
		expect(runner:start("Tackle", context())).toBe("CoolingDown")
		runner:step(0.05)
		expect(runner:cooldownLeft("Tackle")).toBeCloseTo(0.05, 6)
		expect(runner:start("Tackle", context())).toBe("CoolingDown")
		expect(runner:start("Tackle", context(), 0.1)).toBe("Started")
	end)

	it("refuses what the context does not allow", function()
		local runner = ActionRunner.new(actions)
		expect(runner:start("Tackle", context(true))).toBe("NotAllowed")
		expect(runner:start("Dodge", context(false))).toBe("NotAllowed")
		expect(runner:start("ChargeThrow", context(false))).toBe("NotAllowed")
		expect(runner:start("Tackle", context(false, false, true))).toBe("NotAllowed")
		expect(runner:start("Pass", context(true, true, true))).toBe("NotAllowed")
		expect(runner.action).toBe(nil)

		local grounded = Fixtures.config({ Actions = { Uppercut = { requires = { grounded = "grounded" } } } })
		expect(ActionRunner.new(grounded.Actions):start("Uppercut", context(false, true))).toBe("NotAllowed")
		expect(ActionRunner.new(grounded.Actions):start("Uppercut", context(false, false))).toBe("Started")
		local airborne = Fixtures.config({ Actions = { Uppercut = { requires = { grounded = "airborne" } } } })
		expect(ActionRunner.new(airborne.Actions):start("Uppercut", context(false, false))).toBe("NotAllowed")
		expect(ActionRunner.new(airborne.Actions):start("Uppercut", context(false, true))).toBe("Started")
	end)

	it("refuses a second action while one runs", function()
		local runner = ActionRunner.new(actions)
		runner:start("Tackle", context())
		expect(runner:start("Uppercut", context())).toBe("Busy")
		expect(runner.action).toBe("Tackle")
	end)

	-- Roller Champions' tackle key tackles on the ground and dives in the air (#221).
	it("starts a tackle only on the ground and a dive only in the air", function()
		expect(ActionRunner.new(actions):start("Dive", context(false, false))).toBe("NotAllowed")
		expect(ActionRunner.new(actions):start("Tackle", context(false, true))).toBe("NotAllowed")
		local runner = ActionRunner.new(actions)
		expect(runner:start("Dive", context(false, true))).toBe("Started")
		expect(runner.phase).toBe("Active")
		-- Nothing replaces it: no action follows another.
		runner:step(0.1)
		expect(runner:start("Dive", context(false, true))).toBe("Busy")
	end)

	-- The server's view of a jump lags the client's, so it never judges the air: either starts there.
	it("lets a context that cannot tell the air from the ground start either", function()
		local unseen: ActionRunner.Context = { hasBall = false, airborne = nil, knockedDown = false }
		expect(ActionRunner.new(actions):start("Tackle", unseen)).toBe("Started")
		expect(ActionRunner.new(actions):start("Dive", unseen)).toBe("Started")
	end)

	it("lets an action start within the tolerance of the running action's end", function()
		local runner = ActionRunner.new(actions)
		runner:start("Tackle", context())
		-- 0.05 s of the tackle's 0.65 s left.
		runner:step(0.6)
		expect(runner:start("Uppercut", context())).toBe("Busy")
		expect(runner:start("Uppercut", context(), 0.04)).toBe("Busy")
		expect(runner:start("Uppercut", context(), 0.1)).toBe("Started")
		expect(runner.action).toBe("Uppercut")
		expect(runner.phase).toBe("Windup")
	end)

	it("names the action whose active phase the last step ended in or skipped whole", function()
		local runner = ActionRunner.new(actions)
		runner:start("Tackle", context())
		runner:step(0.02)
		expect(runner.lastActive).toBe(nil)
		runner:step(0.1)
		expect(runner.lastActive).toBe("Tackle")
		-- Leaving the active phase does not count: the step before saw it.
		runner:step(0.25)
		expect(runner.phase).toBe("Recovery")
		expect(runner.lastActive).toBe(nil)
		-- One long step from the windup into the recovery.
		runner:reset()
		expect(runner.lastActive).toBe(nil)
		runner:start("Tackle", context())
		runner:step(0.4)
		expect(runner.phase).toBe("Recovery")
		expect(runner.lastActive).toBe("Tackle")
		runner:step(0.1)
		expect(runner.lastActive).toBe(nil)
		-- One step past the action's end.
		runner:reset()
		runner:start("Uppercut", context())
		runner:step(1)
		expect(runner.action).toBe(nil)
		expect(runner.lastActive).toBe("Uppercut")
		-- A cancelled action is no longer active.
		runner:reset()
		runner:start("Tackle", context())
		runner:step(0.1)
		runner:cancel("Tackle", false)
		expect(runner.lastActive).toBe(nil)
	end)

	it("ends an instant action at once and starts its cooldown", function()
		local runner = ActionRunner.new(actions)
		expect(runner:start("CallPass", context())).toBe("Started")
		expect(runner.action).toBe(nil)
		expect(runner:cooldownLeft("CallPass")).toBe(1)
		expect(runner:start("CallPass", context())).toBe("CoolingDown")
	end)

	it("cancels with or without a refund, and resets everything", function()
		local runner = ActionRunner.new(actions)
		runner:start("Tackle", context())
		runner:cancel("Tackle", true)
		expect(runner.action).toBe(nil)
		expect(runner:cooldownLeft("Tackle")).toBe(0)

		runner:start("Tackle", context())
		runner:cancel("Tackle", false)
		expect(runner.action).toBe(nil)
		expect(runner:cooldownLeft("Tackle")).toBe(0.8)

		-- An instant action is never running, so only its cooldown is refunded.
		runner:start("CallPass", context())
		runner:cancel("CallPass", true)
		expect(runner:cooldownLeft("CallPass")).toBe(0)

		runner:start("Uppercut", context())
		runner:reset()
		expect(runner.action).toBe(nil)
		expect(runner:cooldownLeft("Tackle")).toBe(0)
		expect(runner:cooldownLeft("Uppercut")).toBe(0)
	end)
end)
