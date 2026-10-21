--!strict
-- Game configuration: per-area defaults merged with a game mode's overrides, validated, and deep-frozen.
-- Adding a tunable means adding it to an area file (defaults + schema); modes only list what they change.

local Freeze = require(script.Parent.Util.Freeze)
local Match = require(script.Match)
local Scoring = require(script.Scoring)
local Validate = require(script.Validate)

export type MatchConfig = Match.MatchConfig
export type ScoringConfig = Scoring.ScoringConfig

export type GameConfig = {
	Match: MatchConfig,
	Scoring: ScoringConfig,
}

export type Mode = {
	id: string,
	displayName: string,
	itemsEnabled: boolean,
	overrides: { [string]: any },
}

local Config = {}

Config.schema = Validate.record({
	Match = Match.schema,
	Scoring = Scoring.schema,
})

local modeSchema = Validate.record({
	id = Validate.string(),
	displayName = Validate.string(),
	itemsEnabled = Validate.boolean(),
	overrides = Validate.table(),
})

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Tables present on both sides merge key by key; any other override value replaces the default.
local function deepMerge(target: { [any]: any }, overrides: { [any]: any })
	for key, overrideValue in overrides do
		local current = target[key]
		if type(current) == "table" and type(overrideValue) == "table" then
			deepMerge(current, overrideValue)
		else
			target[key] = deepCopy(overrideValue)
		end
	end
end

local function build(overrides: { [string]: any }): GameConfig
	local config = deepCopy({ Match = Match.defaults, Scoring = Scoring.defaults })
	deepMerge(config, overrides)
	Validate.assertValid(config, Config.schema, "")
	return Freeze.deep(config)
end

local defaultConfig = build({})

function Config.defaults(): GameConfig
	return defaultConfig
end

function Config.forMode(mode: Mode): GameConfig
	Validate.assertValid(mode, modeSchema, "Mode")
	return build(mode.overrides)
end

return Config
