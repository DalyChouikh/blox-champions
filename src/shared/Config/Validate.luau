--!strict
-- Small validation DSL for config tables. Every validator returns all the errors it finds, each
-- prefixed with the exact config path (e.g. "Match.pointsToWin"), so a bad value is easy to locate.

export type Validator = (value: any, path: string) -> { string }

local Validate = {}

local function joinPath(path: string, key: string): string
	return if path == "" then key else `{path}.{key}`
end

local function atPath(path: string, message: string): string
	return if path == "" then message else `{path}: {message}`
end

local function typeError(path: string, expected: string, value: any): { string }
	return { atPath(path, `expected {expected}, got {typeof(value)}`) }
end

-- min and max are inclusive bounds; above is an exclusive lower bound (for sizes that must be > 0), below an
-- exclusive upper one (for slopes short of upright).
function Validate.number(
	options: { min: number?, max: number?, above: number?, below: number?, integer: boolean? }?
): Validator
	local min = options and options.min
	local max = options and options.max
	local above = options and options.above
	local below = options and options.below
	local integer = options and options.integer
	return function(value: any, path: string): { string }
		if type(value) ~= "number" then
			return typeError(path, "number", value)
		end
		if value ~= value then
			return { atPath(path, "must not be NaN") }
		end
		if value == math.huge or value == -math.huge then
			return { atPath(path, "must be finite") }
		end
		local errors = {}
		if min ~= nil and value < min then
			table.insert(errors, atPath(path, `must be >= {min} (got {value})`))
		end
		if max ~= nil and value > max then
			table.insert(errors, atPath(path, `must be <= {max} (got {value})`))
		end
		if above ~= nil and value <= above then
			table.insert(errors, atPath(path, `must be > {above} (got {value})`))
		end
		if below ~= nil and value >= below then
			table.insert(errors, atPath(path, `must be < {below} (got {value})`))
		end
		if integer and value % 1 ~= 0 then
			table.insert(errors, atPath(path, `must be an integer (got {value})`))
		end
		return errors
	end
end

function Validate.boolean(): Validator
	return function(value: any, path: string): { string }
		if type(value) ~= "boolean" then
			return typeError(path, "boolean", value)
		end
		return {}
	end
end

function Validate.string(options: { oneOf: { string }?, nonEmpty: boolean? }?): Validator
	local oneOf = options and options.oneOf
	local nonEmpty = options and options.nonEmpty
	return function(value: any, path: string): { string }
		if type(value) ~= "string" then
			return typeError(path, "string", value)
		end
		if nonEmpty and value == "" then
			return { atPath(path, "must not be empty") }
		end
		if oneOf ~= nil and table.find(oneOf, value) == nil then
			return { atPath(path, `must be one of {table.concat(oneOf, ", ")} (got "{value}")`) }
		end
		return {}
	end
end

-- Roblox value types by their typeof name, e.g. "Vector3" or "CFrame".
function Validate.datatype(name: string): Validator
	return function(value: any, path: string): { string }
		if typeof(value) ~= name then
			return typeError(path, name, value)
		end
		return {}
	end
end

-- An item of one Roblox enum, e.g. Validate.enumItem(Enum.KeyCode).
function Validate.enumItem(enumType: Enum): Validator
	return function(value: any, path: string): { string }
		if typeof(value) == "EnumItem" and value.EnumType == enumType then
			return {}
		end
		local shown = if type(value) == "string" then `"{value}"` else tostring(value)
		return { atPath(path, `must be a {tostring(enumType)} (got {shown})`) }
	end
end

function Validate.table(): Validator
	return function(value: any, path: string): { string }
		if type(value) ~= "table" then
			return typeError(path, "table", value)
		end
		return {}
	end
end

function Validate.record(fields: { [string]: Validator }): Validator
	local fieldNames: { string } = {}
	for name in fields do
		table.insert(fieldNames, name)
	end
	table.sort(fieldNames)

	return function(value: any, path: string): { string }
		if type(value) ~= "table" then
			return typeError(path, "table", value)
		end

		local errors: { string } = {}
		for _, name in fieldNames do
			local fieldPath = joinPath(path, name)
			if value[name] == nil then
				table.insert(errors, `{fieldPath}: missing`)
			else
				for _, fieldError in fields[name](value[name], fieldPath) do
					table.insert(errors, fieldError)
				end
			end
		end

		local unknownKeys: { string } = {}
		for key in value do
			if type(key) ~= "string" or fields[key] == nil then
				table.insert(unknownKeys, tostring(key))
			end
		end
		table.sort(unknownKeys)
		for _, key in unknownKeys do
			table.insert(errors, `{joinPath(path, key)}: unknown key`)
		end

		return errors
	end
end

-- True when the keys are exactly the integers 1..n (an empty table counts as an empty list).
function Validate.isList(value: { [any]: any }): boolean
	local length = #value
	local count = 0
	for key in value do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then
			return false
		end
		count += 1
	end
	return count == length
end

function Validate.list(item: Validator): Validator
	return function(value: any, path: string): { string }
		if type(value) ~= "table" then
			return typeError(path, "table", value)
		end
		if not Validate.isList(value) then
			return { atPath(path, "must be a list") }
		end

		local errors: { string } = {}
		for index = 1, #value do
			for _, itemError in item(value[index], `{path}[{index}]`) do
				table.insert(errors, itemError)
			end
		end
		return errors
	end
end

-- A table whose `field` names one of `variants`; that variant checks the whole table. For messages whose shape
-- depends on one field, such as a request naming its action.
function Validate.tagged(field: string, variants: { [string]: Validator }): Validator
	local tags: { string } = {}
	for tag in variants do
		table.insert(tags, tag)
	end
	table.sort(tags)
	local known = table.concat(tags, ", ")

	return function(value: any, path: string): { string }
		if type(value) ~= "table" then
			return typeError(path, "table", value)
		end
		local tag = value[field]
		local variant = if type(tag) == "string" then variants[tag] else nil
		if variant == nil then
			local shown = if type(tag) == "string" then `"{tag}"` else tostring(tag)
			return { atPath(joinPath(path, field), `must be one of {known} (got {shown})`) }
		end
		return variant(value, path)
	end
end

function Validate.check(inner: Validator, predicate: (value: any) -> boolean, message: string): Validator
	return function(value: any, path: string): { string }
		local errors = inner(value, path)
		if #errors > 0 then
			return errors
		end
		if not predicate(value) then
			return { atPath(path, message) }
		end
		return {}
	end
end

-- A size in pixels: a UDim2 whose scales are 0 and whose offsets are above 0, for layouts measured in pixels.
function Validate.pixels(): Validator
	return Validate.check(Validate.datatype("UDim2"), function(size: UDim2): boolean
		return size.X.Scale == 0 and size.Y.Scale == 0 and size.X.Offset > 0 and size.Y.Offset > 0
	end, "must be in pixels (scales 0, offsets > 0)")
end

export type Rule = { message: string, holds: (value: any) -> boolean }

-- Rules checked in order once the inner validator passes; only the first that fails is reported.
function Validate.checkAll(inner: Validator, rules: { Rule }): Validator
	local validator = inner
	for _, rule in rules do
		validator = Validate.check(validator, rule.holds, rule.message)
	end
	return validator
end

function Validate.assertValid(value: any, validator: Validator, rootPath: string, heading: string?)
	local errors = validator(value, rootPath)
	if #errors > 0 then
		error(`{heading or "Invalid config"}:\n  - ` .. table.concat(errors, "\n  - "), 2)
	end
end

return Validate
