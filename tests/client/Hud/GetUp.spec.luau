--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GetUp = require(Client.Hud.GetUp)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(Client.Hud.Style)

local config = Fixtures.config()
-- Roblox's glyph for a gamepad's left stick (probed).
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/Thumbstick1@2x.png"

local folder: Folder

-- The prompt keyed as App keys it, which names its frame.
local function prompt(keys: { Style.KeyView }): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		GetUp = React.createElement(GetUp, { config = config, keys = keys }),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "GetUpTest"
	folder.Parent = workspace
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("GetUp", function()
	it("shows the movement keys in order, then the Get Up label, where the layout puts it", function()
		-- An AZERTY keyboard's movement keys, as Roblox names W, A, S and D there (probed).
		local names = { "Z", "Q", "S", "D" }
		local views: { Style.KeyView } = {}
		for _, name in names do
			table.insert(views, { text = name })
		end
		local frame = Fixtures.mount(prompt(views), folder):FindFirstChild("GetUp") :: Frame
		for index, name in names do
			local key = frame:FindFirstChild(`Key{index}`) :: TextLabel
			expect(`{key.Text} at {key.LayoutOrder}`).toBe(`{name} at {index}`)
		end
		local label = frame:FindFirstChild("Label") :: TextLabel
		expect(label.Text).toBe(config.UI.controlLabels.GetUp)
		expect(label.LayoutOrder).toBe(#names + 1)
		local place = config.UI.hud.layout.getUp
		expect(frame.Position).toEqual(place.position)
		expect(frame.Size).toEqual(place.size)
		-- On the HUD's panel, like Roller Champions' box, so it reads over the skater; the keys fill its height inside
		-- the padding: 40 - 2 × 6 = 28 px.
		expect(frame.BackgroundTransparency).toBeCloseTo(config.UI.hud.panelTransparency, 4)
		expect((frame:FindFirstChild("Key1") :: TextLabel).Size).toEqual(UDim2.fromOffset(28, 28))
	end)

	it("shows a gamepad's stick as Roblox's glyph", function()
		local frame = Fixtures.mount(prompt({ { image = GLYPH } }), folder):FindFirstChild("GetUp") :: Frame
		expect((frame:FindFirstChild("Glyph1") :: ImageLabel).Image).toBe(GLYPH)
		expect(frame:FindFirstChild("Key1")).toBeNil()
		expect((frame:FindFirstChild("Label") :: TextLabel).LayoutOrder).toBe(2)
	end)
end)
