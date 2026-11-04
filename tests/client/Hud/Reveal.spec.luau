--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animator = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Animator)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Reveal = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Reveal)

-- Motion of this spec's own: a 0.2 s pop to 1.1, a 0.4 s ease.
local config = Fixtures.config({
	UI = { hud = { motion = { pop = { seconds = 0.2, overshoot = 0.1 }, easeSeconds = 0.4 } } },
})

describe("Reveal", function()
	-- The Get Up prompt (#369, the owner's Q221) and the TAB board (#357, Q194): no time left to count, each opens and
	-- closes when the game says.
	it("pops in as it opens, fades out as it closes, and shows until it has gone", function()
		local animator = Animator.new(config.UI.hud.motion)
		local reveal = Reveal.new(animator)
		expect(reveal:shown()).toBe(false)
		reveal:set(false)
		expect(reveal:shown()).toBe(false)

		reveal:set(true)
		expect(reveal:shown()).toBe(true)
		expect(reveal.scale.value).toBe(0)
		animator:step(0.1)
		expect(reveal.scale.value > 0).toBe(true)
		animator:step(0.1)
		expect(reveal.scale.value).toBe(1)
		expect(reveal.leave.value).toBe(0)
		-- Still open: nothing starts again.
		reveal:set(true)
		expect(reveal.scale.value).toBe(1)
		expect(reveal.scale.moving).toBe(false)

		reveal:set(false)
		expect(reveal:shown()).toBe(true)
		animator:step(0.2)
		expect(reveal.leave.value > 0 and reveal.leave.value < 1).toBe(true)
		-- Open again before it has gone: it pops in afresh, solid.
		reveal:set(true)
		expect(reveal.leave.value).toBe(0)
		expect(reveal.leave.moving).toBe(false)
		expect(reveal.scale.value).toBe(0)

		reveal:set(false)
		animator:step(0.4)
		expect(reveal.leave.value).toBe(1)
		expect(reveal:shown()).toBe(false)
	end)

	it("moves each reveal on its own tracks", function()
		local animator = Animator.new(config.UI.hud.motion)
		local prompt, board = Reveal.new(animator), Reveal.new(animator)
		board:set(true)
		expect(board.scale.value).toBe(0)
		expect(prompt.scale.value).toBe(1)
		expect(prompt:shown()).toBe(false)
	end)
end)
