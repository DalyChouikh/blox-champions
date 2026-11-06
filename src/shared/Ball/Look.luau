--!strict
-- The ball's look (spec §9.4, #400): the part that draws the ball, a child of the ball part. The ball part keeps the
-- physics (a true sphere rolls smoothly) and is unseen; its look is the ball mesh made in Blender
-- (scripts/art/build_ball.py) in a skin's picture (the owner's Q275-Q277). The server dresses each ball it builds
-- (BallLook); each screen draws the look where it draws the ball (Client/BallView) and paints it in the team's colour
-- (Client/WorldMarkers).

local Look = {}

-- The look's name under its ball part.
Look.NAME = "Look"

-- The look under `ball`, or nil when it has none (yet: it streams in with the ball).
function Look.of(ball: BasePart): BasePart?
	local look = ball:FindFirstChild(Look.NAME)
	return if look ~= nil and look:IsA("BasePart") then look else nil
end

return table.freeze(Look)
