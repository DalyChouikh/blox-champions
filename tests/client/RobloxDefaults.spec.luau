--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local RobloxDefaults = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.RobloxDefaults)

local folder: Folder
-- What the module logged, and what it asked of the fake StarterGui and GuiService.
local lines: { string } = {}
local calls: { { coreGui: Enum.CoreGuiType, enabled: boolean } } = {}
local guiService: { TouchControlsEnabled: boolean }
local starterGui = {
	SetCoreGuiEnabled = function(_self: any, coreGui: Enum.CoreGuiType, enabled: boolean)
		table.insert(calls, { coreGui = coreGui, enabled = enabled })
	end,
}

-- Starts the module on the fakes, with `findContexts` standing in for the wait on Roblox's PlayerModule.
local function start(findContexts: () -> Instance?)
	RobloxDefaults:init({
		Config = Config.defaults(),
		Log = function(line: string)
			table.insert(lines, line)
		end,
		StarterGui = starterGui,
		GuiService = guiService,
		FindContexts = findContexts,
	})
	RobloxDefaults:start()
end

local function newContext(name: string): InputContext
	local context = Instance.new("InputContext")
	context.Name = name
	context.Parent = folder
	return context
end

beforeEach(function()
	table.clear(lines)
	table.clear(calls)
	guiService = { TouchControlsEnabled = true }
	folder = Instance.new("Folder")
	folder.Name = "RobloxDefaultsTest"
	folder.Parent = workspace
end)

afterEach(function()
	folder:Destroy()
end)

describe("RobloxDefaults", function()
	it("turns off the player list and Roblox's touch controls at once, its input once it appears", function()
		local character, camera = newContext("CharacterContext"), newContext("CameraContext")
		local appear = Instance.new("BindableEvent")
		start(function(): Instance?
			appear.Event:Wait()
			return folder
		end)
		expect(calls).toEqual({ { coreGui = Enum.CoreGuiType.PlayerList, enabled = false } })
		expect(guiService.TouchControlsEnabled).toBe(false)
		expect(character.Enabled).toBe(true)

		appear:Fire()
		task.wait() -- the waiting thread resumes
		expect(character.Enabled).toBe(false)
		expect(camera.Enabled).toBe(false)
		expect(lines).toEqual({})
		appear:Destroy()
	end)

	it("still turns off the rest when Roblox's input contexts never appear, and says which", function()
		start(function(): Instance?
			return nil
		end)
		task.wait()
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
