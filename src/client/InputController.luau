--!strict
-- The skating and action keys (spec §8.3) on Roblox's Input Action System, built from Config.Input. One context sits
-- above Roblox's own character controls and sinks the keys it binds, so their defaults never fire on ours.
-- SkateController reads the skating keys once per physics step and ActionController the action keys. A press is
-- counted when it happens, so one that starts and ends between two reads still counts; a hold is read as it is now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- One read of the keys: the move stick (x right, y forward) and the buttons. `jump` is a press since the last read.
export type SkateKeys = { move: Vector2, pump: boolean, brake: boolean, attach: boolean, jump: boolean }
-- One read of the action keys: a press since the last read for each, and the throw held now.
export type ActionKeys = { tackle: boolean, uppercut: boolean, pass: boolean, throw: boolean }

-- The pressed (not held) buttons, each counted on its own.
type Presses = { jump: number, tackle: number, uppercut: number, pass: number }
type Pressed = "jump" | "tackle" | "uppercut" | "pass"

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type InputController = {
	name: string,
	dependencies: { string },
	init: (self: InputController, deps: { [string]: any }) -> (),
	start: ((self: InputController) -> ())?,
	context: InputContext,
	newKeys: () -> SkateKeys,
	read: (self: InputController, into: SkateKeys) -> (),
	newActionKeys: () -> ActionKeys,
	readActions: (self: InputController, into: ActionKeys) -> (),
	destroy: (self: InputController) -> (),
	_move: InputAction,
	_pump: InputAction,
	_brake: InputAction,
	_attach: InputAction,
	_throw: InputAction,
	_presses: Presses,
	_connections: { RBXScriptConnection },
}

local function newAction(context: InputContext, name: string, actionType: Enum.InputActionType): InputAction
	local action = Instance.new("InputAction")
	action.Name = name
	action.Type = actionType
	action.Parent = context
	return action
end

local function bindKeys(action: InputAction, keys: { Enum.KeyCode })
	for _, key in keys do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = action
	end
end

local function newButton(context: InputContext, name: string, keys: { Enum.KeyCode }): InputAction
	local action = newAction(context, name, Enum.InputActionType.Bool)
	bindKeys(action, keys)
	return action
end

-- A button whose presses are counted under `pressed` until the next read.
local function newPressButton(
	self: InputController,
	name: string,
	keys: { Enum.KeyCode },
	pressed: Pressed
): InputAction
	local action = newButton(self.context, name, keys)
	table.insert(
		self._connections,
		action.Pressed:Connect(function()
			self._presses[pressed] += 1
		end)
	)
	return action
end

-- Whether `pressed` was pressed since its last read; the count starts over.
local function takePress(self: InputController, pressed: Pressed): boolean
	local presses = self._presses
	local any = presses[pressed] > 0
	presses[pressed] = 0
	return any
end

local InputController: InputController = {
	name = "InputController",
	dependencies = { "Config" },
	context = nil :: any,
	_move = nil :: any,
	_pump = nil :: any,
	_brake = nil :: any,
	_attach = nil :: any,
	_throw = nil :: any,
	_presses = { jump = 0, tackle = 0, uppercut = 0, pass = 0 },
	_connections = {},

	-- deps.Parent keeps the context out of the local player's PlayerScripts in tests.
	init = function(self: InputController, deps: { [string]: any })
		local input: Config.InputConfig = (deps.Config :: Config.GameConfig).Input
		local context = Instance.new("InputContext")
		context.Name = "SkateControls"
		context.Priority = input.contextPriority
		context.Sink = true
		self.context = context
		self._presses = { jump = 0, tackle = 0, uppercut = 0, pass = 0 }
		self._connections = {}

		local move = newAction(context, "Move", Enum.InputActionType.Direction2D)
		for _, composite in input.move.composites do
			local binding = Instance.new("InputBinding")
			binding.Up = composite.up
			binding.Down = composite.down
			binding.Left = composite.left
			binding.Right = composite.right
			binding.Parent = move
		end
		bindKeys(move, input.move.sticks)
		self._move = move
		newPressButton(self, "Jump", input.jump, "jump")
		self._pump = newButton(context, "Pump", input.pump)
		self._brake = newButton(context, "Brake", input.brake)
		self._attach = newButton(context, "Attach", input.attach)
		newPressButton(self, "Tackle", input.tackle, "tackle")
		newPressButton(self, "Uppercut", input.uppercut, "uppercut")
		newPressButton(self, "Pass", input.pass, "pass")
		self._throw = newButton(context, "Throw", input.throw)
		context.Parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerScripts")
	end,

	newKeys = function(): SkateKeys
		return { move = Vector2.zero, pump = false, brake = false, attach = false, jump = false }
	end,

	read = function(self: InputController, into: SkateKeys)
		into.move = self._move:GetState() :: Vector2
		into.pump = self._pump:GetState() :: boolean
		into.brake = self._brake:GetState() :: boolean
		into.attach = self._attach:GetState() :: boolean
		into.jump = takePress(self, "jump")
	end,

	newActionKeys = function(): ActionKeys
		return { tackle = false, uppercut = false, pass = false, throw = false }
	end,

	readActions = function(self: InputController, into: ActionKeys)
		into.tackle = takePress(self, "tackle")
		into.uppercut = takePress(self, "uppercut")
		into.pass = takePress(self, "pass")
		into.throw = self._throw:GetState() :: boolean
	end,

	destroy = function(self: InputController)
		for _, connection in self._connections do
			connection:Disconnect()
		end
		table.clear(self._connections)
		self.context:Destroy()
	end,
}

return InputController
