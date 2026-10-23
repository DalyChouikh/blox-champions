--!strict
-- The skating and action keys (spec §8.3) for keyboard and gamepad, bound through Roblox's Input Action System.
-- Phase 7 adds the mobile buttons and the on-screen hints here, so bindings and hints come from one place.

local Validate = require(script.Parent.Validate)

-- Four keys that make one direction, like WASD.
export type Composite = { up: Enum.KeyCode, down: Enum.KeyCode, left: Enum.KeyCode, right: Enum.KeyCode }

export type InputConfig = {
	-- Above Roblox's own character controls (priority 150), whose defaults on our keys this context sinks.
	contextPriority: number,
	move: { composites: { Composite }, sticks: { Enum.KeyCode } },
	jump: { Enum.KeyCode },
	pump: { Enum.KeyCode },
	brake: { Enum.KeyCode },
	attach: { Enum.KeyCode },
	-- Tackle, a Dive during a tackle, or a Dodge with the ball.
	tackle: { Enum.KeyCode },
	uppercut: { Enum.KeyCode },
	-- A Pass with the ball, a Call Pass without.
	pass: { Enum.KeyCode },
	-- Held to charge a throw, released to throw.
	throw: { Enum.KeyCode },
}

local defaults: InputConfig = {
	contextPriority = 1000,
	move = {
		composites = { { up = Enum.KeyCode.W, down = Enum.KeyCode.S, left = Enum.KeyCode.A, right = Enum.KeyCode.D } },
		sticks = { Enum.KeyCode.Thumbstick1 },
	},
	jump = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
	pump = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2 },
	brake = { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonR1 },
	attach = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
	tackle = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
	uppercut = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
	pass = { Enum.KeyCode.R, Enum.KeyCode.ButtonY },
	throw = { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonL2 },
}

local key = Validate.enumItem(Enum.KeyCode)
local keys = Validate.list(key)

local fields = Validate.record({
	contextPriority = Validate.number({ min = 0, integer = true }),
	move = Validate.record({
		composites = Validate.list(Validate.record({ up = key, down = key, left = key, right = key })),
		sticks = keys,
	}),
	jump = keys,
	pump = keys,
	brake = keys,
	attach = keys,
	tackle = keys,
	uppercut = keys,
	pass = keys,
	throw = keys,
})

-- Every key the bindings use, in order.
local function boundKeys(input: InputConfig): { Enum.KeyCode }
	local all: { Enum.KeyCode } = {}
	for _, composite in input.move.composites do
		table.insert(all, composite.up)
		table.insert(all, composite.down)
		table.insert(all, composite.left)
		table.insert(all, composite.right)
	end
	local lists = {
		input.move.sticks,
		input.jump,
		input.pump,
		input.brake,
		input.attach,
		input.tackle,
		input.uppercut,
		input.pass,
		input.throw,
	}
	for _, list in lists do
		for _, bound in list do
			table.insert(all, bound)
		end
	end
	return all
end

-- One key for one action: the first key bound twice is reported by name.
local function schema(value: any, path: string): { string }
	local errors = fields(value, path)
	if #errors > 0 then
		return errors
	end
	local seen: { [Enum.KeyCode]: boolean } = {}
	for _, bound in boundKeys(value) do
		if seen[bound] then
			return { `{path}: {bound.Name} is bound to more than one action` }
		end
		seen[bound] = true
	end
	return {}
end

return {
	defaults = defaults,
	schema = schema,
}
