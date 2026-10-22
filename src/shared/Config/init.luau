--!strict
-- Game configuration: per-area defaults merged with a game mode's overrides, validated, and deep-frozen.
-- Adding a tunable means adding it to an area file (defaults + schema); modes only list what they change.

local Arena = require(script.Arena)
local Ball = require(script.Ball)
local Freeze = require(script.Parent.Util.Freeze)
local Match = require(script.Match)
local Network = require(script.Network)
local Scoring = require(script.Scoring)
local UI = require(script.UI)
local Validate = require(script.Validate)

export type ArenaConfig = Arena.ArenaConfig
export type BallConfig = Ball.BallConfig
export type MatchConfig = Match.MatchConfig
export type NetworkConfig = Network.NetworkConfig
export type ScoringConfig = Scoring.ScoringConfig
export type UIConfig = UI.UIConfig

export type GameConfig = {
	Arena: ArenaConfig,
	Ball: BallConfig,
	Match: MatchConfig,
	Network: NetworkConfig,
	Scoring: ScoringConfig,
	UI: UIConfig,
}

export type Mode = {
	id: string,
	displayName: string,
	itemsEnabled: boolean,
	overrides: { [string]: any },
}

local Config = {}

-- Checks spanning two areas, in order, once each area is valid on its own.
local crossAreaRules: { Validate.Rule } = {
	{
		-- Each team lines up on its own straight (spec §9.1).
		message = "Arena: Match.teamSize spawns teamSpawnSpacing apart must fit on a straight",
		holds = function(config: GameConfig): boolean
			return (config.Match.teamSize - 1) * config.Arena.teamSpawnSpacing <= config.Arena.straightLength
		end,
	},
	{
		message = "Ball: radius must be smaller than the goal ring's opening (Arena.goal.ringRadius)",
		holds = function(config: GameConfig): boolean
			return config.Ball.radius < config.Arena.goal.ringRadius
		end,
	},
}

Config.schema = Validate.checkAll(
	Validate.record({
		Arena = Arena.schema,
		Ball = Ball.schema,
		Match = Match.schema,
		Network = Network.schema,
		Scoring = Scoring.schema,
		UI = UI.schema,
	}),
	crossAreaRules
)

local modeSchema = Validate.record({
	id = Validate.string({ nonEmpty = true }),
	displayName = Validate.string({ nonEmpty = true }),
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

-- Tables present on both sides merge key by key, except lists: an override list replaces the default list
-- whole, so `{ 10 }` over `{ 60, 30 }` gives `{ 10 }`. Any other override value replaces the default.
local function deepMerge(target: { [any]: any }, overrides: { [any]: any })
	for key, overrideValue in overrides do
		local current = target[key]
		if type(current) == "table" and type(overrideValue) == "table" and not Validate.isList(current) then
			deepMerge(current, overrideValue)
		else
			target[key] = deepCopy(overrideValue)
		end
	end
end

local function build(overrides: { [string]: any }): GameConfig
	local config = deepCopy({
		Arena = Arena.defaults,
		Ball = Ball.defaults,
		Match = Match.defaults,
		Network = Network.defaults,
		Scoring = Scoring.defaults,
		UI = UI.defaults,
	})
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
