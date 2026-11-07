--!strict
-- The goal's door (Arena spec §5.3, #410, the owner's Q324: elevator doors parting from the middle), in the hoop's
-- frame (x toward the outer wall, y up, z back at oncoming skaters): `goal.door.bars` horizontal bars a half, stacked
-- over the opening's height, each from the middle to its row's widest chord and `goal.door.past` beyond, so the shut
-- door fills the round opening and the bars' ends lie in the housing round it, which hides them. A flat door that
-- slid whole would stick out of the goal; these bars only shorten. Every bar opens along its own +X, away from the
-- middle (the left half's are turned half round Y), so ArenaGlow opens each from its own shut look.

local Config = require(script.Parent.Parent.Parent.Config)
local Types = require(script.Parent.Types)

type ArenaConfig = Config.ArenaConfig

local HALF_TURN = CFrame.Angles(0, math.pi, 0)
-- The right half's bars, then the left half's.
local SIDES = { 1, -1 }

local GoalDoor = {}

-- Every bar of the shut door, each half's from the bottom up.
function GoalDoor.bars(arena: ArenaConfig): { Types.Piece }
	local goal = arena.goal
	local radius, count = goal.ringRadius, goal.door.bars
	local height = 2 * radius / count
	local bars: { Types.Piece } = {}
	for _, side in SIDES do
		for row = 1, count do
			local bottom = -radius + (row - 1) * height
			local top = bottom + height
			-- A row is widest at its edge nearest the middle, or at the middle when it spans it.
			local nearest = if bottom < 0 and top > 0 then 0 else math.min(math.abs(bottom), math.abs(top))
			local length = math.sqrt(radius * radius - nearest * nearest) + goal.door.past
			local centre = CFrame.new(side * length / 2, bottom + height / 2, 0)
			table.insert(bars, {
				shape = "Block",
				cframe = if side > 0 then centre else centre * HALF_TURN,
				size = Vector3.new(length, height, goal.panelThickness),
			})
		end
	end
	return bars
end

-- How far the shut door's farthest bar corner lies from the opening's centre.
function GoalDoor.reach(arena: ArenaConfig): number
	local farthest = 0
	for _, bar in GoalDoor.bars(arena) do
		local position = bar.cframe.Position
		local corner = Vector2.new(math.abs(position.X) + bar.size.X / 2, math.abs(position.Y) + bar.size.Y / 2)
		farthest = math.max(farthest, corner.Magnitude)
	end
	return farthest
end

return GoalDoor
