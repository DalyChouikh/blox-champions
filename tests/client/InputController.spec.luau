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
		Fixtures.scriptedBinding(context, "Move"):Fire(Vector2.new(0.6, 0.8))
		Fixtures.scriptedBinding(context, "Brake"):Fire(true)
		local keys = InputController.newKeys()
		InputController:read(keys)
		expect(keys.move.X).toBeCloseTo(0.6, 5)
		expect(keys.move.Y).toBeCloseTo(0.8, 5)
		expect(keys.brake).toBe(true)
		expect(keys.pump).toBe(false)
		expect(keys.attach).toBe(false)
	end)

	it("counts a jump press once, however long it is held", function()
		local jump = Fixtures.scriptedBinding(InputController.context, "Jump")
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

	it("reads action presses once and the throw while held", function()
		local context = InputController.context
		local tackle = Fixtures.scriptedBinding(context, "Tackle")
		local pass = Fixtures.scriptedBinding(context, "Pass")
		local throw = Fixtures.scriptedBinding(context, "Throw")
		local actions = InputController.newActionKeys()
		tackle:Fire(true)
		pass:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:readActions(actions)
		expect(actions).toEqual({ tackle = true, uppercut = false, pass = true, throw = false })
		InputController:readActions(actions)
		expect(actions).toEqual({ tackle = false, uppercut = false, pass = false, throw = false })
		-- A hold is read from the state, at once.
		throw:Fire(true)
		InputController:readActions(actions)
		expect(actions.throw).toBe(true)
		InputController:readActions(actions)
		expect(actions.throw).toBe(true)
		throw:Fire(false)
		InputController:readActions(actions)
		expect(actions.throw).toBe(false)
	end)

	it("keeps the skating keys and the action keys apart", function()
		local context = InputController.context
		local jump = Fixtures.scriptedBinding(context, "Jump")
		local tackle = Fixtures.scriptedBinding(context, "Tackle")
		local keys, actions = InputController.newKeys(), InputController.newActionKeys()
		jump:Fire(true)
		tackle:Fire(true)
		task.wait()
		InputController:readActions(actions)
		InputController:read(keys)
		expect(keys.jump).toBe(true)
		expect(actions.tackle).toBe(true)

		jump:Fire(false)
		tackle:Fire(false)
		jump:Fire(true)
		tackle:Fire(true)
		task.wait()
		InputController:read(keys)
		InputController:readActions(actions)
		expect(keys.jump).toBe(true)
		expect(actions.tackle).toBe(true)
	end)
end)
