--!strict
-- CollectionService tags and attribute names of the arena's features (spec §9.2) and the ball, spelled only here.
-- Gameplay code finds them through these tags, so any model carrying the same tags (a later art pass) drops in.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Tags = {
	LapGate = "LapGate",
	GoalHoop = "GoalHoop",
	GoalPanel = "GoalPanel",
	-- On what takes the team's colour while the goal is open (ArenaGlow): a model or a part. The ring's blocks until
	-- the goal's meshes come, then each piece whose look glows (Config.Arena.goal.looks: the lip and the strips,
	-- #410).
	GoalGlow = "GoalGlow",
	-- On the model of the door's bars (Arena/Geometry/GoalDoor), which come with the goal's meshes: ArenaGlow opens
	-- and shuts it.
	GoalDoor = "GoalDoor",
	TeamSpawn = "TeamSpawn",
	CornerMarker = "CornerMarker",
	-- On the folders of surfaces skaters ride (the floors, the banks, the walls and the glass): the only things their
	-- rays hit.
	RideSurface = "RideSurface",
	-- On the folder of the arena's top (A7), the goal's solid pieces and its panel (#422): skaters and the ball bounce
	-- off them, and only a skater's collider sweep sees them; every ray looks through them.
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
