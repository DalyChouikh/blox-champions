--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.InputController)

local folder: Folder
beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "InputControllerTest"
	folder.Parent = ReplicatedStorage
	InputController:init({ Config = Fixtures.config(), Parent = folder })
end)
afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("InputController", function()
	it("builds one sinking context above Roblox's own controls, bound as Config.Input says", function()
		local context = InputController.context
		expect(context.Priority).toBe(1000)
		expect(context.Sink).toBe(true)
		local pump = context:FindFirstChild("Pump") :: InputAction
		expect(pump.Type).toBe(Enum.InputActionType.Bool)
		local keys: { string } = {}
		for _, binding in pump:GetChildren() do
			table.insert(keys, (binding :: InputBinding).KeyCode.Name)
		end
		table.sort(keys)
		expect(keys).toEqual({ "ButtonR2", "LeftShift" })
		local move = context:FindFirstChild("Move") :: InputAction
		expect(move.Type).toBe(Enum.InputActionType.Direction2D)
		expect(#move:GetChildren()).toBe(2) -- the WASD composite and the left stick
	end)

	it("reads the move stick and the held buttons", function()
		local context = InputController.context
		Fixtures.scriptedBinding(context:FindFirstChild("Move") :: InputAction):Fire(Vector2.new(0.6, 0.8))
		Fixtures.scriptedBinding(context:FindFirstChild("Brake") :: InputAction):Fire(true)
		local keys = InputController.newKeys()
		InputController:read(keys)
		expect(keys.move.X).toBeCloseTo(0.6, 5)
		expect(keys.move.Y).toBeCloseTo(0.8, 5)
		expect(keys.brake).toBe(true)
		expect(keys.pump).toBe(false)
		expect(keys.attach).toBe(false)
	end)

	it("counts a jump press once, however long it is held", function()
		local jump = Fixtures.scriptedBinding(InputController.context:FindFirstChild("Jump") :: InputAction)
		local keys = InputController.newKeys()
		jump:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:read(keys)
		expect(keys.jump).toBe(true)
		InputController:read(keys)
		expect(keys.jump).toBe(false)
		jump:Fire(false)
		jump:Fire(true)
		task.wait()
		InputController:read(keys)
		expect(keys.jump).toBe(true)
	end)
end)
