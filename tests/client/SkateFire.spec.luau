--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SkateFire = require(Client.SkateFire)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)

local config = Config.defaults()
local fire = config.UI.skateFire
local DT = 1 / 60

-- Roblox's names for the parts a skate is on: an R15 avatar's feet, an R6 one's legs.
local FEET = { R15 = { "LeftFoot", "RightFoot" }, R6 = { "Left Leg", "Right Leg" } }

local folder: Folder
local players: { any }

-- A stand-in player on `team` (nil while spectating) with a rig whose skates sit under it: R15 feet, or R6 legs.
local function join(userId: number, team: string?, rigType: Enum.HumanoidRigType?): any
	local player = Fixtures.stubPlayer(userId)
	local rig = Fixtures.rig(folder, `Skater{userId}`, CFrame.new(userId * 10, 5, 0), rigType)
	for _, name in FEET[if rigType == Enum.HumanoidRigType.R6 then "R6" else "R15"] do
		if rig:FindFirstChild(name) == nil then
			local foot = Instance.new("Part")
			foot.Name = name
			foot.Size = Vector3.new(1, 0.4, 1.2)
			foot.CFrame = CFrame.new(userId * 10, 2, 0)
			foot.Anchored = true
			foot.Parent = rig
		end
	end
	player.Character = rig
	player:SetAttribute(Attributes.Team, team)
	table.insert(players, player)
	return player
end

local function trailsOf(player: any): { Trail }
	local trails = {}
	for _, name in FEET[if player.Character:FindFirstChild("LeftFoot") then "R15" else "R6"] do
		local trail = (player.Character:FindFirstChild(name) :: BasePart):FindFirstChildWhichIsA("Trail")
		if trail ~= nil then
			table.insert(trails, trail)
		end
	end
	return trails
end

local function moving(player: any, speed: number)
	Fixtures.root(player.Character).AssemblyLinearVelocity = Vector3.new(speed, 0, 0)
end

-- Whether both trails show (or neither, `shown` false), in `team`'s colour.
local function lit(player: any, shown: boolean, team: string?): boolean
	local trails = trailsOf(player)
	if #trails ~= 2 then
		return false
	end
	for _, trail in trails do
		if trail.Enabled ~= shown then
			return false
		end
		if team ~= nil and trail.Color ~= ColorSequence.new(config.UI.teamColors[team :: any]) then
			return false
		end
	end
	return true
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "SkateFireTest"
	folder.Parent = workspace
	players = {}
	SkateFire:init({
		Config = config,
		Players = function(): { Player }
			return players
		end,
	})
end)

afterEach(function()
	folder:Destroy()
end)

