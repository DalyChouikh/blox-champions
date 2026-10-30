--!strict
-- CollectionService tags and attribute names of the arena's features (spec §9.2) and the ball, spelled only here.
-- Gameplay code finds them through these tags, so any model carrying the same tags (a later art pass) drops in.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Tags = {
	LapGate = "LapGate",
	GoalHoop = "GoalHoop",
	GoalPanel = "GoalPanel",
	TeamSpawn = "TeamSpawn",
	BallSpawn = "BallSpawn",
	CornerMarker = "CornerMarker",
	-- On the folders of surfaces skaters ride (the floors, the banks, the walls and the glass): the only things their
	-- rays hit.
	RideSurface = "RideSurface",
	-- On the folder of the arena's top (A7): skaters and the ball bounce off it, and only a skater's collider sweep
	-- sees it; every ray looks through it.
	Barrier = "Barrier",
	-- On the folder of the glass, a ride surface too: the skates only roll on it, so no climb holds there (#299).
	Glass = "Glass",
	-- On the ball's part, so clients find the ball the server built.
	Ball = "Ball",
	Attribute = {
		-- On LapGate parts and CornerMarkers (a Model or a part): which gate, 1..4 in travel order.
		GateIndex = "GateIndex",
		-- On TeamSpawn parts: "Blue" or "Orange".
		Team = "Team",
		-- On the GoalHoop model: the scoring disc's radius.
		OpeningRadius = "OpeningRadius",
	},
}

return Freeze.deep(Tags)
