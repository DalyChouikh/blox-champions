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

	it("rejects an unknown skin", function()
		expect(function()
			BallSkins.get("Ghost")
		end).toThrow('BallSkins: unknown skin "Ghost"')
	end)
end)
