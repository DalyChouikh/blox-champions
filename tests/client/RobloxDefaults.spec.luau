--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local RobloxDefaults = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.RobloxDefaults)

local folder: Folder?
-- What the module logged, and what it asked of the fake StarterGui.
local lines: { string } = {}
local calls: { { coreGui: Enum.CoreGuiType, enabled: boolean } } = {}
local starterGui = {
	SetCoreGuiEnabled = function(_self: any, coreGui: Enum.CoreGuiType, enabled: boolean)
		table.insert(calls, { coreGui = coreGui, enabled = enabled })
	end,
}

beforeEach(function()
	table.clear(lines)
	table.clear(calls)
	RobloxDefaults:init({
		Config = Config.defaults(),
		Log = function(line: string)
			table.insert(lines, line)
		end,
	})
end)

afterEach(function()
	if folder then
		folder:Destroy()
		folder = nil
	end
end)

describe("RobloxDefaults", function()
	it("turns off the player list, Roblox's touch controls, and its character and camera input", function()
		local contexts = Instance.new("Folder")
		contexts.Name = "RobloxDefaultsTest"
		contexts.Parent = workspace
		folder = contexts
		local character = Instance.new("InputContext")
		character.Name = "CharacterContext"
		character.Parent = contexts
		local camera = Instance.new("InputContext")
		camera.Name = "CameraContext"
		camera.Parent = contexts
		local guiService = { TouchControlsEnabled = true }

		RobloxDefaults:apply({ StarterGui = starterGui, GuiService = guiService, InputContexts = contexts })

		expect(calls).toEqual({ { coreGui = Enum.CoreGuiType.PlayerList, enabled = false } })
		expect(guiService.TouchControlsEnabled).toBe(false)
		expect(character.Enabled).toBe(false)
		expect(camera.Enabled).toBe(false)
		expect(lines).toEqual({})
	end)

	it("still turns off the rest when Roblox's input contexts never appear, and says which", function()
		local guiService = { TouchControlsEnabled = true }

		RobloxDefaults:apply({ StarterGui = starterGui, GuiService = guiService, InputContexts = nil })

		expect(calls).toEqual({ { coreGui = Enum.CoreGuiType.PlayerList, enabled = false } })
		expect(guiService.TouchControlsEnabled).toBe(false)
		expect(lines).toEqual({
			"[BloxChampions] RobloxDefaults: no CharacterContext in Roblox's PlayerModule; its keys stay on",
			"[BloxChampions] RobloxDefaults: no CameraContext in Roblox's PlayerModule; its keys stay on",
		})
	end)

	it("keeps Roblox's shift lock off in the place", function()
		expect(game:GetService("StarterPlayer").EnableMouseLockOption).toBe(false)
	end)
end)
