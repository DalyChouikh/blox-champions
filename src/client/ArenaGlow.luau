--!strict
-- The arena's glow (spec §9.1), stepped before each frame is drawn (FrameController) and acting only when the HUD's
-- state or the arena's parts change:
-- - while the goal is open for a team, the hoop's parts take that team's colour and Config.UI.arenaGlow.material, and
--   the goal panel slides panelSlide studs up out of the ring over panelSlideSeconds (the server only lets the ball
--   through it); when the goal closes, the hoop looks as before and the panel slides back;
-- - every part of the next gate's corner marker (its glass panel) glows in the colour of the team with the ball, none
--   before their first gate (the owner's choice, as the snapshot's nextGate is nil then); the marker it leaves looks
--   as before.
-- "As before" is how each part looked when it reached this client. Everything here is this client's own view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaParts = require(script.Parent.ArenaParts)
local Config = require(ReplicatedStorage.Shared.Config)
local HudStore = require(script.Parent.HudStore)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team
-- How a part looked when it reached this client.
type Look = { color: Color3, material: Enum.Material, frame: CFrame }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type ArenaGlow = {
	name: string,
	dependencies: { string },
	init: (self: ArenaGlow, deps: { [string]: any }) -> (),
	start: ((self: ArenaGlow) -> ())?,
	step: (self: ArenaGlow, dt: number) -> (),
	_config: Config.GameConfig,
	_store: HudStore.HudStore,
	_arena: ArenaParts.ArenaParts,
	-- Moves a part to `to` over `seconds`: a tween, or a fake.
	_slide: (part: BasePart, to: CFrame, seconds: number) -> (),
	_looks: { [BasePart]: Look },
	-- What was last acted on: the arena's parts, the HUD state's version, the team the goal is open for, the glowing
	-- marker and its team, and whether the panel is out of the ring.
	_parts: ArenaParts.Parts?,
	_version: number?,
	_goalTeam: Team?,
	_gate: ArenaParts.Marker?,
	_gateTeam: Team?,
	_open: boolean,
}

local function tween(part: BasePart, to: CFrame, seconds: number)
	TweenService:Create(part, TweenInfo.new(seconds), { CFrame = to }):Play()
end

-- Notes how each part looks the first time it is seen.
local function remember(self: ArenaGlow, parts: ArenaParts.Parts)
	local looks = self._looks
	local function keep(part: BasePart)
		if looks[part] == nil then
			looks[part] = { color = part.Color, material = part.Material, frame = part.CFrame }
		end
	end
	for _, part in parts.hoop do
		keep(part)
	end
	for _, marker in parts.markers do
		for _, part in marker.parts do
			keep(part)
		end
	end
	keep(parts.panel)
end

local function light(self: ArenaGlow, part: BasePart, team: Team)
	part.Color = self._config.UI.teamColors[team]
	part.Material = self._config.UI.arenaGlow.material
end

local function restore(self: ArenaGlow, part: BasePart)
	local look = self._looks[part]
	if look ~= nil then
		part.Color = look.color
		part.Material = look.material
	end
end

local function glowGoal(self: ArenaGlow, parts: ArenaParts.Parts, team: Team?)
	self._goalTeam = team
	for _, part in parts.hoop do
		if team ~= nil then
			light(self, part, team)
		else
			restore(self, part)
		end
	end
	local open = team ~= nil
	if open ~= self._open then
		self._open = open
		local glow = self._config.UI.arenaGlow
		local closed = self._looks[parts.panel].frame
		self._slide(
			parts.panel,
			if open then closed + parts.hoopUp * glow.panelSlide else closed,
			glow.panelSlideSeconds
		)
	end
end

local function glowGate(self: ArenaGlow, gate: ArenaParts.Marker?, team: Team?)
	local previous = self._gate
	if previous ~= nil and previous ~= gate then
		for _, part in previous.parts do
			restore(self, part)
		end
	end
	self._gate, self._gateTeam = gate, team
	if gate ~= nil and team ~= nil then
		for _, part in gate.parts do
			light(self, part, team)
		end
	end
end

local ArenaGlow: ArenaGlow = {
	name = "ArenaGlow",
	dependencies = { "Config", "HudStore", "ArenaParts" },
	_config = nil :: any,
	_store = nil :: any,
	_arena = nil :: any,
	_slide = tween,
	_looks = {},
	_parts = nil,
	_version = nil,
	_goalTeam = nil,
	_gate = nil,
	_gateTeam = nil,
	_open = false,

	-- deps.Slide replaces the tween in tests.
	init = function(self: ArenaGlow, deps: { [string]: any })
		self._config = deps.Config
		self._store = deps.HudStore
		self._arena = deps.ArenaParts
		self._slide = deps.Slide or tween
		self._looks = {}
		self._parts = nil
		self._version = nil
		self._goalTeam = nil
		self._gate = nil
		self._gateTeam = nil
		self._open = false
	end,

	step = function(self: ArenaGlow, _dt: number)
		local parts = self._arena.parts
		local state = self._store.state
		if parts == nil then
			return
		end
		local fresh = parts ~= self._parts
		if not fresh and state.version == self._version then
			return
		end
		if fresh then
			self._parts = parts
			remember(self, parts)
		end
		self._version = state.version
		local match = state.match
		local goalTeam: Team? = if match ~= nil then match.goalOpenFor else nil
		if fresh or goalTeam ~= self._goalTeam then
			glowGoal(self, parts, goalTeam)
		end
		local team: Team? = if match ~= nil then match.possessingTeam else nil
		local nextGate = if match ~= nil then match.nextGate else nil
		local gate = if team ~= nil and nextGate ~= nil then parts.markers[nextGate] else nil
		if fresh or gate ~= self._gate or team ~= self._gateTeam then
			glowGate(self, gate, team)
		end
	end,
}

return ArenaGlow
