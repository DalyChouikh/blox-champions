--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local CallBadge = require(ReplicatedStorage.Shared.Hud.CallBadge)
local Config = require(ReplicatedStorage.Shared.Config)

local call = Config.defaults().UI.nameTag.call

describe("CallBadge", function()
	-- Roblox turns a frame round its middle; a glove part turns round the middle of its bottom edge (Q241), so its
	-- middle moves: up its height's half from that point, turned with it.
	it("places a glove part by its middle once turned round the middle of its bottom edge", function()
		local straight = CallBadge.place({ x = -9, y = -6, width = 18, height = 16, corner = 5, turn = 0 }, 2, 0)
		expect(straight).toEqual({ x = 0, y = 4, width = 36, height = 32, corner = 10, rotation = 0 })
		-- Off the glove's middle, in pixels too.
		local finger = CallBadge.place({ x = 4.5, y = -14, width = 4.5, height = 11, corner = 2.25, turn = 0 }, 2, 0)
		expect(finger.x).toBeCloseTo(13.5, 6)
		-- A quarter turn clockwise: the bar lies along its bottom edge's middle, out to the right.
		local turned = CallBadge.place({ x = 0, y = 0, width = 4, height = 10, corner = 2, turn = 90 }, 1, 0)
		expect(turned.x).toBeCloseTo(7, 6)
		expect(turned.y).toBeCloseTo(10, 6)
		expect(turned.rotation).toBe(90)
		-- E2's thumb, -26 degrees: its middle 6 units up its lean from (-7.1, 6).
		local thumb = CallBadge.place({ x = -9.6, y = -6, width = 5, height = 12, corner = 2.5, turn = -26 }, 1, 0)
		expect(thumb.x).toBeCloseTo(-7.1 - 6 * math.sin(math.rad(26)), 6)
		expect(thumb.y).toBeCloseTo(6 - 6 * math.cos(math.rad(26)), 6)
	end)

	-- The ink pass: the same middle, grown `grow` units all round, its corners too.
	it("grows a part round its own middle for the glove's ink", function()
		local part = { x = 0, y = -12, width = 4.5, height = 15, corner = 2.25, turn = -26 }
		local fill, ink = CallBadge.place(part, 1.5, 0), CallBadge.place(part, 1.5, 2.5)
		expect(ink.x).toBeCloseTo(fill.x, 6)
		expect(ink.y).toBeCloseTo(fill.y, 6)
		expect(ink.width).toBeCloseTo(fill.width + 7.5, 6)
		expect(ink.height).toBeCloseTo(fill.height + 7.5, 6)
		expect(ink.corner).toBeCloseTo(fill.corner + 3.75, 6)
		expect(ink.rotation).toBe(fill.rotation)
	end)

	-- H4 (Q198): the glove waves waveDegrees each way at waveRate radians a second; a ring ripples out every
	-- rippleSeconds, from nothing grown to all of it.
	it("waves the glove and ripples the ring with the time", function()
		expect(CallBadge.wave(call, 0)).toBe(0)
		expect(CallBadge.wave(call, math.pi / (2 * call.waveRate))).toBeCloseTo(call.waveDegrees, 6)
		expect(CallBadge.wave(call, 3 * math.pi / (2 * call.waveRate))).toBeCloseTo(-call.waveDegrees, 6)
		expect(CallBadge.ripple(call, 0)).toBe(0)
		expect(CallBadge.ripple(call, call.rippleSeconds / 4)).toBeCloseTo(0.25, 6)
		expect(CallBadge.ripple(call, call.rippleSeconds * 2.5)).toBeCloseTo(0.5, 6)
		local slow = table.clone(call)
		slow.rippleSeconds = 2
		expect(CallBadge.ripple(slow, 1)).toBeCloseTo(0.5, 6)
	end)
end)
