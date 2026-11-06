--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local CallBadge = require(ReplicatedStorage.Shared.Hud.CallBadge)
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NameTags = require(Client.NameTags)
local Style = require(Client.Hud.Style)

local config = Config.defaults()
local tagConfig = config.UI.nameTag
local look = config.UI.hud.look
local sizes, compactSizes = tagConfig.sizes, tagConfig.compactSizes
local DT = 1 / 60
-- A gamepad's glyph for the pass key, as Roblox names it (probed: a PNG under the controller's textures).
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/ButtonY@2x.png"

local folder: Folder
-- The game's players as NameTags sees them; the first is the local player, on Blue.
local players: { any }
-- The teammate a pass would go to now (ActionController:passTarget), the HUD's pass and Attach keys and its screen's
-- form.
local target: string?
local hud: { passKey: Style.KeyView?, attachKey: Style.KeyView?, compact: boolean }
-- The teammate the skater would attach behind now (SkateController.attachWith).
local skate: { attachWith: string? }
-- How many times the tags asked for a pass's target.
local passAsks: number

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

-- A part of a player's tag, wherever it sits in it; nil while it is not drawn.
local function part(userId: number, name: string): any
	local found = tag(userId)
	return if found ~= nil then found:FindFirstChild(name, true) else nil
end

