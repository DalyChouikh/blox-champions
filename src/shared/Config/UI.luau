--!strict
-- HUD settings (spec §11.2). The clock-warning marks also drive the rules' ClockWarning events (spec §5.1).
-- Team colors are the one source for everything drawn in a team's color (spawn pads now, the HUD later).

local Validate = require(script.Parent.Validate)

export type UIConfig = {
	clockWarnings: { number },
	teamColors: { Blue: Color3, Orange: Color3 },
}

local defaults: UIConfig = {
	clockWarnings = { 60, 30 },
	teamColors = { Blue = Color3.fromRGB(13, 105, 172), Orange = Color3.fromRGB(218, 133, 65) },
}

local function noDuplicates(values: { number }): boolean
	local seen: { [number]: boolean } = {}
	for _, value in values do
		if seen[value] then
			return false
		end
		seen[value] = true
	end
	return true
end

local schema = Validate.record({
	clockWarnings = Validate.check(
		Validate.list(Validate.number({ min = 1, integer = true })),
		noDuplicates,
		"must not contain duplicates"
	),
	teamColors = Validate.record({ Blue = Validate.datatype("Color3"), Orange = Validate.datatype("Color3") }),
})

return {
	defaults = defaults,
	schema = schema,
}
