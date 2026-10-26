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
	-- On the folder of surfaces skaters ride (the floors, the inner bank and the outer wall): the only things their
	-- rays hit.
	RideSurface = "RideSurface",
	-- On the folders of the arena's top and the glass on its walls' tops (A7): skaters and the ball bounce off them,
	-- and only a skater's collider sweep sees them; every ray looks through them.
	Barrier = "Barrier",
	-- On the ball's part, so clients find the ball the server built.
	Ball = "Ball",
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
