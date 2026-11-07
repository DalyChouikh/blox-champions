--!strict
-- The arena's glow (spec §9.1), stepped before each frame is drawn (FrameController) and acting only when the HUD's
-- state or the arena's parts change, or while the goal's door moves:
-- - while the goal is open for a team, what glows then (ArenaParts' `glow`: the goal's lip and strips, or the ring's
--   blocks before its meshes come) takes that team's colour and Config.UI.arenaGlow.material, the goal's panel hides
--   (the server only lets the ball through it then), and the goal's door (its bars, which come with the meshes,
--   Arena/Geometry/GoalDoor) opens from the middle over arenaGlow.doorSeconds (the owner's Q324: elevator doors);
--   when the goal closes, they look as before, the panel shows and the door shuts;
-- - only the next gate's corner marker (its glass wall) shows (the owner's choice, 2026-10-27): every part of it glows
--   in the colour of the team with the ball, at the transparency it had when it reached this client. Every other
--   marker is hidden from the start, and none shows while nobody has the ball; every streak starts at the goal's gate
--   (spec §4.2), so its marker shows from the pickup. The marker it leaves looks as before, hidden.
-- "As before" is how each part looked when it reached this client. Everything here is this client's own view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaParts = require(script.Parent.ArenaParts)
local Config = require(ReplicatedStorage.Shared.Config)
local HudStore = require(script.Parent.HudStore)
local PartSize = require(ReplicatedStorage.Shared.Util.PartSize)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team
-- How a part looked when it reached this client.
type Look = { color: Color3, material: Enum.Material, transparency: number, frame: CFrame, size: Vector3 }

-- An invisible part: every corner marker but the next gate's.
local HIDDEN = 1
-- A part hidden on this client only (LocalTransparencyModifier), and shown again.
local HIDDEN_HERE, SHOWN_HERE = 1, 0

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
	_looks: { [BasePart]: Look },
	-- What was last acted on: the arena's parts, the HUD state's version, the team the goal is open for, the glowing
	-- marker and its team, and whether the goal is open.
	_parts: ArenaParts.Parts?,
	_version: number?,
	_goalTeam: Team?,
	_gate: ArenaParts.Marker?,
	_gateTeam: Team?,
	_open: boolean,
	-- The door: how open it is (0 shut, 1 open), whether it is moving, how open it was when it last set off, the
	-- seconds since, and how far its edge travels from the middle (its longest bar).
	_opened: number,
	_moving: boolean,
	_openedFrom: number,
	_moved: number,
	_reach: number,
}

-- Notes how each part looks the first time it is seen.
local function remember(self: ArenaGlow, parts: ArenaParts.Parts)
	local looks = self._looks
	local function keep(part: BasePart)
		if looks[part] == nil then
			looks[part] = {
				color = part.Color,
				material = part.Material,
				transparency = part.Transparency,
				frame = part.CFrame,
				size = part.Size,
			}
		end
	end
	for _, part in parts.glow do
		keep(part)
	end
	for _, marker in parts.markers do
		for _, part in marker.parts do
			keep(part)
		end
	end
	for _, bar in parts.door do
		keep(bar)
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

-- Each bar of the door with its edge `edge` studs from the middle: every bar opens along its own +X (GoalDoor), so
-- one of shut length L shows L − edge, moved edge/2 along it, and hides once the edge has passed its end.
local function placeDoor(self: ArenaGlow, door: { BasePart }, edge: number)
	for _, bar in door do
		local shut = self._looks[bar]
		local shown = shut.size.X - edge
		if shown < PartSize.MIN then
			bar.LocalTransparencyModifier = HIDDEN_HERE
		else
			bar.LocalTransparencyModifier = SHOWN_HERE
			bar.Size = Vector3.new(shown, shut.size.Y, shut.size.Z)
			bar.CFrame = shut.frame * CFrame.new(edge / 2, 0, 0)
		end
	end
end

