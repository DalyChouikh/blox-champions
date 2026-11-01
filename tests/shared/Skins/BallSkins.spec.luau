--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)

describe("BallSkins", function()
	it("holds a frozen Default skin with a color and a material", function()
		local skin = BallSkins.get(BallSkins.DEFAULT)
		expect(typeof(skin.color)).toBe("Color3")
		expect(typeof(skin.material)).toBe("EnumItem")
		expect(table.isfrozen(skin)).toBe(true)
	end)

	it("makes the Default ball white, Roller Champions' neutral ball", function()
		-- The owner (#327, Q159): the ball's colour from a kickoff until a team first holds it (Video 31 at 27.2 s).
		expect(BallSkins.get(BallSkins.DEFAULT).color:ToHex()).toBe("ffffff")
	end)

	it("rejects an unknown skin", function()
		expect(function()
			BallSkins.get("Ghost")
		end).toThrow('BallSkins: unknown skin "Ghost"')
	end)
end)
