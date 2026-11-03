--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animator = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Animator)
local BannerMotion = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.BannerMotion)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)

-- Motion of this spec's own: a 0.2 s pop to 1.1, a 0.4 s ease; a lap shows 2 s, the goal message 3.
local config = Fixtures.config({
	UI = {
		hud = {
			bannerSeconds = { headline = 1, lap = 2, message = 3 },
			motion = { pop = { seconds = 0.2, overshoot = 0.1 }, easeSeconds = 0.4 },
		},
	},
})

local function live(): HudState.HudState
	local state = HudState.new(config, "1")
	state:applySnapshot(Fixtures.matchSnapshot())
	return state
end

describe("BannerMotion", function()
	-- Each pops in with a quick overshoot (the owner, Q191).
	it("pops each new banner in from nothing, on its own line, and nothing that was already shown", function()
		local animator = Animator.new(config.UI.hud.motion)
		local motion = BannerMotion.new(config.UI.hud.motion, animator)
		local state = live()
		motion:watch(state)
		expect(motion.line.scale.moving).toBe(false)
		expect(motion.line.scale.value).toBe(1)
		state:applyEvents({ { name = "LapCompleted", team = "Blue", streak = 1, holder = "1" } })
		motion:watch(state)
		expect(motion.line.scale.value).toBe(0)
		expect(motion.message.scale.moving).toBe(false)
		-- Halfway it peaks at 1.1, then settles at 1.
		animator:step(0.1)
		expect(motion.line.scale.value).toBeCloseTo(1.1, 6)
		animator:step(0.1)
		expect(motion.line.scale.value).toBe(1)
		state:applyEvents({ { name = "GoalOpened", team = "Blue" } })
		motion:watch(state)
		expect(motion.message.scale.value).toBe(0)
		expect(motion.line.scale.moving).toBe(false)
		-- A new lap is a new banner, though of the same kind.
		state:applyEvents({ { name = "LapCompleted", team = "Blue", streak = 2, holder = "1" } })
		motion:watch(state)
		expect(motion.line.scale.value).toBe(0)
	end)

	-- ... holds, then floats up as it fades (Q191, Q194): over its last easeSeconds.
	it("leaves each line over its banner's last easeSeconds, writing only when that changes", function()
		local animator = Animator.new(config.UI.hud.motion)
		local motion = BannerMotion.new(config.UI.hud.motion, animator)
		local state = live()
		state:applyEvents({
			{ name = "LapCompleted", team = "Blue", streak = 1, holder = "1" },
			{ name = "GoalOpened", team = "Blue" },
		})
		motion:watch(state)
		motion:step(state)
		expect(motion.line.leave:getValue()).toBe(0)
		local writes = motion.writes
		motion:step(state)
		expect(motion.writes).toBe(writes)
		-- 0.2 s left of the lap's 2: half the ease, eased out (1 - 0.5^3).
		state:step(1.8)
		motion:step(state)
		expect(motion.line.leave:getValue()).toBeCloseTo(0.875, 6)
		expect(motion.message.leave:getValue()).toBe(0)
		-- The lap gone: its line at rest again; the message, 0.1 s left of 3, nearly gone.
		state:step(1.1)
		motion:step(state)
		expect(motion.line.leave:getValue()).toBe(0)
		expect(motion.message.leave:getValue()).toBeCloseTo(1 - 0.25 ^ 3, 6)
	end)
end)
