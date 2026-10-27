--!strict
-- Skating (spec §7.2): the skater's body, momentum, steering, wall riding, pump, brake, jump, draft and attach, the
-- slide of a knocked-down skater, and the speedometer's scale.
-- Speeds are in studs/s, accelerations in studs/s², turn rates in rad/s, angles in degrees. The values the spec
-- doesn't give (hoverSpring, strideAccel, airTurnRate, airUprightRate, pumpFlatSlopeDeg, normalFilter, attachSpring)
-- are starting points for tuning, like the spec's own.

local PartSize = require(script.Parent.Parent.Util.PartSize)
local Validate = require(script.Parent.Validate)

export type MovementConfig = {
	-- The one collider every skater gets, whatever their avatar: a ball this wide around the root.
	colliderDiameter: number,
	-- The root rides this high above the ground ray's hit, so seams between arena parts never snag.
	hoverHeight: number,
	-- How hard the hover pulls back to hoverHeight: normal speed per stud of error.
	hoverSpring: number,
	groundProbeLength: number,
	-- The push of holding the stick, up to cruiseSpeed.
	strideAccel: number,
	rollingFriction: number,
	-- Speed lost per second per stud/s of speed.
	airDrag: number,
	-- On the ground, a skater pressing nothing (no stick, pump or brake) loses this much more speed per second
	-- (the owner, #215: from cruise to a stop in about 5 s). A knocked-down skater slides by knockdownDecel instead.
	coastDecel: number,
	cruiseSpeed: number,
	-- Speeding up fades from softCap to nothing at hardCap; hardCap is never exceeded, on the ground or in the air
	-- (Roller Champions' readout never passed 145 km/h, #214).
	softCap: number,
	hardCap: number,
	-- On the ground, speed past softCap bleeds off at this rate per second: each step loses 1 − e^(−rate × dt) of
	-- the excess, so the further over, the faster (RC: whipped to 144 km/h, back near 110 within a second).
	overSpeedBleed: number,
	-- Turn rate at rest and at hardCap: turns widen with speed.
	turnRateLow: number,
	turnRateHigh: number,
	airTurnRate: number,
	-- How fast a skater in the air turns back upright.
	airUprightRate: number,
	-- A surface steeper than wallAngle (degrees from flat) is a wall: gravity pulls along it at wallGravityScale of its
	-- full strength (the owner, #216: about a third, from RC's glass rides). A wall holds a skater at any speed; past
	-- straight up the loop rule decides (A3).
	wallAngle: number,
	wallGravityScale: number,
	-- How far back along the skater's path the curve of an overhang is measured (A3): a few of a lip's flat strips,
	-- so a curve of strips reads as the arc it makes, yet short enough to follow a curve from where it starts.
	curvatureWindow: number,
	pumpSlopeMultiplier: number,
	pumpFlatAccel: number,
	-- Within this slope of flat, pumping gives pumpFlatAccel.
	pumpFlatSlopeDeg: number,
	brakeDecel: number,
	tiptoeSpeed: number,
	jumpImpulse: number,
	-- A ground normal turning more than maxTurnDeg is trusted only once a second ray agrees; smaller turns are
	-- smoothed at this rate (per second).
	normalFilter: { maxTurnDeg: number, smoothing: number },
	draftRange: number,
	draftConeDeg: number,
	draftMaxAccel: number,
	attachRange: number,
	attachConeDeg: number,
	attachFollowDistance: number,
	-- How hard an attached skater is pulled to the follow point: speed per stud of error.
	attachSpring: number,
	attachMaxSeconds: number,
	-- Letting go adds this speed toward the stick held then, or along the leader's way (RC: about +90 km/h, #214).
	attachBoostSpeed: number,
	attachCooldown: number,
	-- A knocked-down skater slides, losing this much speed per second on top of friction.
	knockdownDecel: number,
	-- The speedometer reads a skater's speed times this, in km/h.
	speedometerScale: number,
}

local defaults: MovementConfig = {
	colliderDiameter = 2,
	hoverHeight = 2.5,
	hoverSpring = 15,
	groundProbeLength = 6,
	strideAccel = 30,
	rollingFriction = 4,
	airDrag = 0.02,
	coastDecel = 7.5,
	cruiseSpeed = 60,
	softCap = 90,
	hardCap = 121,
	overSpeedBleed = 5,
	turnRateLow = 4.0,
	turnRateHigh = 1.5,
	airTurnRate = 1,
	airUprightRate = 6,
	wallAngle = 30,
	wallGravityScale = 1 / 3,
	curvatureWindow = 10,
	pumpSlopeMultiplier = 1.6,
	pumpFlatAccel = 8,
	pumpFlatSlopeDeg = 3,
	brakeDecel = 120,
	tiptoeSpeed = 12,
	jumpImpulse = 60,
	normalFilter = { maxTurnDeg = 30, smoothing = 30 },
	draftRange = 18,
	draftConeDeg = 30,
	draftMaxAccel = 20,
	attachRange = 8,
	attachConeDeg = 45,
	attachFollowDistance = 4,
	attachSpring = 10,
	attachMaxSeconds = 3,
	attachBoostSpeed = 75,
	attachCooldown = 3,
	knockdownDecel = 75,
	speedometerScale = 1.2,
}

local positive = Validate.number({ above = 0 })
local nonNegative = Validate.number({ min = 0 })
local angle = Validate.number({ above = 0, max = 180 })

local fields = Validate.record({
	colliderDiameter = Validate.number({ above = 0, max = PartSize.MAX }),
	hoverHeight = positive,
	hoverSpring = positive,
	groundProbeLength = positive,
	strideAccel = nonNegative,
	rollingFriction = nonNegative,
	airDrag = nonNegative,
	coastDecel = nonNegative,
	cruiseSpeed = positive,
	softCap = positive,
	hardCap = positive,
	overSpeedBleed = nonNegative,
	turnRateLow = nonNegative,
	turnRateHigh = nonNegative,
	airTurnRate = nonNegative,
	airUprightRate = positive,
	wallAngle = angle,
	wallGravityScale = Validate.number({ above = 0, max = 1 }),
	curvatureWindow = positive,
	pumpSlopeMultiplier = Validate.number({ min = 1 }),
	pumpFlatAccel = nonNegative,
	pumpFlatSlopeDeg = Validate.check(nonNegative, function(degrees: number): boolean
		return degrees < 90
	end, "must be < 90"),
	brakeDecel = positive,
	tiptoeSpeed = nonNegative,
	jumpImpulse = nonNegative,
	normalFilter = Validate.record({ maxTurnDeg = angle, smoothing = positive }),
	draftRange = positive,
	draftConeDeg = angle,
	draftMaxAccel = nonNegative,
	attachRange = positive,
	attachConeDeg = angle,
	attachFollowDistance = nonNegative,
	attachSpring = nonNegative,
	attachMaxSeconds = positive,
	attachBoostSpeed = nonNegative,
	attachCooldown = nonNegative,
	knockdownDecel = nonNegative,
	speedometerScale = positive,
})

local rules: { Validate.Rule } = {
	{
		message = "speeds must rise: cruiseSpeed <= softCap < hardCap",
		holds = function(movement: MovementConfig): boolean
			return movement.cruiseSpeed <= movement.softCap and movement.softCap < movement.hardCap
		end,
	},
	{
		message = "turnRateHigh must not exceed turnRateLow",
		holds = function(movement: MovementConfig): boolean
			return movement.turnRateHigh <= movement.turnRateLow
		end,
	},
	{
		message = "groundProbeLength must reach past hoverHeight",
		holds = function(movement: MovementConfig): boolean
			return movement.groundProbeLength > movement.hoverHeight
		end,
	},
	{
		message = "tiptoeSpeed must not exceed cruiseSpeed",
		holds = function(movement: MovementConfig): boolean
			return movement.tiptoeSpeed <= movement.cruiseSpeed
		end,
	},
	{
		message = "the collider must clear the ground: colliderDiameter / 2 < hoverHeight",
		holds = function(movement: MovementConfig): boolean
			return movement.colliderDiameter / 2 < movement.hoverHeight
		end,
	},
}

return {
	defaults = defaults,
	schema = Validate.checkAll(fields, rules),
}
