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
		-- Past the tackle's 0.65 s of phases, 0.1 s before its cooldown ends.
		runner:step(actions.Tackle.cooldown - 0.1)
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

	-- The server's view of a jump lags the client's, so it never judges the air: either starts there.
	it("lets a context that cannot tell the air from the ground start either", function()
		local unseen: ActionRunner.Context = { hasBall = false, airborne = nil, knockedDown = false }
		for _, grounded in { "grounded", "airborne" } do
			local only = Fixtures.config({ Actions = { Uppercut = { requires = { grounded = grounded } } } })
			expect(ActionRunner.new(only.Actions):start("Uppercut", unseen)).toBe("Started")
		end
	end)

	-- Roller Champions' tackle key (#240): a Tackle on the ground or in the air, then its Dive only from 0.1 to 1.0 s
	-- after it (the owner's Video 4: "Dive" replaces "Tackle" 0.1-0.2 s after the press, for 0.7-0.8 s).
	it("starts a dive only inside its tackle's follow-up window, on the ground or in the air", function()
		expect(ActionRunner.new(actions):start("Dive", context())).toBe("NotAllowed")
		local runner = ActionRunner.new(actions)
		-- Long after the runner was made: the window counts from the tackle's start.
		runner:step(2)
		expect(runner:start("Tackle", context(false, true))).toBe("Started")
		runner:step(0.06)
		expect(runner:available("Dive", context(false, true))).toBe(false)
		expect(runner:start("Dive", context(false, true))).toBe("NotAllowed")
		runner:step(0.06)
		expect(runner:available("Dive", context(false, true))).toBe(true)
		-- 0.12 s in, during the tackle's strike: the dive replaces it.
		expect(runner:start("Dive", context(false, true))).toBe("Started")
		expect(runner.action).toBe("Dive")
		local late = ActionRunner.new(actions)
		late:start("Tackle", context())
		late:step(1.02)
		expect(late:available("Dive", context())).toBe(false)
		-- The window is over and so is the tackle's 1 s cooldown: the key tackles again.
		expect(late:start("Tackle", context())).toBe("Started")
	end)

	it("opens no dive window for a tackle the server refused, nor after a reset", function()
		local refused = ActionRunner.new(actions)
		refused:start("Tackle", context())
		refused:cancel("Tackle", true)
		refused:step(0.2)
		expect(refused:start("Dive", context())).toBe("NotAllowed")
		local reset = ActionRunner.new(actions)
		reset:start("Tackle", context())
		reset:reset()
		reset:step(0.2)
		expect(reset:start("Dive", context())).toBe("NotAllowed")
	end)

	it("lets a dive start within the tolerance of its window's edges", function()
		local early = ActionRunner.new(actions)
		early:start("Tackle", context())
		early:step(0.08)
		expect(early:start("Dive", context(), 0.05)).toBe("Started")
		local late = ActionRunner.new(actions)
		late:start("Tackle", context())
		late:step(1.03)
		expect(late:start("Dive", context(), 0.05)).toBe("Started")
		local over = ActionRunner.new(actions)
		over:start("Tackle", context())
		over:step(1.06)
		expect(over:start("Dive", context(), 0.05)).toBe("NotAllowed")
	end)

	-- The owner (Q8): RC's air Tackle was ready 0.13-0.3 s after an Uppercut; ours once the Uppercut's strike is over.
	it("lets a tackle follow an uppercut once the uppercut's strike is over", function()
		local runner = ActionRunner.new(actions)
		runner:start("Uppercut", context())
		runner:step(0.2)
		expect(runner:start("Tackle", context(false, true))).toBe("Busy")
		runner:step(0.06)
		expect(runner:start("Tackle", context(false, true))).toBe("Started")
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
		expect(runner:cooldownLeft("Tackle")).toBe(actions.Tackle.cooldown)

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
