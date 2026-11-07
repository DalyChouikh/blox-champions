--!strict
-- Gets a skater out of the goal (#423, the owner's Q339-Q340). The goal's housing and pylon stop skaters (#422) but
-- are not ground they skate on, so a skater who comes to rest inside its tunnel has nothing to push off. Anyone inside
-- the tunnel (within the scoring disc's radius of its axis, less than half the housing's depth from the disc), moving
-- slower than `speed` for `seconds`, is pushed back out the way they came: along the disc's normal toward the side
-- they are on, so a push never crosses the disc and never scores. Pure: the skating calls it each step.

local Config = require(script.Parent.Parent.Config)
local Crossing = require(script.Parent.Parent.Rules.Crossing)

local GoalEscape = {}

-- How long the skater has been still inside, so far.
export type State = { seconds: number }

function GoalEscape.new(): State
	return { seconds = 0 }
end

-- One step of a skater at `position` moving at `velocity`, by the goal's scoring disc and the housing `depth` deep
-- round it: the velocity change that pushes them out once they have been stuck long enough, else nil.
function GoalEscape.step(
	state: State,
	disc: Crossing.Disc,
	depth: number,
	position: Vector3,
	velocity: Vector3,
	dt: number,
	settings: Config.GoalEscapeSettings
): Vector3?
	local normal = disc.frame.ZVector
	-- Along the normal from the disc: +Z toward the housing's front.
	local along = (position - disc.frame.Position):Dot(normal)
	local inside = math.abs(along) < depth / 2 and Crossing.withinDisc(disc, position)
	if not inside or velocity.Magnitude >= settings.speed then
		state.seconds = 0
		return nil
	end
	state.seconds += dt
	if state.seconds < settings.seconds then
		return nil
	end
	state.seconds = 0
	-- Out of the face they are on, from the disc's plane on.
	return (if along >= 0 then normal else -normal) * settings.push
end

return GoalEscape
