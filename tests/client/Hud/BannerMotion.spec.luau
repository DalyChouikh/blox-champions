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
		local motion = BannerMotion.new(config.UI.hud.motion, animator, 1)
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
	-- The feed's chips (#373, the owner's Q227): each line pops in and fades out whole, as a banner does.
	it("seats each feed line in a slot that pops it in and fades it over its last moments", function()
		local animator = Animator.new(config.UI.hud.motion)
		local motion = BannerMotion.new(config.UI.hud.motion, animator, 2)
		local state = live()
		state:applyEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } })
		motion:watch(state)
		local chip = motion.chips[state.feed[1].id]
		expect(chip.scale.value).toBe(0)
		animator:step(0.1)
		expect(chip.scale.value > 1).toBe(true)
		animator:step(0.1)
		expect(chip.scale.value).toBe(1)
		-- Nothing moves it again while the state only changes around it.
		state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		motion:watch(state)
		expect(chip.scale.moving).toBe(false)
		expect(chip.scale.value).toBe(1)
		motion:step(state)
		expect(chip.leave:getValue()).toBe(0)
		-- Half way through its last 0.4 s.
		state:step(config.UI.hud.feedSeconds - 0.2)
		motion:step(state)
		local share = chip.leave:getValue()
		expect(share > 0 and share < 1).toBe(true)
	end)

	it("gives a gone line's slot to a new one, which starts solid", function()
		local animator = Animator.new(config.UI.hud.motion)
		local motion = BannerMotion.new(config.UI.hud.motion, animator, 1)
		local state = live()
		state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		motion:watch(state)
		local firstId = state.feed[1].id
		local chip = motion.chips[firstId]
		animator:step(0.2)
		state:step(config.UI.hud.feedSeconds - 0.1)
		motion:step(state)
		expect(chip.leave:getValue() > 0).toBe(true)
		state:step(0.2)
		expect(#state.feed).toBe(0)
		motion:watch(state)
		expect(motion.chips[firstId]).toBeNil()
		state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		motion:watch(state)
		expect(motion.chips[state.feed[1].id] == chip).toBe(true)
		expect(chip.scale.value).toBe(0)
		motion:step(state)
		expect(chip.leave:getValue()).toBe(0)
	end)

	-- The oldest gives up its slot in the same change that brings the new line, so the feed's most never runs out.
	it("seats a line that pushes the oldest out of a full feed", function()
		local most = config.UI.hud.feedMaxEntries
		local motion = BannerMotion.new(config.UI.hud.motion, Animator.new(config.UI.hud.motion), most)
		local state = live()
		local function score()
			state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
			motion:watch(state)
		end
		for _ = 1, most do
			score()
		end
		local oldest = state.feed[1].id
		score()
		expect(motion.chips[oldest]).toBeNil()
		for _, entry in state.feed do
			expect(motion.chips[entry.id] ~= nil).toBe(true)
		end
	end)

	it("writes nothing for a chip on a quiet step", function()
		local motion = BannerMotion.new(config.UI.hud.motion, Animator.new(config.UI.hud.motion), 2)
		local state = live()
		state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		motion:watch(state)
		motion:step(state)
		local writes = motion.writes
		state:step(1)
		motion:step(state)
		expect(motion.writes).toBe(writes)
	end)

	-- The Get Up prompt (#369, the owner's Q221): it has no time left to count, it ends when the skater is up.
	it("pops the prompt in as it starts, fades it out as it ends, and shows it until it has gone", function()
		local animator = Animator.new(config.UI.hud.motion)
		local motion = BannerMotion.new(config.UI.hud.motion, animator, 1)
		expect(motion:promptShown()).toBe(false)
		motion:prompting(false)
		expect(motion:promptShown()).toBe(false)

		motion:prompting(true)
		expect(motion:promptShown()).toBe(true)
		expect(motion.promptScale.value).toBe(0)
		animator:step(0.1)
		expect(motion.promptScale.value > 0).toBe(true)
		animator:step(0.1)
		expect(motion.promptScale.value).toBe(1)
		expect(motion.promptLeave.value).toBe(0)
		-- Still prompting: nothing starts again.
		motion:prompting(true)
		expect(motion.promptScale.value).toBe(1)
		expect(motion.promptScale.moving).toBe(false)

		motion:prompting(false)
		expect(motion:promptShown()).toBe(true)
		animator:step(0.2)
		expect(motion.promptLeave.value > 0 and motion.promptLeave.value < 1).toBe(true)
		-- Down again before it has gone: it pops in afresh, solid.
		motion:prompting(true)
		expect(motion.promptLeave.value).toBe(0)
		expect(motion.promptLeave.moving).toBe(false)
		expect(motion.promptScale.value).toBe(0)

		motion:prompting(false)
		animator:step(0.4)
		expect(motion.promptLeave.value).toBe(1)
		expect(motion:promptShown()).toBe(false)
	end)

	it("leaves each line over its banner's last easeSeconds, writing only when that changes", function()
		local animator = Animator.new(config.UI.hud.motion)
		local motion = BannerMotion.new(config.UI.hud.motion, animator, 1)
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
