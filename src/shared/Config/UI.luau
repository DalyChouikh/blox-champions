--!strict
-- HUD settings (spec §11.2). The clock-warning marks also drive the rules' ClockWarning events (spec §5.1).

local Validate = require(script.Parent.Validate)

export type UIConfig = {
	clockWarnings: { number },
}

local defaults: UIConfig = {
	clockWarnings = { 60, 30 },
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
})

return {
	defaults = defaults,
	schema = schema,
}
