--!strict
-- Allowances for network lag when the server judges what a player did (spec §10), and the thresholds of the movement
-- guard that catches a client moving faster than skating allows or found outside the arena.

local Validate = require(script.Parent.Validate)

-- How the server sends the loose ball to every screen, and how each screen draws it between the server's states
-- (#316): carried on to now, then closed on smoothly.
export type BallStreamConfig = {
	-- How fast a screen's drawn ball closes on where the server's state says it is: the gap left shrinks to 37% over
	-- this time (an exponential ease), while the drawn ball also moves with the server's.
	correctionSeconds: number,
	-- A gap wider than this is a jump (a drop-in's start, a respawn), drawn at once.
	snapStuds: number,
	-- A screen carries a state on to now for at most this long, so a stalled stream never flies the ball on.
	maxAgeSeconds: number,
	-- A resting ball's state is sent this often; a moving ball's, every frame.
	restSeconds: number,
}

export type NetworkConfig = {
	-- Extra catch reach, because the server sees each player slightly behind where their own screen does.
	pickupLagToleranceStuds: number,
	-- How often a client may report its pump and brake (a burst of this many, refilled per second).
	maxSkateStatesPerSecond: number,
	-- How often the movement guard samples each skater's position.
	guardSampleSeconds: number,
	-- How far above the allowed speed a skater may move in one sample before it counts as a strike.
	speedTolerance: number,
	-- Strikes in a row that return a skater to their last valid place.
	guardStrikes: number,
	-- A move this many times the allowed distance in one sample returns the skater at once.
	guardTeleportFactor: number,
	-- How far outside the arena (past either glass, under the floor or over the top: Bounds.inArena) a skater's root
	-- may be before the guard puts them back on their team's spawn.
	guardOutsideMargin: number,
	-- How many action requests a client may send (a burst of this many, refilled per second).
	maxActionsPerSecond: number,
	-- Extra reach for strikes judged on the server, which sees each player slightly behind their own screen.
	hitLagToleranceStuds: number,
	-- How far network jitter may move an action's timing on the server: it may arrive this early before its cooldown
	-- or the running action ends, and this far outside a follow-up's window (the Tackle's Dive).
	actionTimingTolerance: number,
	-- How many requests to get up a client may send (a burst of this many, refilled per second): an honest client
	-- sends one per knockdown, and a knockdown lasts at least Actions.getUpAfter.
	maxGetUpsPerSecond: number,
	-- How long a client keeps reporting an Air Pose it touched down in (#245): the server judges that fall from the
	-- report, but sees the touchdown behind this client's screen, and the character's physics and remote events reach
	-- it in no fixed order. The server's knockdown ends the report sooner.
	posedLandingTolerance: number,
	-- How many requests to switch team a client may send (a burst of this many, refilled per second, #310).
	maxTeamSwitchesPerSecond: number,
	ballStream: BallStreamConfig,
}

local defaults: NetworkConfig = {
	pickupLagToleranceStuds = 2,
	maxSkateStatesPerSecond = 20,
	guardSampleSeconds = 0.25,
	speedTolerance = 1.2,
	guardStrikes = 3,
	guardTeleportFactor = 2,
	guardOutsideMargin = 2,
	maxActionsPerSecond = 15,
	hitLagToleranceStuds = 3,
	actionTimingTolerance = 0.1,
	maxGetUpsPerSecond = 2,
	posedLandingTolerance = 0.3,
	-- The owner (Q120): no cooldown between switches; the server only drops spam.
	maxTeamSwitchesPerSecond = 1,
	-- #316 (Q101), measured in a 2-player test: Roblox's own replication drew a steady 90-studs/s pass 0.19 s late at
	-- 46-248 studs/s a frame, and other screens drew a thrown ball still for 0.29 s. Drawn from these states (the
	-- prototype): no lag, 83-107 studs/s a frame, within 2 studs of the server's path through a bounce, 0.07 s. A
	-- frame's travel at the fastest throw (~233) is ~4 studs, well under the snap. A still ball costs four states a
	-- second, and a lost last one is set right within a quarter second.
	ballStream = { correctionSeconds = 0.08, snapStuds = 10, maxAgeSeconds = 0.3, restSeconds = 0.25 },
}

local schema = Validate.record({
	pickupLagToleranceStuds = Validate.number({ min = 0 }),
	maxSkateStatesPerSecond = Validate.number({ above = 0 }),
	guardSampleSeconds = Validate.number({ above = 0 }),
	speedTolerance = Validate.number({ above = 0 }),
	guardStrikes = Validate.number({ min = 1, integer = true }),
	guardTeleportFactor = Validate.number({ above = 0 }),
	guardOutsideMargin = Validate.number({ min = 0 }),
	maxActionsPerSecond = Validate.number({ above = 0 }),
	hitLagToleranceStuds = Validate.number({ min = 0 }),
	actionTimingTolerance = Validate.number({ min = 0 }),
	maxGetUpsPerSecond = Validate.number({ above = 0 }),
	posedLandingTolerance = Validate.number({ min = 0 }),
	maxTeamSwitchesPerSecond = Validate.number({ above = 0 }),
	ballStream = Validate.record({
		correctionSeconds = Validate.number({ above = 0 }),
		snapStuds = Validate.number({ above = 0 }),
		maxAgeSeconds = Validate.number({ above = 0 }),
		restSeconds = Validate.number({ above = 0 }),
	}),
})

return {
	defaults = defaults,
	schema = schema,
}
