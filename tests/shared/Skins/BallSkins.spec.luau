--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)

describe("BallSkins", function()
	it("holds a frozen Default skin: a colour and the name of its look", function()
		local skin = BallSkins.get(BallSkins.DEFAULT)
		expect(typeof(skin.color)).toBe("Color3")
		expect(skin.look).toBe("Default")
		expect(table.isfrozen(skin)).toBe(true)
	end)

	it("makes the Default ball white, Roller Champions' neutral ball", function()
		-- The owner (#327, Q159): the ball's colour from a kickoff until a team first holds it (Video 31 at 27.2 s).
		expect(BallSkins.get(BallSkins.DEFAULT).color:ToHex()).toBe("ffffff")
	end)

	-- #400 (the owner's Q277): a skin's look is its picture over the ball mesh's paint map, laid over the ball's own
	-- colour where the picture is see-through (Overlay), so the team colours still show (Q158).
	it("gives every skin a look: a picture laid over the ball's colour", function()
		for _, id in BallSkins.ids() do
			local look = BallSkins.look(id)
			expect(look:IsA("SurfaceAppearance")).toBe(true)
			expect(look.AlphaMode).toBe(Enum.AlphaMode.Overlay)
			expect(string.match(look.ColorMapContent.Uri or "", "^rbxassetid://%d+$")).never.toBeNil()
		end
	end)

	-- #415 (the owner's Q319, Q345): the ball glows in the colour of the team that last held it where its skin's glow
	-- mask is white (the Default's is black on the band, scripts/art/build_ball.py), and each screen lights it; the
	-- look itself starts unlit, so a neutral ball, or a screen that has not lit it yet, never glows white.
	it("gives every skin's look a glow mask, unlit until a screen lights it", function()
		for _, id in BallSkins.ids() do
			local look = BallSkins.look(id)
			expect(string.match(look.EmissiveMaskContent.Uri or "", "^rbxassetid://%d+$")).never.toBeNil()
			expect(look.EmissiveStrength).toBe(0)
		end
	end)

	it("lists every skin, Default among them", function()
		expect(table.find(BallSkins.ids(), BallSkins.DEFAULT)).never.toBeNil()
		expect(table.isfrozen(BallSkins.ids())).toBe(true)
	end)

	it("rejects an unknown skin", function()
		expect(function()
			BallSkins.get("Ghost")
		end).toThrow('BallSkins: unknown skin "Ghost"')
		expect(function()
			BallSkins.look("Ghost")
		end).toThrow('BallSkins: unknown skin "Ghost"')
	end)
end)
