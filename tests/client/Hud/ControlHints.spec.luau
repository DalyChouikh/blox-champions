--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(Client.Hud.ControlHints)
local ControlLabels = require(Client.ControlLabels)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(Client.Hud.Style)

local config = Fixtures.config()
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/ButtonX@2x.png"

local folder: Folder
local setters: { [string]: (string) -> () }
local fadeSetters: { [string]: (number) -> () }

-- Hints for every control, each reading its own name, lit, with `keys` for their keys (an "X" key otherwise).
local function hints(keys: { [string]: Style.KeyView }): React.ReactElement
	local views: ControlHints.HintKeys = {}
	local labels: ControlHints.HintLabels = {}
	local fades: ControlHints.HintFades = {}
	setters, fadeSetters = {}, {}
	for _, control: Config.TouchControl in ControlLabels.CONTROLS do
		views[control] = keys[control] or { text = "X" }
		labels[control], setters[control] = React.createBinding(control)
		fades[control], fadeSetters[control] = React.createBinding(0)
	end
	return React.createElement(React.Fragment, nil, {
		ControlHints = React.createElement(
			ControlHints,
			{ config = config, keys = views, labels = labels, fades = fades }
		),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ControlHintsTest"
	folder.Parent = workspace
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("ControlHints", function()
	it("shows each control's key: the keyboard's own key names, Roblox's gamepad glyphs", function()
		local mounted = Fixtures.mount(hints({ tackle = { text = "E" }, pass = { image = GLYPH } }), folder)
		local frame = mounted:FindFirstChild("ControlHints") :: Frame
		local tackle = frame:FindFirstChild("tackle") :: Frame
		expect((tackle:FindFirstChild("Key") :: TextLabel).Text).toBe("E")
		expect((tackle:FindFirstChild("Label") :: TextLabel).Text).toBe("tackle")
		local pass = frame:FindFirstChild("pass") :: Frame
		expect((pass:FindFirstChild("Glyph") :: ImageLabel).Image).toBe(GLYPH)
		expect(pass:FindFirstChild("Key")).toBeNil()
		for index, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect((frame:FindFirstChild(control) :: Frame).LayoutOrder).toBe(index)
		end
	end)

	-- A greyed hint (#315: Magnetic Pass with nobody to pass to; RC fades the whole row, Video 34 at 43.0 s): its key
	-- or glyph and its label faded as its fade binding says, without a render.
	it("fades a greyed hint's key and label as its fade says", function()
		local mounted = Fixtures.mount(hints({ pass = { image = GLYPH } }), folder)
		local frame = mounted:FindFirstChild("ControlHints") :: Frame
		local tackle, pass = frame:FindFirstChild("tackle") :: Frame, frame:FindFirstChild("pass") :: Frame
		expect((tackle:FindFirstChild("Key") :: TextLabel).TextTransparency).toBe(0)
		fadeSetters.tackle(0.6)
		fadeSetters.pass(0.6)
		expect((tackle:FindFirstChild("Key") :: TextLabel).TextTransparency).toBeCloseTo(0.6, 4)
		expect((tackle:FindFirstChild("Label") :: TextLabel).TextTransparency).toBeCloseTo(0.6, 4)
		expect((pass:FindFirstChild("Glyph") :: ImageLabel).ImageTransparency).toBeCloseTo(0.6, 4)
		expect((pass:FindFirstChild("Label") :: TextLabel).TextTransparency).toBeCloseTo(0.6, 4)
		fadeSetters.tackle(0)
		expect((tackle:FindFirstChild("Label") :: TextLabel).TextTransparency).toBe(0)
	end)

	it("hides a hint whose control does nothing now", function()
		local mounted = Fixtures.mount(hints({}), folder)
		local attach = (mounted:FindFirstChild("ControlHints") :: Frame):FindFirstChild("attach") :: Frame
		expect(attach.Visible).toBe(true)
		setters.attach("")
		expect(attach.Visible).toBe(false)
		setters.attach("Attach")
		expect(attach.Visible).toBe(true)
		expect((attach:FindFirstChild("Label") :: TextLabel).Text).toBe("Attach")
	end)
end)
