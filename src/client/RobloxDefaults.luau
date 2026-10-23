--!strict
-- Switches off what Roblox gives every game by default and ours replaces (spec §8.5): the player list (Tab opens our
-- score tab), Roblox's touch controls (ours draw their own stick and buttons), and its character and camera input
-- contexts (our skating, actions and camera own those keys, and Roblox's abilities would still fire on the keys we
-- don't sink). Roblox's shift lock is off in the place itself (the project files set
-- StarterPlayer.EnableMouseLockOption). Roblox adds its PlayerModule, which holds the input contexts, to
-- StarterPlayer once the client runs, so start() waits for them in its own thread; a context it never finds is
-- reported, and everything else is still switched off.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)

-- Roblox's own names for the PlayerModule, its contexts folder, and the contexts we switch off.
local PLAYER_MODULE = "PlayerModule"
local INPUT_CONTEXTS = "InputContexts"
local CONTEXTS = { "CharacterContext", "CameraContext" }

-- What `apply` switches off: StarterGui, GuiService and the PlayerModule's InputContexts folder (nil when it never
-- appeared), or fakes in tests.
export type Services = { StarterGui: any, GuiService: any, InputContexts: Instance? }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type RobloxDefaults = {
	name: string,
	dependencies: { string },
	init: (self: RobloxDefaults, deps: { [string]: any }) -> (),
	start: (self: RobloxDefaults) -> (),
	apply: (self: RobloxDefaults, services: Services) -> (),
	_config: Config.GameConfig,
	_log: (line: string) -> (),
}

local function logLine(line: string)
	warn(line)
end

local RobloxDefaults: RobloxDefaults = {
	name = "RobloxDefaults",
	dependencies = { "Config" },
	_config = nil :: any,
	_log = logLine,

	-- deps.Log replaces the console in tests.
	init = function(self: RobloxDefaults, deps: { [string]: any })
		self._config = deps.Config
		self._log = deps.Log or logLine
	end,

	start = function(self: RobloxDefaults)
		task.spawn(function()
			local wait = self._config.Input.robloxContextsWaitSeconds
			local playerModule = StarterPlayer:WaitForChild(PLAYER_MODULE, wait)
			self:apply({
				StarterGui = StarterGui,
				GuiService = GuiService,
				InputContexts = if playerModule ~= nil then playerModule:WaitForChild(INPUT_CONTEXTS, wait) else nil,
			})
		end)
	end,

	apply = function(self: RobloxDefaults, services: Services)
		services.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		services.GuiService.TouchControlsEnabled = false
		local contexts = services.InputContexts
		for _, name in CONTEXTS do
			local context = if contexts ~= nil then contexts:FindFirstChild(name) else nil
			if context ~= nil and context:IsA("InputContext") then
				context.Enabled = false
			else
				self._log(`[BloxChampions] RobloxDefaults: no {name} in Roblox's {PLAYER_MODULE}; its keys stay on`)
			end
		end
	end,
}

return RobloxDefaults
