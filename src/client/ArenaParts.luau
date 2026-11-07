--!strict
-- The arena's parts the HUD points at and lights (spec §9.1): the corner markers (the gates' glass panels) by gate
-- index, what glows while the goal is open, the goal's opening, its panel and its door, found by their tags
-- (Arena/Tags); a throw aims at the opening's centre through it (#313). The arena model is Persistent, so it reaches
-- every client whole, soon after the player joins, and stays; until it has, `parts` is nil. The goal's meshes come
-- later (GoalLook, #410), and the glow moves to them then, with the door, which the GoalGlow and GoalDoor tags'
-- signals show. One cache every client module reads, refreshed by the tags' signals from start on. Each refresh
-- makes a new record, so a reader sees that it changed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)
local PartsOf = require(ReplicatedStorage.Shared.Util.PartsOf)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

-- A corner marker: every part of it (a model's parts, or the marker itself when it is a part), and its pivot's
-- position, where the carrier's arrow points (a gate panel's middle).
export type Marker = { parts: { BasePart }, position: Vector3 }

export type Parts = {
	-- By GateIndex.
	markers: { [number]: Marker },
	-- What takes the team's colour while the goal is open: every part of everything tagged GoalGlow (the ring's
	-- blocks until the goal's meshes come, then its lip). It may be empty.
	glow: { BasePart },
	-- The scoring disc (TaggedLayout.goalDisc).
	goal: Crossing.Disc,
	panel: BasePart,
	-- The door's bars (Q324): every part of everything tagged GoalDoor, none until the goal's meshes come.
	door: { BasePart },
}

-- What a module that reads only the scoring disc needs of this one (a fake in tests): a throw aims through it
-- (ActionController), a skater resting in its tunnel is pushed out (SkateController, #423).
export type Goal = { parts: { goal: Crossing.Disc }? }

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type ArenaParts = {
	name: string,
	dependencies: { string },
	init: (self: ArenaParts, deps: { [string]: any }) -> (),
	start: (self: ArenaParts) -> (),
	parts: Parts?,
	refresh: (self: ArenaParts) -> (),
	-- Lets go of the tags' signals (tests).
	destroy: (self: ArenaParts) -> (),
	_connections: { RBXScriptConnection },
}

-- Every tag `refresh` reads.
local WATCHED = { Tags.CornerMarker, Tags.GoalHoop, Tags.GoalGlow, Tags.GoalPanel, Tags.GoalDoor }

local function firstPart(tag: string): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

-- Every part of everything tagged `tag`.
local function partsTagged(tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		for _, part in PartsOf(instance) do
			table.insert(parts, part)
		end
	end
	return parts
end

local ArenaParts: ArenaParts = {
	name = "ArenaParts",
	dependencies = {},
	parts = nil,
	_connections = {},

	init = function(self: ArenaParts, _deps: { [string]: any })
		self._connections = {}
		self:refresh()
	end,

	start = function(self: ArenaParts)
		local function changed()
			self:refresh()
		end
		for _, tag in WATCHED do
			table.insert(self._connections, CollectionService:GetInstanceAddedSignal(tag):Connect(changed))
			table.insert(self._connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(changed))
		end
	end,

	refresh = function(self: ArenaParts)
		local markers: { [number]: Marker } = {}
		local count = 0
		for _, instance in CollectionService:GetTagged(Tags.CornerMarker) do
			local index = instance:GetAttribute(Tags.Attribute.GateIndex)
			if (instance:IsA("Model") or instance:IsA("BasePart")) and type(index) == "number" then
				markers[index] = { parts = PartsOf(instance), position = (instance :: PVInstance):GetPivot().Position }
				count += 1
			end
		end
		local hoopModel = CollectionService:GetTagged(Tags.GoalHoop)[1]
		local goal = if hoopModel ~= nil then TaggedLayout.goalDisc(hoopModel) else nil
		local panel = firstPart(Tags.GoalPanel)
		if count == 0 or goal == nil or panel == nil then
			self.parts = nil
			return
		end
		self.parts = {
			markers = markers,
			glow = partsTagged(Tags.GoalGlow),
			goal = goal,
			panel = panel,
			door = partsTagged(Tags.GoalDoor),
		}
	end,

	destroy = function(self: ArenaParts)
		for _, connection in self._connections do
			connection:Disconnect()
		end
		table.clear(self._connections)
		self.parts = nil
	end,
}

return ArenaParts
