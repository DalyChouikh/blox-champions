--!strict
-- Switches off what Roblox gives every game by default and ours replaces (spec §8.5):
-- - the player list (Tab opens our score tab);
-- - a gamepad's Select (or Backslash) jumping into gui navigation (Select also opens the score tab);
-- - Roblox's touch controls (ours draw their own stick and buttons);
-- - its character and camera input contexts (our skating, actions and camera own those keys, and Roblox's abilities
--   would still fire on the keys we don't sink).
-- Roblox's shift lock is off in the place itself (the project files set StarterPlayer.EnableMouseLockOption). The
-- player list, the gui navigation and the touch controls go off at once. Roblox adds its PlayerModule, which holds the
-- input contexts, to StarterPlayer once the client runs, so the contexts go off in a thread of their own once they
-- appear; a context never found is reported by name.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)

-- Roblox's own names for the PlayerModule, its contexts folder, and the contexts we switch off.
local PLAYER_MODULE = "PlayerModule"
local INPUT_CONTEXTS = "InputContexts"
local CONTEXTS = { "CharacterContext", "CameraContext" }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type RobloxDefaults = {
	name: string,
	dependencies: { string },
	init: (self: RobloxDefaults, deps: { [string]: any }) -> (),
	start: (self: RobloxDefaults) -> (),
	_log: (line: string) -> (),
	-- StarterGui and GuiService, or fakes.
	_starterGui: any,
	_guiService: any,
	-- Waits for the PlayerModule's InputContexts folder; nil when it never appears.
	_findContexts: () -> Instance?,
}

local function logLine(line: string)
	warn(line)
end

local RobloxDefaults: RobloxDefaults = {
	name = "RobloxDefaults",
	dependencies = { "Config" },
	_log = logLine,
	_starterGui = nil,
	_guiService = nil,
	_findContexts = function(): Instance?
		return nil
	end,

	-- deps.Log, deps.StarterGui, deps.GuiService and deps.FindContexts replace the live game in tests.
	init = function(self: RobloxDefaults, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._log = deps.Log or logLine
		self._starterGui = deps.StarterGui or StarterGui
		self._guiService = deps.GuiService or GuiService
		self._findContexts = deps.FindContexts
			or function(): Instance?
				local wait = config.Input.robloxContextsWaitSeconds
				local playerModule = StarterPlayer:WaitForChild(PLAYER_MODULE, wait)
				return if playerModule ~= nil then playerModule:WaitForChild(INPUT_CONTEXTS, wait) else nil
			end
	end,

	start = function(self: RobloxDefaults)
		self._starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		self._guiService.TouchControlsEnabled = false
		self._guiService.AutoSelectGuiEnabled = false
		task.spawn(function()
			local contexts = self._findContexts()
			for _, name in CONTEXTS do
				local context = if contexts ~= nil then contexts:FindFirstChild(name) else nil
				if context ~= nil and context:IsA("InputContext") then
					context.Enabled = false
				else
					self._log(`[BloxChampions] RobloxDefaults: no {name} in Roblox's {PLAYER_MODULE}; its keys stay on`)
				end
			end
		end)
	end,
}

return RobloxDefaults
