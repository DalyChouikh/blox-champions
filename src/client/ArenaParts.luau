--!strict
-- The arena's parts the HUD points at and lights (spec §9.1): the corner markers (the gates' glass panels) by gate
-- index, the goal hoop's parts and its up (its pivot's), and the goal panel, found by their tags (Arena/Tags). The
-- arena model is Persistent, so it reaches every client whole, soon after the player joins, and stays; until it has,
-- `parts` is nil. One cache every client module reads, refreshed by the tags' signals from start on. Each refresh makes
-- a new record, so a reader sees that it changed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

-- A corner marker: every part of it (a model's parts, or the marker itself when it is a part), and its pivot's
-- position, where the carrier's arrow points (a gate panel's middle).
export type Marker = { parts: { BasePart }, position: Vector3 }

export type Parts = {
	-- By GateIndex.
	markers: { [number]: Marker },
	hoop: { BasePart },
	-- Up in the ring's own plane: the panel slides along it, out of the ring.
	hoopUp: Vector3,
	panel: BasePart,
}

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
local WATCHED = { Tags.CornerMarker, Tags.GoalHoop, Tags.GoalPanel }

-- Every part of `instance`: its descendants that are parts, and itself when it is one.
local function partsOf(instance: Instance): { BasePart }
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function firstPart(tag: string): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
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
				markers[index] = { parts = partsOf(instance), position = (instance :: PVInstance):GetPivot().Position }
				count += 1
			end
		end
		local hoopModel = CollectionService:GetTagged(Tags.GoalHoop)[1]
		local panel = firstPart(Tags.GoalPanel)
		if count == 0 or hoopModel == nil or not hoopModel:IsA("PVInstance") or panel == nil then
			self.parts = nil
			return
		end
		local hoop = partsOf(hoopModel)
		self.parts = { markers = markers, hoop = hoop, hoopUp = hoopModel:GetPivot().UpVector, panel = panel }
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