describe("SkateFire", function()
	-- The owner's Q298: every skater's two skates, in the team's colour; a flat ribbon behind each, like RC's. Q331
	-- (look G): lifted off the floor, drawn in the colour itself at three times its brightness.
	it(
		"gives each skater with a team a trail under each skate, flat and just over its sole, glowing in the team's "
			.. "colour",
		function()
			local player = join(1, "Orange")
			SkateFire:step(DT)
			expect(lit(player, false, "Orange")).toBe(true)
			for _, trail in trailsOf(player) do
				local foot = trail.Parent :: BasePart
				local a0, a1 = trail.Attachment0 :: Attachment, trail.Attachment1 :: Attachment
				expect(a0.Parent == foot and a1.Parent == foot).toBe(true)
				expect({ trail.Name, a0.Name, a1.Name }).toEqual({ "SkateFire", "SkateFireLeft", "SkateFireRight" })
				local over = -foot.Size.Y / 2 + fire.lift
				Fixtures.expectNear(a0.Position, Vector3.new(-fire.width / 2, over, 0))
				Fixtures.expectNear(a1.Position, Vector3.new(fire.width / 2, over, 0))
				expect(trail.FaceCamera).toBe(false)
				-- Stored as a 32-bit float.
				expect(trail.Lifetime).toBeCloseTo(fire.lifetime, 6)
				expect(trail.LightEmission).toBe(0)
				expect(trail.LightInfluence).toBe(0)
				expect(trail.Brightness).toBe(fire.brightness)
				expect(trail.Transparency).toEqual(NumberSequence.new({
					NumberSequenceKeypoint.new(0, fire.transparency),
					NumberSequenceKeypoint.new(fire.fade.from, fire.fade.transparency),
					NumberSequenceKeypoint.new(1, 1),
				}))
			end
		end
	)

	-- Q298: while moving (skating, pumping, any motion), none while still; Roblox lengthens a trail with speed.
	it("shows the trails while the skater moves and hides them once nearly still", function()
		local player = join(1, "Blue")
		moving(player, fire.minSpeed)
		SkateFire:step(DT)
		expect(lit(player, true, "Blue")).toBe(true)
		moving(player, fire.minSpeed * 0.9)
		SkateFire:step(DT)
		expect(lit(player, false, "Blue")).toBe(true)
	end)

	it("changes the trails' colour when the skater switches team", function()
		local player = join(1, "Blue")
		moving(player, 40)
		SkateFire:step(DT)
		player:SetAttribute(Attributes.Team, "Orange")
		SkateFire:step(DT)
		expect(lit(player, true, "Orange")).toBe(true)
	end)

	it("gives a spectator none, and takes a skater's away once they leave or stop playing", function()
		local spectator = join(1, nil)
		local player = join(2, "Orange")
		-- On a team, between characters (dead, or not spawned yet).
		join(3, "Blue").Character = nil
		SkateFire:step(DT)
		expect(#trailsOf(spectator)).toBe(0)
		expect(#trailsOf(player)).toBe(2)
		player:SetAttribute(Attributes.Team, nil)
		SkateFire:step(DT)
		expect(#trailsOf(player)).toBe(0)
		player:SetAttribute(Attributes.Team, "Orange")
		SkateFire:step(DT)
		expect(lit(player, false, "Orange")).toBe(true)
		table.clear(players)
		SkateFire:step(DT)
		expect(#trailsOf(player)).toBe(0)
		-- The attachments the trails ran between go too.
		expect(player.Character:FindFirstChildWhichIsA("Attachment", true)).toBeNil()
	end)

	-- Roblox sets a player's character before every part of the avatar has arrived.
	it("waits for a character's root, humanoid and both skates before giving it trails", function()
		local player = join(1, "Orange")
		local character = player.Character
		for _, name in { SkaterRig.root, SkaterRig.humanoid, FEET.R15[2] } do
			local part = character:FindFirstChild(name) :: Instance
			part.Parent = nil
			SkateFire:step(DT)
			expect(character:FindFirstChildWhichIsA("Trail", true)).toBeNil()
			part.Parent = character
		end
		SkateFire:step(DT)
		expect(lit(player, false, "Orange")).toBe(true)
	end)

	it("gives a new character trails of its own, and an R6 avatar trails under its legs", function()
		local player = join(1, "Orange")
		SkateFire:step(DT)
		local old = player.Character
		local other = join(2, "Blue", Enum.HumanoidRigType.R6)
		table.remove(players, 2)
		player.Character = other.Character
		SkateFire:step(DT)
		expect(#trailsOf(player)).toBe(2)
		expect(lit(player, false, "Orange")).toBe(true)
		expect(old:FindFirstChildWhichIsA("Trail", true)).toBeNil()
	end)

	-- Six skaters, as a match has; every 50 steps one starts or stops and another switches team.
	it("steps six skaters in under 0.1 ms", function()
		for userId = 1, 6 do
			moving(join(userId, if userId % 2 == 0 then "Blue" else "Orange"), 40)
		end
		SkateFire:step(DT)
		local total = 0
		for step = 1, 600 do
			if step % 50 == 0 then
				local skater, switcher = players[step % 6 + 1], players[(step + 3) % 6 + 1]
				moving(skater, if Fixtures.root(skater.Character).AssemblyLinearVelocity.Magnitude > 0 then 0 else 40)
				switcher:SetAttribute(
					Attributes.Team,
					if switcher:GetAttribute(Attributes.Team) == "Blue" then "Orange" else "Blue"
				)
			end
			local started = os.clock()
			SkateFire:step(DT)
			total += os.clock() - started
		end
		Fixtures.expectWithinBudget(total / 600, 0.0001)
	end)
end)
