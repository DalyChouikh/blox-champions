--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)

-- Roblox gives every character its default Animate unless StarterCharacterScripts holds a LocalScript of that name.
-- Destroying the default after a load raced the client: it could start a looping animation first, which then played
-- over the poses for good.
describe("Animate", function()
	it("replaces Roblox's default Animate, so no default animation ever plays over the poses", function()
		local animate = StarterPlayer.StarterCharacterScripts:FindFirstChild(SkaterRig.animate)
		expect(animate ~= nil and animate.ClassName == "LocalScript").toBe(true)
	end)
end)
