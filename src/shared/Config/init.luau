--!strict
-- Game configuration: per-area defaults merged with a game mode's overrides, validated, and deep-frozen.
-- Adding a tunable means adding it to an area file (defaults + schema); modes only list what they change.

local Actions = require(script.Actions)
local Arena = require(script.Arena)
local Ball = require(script.Ball)
local Camera = require(script.Camera)
local Input = require(script.Input)
local Freeze = require(script.Parent.Util.Freeze)
local Match = require(script.Match)
local Movement = require(script.Movement)
local Network = require(script.Network)
local Pose = require(script.Pose)
local Scoring = require(script.Scoring)
local UI = require(script.UI)
local Validate = require(script.Validate)
local World = require(script.World)

export type ActionsConfig = Actions.ActionsConfig
export type ActionConfig = Actions.ActionConfig
export type ActionName = Actions.ActionName
export type Effect = Actions.Effect
export type PoseName = Actions.PoseName
export type Hit = Actions.Hit
export type Motion = Actions.Motion
export type Landing = Actions.Landing
export type FollowUp = Actions.FollowUp
export type ThrowSettings = Actions.ThrowSettings
export type PassSettings = Actions.PassSettings
export type ArenaConfig = Arena.ArenaConfig
export type BallConfig = Ball.BallConfig
export type CameraConfig = Camera.CameraConfig
export type InputConfig = Input.InputConfig
export type Control = Input.Control
export type ActionKey = Input.ActionKey
export type LookBinding = Input.LookBinding
export type FocusMode = Input.FocusMode
export type TouchLayout = Input.TouchLayout
export type TouchControl = Input.TouchControl
export type MatchConfig = Match.MatchConfig
export type MovementConfig = Movement.MovementConfig
export type NetworkConfig = Network.NetworkConfig
export type PoseConfig = Pose.PoseConfig
export type ScoringConfig = Scoring.ScoringConfig
export type UIConfig = UI.UIConfig
export type ControlLabels = UI.ControlLabels
export type TouchStyle = UI.TouchStyle
export type UIText = UI.UIText
export type HudSettings = UI.HudSettings
export type HudLayout = UI.HudLayout
export type MarkerSettings = UI.MarkerSettings
export type NameTagSettings = UI.NameTagSettings
export type ArenaGlowSettings = UI.ArenaGlowSettings
export type WorldConfig = World.WorldConfig

export type GameConfig = {
	Actions: ActionsConfig,
	Arena: ArenaConfig,
	Ball: BallConfig,
	Camera: CameraConfig,
	Input: InputConfig,
	Match: MatchConfig,
	Movement: MovementConfig,
	Network: NetworkConfig,
	Pose: PoseConfig,
	Scoring: ScoringConfig,
	UI: UIConfig,
	World: WorldConfig,
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
		Actions = Actions.schema,
		Arena = Arena.schema,
		Ball = Ball.schema,
		Camera = Camera.schema,
		Input = Input.schema,
		Match = Match.schema,
		Movement = Movement.schema,
		Network = Network.schema,
		Pose = Pose.schema,
		Scoring = Scoring.schema,
		UI = UI.schema,
		World = World.schema,
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
		Actions = Actions.defaults,
		Arena = Arena.defaults,
		Ball = Ball.defaults,
		Camera = Camera.defaults,
		Input = Input.defaults,
		Match = Match.defaults,
		Movement = Movement.defaults,
		Network = Network.defaults,
		Pose = Pose.defaults,
		Scoring = Scoring.defaults,
		UI = UI.defaults,
		World = World.defaults,
	})
	deepMerge(config, overrides)
	Validate.assertValid(config, Config.schema, "")
	return Freeze.deep(config)
end

local defaultConfig = build({})

function Config.defaults(): GameConfig
	return defaultConfig
end

-- The world's pull (World.gravity) as a vector, straight down: what skating, the ball and the rules fall by.
function Config.gravity(config: GameConfig): Vector3
	return Vector3.new(0, -config.World.gravity, 0)
end

function Config.forMode(mode: Mode): GameConfig
	Validate.assertValid(mode, modeSchema, "Mode")
	return build(mode.overrides)
end

return Config
