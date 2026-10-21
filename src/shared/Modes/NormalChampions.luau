--!strict
-- Normal Champions: the standard 3v3 mode with no items. Uses the default config unchanged.

local Config = require(script.Parent.Parent.Config)

local NormalChampions: Config.Mode = {
	id = "NormalChampions",
	displayName = "Normal Champions",
	itemsEnabled = false,
	overrides = {},
}

return NormalChampions
