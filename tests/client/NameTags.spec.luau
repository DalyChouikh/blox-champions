--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NameTags = require(Client.NameTags)

local config = Config.defaults()
local colors = config.UI.teamColors
local DT = 1 / 60

local folder: Folder
-- The game's players as NameTags sees them; the first is the local player, on Blue.
local players: { any }

-- A stand-in player in the game, named `name`, on `team` (nil while spectating), with a rig in the test folder.
local function join(userId: number, name: string, team: string?): any
	local player = Fixtures.stubPlayer(userId)
	player.DisplayName = name
	player.Character = Fixtures.rig(folder, name, CFrame.new(userId * 10, 5, 0))
	player:SetAttribute(Attributes.Team, team)
	table.insert(players, player)
	return player
end

-- A player's tag, straight under the tags' parent.
local function tag(userId: number): BillboardGui?
	return folder:FindFirstChild(tostring(userId)) :: BillboardGui?
end

local function label(userId: number, name: string): TextLabel
	return (tag(userId) :: BillboardGui):FindFirstChild(name) :: TextLabel
end

local function call(player: any, calling: boolean?)
	(player.Character :: Model):SetAttribute(Attributes.CallingPass, calling)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "NameTagsTest"
	folder.Parent = workspace
	players = {}
	local localPlayer = join(1, "One", "Blue")
	NameTags:init({
		Config = config,
		Parent = folder,
		Players = function(): { any }
			return players
		end,
		LocalPlayer = localPlayer,
	})
end)

afterEach(function()
	folder:Destroy()
end)

describe("NameTags", function()
	it("tags every other player with their name in their team's colour, through walls", function()
		local mate = join(2, "Two", "Blue")
		join(3, "Three", "Orange")
		NameTags:step(DT)
		expect(tag(1) == nil).toBe(true)
		local found = tag(2)
		expect(found ~= nil).toBe(true)
		local gui = found :: BillboardGui
		expect(gui.AlwaysOnTop).toBe(true)
		-- A respawn deletes a folder in PlayerGui and every gui there with ResetOnSpawn on (probed in Play).
		expect(gui.ResetOnSpawn).toBe(false)
		expect(gui.Adornee == Fixtures.root(mate.Character)).toBe(true)
		expect(gui.StudsOffset == config.UI.nameTag.studsOffset).toBe(true)
		expect(gui.Size == config.UI.nameTag.size).toBe(true)
		expect(label(2, "Name").Text).toBe("Two")
		expect(label(2, "Name").TextColor3 == colors.Blue).toBe(true)
		expect(label(3, "Name").Text).toBe("Three")
		expect(label(3, "Name").TextColor3 == colors.Orange).toBe(true)
		expect(label(2, "Call").Visible).toBe(false)
	end)

	it("shows a hand over a teammate calling for the ball, not over an opponent", function()
		local mate = join(2, "Two", "Blue")
		local opponent = join(3, "Three", "Orange")
		call(mate, true)
		call(opponent, true)
		NameTags:step(DT)
		expect(label(2, "Call").Visible).toBe(true)
		expect(label(2, "Call").Text).toBe(config.UI.text.callPass)
		expect(label(3, "Call").Visible).toBe(false)
		call(mate, nil)
		NameTags:step(DT)
		expect(label(2, "Call").Visible).toBe(false)
	end)

	it("drops the tag of a player who left or lost their character, and tags no one without a seat", function()
		local leaving = join(2, "Two", "Blue")
		local unloaded = join(3, "Three", "Orange")
		local unseated = join(4, "Four", "Orange")
		join(5, "Five", nil)
		NameTags:step(DT)
		expect(tag(2) ~= nil and tag(3) ~= nil and tag(4) ~= nil).toBe(true)
		expect(tag(5) == nil).toBe(true)
		table.remove(players, table.find(players, leaving))
		unloaded.Character = nil
		unseated:SetAttribute(Attributes.Team, nil)
		NameTags:step(DT)
		expect(tag(2) == nil and tag(3) == nil and tag(4) == nil).toBe(true)
	end)

	it("follows a player to a new character and a new team", function()
		local other = join(2, "Two", "Blue")
		NameTags:step(DT)
		local gui = tag(2) :: BillboardGui
		other.Character = Fixtures.rig(folder, "TwoAgain", CFrame.new(0, 5, 50))
		other:SetAttribute(Attributes.Team, "Orange")
		NameTags:step(DT)
		expect(tag(2) == gui).toBe(true)
		expect(gui.Adornee == Fixtures.root(other.Character)).toBe(true)
		expect(label(2, "Name").TextColor3 == colors.Orange).toBe(true)
	end)

	it("steps in under 0.1 ms", function()
		local others = {}
		for userId = 2, 6 do
			table.insert(others, join(userId, `Player{userId}`, if userId % 2 == 0 then "Blue" else "Orange"))
		end
		NameTags:step(DT)
		local total = 0
		for step = 1, 600 do
			-- A teammate starts or stops calling every 100 steps.
			if step % 100 == 0 then
				call(others[1], not (others[1].Character :: Model):GetAttribute(Attributes.CallingPass))
			end
			local started = os.clock()
			NameTags:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
