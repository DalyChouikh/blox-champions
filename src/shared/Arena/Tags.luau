--!strict
-- CollectionService tags and attribute names of the arena's features (spec §9.2), spelled only here. Gameplay
-- code finds the arena through them, so any model carrying the same tags (a later art pass) drops in.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Tags = {
	LapGate = "LapGate",
	GoalHoop = "GoalHoop",
	GoalPanel = "GoalPanel",
	TeamSpawn = "TeamSpawn",
	BallSpawn = "BallSpawn",
	CornerMarker = "CornerMarker",
	Attribute = {
		-- On LapGate and CornerMarker parts: which gate, 1..4 in travel order.
		GateIndex = "GateIndex",
		-- On TeamSpawn parts: "Blue" or "Orange".
		Team = "Team",
		-- On the GoalHoop model: the scoring disc's radius.
		OpeningRadius = "OpeningRadius",
	},
}

return Freeze.deep(Tags)
