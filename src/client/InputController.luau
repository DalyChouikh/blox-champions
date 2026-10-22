--!strict
-- The skating keys (spec §8.3) on Roblox's Input Action System, built from Config.Input. One context sits above
-- Roblox's own character controls and sinks the keys it binds, so their defaults never fire on ours. SkateController
-- reads it once per physics step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- One read of the keys: the move stick (x right, y forward) and the buttons. `jump` is a press since the last read.
export type SkateKeys = { move: Vector2, pump: boolean, brake: boolean, attach: boolean, jump: boolean }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type InputController = {
	name: string,
	dependencies: { string },
	init: (self: InputController, deps: { [string]: any }) -> (),
	start: ((self: InputController) -> ())?,
	context: InputContext,
	newKeys: () -> SkateKeys,
	read: (self: InputController, into: SkateKeys) -> (),
	destroy: (self: InputController) -> (),
	_move: InputAction,
	_pump: InputAction,
	_brake: InputAction,
	_attach: InputAction,
	_jumps: number,
	_jumpPressed: RBXScriptConnection?,
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

local InputController: InputController = {
	name = "InputController",
	dependencies = { "Config" },
	context = nil :: any,
	_move = nil :: any,
	_pump = nil :: any,
	_brake = nil :: any,
	_attach = nil :: any,
	_jumps = 0,
	_jumpPressed = nil,

	-- deps.Parent keeps the context out of the local player's PlayerScripts in tests.
	init = function(self: InputController, deps: { [string]: any })
		local input: Config.InputConfig = (deps.Config :: Config.GameConfig).Input
		local context = Instance.new("InputContext")
		context.Name = "SkateControls"
		context.Priority = input.contextPriority
		context.Sink = true

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
		local jump = newButton(context, "Jump", input.jump)
		self._move = move
		self._pump = newButton(context, "Pump", input.pump)
		self._brake = newButton(context, "Brake", input.brake)
		self._attach = newButton(context, "Attach", input.attach)

		self._jumps = 0
		self._jumpPressed = jump.Pressed:Connect(function()
			self._jumps += 1
		end)
		context.Parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerScripts")
		self.context = context
	end,

	newKeys = function(): SkateKeys
		return { move = Vector2.zero, pump = false, brake = false, attach = false, jump = false }
	end,

	read = function(self: InputController, into: SkateKeys)
		into.move = self._move:GetState() :: Vector2
		into.pump = self._pump:GetState() :: boolean
		into.brake = self._brake:GetState() :: boolean
		into.attach = self._attach:GetState() :: boolean
		into.jump = self._jumps > 0
		self._jumps = 0
	end,

	destroy = function(self: InputController)
		if self._jumpPressed ~= nil then
			self._jumpPressed:Disconnect()
			self._jumpPressed = nil
		end
		self.context:Destroy()
	end,
}

return InputController