-- Moves the door `dt` further toward open or shut, eased as a tween's default (Quad, Out) over doorSeconds from where
-- it set off, so a door turned back mid-way leaves from where it is.
local function moveDoor(self: ArenaGlow, door: { BasePart }, dt: number)
	local target = if self._open then 1 else 0
	local seconds = self._config.UI.arenaGlow.doorSeconds
	self._moved += dt
	-- Once its time is up it is there, at once for a door that takes no time.
	self._moving = self._moved < seconds
	if self._moving then
		local eased = TweenService:GetValue(self._moved / seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		self._opened = self._openedFrom + (target - self._openedFrom) * eased
	else
		self._opened = target
	end
	placeDoor(self, door, self._opened * self._reach)
end

local function glowGoal(self: ArenaGlow, parts: ArenaParts.Parts, team: Team?)
	self._goalTeam = team
	for _, part in parts.glow do
		if team ~= nil then
			light(self, part, team)
		else
			restore(self, part)
		end
	end
	local open = team ~= nil
	parts.panel.LocalTransparencyModifier = if open then HIDDEN_HERE else SHOWN_HERE
	if open ~= self._open then
		self._open = open
		self._moving = true
		self._openedFrom = self._opened
		self._moved = 0
	end
end

-- A marker that is not the next gate's looks as before, hidden.
local function hide(self: ArenaGlow, marker: ArenaParts.Marker)
	for _, part in marker.parts do
		restore(self, part)
		part.Transparency = HIDDEN
	end
end

-- The next gate's marker glows for `team`, each part at the transparency it reached this client with (remembered,
-- since every marker is hidden from the start).
local function show(self: ArenaGlow, marker: ArenaParts.Marker, team: Team)
	for _, part in marker.parts do
		light(self, part, team)
		part.Transparency = self._looks[part].transparency
	end
end

local function glowGate(self: ArenaGlow, gate: ArenaParts.Marker?, team: Team?)
	local previous = self._gate
	if previous ~= nil and previous ~= gate then
		hide(self, previous)
	end
	self._gate, self._gateTeam = gate, team
	if gate ~= nil and team ~= nil then
		show(self, gate, team)
	end
end

-- New parts: their looks noted, every marker hidden, and the door (which may have just come with the goal's meshes,
-- even while the goal is open) put where it is.
local function found(self: ArenaGlow, parts: ArenaParts.Parts)
	self._parts = parts
	remember(self, parts)
	for _, marker in parts.markers do
		hide(self, marker)
	end
	local reach = 0
	for _, bar in parts.door do
		reach = math.max(reach, self._looks[bar].size.X)
	end
	self._reach = reach
	placeDoor(self, parts.door, self._opened * reach)
end

local ArenaGlow: ArenaGlow = {
	name = "ArenaGlow",
	dependencies = { "Config", "HudStore", "ArenaParts" },
	_config = nil :: any,
	_store = nil :: any,
	_arena = nil :: any,
	_looks = {},
	_parts = nil,
	_version = nil,
	_goalTeam = nil,
	_gate = nil,
	_gateTeam = nil,
	_open = false,
	_opened = 0,
	_moving = false,
	_openedFrom = 0,
	_moved = 0,
	_reach = 0,

	init = function(self: ArenaGlow, deps: { [string]: any })
		self._config = deps.Config
		self._store = deps.HudStore
		self._arena = deps.ArenaParts
		self._looks = {}
		self._parts = nil
		self._version = nil
		self._goalTeam = nil
		self._gate = nil
		self._gateTeam = nil
		self._open = false
		self._opened = 0
		self._moving = false
		self._openedFrom = 0
		self._moved = 0
		self._reach = 0
	end,

	step = function(self: ArenaGlow, dt: number)
		local parts = self._arena.parts
		local state = self._store.state
		if parts == nil then
			return
		end
		local fresh = parts ~= self._parts
		if fresh or state.version ~= self._version then
			if fresh then
				found(self, parts)
			end
			self._version = state.version
			local match = state.match
			local goalTeam: Team? = if match ~= nil then match.goalOpenFor else nil
			if fresh or goalTeam ~= self._goalTeam then
				glowGoal(self, parts, goalTeam)
			end
			local team: Team? = if match ~= nil then match.possessingTeam else nil
			-- No gate is next once the streak has counted its last lap (the owner's Q255): then no wall glows.
			local nextGate: number? = if match ~= nil and team ~= nil then match.nextGate else nil
			local gate = if nextGate ~= nil then parts.markers[nextGate] else nil
			if fresh or gate ~= self._gate or team ~= self._gateTeam then
				glowGate(self, gate, team)
			end
		end
		if self._moving then
			moveDoor(self, parts.door, dt)
		end
	end,
}

return ArenaGlow
