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
-- A gamepad's glyph for the pass key, as Roblox names it (probed: a PNG under the controller's textures).
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/ButtonY@2x.png"

local folder: Folder
-- The game's players as NameTags sees them; the first is the local player, on Blue.
local players: { any }
-- The teammate a pass would go to now (ActionController:passTarget), and the HUD's pass key (Hud.passKey).
local target: string?
local hud: { passKey: { text: string?, image: string? }? }

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

-- A part of a player's tag, wherever it sits in it.
local function label(userId: number, name: string): TextLabel
	return (tag(userId) :: BillboardGui):FindFirstChild(name, true) :: TextLabel
end

-- The pass key's cap over a player's tag (#315): a key's name ("Key") or a gamepad's glyph ("Glyph"); nil without.
local function passKey(userId: number): GuiObject?
	local found = tag(userId)
	local holder = if found ~= nil then found:FindFirstChild("PassKey", true) else nil
	if holder == nil then
		return nil
	end
	return (holder:FindFirstChild("Key") or holder:FindFirstChild("Glyph")) :: GuiObject?
end

-- A call for the ball at `at` on the server's clock (its CallingPass), or none.
local function call(player: any, at: number?)
	(player.Character :: Model):SetAttribute(Attributes.CallingPass, at)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "NameTagsTest"
	folder.Parent = workspace
	players = {}
	target = nil
	hud = { passKey = { text = "R" } }
	local localPlayer = join(1, "One", "Blue")
	NameTags:init({
		Config = config,
		ActionController = {
			passTarget = function(_self: any): string?
				return target
			end,
		},
		Hud = hud,
		Parent = folder,
		Players = function(): { any }
			return players
		end,
		LocalPlayer = localPlayer,
	})
end)

afterEach(function()
	NameTags:destroy()
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
		call(mate, 1)
		call(opponent, 1)
		NameTags:step(DT)
		expect(label(2, "Call").Visible).toBe(true)
		expect(label(2, "Call").Text).toBe(config.UI.text.callPass)
		expect(label(3, "Call").Visible).toBe(false)
		call(mate, nil)
		NameTags:step(DT)
		expect(label(2, "Call").Visible).toBe(false)
	end)

	-- Magnetic Pass, RC's way (#315, the owner: Q103, Q105; Video 34 at 41.6 s): with the ball, the pass key's letter
	-- floats over the teammate the pass would go to, beside their hand while they call.
	it("shows the pass key over the teammate a pass would go to, beside their hand while they call", function()
		local mate = join(2, "Two", "Blue")
		join(3, "Three", "Blue")
		NameTags:step(DT)
		expect(passKey(2)).toBeNil()
		expect(passKey(3)).toBeNil()
		target = "2"
		NameTags:step(DT)
		local key = passKey(2) :: TextLabel
		expect(key.Text).toBe("R")
		-- As tall as the hand's row.
		expect(key.Size.Y.Offset).toBe(config.UI.nameTag.callSize)
		expect(passKey(3)).toBeNil()
		-- In the hand's row, after the hand: alone in its middle until they call, then beside the hand.
		local holder = key.Parent :: GuiObject
		local hand = label(2, "Call")
		expect(holder.Parent == hand.Parent).toBe(true)
		expect(holder.LayoutOrder).toBeGreaterThan(hand.LayoutOrder)
		local layout = (hand.Parent :: Instance):FindFirstChildOfClass("UIListLayout") :: UIListLayout
		expect(layout.FillDirection).toBe(Enum.FillDirection.Horizontal)
		expect(layout.HorizontalAlignment).toBe(Enum.HorizontalAlignment.Center)
		call(mate, 1)
		NameTags:step(DT)
		expect(hand.Visible).toBe(true)
		expect(passKey(2) == key).toBe(true)
		-- Another target, then none.
		target = "3"
		NameTags:step(DT)
		expect(passKey(2)).toBeNil()
		expect((passKey(3) :: TextLabel).Text).toBe("R")
		target = nil
		NameTags:step(DT)
		expect(passKey(3)).toBeNil()
		-- Never over an opponent.
		join(4, "Four", "Orange")
		target = "4"
		NameTags:step(DT)
		expect(passKey(4)).toBeNil()
	end)

	it("shows the pass key as the device shows it: a gamepad's glyph, the touch mark", function()
		join(2, "Two", "Blue")
		target = "2"
		hud.passKey = { image = GLYPH }
		NameTags:step(DT)
		expect((passKey(2) :: ImageLabel).Image).toBe(GLYPH)
		hud.passKey = { text = config.UI.text.touchPassTarget }
		NameTags:step(DT)
		expect((passKey(2) :: TextLabel).Text).toBe(config.UI.text.touchPassTarget)
		-- No key to show (no skater): no cap.
		hud.passKey = nil
		NameTags:step(DT)
		expect(passKey(2)).toBeNil()
	end)

	it("keeps the pass key when its target's tag goes, for the next target", function()
		local leaving = join(2, "Two", "Blue")
		join(3, "Three", "Blue")
		target = "2"
		NameTags:step(DT)
		expect(passKey(2) ~= nil).toBe(true)
		table.remove(players, table.find(players, leaving))
		NameTags:step(DT)
		expect(tag(2) == nil).toBe(true)
		target = "3"
		NameTags:step(DT)
		expect((passKey(3) :: TextLabel).Text).toBe("R")
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
			-- A teammate starts or stops calling every 100 steps, and a pass's target changes every 150.
			if step % 100 == 0 then
				local calling = (others[1].Character :: Model):GetAttribute(Attributes.CallingPass)
				call(others[1], if calling == nil then step else nil)
			end
			if step % 150 == 0 then
				target = if target == "2" then "4" else "2"
			end
			local started = os.clock()
			NameTags:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