-- The pass key's cap over a player's tag (#315): a key's name ("Key") or a gamepad's glyph ("Glyph"); nil without.
local function passKey(userId: number): GuiObject?
	local holder = part(userId, "PassKey")
	if holder == nil then
		return nil
	end
	return (holder:FindFirstChild("Key", true) or holder:FindFirstChild("Glyph", true)) :: GuiObject?
end

-- The words a cap shows: its legend's.
local function legend(cap: GuiObject): string
	return (cap:FindFirstChild("Legend", true) :: TextLabel).Text
end

-- A call for the ball at `at` on the server's clock (its CallingPass), or none.
local function call(player: any, at: number?)
	(player.Character :: Model):SetAttribute(Attributes.CallingPass, at)
end

-- How far above the tag's middle the key cap's line runs: the pill's top half and ink, the gap, the pointer, half the
-- cap.
local function lineAt(tagSizes: Config.TagSizes): number
	return tagSizes.height / 2
		- (tagSizes.pillHeight / 2 + look.outline + tagSizes.gap + tagSizes.pointer + tagSizes.cap.height / 2)
end

-- NameTags afresh at `settings`, over this test's players (the first the local one), target and HUD.
local function start(settings: Config.GameConfig)
	NameTags:init({
		Config = settings,
		ActionController = {
			passTarget = function(_self: any): string?
				passAsks += 1
				return target
			end,
		},
		Hud = hud,
		SkateController = skate,
		Parent = folder,
		Players = function(): { any }
			return players
		end,
		LocalPlayer = players[1],
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "NameTagsTest"
	folder.Parent = workspace
	players = {}
	target = nil
	hud = { passKey = { text = "R" }, attachKey = { text = "F" }, compact = false }
	skate = { attachWith = nil }
	passAsks = 0
	join(1, "One", "Blue")
	start(config)
end)

afterEach(function()
	NameTags:destroy()
	folder:Destroy()
end)

describe("NameTags", function()
	-- M1 Stacked (the owner's Q197): the name in a look C pill in the team's HUD colour, white lettering in its ink.
	it("tags every other player with their name in a pill of their team's colour, through walls", function()
		local mate = join(2, "Two", "Blue")
		join(3, "Three", "Orange")
		NameTags:step(DT)
		expect(tag(1) == nil).toBe(true)
		local gui = tag(2) :: BillboardGui
		expect(gui.AlwaysOnTop).toBe(true)
		-- A respawn deletes a folder in PlayerGui and every gui there with ResetOnSpawn on (probed in Play).
		expect(gui.ResetOnSpawn).toBe(false)
		-- Look C's parts lie in ZIndex order among siblings; a BillboardGui draws by global ZIndex unless told.
		expect(gui.ZIndexBehavior).toBe(Enum.ZIndexBehavior.Sibling)
		expect(gui.Adornee == Fixtures.root(mate.Character)).toBe(true)
		expect(gui.StudsOffset == tagConfig.studsOffset).toBe(true)
		expect(gui.Size).toEqual(UDim2.fromOffset(sizes.width, sizes.height))
		-- Lifted in pixels, so the pill's ink rests on the point over the head at any distance.
		local lift = (sizes.pillHeight / 2 + look.outline + look.shadow) / sizes.height
		expect(gui.SizeOffset.Y).toBeCloseTo(lift, 4)
		expect(gui.SizeOffset.X).toBe(0)
		local name = part(2, "Player") :: TextLabel
		expect(name.Text).toBe("Two")
		expect(name.TextSize).toBe(sizes.textSize)
		expect(name.Font).toBe(look.font)
		expect(name.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(name:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		expect(name.Size).toEqual(UDim2.new(1, -2 * sizes.pillInset, 1, 0))
		-- The pill: as wide as the name with pillInset each side, on the tag's middle.
		local pill = part(2, "Pill") :: Frame
		local width = Style.textWidth(config, "Two", sizes.textSize) + 2 * sizes.pillInset
		expect(pill.Size).toEqual(UDim2.fromOffset(width, sizes.pillHeight))
		expect(pill.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
		expect(pill.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		-- Round all the way (M1 drew a pill).
		local corner = (pill:FindFirstChild("Fill1") :: Frame):FindFirstChildOfClass("UICorner") :: UICorner
		expect(corner.CornerRadius).toEqual(UDim.new(0.5, 0))
		local shade = (pill:FindFirstChild("Shade", true) :: UIGradient).Color.Keypoints[1].Value
		expect(shade == look.teamColors.Blue).toBe(true)
		local other = (part(3, "Pill") :: Frame):FindFirstChild("Shade", true) :: UIGradient
		expect(other.Color.Keypoints[1].Value == look.teamColors.Orange).toBe(true)
		expect(part(2, "Badge")).toBeNil()
		expect(passKey(2)).toBeNil()
	end)

	-- A long name ends where the pill would pass the tag's edge.
	it("keeps a long name's pill inside the tag", function()
		join(2, string.rep("W", 40), "Blue")
		NameTags:step(DT)
		local pill = part(2, "Pill") :: Frame
		expect(pill.Size.X.Offset).toBe(sizes.width - 2 * look.outline)
		expect((part(2, "Player") :: TextLabel).TextTruncate).toBe(Enum.TextTruncate.AtEnd)
	end)

	-- On a phone's screen the phone's sizes (the Hud's compact).
	it("draws at the phone's sizes on a phone's screen, again when the screen changes", function()
		local mate = join(2, "Two", "Blue")
		NameTags:step(DT)
		hud.compact = true
		NameTags:step(DT)
		expect((tag(2) :: BillboardGui).Size).toEqual(UDim2.fromOffset(compactSizes.width, compactSizes.height))
		local lift = (compactSizes.pillHeight / 2 + look.outline + look.shadow) / compactSizes.height
		expect((tag(2) :: BillboardGui).SizeOffset.Y).toBeCloseTo(lift, 4)
		expect((part(2, "Player") :: TextLabel).TextSize).toBe(compactSizes.textSize)
		expect((part(2, "Pill") :: Frame).Size.Y.Offset).toBe(compactSizes.pillHeight)
		-- The glove's pivot on the nearest pixel: 2 + 10 x 0.76 = 9.6, which an Offset would cut to 9.
		call(mate, 1)
		NameTags:step(DT)
		expect((part(2, "Glove") :: Frame).Position.Y.Offset).toBe(10)
	end)

	-- H4 (Q198): a team-colour badge with an ink rim, the E2 glove (Q241) inside, alone over the name.
	it("shows the call's badge over a teammate calling for the ball, not over an opponent", function()
		local mate = join(2, "Two", "Blue")
		local opponent = join(3, "Three", "Orange")
		call(mate, 1)
		call(opponent, 1)
		NameTags:step(DT)
		local badge = part(2, "Badge") :: Frame
		expect(part(3, "Badge")).toBeNil()
		local disc = badge:FindFirstChild("Disc") :: Frame
		expect(disc.BackgroundColor3 == look.teamColors.Blue).toBe(true)
		expect((disc:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness).toBe(sizes.rim)
		expect((disc:FindFirstChildOfClass("UIStroke") :: UIStroke).Color == look.ink).toBe(true)
		expect(badge.Size).toEqual(UDim2.fromOffset(2 * sizes.badge, 2 * sizes.badge))
		-- Over the name's middle, on the key cap's line.
		expect(badge.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
		expect(badge.Position).toEqual(UDim2.fromOffset(sizes.width / 2, lineAt(sizes)))
		-- The glove: each part over its ink, the seams on top.
		local glove = badge:FindFirstChild("Glove") :: Frame
		-- The ring behind the disc, the glove in front of it.
		local ripple = badge:FindFirstChild("Ripple") :: Frame
		expect(ripple.ZIndex < disc.ZIndex and disc.ZIndex < glove.ZIndex).toBe(true)
		for index = 1, #tagConfig.glove.parts do
			expect(glove:FindFirstChild(`Ink{index}`) ~= nil and glove:FindFirstChild(`Fill{index}`) ~= nil).toBe(true)
		end
		for index = 1, #tagConfig.glove.seams do
			expect(glove:FindFirstChild(`Seam{index}`) ~= nil).toBe(true)
		end
		local palm = CallBadge.place(tagConfig.glove.parts[1], sizes.glove, 0)
		local fill = glove:FindFirstChild("Fill1") :: Frame
		-- By Scale in a holder 2 x badge across: a UDim's Offset would cut a seam 0.9 units wide to nothing.
		local across = 2 * sizes.badge
		expect(fill.Size.X.Scale).toBeCloseTo(palm.width / across, 4)
		expect(fill.Size.Y.Scale).toBeCloseTo(palm.height / across, 4)
		expect(fill.BackgroundColor3 == Color3.new(1, 1, 1)).toBe(true)
		local ink = glove:FindFirstChild("Ink1") :: Frame
		local grown = CallBadge.place(tagConfig.glove.parts[1], sizes.glove, tagConfig.glove.ink)
		expect(ink.Size.X.Scale).toBeCloseTo(grown.width / across, 4)
		expect(ink.Size.Y.Scale).toBeCloseTo(grown.height / across, 4)
		expect(ink.BackgroundColor3 == look.ink).toBe(true)
		local seam = glove:FindFirstChild("Seam1") :: Frame
		expect(seam.BackgroundColor3 == look.ink).toBe(true)
		-- A seam has no ink of its own.
		local placedSeam = CallBadge.place(tagConfig.glove.seams[1], sizes.glove, 0)
		expect(seam.Size.X.Scale).toBeCloseTo(placedSeam.width / across, 4)
		expect(ink.ZIndex < fill.ZIndex and fill.ZIndex < seam.ZIndex).toBe(true)
		-- The thumb keeps its own turn inside the glove.
		local thumb = #tagConfig.glove.parts
		local thumbFill = glove:FindFirstChild(`Fill{thumb}`) :: Frame
		expect(thumbFill.Rotation).toBe(tagConfig.glove.parts[thumb].turn)
		-- By its middle, wherever that lies in the glove.
		local placedThumb = CallBadge.place(tagConfig.glove.parts[thumb], sizes.glove, 0)
		expect(thumbFill.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
		expect(thumbFill.Position.X.Scale).toBeCloseTo(0.5 + placedThumb.x / across, 4)
		-- The glove turns round its wave's pivot, gloveDrop under the badge's middle and wavePivot glove units more.
		local pivot = tagConfig.call.wavePivot * sizes.glove
		expect(glove.Position).toEqual(UDim2.new(0.5, 0, 0.5, sizes.gloveDrop + pivot))
		expect(fill.Position.X.Scale).toBeCloseTo(0.5 + palm.x / across, 4)
		expect(fill.Position.Y.Scale).toBeCloseTo(0.5 + (palm.y - pivot) / across, 4)
		-- A bar's corners as round as the part's: the palm's 5 units on its 16 units' shorter side.
		expect((fill:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius.Scale).toBeCloseTo(5 / 16, 4)
		-- A finger's 2.25 units on its 4.5 units' shorter side: round all the way.
		local finger = glove:FindFirstChild("Fill2") :: Frame
		expect((finger:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius.Scale).toBeCloseTo(0.5, 4)
		call(mate, nil)
		NameTags:step(DT)
		expect(part(2, "Badge")).toBeNil()
	end)

	-- Their settings are their own, though equal today.
	it("draws the rim and the ring's line at their own widths", function()
		NameTags:destroy()
		start(Fixtures.config({ UI = { nameTag = { sizes = { rim = 5, rippleLine = 2 } } } }))
		call(join(2, "Two", "Blue"), 1)
		NameTags:step(DT)
		expect((part(2, "Rim") :: UIStroke).Thickness).toBe(5)
		local ring = part(2, "Ripple") :: Frame
		expect((ring:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness).toBe(2)
	end)

	-- Magnetic Pass, RC's way (#315, the owner: Q103, Q105; Video 34 at 41.6 s), in M1: the pass key on look C's cap
	-- with a pointer under it over the teammate the pass would go to, the badge left of it while they call.
	it("shows the pass key with its pointer over the teammate a pass would go to, the badge left of it", function()
		local mate = join(2, "Two", "Blue")
		join(3, "Three", "Blue")
		NameTags:step(DT)
		expect(passKey(2)).toBeNil()
		target = "2"
		NameTags:step(DT)
		local cap = passKey(2) :: GuiObject
		expect(legend(cap)).toBe("R")
		expect(cap.Size.Y.Offset).toBe(sizes.cap.height)
		expect(passKey(3)).toBeNil()
		-- Alone, in the tag's middle on whole pixels, the pointer in the key's yellow under it.
		local key = part(2, "PassKey") :: Frame
		local width = Style.capWidth(config, { text = "R" }, sizes.cap)
		local line = lineAt(sizes)
		expect(key.Size).toEqual(UDim2.fromOffset(width, sizes.cap.height))
		expect(key.Position).toEqual(
			UDim2.fromOffset(math.floor((sizes.width - width) / 2), line - sizes.cap.height / 2)
		)
		local pointer = key:FindFirstChild("Pointer") :: Frame
		expect(pointer.BackgroundColor3 == look.key).toBe(true)
		expect(pointer:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		expect(pointer.Rotation).toBe(45)
		expect(pointer.Position).toEqual(UDim2.fromScale(0.5, 1))
		expect(pointer.Size).toEqual(
			UDim2.fromOffset(math.round(sizes.pointer * math.sqrt(2)), math.round(sizes.pointer * math.sqrt(2)))
		)
		expect(pointer.ZIndex < (key:FindFirstChild("Cap") :: Frame).ZIndex).toBe(true)
		-- They call: the badge, then badgeGap, then the key, the pair on the tag's middle.
		call(mate, 1)
		NameTags:step(DT)
		local badge = part(2, "Badge") :: Frame
		local ringed = 2 * (sizes.badge + sizes.rim)
		local left = math.floor((sizes.width - (ringed + sizes.badgeGap + width)) / 2)
		expect(badge.Position).toEqual(UDim2.fromOffset(left + sizes.badge + sizes.rim, line))
		expect((part(2, "PassKey") :: Frame).Position.X.Offset).toBe(left + ringed + sizes.badgeGap)
		-- Another target, then none; never over an opponent.
		target = "3"
		NameTags:step(DT)
		expect(passKey(2)).toBeNil()
		expect(legend(passKey(3) :: GuiObject)).toBe("R")
		target = nil
		NameTags:step(DT)
		expect(passKey(3)).toBeNil()
		join(4, "Four", "Orange")
		target = "4"
		NameTags:step(DT)
		expect(passKey(4)).toBeNil()
	end)

	it("shows the pass key as the device shows it: a gamepad's glyph, the PASS chip on touch", function()
		join(2, "Two", "Blue")
		target = "2"
		hud.passKey = { image = GLYPH }
		NameTags:step(DT)
		expect(((passKey(2) :: GuiObject):FindFirstChild("Face") :: ImageLabel).Image).toBe(GLYPH)
		hud.passKey = { text = config.UI.text.touchPassTarget }
		hud.compact = true
		NameTags:step(DT)
		local chip = passKey(2) :: GuiObject
		expect(legend(chip)).toBe("PASS")
		expect(chip.Size.Y.Offset).toBe(compactSizes.cap.height)
		-- The holder as wide as its words.
		local chipWidth = Style.capWidth(config, { text = "PASS" }, compactSizes.cap)
		expect(chipWidth > compactSizes.cap.height).toBe(true)
		expect((part(2, "PassKey") :: Frame).Size.X.Offset).toBe(chipWidth)
		-- No key to show (no skater): no cap.
		hud.passKey = nil
		NameTags:step(DT)
		expect(passKey(2)).toBeNil()
	end)

	-- Only the hints' caps have a mouse's sizes: on a tag a pass key on a mouse's button goes by its name, as a cap
	-- that cannot draw the mouse would otherwise throw and take the tag down.
	it("names a pass key on a mouse's button on its cap", function()
		join(2, "Two", "Blue")
		target = "2"
		hud.passKey = { text = "RMB", mouse = "Right" }
		NameTags:step(DT)
		local cap = passKey(2) :: GuiObject
		expect(legend(cap)).toBe("RMB")
		expect(cap:FindFirstChild("Mouse", true)).toBeNil()
		expect((part(2, "PassKey") :: Frame).Size.X.Offset).toBe(Style.capWidth(config, { text = "RMB" }, sizes.cap))
	end)

	-- Hud.passKey makes a new key at each of its renders: alike, it draws nothing; differing in any way, once.
	it("draws the pass key again only when the key it shows changes", function()
		join(2, "Two", "Blue")
		target = "2"
		NameTags:step(DT)
		local function redraws(view: Style.KeyView): number
			local before = NameTags.renders
			hud.passKey = view
			NameTags:step(DT)
			return NameTags.renders - before
		end
		expect(redraws({ text = "R" })).toBe(0)
		expect(redraws({ text = "E" })).toBe(1)
		expect(legend(passKey(2) :: GuiObject)).toBe("E")
		expect(redraws({ image = GLYPH })).toBe(1)
		expect(redraws({ image = "rbxasset://textures/ui/Controls/DefaultController/ButtonX@2x.png" })).toBe(1)
		expect(redraws({ text = "MB", mouse = "Left" })).toBe(1)
		expect(redraws({ text = "MB", mouse = "Right" })).toBe(1)
		expect(redraws({ text = "MB", mouse = "Right" })).toBe(0)
	end)

	-- Working out a pass's target walks the teammates and casts through the arena: not while no key would show.
	it("asks for a pass's target only while there is a key to show", function()
		join(2, "Two", "Blue")
		hud.passKey = nil
		NameTags:step(DT)
		expect(passAsks).toBe(0)
		hud.passKey = { text = "R" }
		NameTags:step(DT)
		expect(passAsks).toBe(1)
	end)

	-- The Attach mark (#381, the owner's Q246, Q247 Look 1) over the teammate the skater would attach behind now
	-- (SkateController.attachWith): a dark box as tall as the pass key's cap and outlined as it is, in the touch
	-- buttons' fill as the page drew it; the Attach key's cap flush with its left, its right edge inked, then the word
	-- with cap.padding round it; its pointer under its middle.
	it("shows the Attach mark over the teammate to attach behind: its key's cap and the word in a dark box", function()
		join(2, "Two", "Blue")
		join(3, "Three", "Blue")
		join(4, "Four", "Orange")
		NameTags:step(DT)
		expect(part(2, "Attach")).toBeNil()
		skate.attachWith = "2"
		NameTags:step(DT)
		expect(part(3, "Attach")).toBeNil()
		local mark = part(2, "Attach") :: Frame
		local cap = sizes.cap
		local keyWidth = Style.capWidth(config, { text = "F" }, cap)
		local edge = math.ceil(look.textOutline)
		local word = config.UI.controlLabels.Attach
		local wordWidth = Style.textWidth(config, word, cap.textSize)
		local width = keyWidth + edge + cap.padding + wordWidth + cap.padding
		-- Alone, on the tag's middle and the pass key's line.
		expect(mark.Size).toEqual(UDim2.fromOffset(width, cap.height))
		expect(mark.Position).toEqual(
			UDim2.fromOffset(math.floor((sizes.width - width) / 2), lineAt(sizes) - cap.height / 2)
		)
		-- The box: the touch buttons' fill, round at the cap's corners, outlined as the cap is.
		local box = mark:FindFirstChild("Box") :: Frame
		expect(box.Size).toEqual(UDim2.fromScale(1, 1))
		-- White under its gradient, which multiplies the colour it covers.
		expect(box.BackgroundColor3 == Color3.new(1, 1, 1)).toBe(true)
		local outline = box:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(outline.Thickness).toBe(look.textOutline)
		expect(outline.Color == look.ink).toBe(true)
		expect((box:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(cap.corner)
		local fill = config.UI.touchStyle.fill
		local shade = (box:FindFirstChildOfClass("UIGradient") :: UIGradient).Color.Keypoints
		expect(shade[1].Value == fill.top and shade[#shade].Value == fill.bottom).toBe(true)
		-- The key's cap at its left in the key's yellow, round on the left as the box is, square on the right, where
		-- its edge is inked.
		local key = box:FindFirstChild("Key") :: Frame
		expect(key.Position).toEqual(UDim2.new())
		expect(key.Size).toEqual(UDim2.new(0, keyWidth, 1, 0))
		expect(key.BackgroundColor3 == look.key).toBe(true)
		expect((key:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(cap.corner)
		local square = key:FindFirstChild("Square") :: Frame
		expect(square.Position).toEqual(UDim2.fromScale(0.5, 0))
		expect(square.Size).toEqual(UDim2.fromScale(0.5, 1))
		expect(square.BackgroundColor3 == look.key).toBe(true)
		local letter = key:FindFirstChild("Legend") :: TextLabel
		expect(letter.Text).toBe("F")
		expect(letter.TextSize).toBe(cap.textSize)
		expect(letter.TextColor3 == look.ink).toBe(true)
		expect(letter.ZIndex > square.ZIndex).toBe(true)
		local inked = box:FindFirstChild("Edge") :: Frame
		expect(inked.Position).toEqual(UDim2.fromOffset(keyWidth, 0))
		expect(inked.Size).toEqual(UDim2.new(0, edge, 1, 0))
		expect(inked.BackgroundColor3 == look.ink).toBe(true)
		-- The word white in look C's ink, cap.padding past the edge.
		local words = box:FindFirstChild("Word") :: TextLabel
		expect(words.Text).toBe(word)
		expect(words.TextSize).toBe(cap.textSize)
		expect(words.Font).toBe(look.font)
		expect(words.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(words:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		expect(words.Position).toEqual(UDim2.fromOffset(keyWidth + edge + cap.padding, 0))
		expect(words.Size).toEqual(UDim2.new(0, wordWidth, 1, 0))
		-- Its pointer under its middle in the box's colour where they meet, half under the box.
		local pointer = mark:FindFirstChild("Pointer") :: Frame
		expect(pointer.BackgroundColor3 == fill.bottom).toBe(true)
		expect(pointer.Rotation).toBe(45)
		expect(pointer.Position).toEqual(UDim2.fromScale(0.5, 1))
		expect(pointer.ZIndex < box.ZIndex).toBe(true)
		-- Another teammate, then none; never over an opponent.
		skate.attachWith = "3"
		NameTags:step(DT)
		expect(part(2, "Attach")).toBeNil()
		expect(part(3, "Attach") ~= nil).toBe(true)
		skate.attachWith = "4"
		NameTags:step(DT)
		expect(part(3, "Attach")).toBeNil()
		expect(part(4, "Attach")).toBeNil()
	end)

	-- Q247's order: the badge, the pass key, the Attach mark; each that shows badgeGap from the next, the row on the
	-- tag's middle.
	it("lays the badge, the pass key and the Attach mark out in that order, badgeGap apart", function()
		local mate = join(2, "Two", "Blue")
		target = "2"
		skate.attachWith = "2"
		call(mate, 1)
		NameTags:step(DT)
		local gap = sizes.badgeGap
		local ringed = 2 * (sizes.badge + sizes.rim)
		local keyWidth = Style.capWidth(config, { text = "R" }, sizes.cap)
		local attachWidth = (part(2, "Attach") :: Frame).Size.X.Offset
		local function placed(): (number, number, number)
			local badge, key = part(2, "Badge"), part(2, "PassKey")
			return if badge ~= nil then badge.Position.X.Offset - sizes.badge - sizes.rim else -1,
				if key ~= nil then key.Position.X.Offset else -1,
				(part(2, "Attach") :: Frame).Position.X.Offset
		end
		local left = math.floor((sizes.width - (ringed + gap + keyWidth + gap + attachWidth)) / 2)
		expect({ placed() }).toEqual({ left, left + ringed + gap, left + ringed + gap + keyWidth + gap })
		target = nil
		NameTags:step(DT)
		left = math.floor((sizes.width - (ringed + gap + attachWidth)) / 2)
		expect({ placed() }).toEqual({ left, -1, left + ringed + gap })
		call(mate, nil)
		target = "2"
		NameTags:step(DT)
		left = math.floor((sizes.width - (keyWidth + gap + attachWidth)) / 2)
		expect({ placed() }).toEqual({ -1, left, left + keyWidth + gap })
		target = nil
		NameTags:step(DT)
		expect({ placed() }).toEqual({ -1, -1, math.floor((sizes.width - attachWidth) / 2) })
	end)

	-- As the hints show the Attach key: a gamepad's glyph on the box, no cap; on touch, which has no key, the word
	-- alone with cap.padding each side.
	it("shows the Attach mark as the device shows its key: a gamepad's glyph, the word alone on touch", function()
		join(2, "Two", "Blue")
		skate.attachWith = "2"
		hud.attachKey = { image = GLYPH }
		NameTags:step(DT)
		local word = config.UI.controlLabels.Attach
		local cap = sizes.cap
		local box = part(2, "Box") :: Frame
		local glyph = box:FindFirstChild("Glyph") :: Frame
		expect(glyph.Position).toEqual(UDim2.new())
		expect(glyph.Size).toEqual(UDim2.fromOffset(cap.height, cap.height))
		expect((glyph:FindFirstChild("Face") :: ImageLabel).Image).toBe(GLYPH)
		expect(box:FindFirstChild("Key")).toBeNil()
		expect(box:FindFirstChild("Edge")).toBeNil()
		local wordWidth = Style.textWidth(config, word, cap.textSize)
		expect((box:FindFirstChild("Word") :: TextLabel).Position.X.Offset).toBe(cap.height + cap.padding)
		expect((part(2, "Attach") :: Frame).Size.X.Offset).toBe(cap.height + 2 * cap.padding + wordWidth)
		hud.attachKey = nil
		hud.compact = true
		NameTags:step(DT)
		local small = compactSizes.cap
		box = part(2, "Box") :: Frame
		expect(box:FindFirstChild("Glyph")).toBeNil()
		expect(box:FindFirstChild("Key")).toBeNil()
		expect(box:FindFirstChild("Edge")).toBeNil()
		local words = box:FindFirstChild("Word") :: TextLabel
		local smallWidth = Style.textWidth(config, word, small.textSize)
		expect(words.TextSize).toBe(small.textSize)
		expect(words.Position).toEqual(UDim2.fromOffset(small.padding, 0))
		expect((part(2, "Attach") :: Frame).Size).toEqual(
			UDim2.fromOffset(smallWidth + 2 * small.padding, small.height)
		)
	end)

	-- Hud.attachKey is a new key at each of the Hud's renders: alike, it draws nothing; the mark or its key changing,
	-- once; a key changing while no one is to attach behind, nothing.
	it("draws the Attach mark again only when it or its key changes", function()
		join(2, "Two", "Blue")
		join(3, "Three", "Blue")
		NameTags:step(DT)
		local function redraws(): number
			local before = NameTags.renders
			NameTags:step(DT)
			return NameTags.renders - before
		end
		hud.attachKey = { text = "F" }
		expect(redraws()).toBe(0)
		skate.attachWith = "2"
		expect(redraws()).toBe(1)
		hud.attachKey = { text = "F" }
		expect(redraws()).toBe(0)
		hud.attachKey = { text = "G" }
		expect(redraws()).toBe(1)
		expect(((part(2, "Key") :: Frame):FindFirstChild("Legend") :: TextLabel).Text).toBe("G")
		hud.attachKey = nil
		expect(redraws()).toBe(1)
		expect(part(2, "Key")).toBeNil()
		skate.attachWith = "3"
		expect(redraws()).toBe(2)
		skate.attachWith = nil
		expect(redraws()).toBe(1)
		hud.attachKey = { text = "H" }
		expect(redraws()).toBe(0)
	end)

	-- The widest row (#381): the badge at its widest ripple, the pass key and the Attach mark in its ink, inside the
	-- tag on a desktop and on a phone, by touch and with keys, at the default keys and words.
	it("keeps its widest row inside the tag on either kind of screen", function()
		local mate = join(2, "Two", "Blue")
		target = "2"
		skate.attachWith = "2"
		call(mate, 1)
		type Case = { compact: boolean, pass: Style.KeyView, attach: Style.KeyView? }
		local keys: Case = { compact = false, pass = { text = "R" }, attach = { text = "F" } }
		local cases: { Case } = {
			keys,
			{ compact = true, pass = { text = config.UI.text.touchPassTarget }, attach = nil },
			{ compact = true, pass = keys.pass, attach = keys.attach },
		}
		for _, case in cases do
			hud.compact, hud.passKey, hud.attachKey = case.compact, case.pass, case.attach
			NameTags:step(DT)
			local tagSizes = if hud.compact then compactSizes else sizes
			local ring = tagSizes.badge + tagSizes.ripple + tagSizes.rippleLine
			local mark = part(2, "Attach") :: Frame
			expect((part(2, "Badge") :: Frame).Position.X.Offset - ring >= 0).toBe(true)
			expect(mark.Position.X.Offset + mark.Size.X.Offset + look.textOutline <= tagSizes.width).toBe(true)
		end
	end)

	-- H4: while anyone calls, the glove waves and the ring ripples out, by writing the shared bindings; at rest
	-- nothing.
	it("waves the glove and ripples the ring while a teammate calls, writing nothing at rest", function()
		local mate = join(2, "Two", "Blue")
		NameTags:step(DT)
		local writes = NameTags.writes
		NameTags:step(DT)
		expect(NameTags.writes).toBe(writes)
		call(mate, 1)
		NameTags:step(DT)
		-- A step writes the three bindings; the ring starts at the badge's own size, from sizes made once.
		expect(NameTags.writes).toBe(writes + 3)
		local glove = part(2, "Glove") :: Frame
		local ring = part(2, "Ripple") :: Frame
		local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(ring.Size).toEqual(UDim2.fromOffset(2 * sizes.badge, 2 * sizes.badge))
		local rings = NameTags._rings[sizes]
		expect(rings ~= nil).toBe(true)
		NameTags:step(DT)
		expect(NameTags._rings[sizes] == rings).toBe(true)
		local elapsed = 2 * DT
		for _ = 1, 20 do
			NameTags:step(DT)
			elapsed += DT
		end
		expect(glove.Rotation).toBeCloseTo(CallBadge.wave(tagConfig.call, elapsed), 3)
		local share = CallBadge.ripple(tagConfig.call, elapsed)
		local grown = math.floor(share * sizes.ripple)
		expect(ring.Size).toEqual(UDim2.fromOffset(2 * (sizes.badge + grown), 2 * (sizes.badge + grown)))
		expect(stroke.Transparency).toBeCloseTo(share, 3)
		expect(stroke.Thickness).toBe(sizes.rippleLine)
		expect(stroke.Color == look.teamColors.Blue).toBe(true)
		-- The ring's sizes follow the screen's form.
		hud.compact = true
		NameTags:step(DT)
		elapsed += DT
		share = CallBadge.ripple(tagConfig.call, elapsed)
		grown = math.floor(share * compactSizes.ripple)
		local phoneRing = part(2, "Ripple") :: Frame
		expect(phoneRing.Size).toEqual(
			UDim2.fromOffset(2 * (compactSizes.badge + grown), 2 * (compactSizes.badge + grown))
		)
		call(mate, nil)
		NameTags:step(DT)
		writes = NameTags.writes
		NameTags:step(DT)
		expect(NameTags.writes).toBe(writes)
		-- A new call starts from rest.
		call(mate, 2)
		NameTags:step(DT)
		expect((part(2, "Glove") :: Frame).Rotation).toBeCloseTo(CallBadge.wave(tagConfig.call, DT), 3)
	end)

	-- The last in the list stopping does not stop the rest.
	it("keeps the call moving while any teammate calls", function()
		local first = join(2, "Two", "Blue")
		join(3, "Three", "Blue")
		call(first, 1)
		NameTags:step(DT)
		local writes = NameTags.writes
		NameTags:step(DT)
		expect(NameTags.writes).toBe(writes + 3)
	end)

	-- Its drawing is unmounted, not only its gui destroyed: the shared bindings would keep writing to it for good.
	it("stops following the call once a tag has gone", function()
		local leaving = join(2, "Two", "Blue")
		local staying = join(3, "Three", "Blue")
		call(leaving, 1)
		call(staying, 1)
		NameTags:step(DT)
		local ring = part(2, "Ripple") :: Frame
		table.remove(players, table.find(players, leaving))
		NameTags:step(DT)
		local gone = ring.Size
		for _ = 1, 20 do
			NameTags:step(DT)
		end
		expect(ring.Size).toEqual(gone)
	end)

	-- #364's race: a width measured before look C's font loaded is forgotten once it has; the pills measure again.
	it("draws a tag again only when what it shows changes, and once the widths are measured again", function()
		local mate = join(2, "Two", "Blue")
		NameTags:step(DT)
		local renders = NameTags.renders
		NameTags:step(DT)
		expect(NameTags.renders).toBe(renders)
		Style.widths:forget()
		NameTags:step(DT)
		expect(NameTags.renders).toBe(renders + 1)
		mate.DisplayName = "Deux"
		NameTags:step(DT)
		expect(NameTags.renders).toBe(renders + 2)
		expect((part(2, "Player") :: TextLabel).Text).toBe("Deux")
	end)

	it("keeps the pass key with the next target when its target's tag goes", function()
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
		expect(legend(passKey(3) :: GuiObject)).toBe("R")
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
		-- Back in the game, tagged again.
		table.insert(players, leaving)
		NameTags:step(DT)
		expect(tag(2) ~= nil).toBe(true)
	end)

	it("starts over after destroy", function()
		join(2, "Two", "Blue")
		NameTags:step(DT)
		NameTags:destroy()
		expect(tag(2)).toBeNil()
		NameTags:step(DT)
		expect(tag(2) ~= nil).toBe(true)
	end)

	it("starts afresh when it is initialised again", function()
		call(join(2, "Two", "Blue"), 1)
		for _ = 1, 5 do
			NameTags:step(DT)
		end
		NameTags:destroy()
		start(config)
		expect(NameTags.renders).toBe(0)
		expect(NameTags.writes).toBe(0)
		expect(next(NameTags._rings)).toBeNil()
		NameTags:step(DT)
		expect((part(2, "Glove") :: Frame).Rotation).toBeCloseTo(CallBadge.wave(tagConfig.call, DT), 3)
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
		local shade = (part(2, "Pill") :: Frame):FindFirstChild("Shade", true) :: UIGradient
		expect(shade.Color.Keypoints[1].Value == look.teamColors.Orange).toBe(true)
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
		Fixtures.expectWithinBudget(total / 600, 0.0001)
	end)
end)
