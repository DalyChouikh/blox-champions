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

local config = Fixtures.config()
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/ButtonX@2x.png"

local folder: Folder
local setters: { [string]: (string) -> () }

-- Hints for every control, each reading its own name, with `keys` for their keys (an "X" key otherwise).
local function hints(keys: { [string]: ControlHints.KeyView }): React.ReactElement
	local views: ControlHints.HintKeys = {}
	local labels: ControlHints.HintLabels = {}
	setters = {}
	for _, control: Config.TouchControl in ControlLabels.CONTROLS do
		views[control] = keys[control] or { text = "X" }
		labels[control], setters[control] = React.createBinding(control)
	end
	return React.createElement(React.Fragment, nil, {
		ControlHints = React.createElement(ControlHints, { config = config, keys = views, labels = labels }),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ControlHintsTest"
	folder.Parent = workspace
end)

afterEach(function()
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
