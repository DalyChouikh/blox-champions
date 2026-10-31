--!strict
-- Where a caught ball is drawn while it flies into its carrier's hand (spec §9.3; the owner's trial #311, Q91, Q132):
-- straight from where a screen last showed it to the carry spot, both in the carrier's root frame, over
-- Ball.pickupPullSeconds; at the carry spot once that time is up, and at once when the pull takes none.

local Pull = {}

function Pull.offset(from: Vector3, to: Vector3, elapsed: number, seconds: number): Vector3
	if Pull.over(elapsed, seconds) then
		return to
	end
	return from:Lerp(to, elapsed / seconds)
end

-- Whether a pull `elapsed` seconds old is over.
function Pull.over(elapsed: number, seconds: number): boolean
	return elapsed >= seconds
end

return Pull
