--!strict
-- Deep, cycle-safe freezing for config and other shared data that must never change at runtime.

local Freeze = {}

local function freezeTable(value: { [any]: any }, visited: { [any]: boolean })
	if visited[value] then
		return
	end
	visited[value] = true

	for _, child in value do
		if type(child) == "table" then
			freezeTable(child, visited)
		end
	end

	if not table.isfrozen(value) then
		table.freeze(value)
	end
end

function Freeze.deep<T>(value: T): T
	if type(value) == "table" then
		freezeTable(value :: any, {})
	end
	return value
end

return Freeze
