--!strict
-- Skating (spec §7.2): the skater's body, momentum, steering, wall riding, pump, brake, jump, draft and attach, the
-- slide of a knocked-down skater, a hard landing and a belly landing, and the speedometer's scale.
-- Speeds are in studs/s, accelerations in studs/s², turn rates in rad/s, angles in degrees. The values the spec
-- doesn't give (hoverSpring, strideAccel, airTurnRate, airUprightRate, pumpFlatSlopeDeg, bodyUpSmoothing, attachSpring)
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
	-- The stride's top speed on flat ground: 46 reads 55 km/h, like Roller Champions' 45-58 (the owner, #265).
	cruiseSpeed: number,
	-- Speeding up fades from softCap to nothing at hardCap; hardCap is never exceeded, on the ground or in the air
	-- (Roller Champions' readout never passed 145 km/h, #214).
	softCap: number,
	hardCap: number,
	-- On the ground, speed past softCap bleeds off at this rate per second: each step loses 1 − e^(−rate × dt) of
	-- the excess, so the further over, the faster (RC: whipped to 144 km/h, back near 110 within a second).
	overSpeedBleed: number,
	-- Turn rate at rest and at hardCap: turns widen with speed; a stick held back brakes instead of turning (#266).
	-- Halved once (Q34), back (#272, Q37), then a quarter quicker (the owner, #298, Q85: "decrease a little the turn
	-- weights"; Roller Champions' skaters circle with W, A, S, D in turn, Video 19): a loop at the stride's top
	-- speed is 4.1 body lengths across, 1.63 s round.
	turnRateLow: number,
	turnRateHigh: number,
	-- The skater's facing turns toward the way they move at most a half-turn in this many seconds, so it never snaps
	-- (the owner, #246: RC turned round over ~0.3 s, Video 7): π / 0.3 = 10.5 rad/s, so the facing keeps up with
	-- steering (at most turnRateLow).
	turnRoundSeconds: number,
	-- A skater carried back against their facing (down a bank or a wall they climbed) rides backwards while the stick
	-- points within this many degrees of the way they roll, and their facing within it of the way back (the owner,
	-- #246). S alone holds it; S with A or D, 45° off, steers elsewhere and turns them round.
	backwardsConeDeg: number,
	airTurnRate: number,
	-- How fast a skater in the air turns back upright.
	airUprightRate: number,
	-- A diver in the air flies down a line this far below their facing, gravity's pull along it speeding them up:
	-- 130.8 × sin 20° × cos 20° = 42 studs/s² across the ground, 50 km/h per s (the owner, #241, from RC's readout:
	-- ~75 km/h per s diving down; two thirds of the gravity since #279).
	fallLineDeg: number,
	-- A surface steeper than wallAngle (degrees from flat) is a wall. Gravity pulls along it at full strength, as
	-- everywhere (the owner, #256: one gravity, real physics). A wall holds a skater unless it bends away from them
	-- more than it presses them on (#257, the contact rule); past straight up that takes speed² × curvature (A3).
	wallAngle: number,
	-- A surface that holds presses the skates on at least this firmly (studs/s²) against a bend away from them, on it
	-- or flying beside it after leaving or touching it (#289): gravity presses nothing onto an upright wall, so without
	-- it the slightest drift round the middle glass's round ends let go. 38 holds a skater going round them (the root
	-- 22.5 from their axis) slower than √(38 × 22.5) = 29 studs/s, 5 body lengths a second; faster flies off (Q71).
	wallGrip: number,
	-- On a wall the stick never strides and the brake does nothing (the owner, #239; up a solid wall it only climbs,
	-- below), and the stick turns the heading at most this fast. A level line along upright glass needs
	-- g / wallTurnRate (131 studs/s at #279's gravity), past hardCap, so every rider curves back down.
	wallTurnRate: number,
	-- Holding the stick up any solid ride surface, however steep (the floors' slopes, the banks, the walls up to
	-- their glass), the skater gains speed along their heading at climbAccel (studs/s²) whatever the slope, up to
	-- climbSpeed; never on the glass, where the skates only roll (#239). The owner (#299, Q79-Q85: "I want the
	-- player to be able to climb all walls, just till they reach the glass then they start dropping"), trial S4
	-- kept: 1.5x the stride's push, up to 6.8 body lengths a second (the flat's top is 7.9). It replaced #273's
	-- crawl (3.33 studs/s up slopes under 45°), where a W-only start in the spawn room topped the rise in 4.8 s.
	climbSpeed: number,
	climbAccel: number,
	-- How far back along the skater's path, in studs the way the surface bends (#289), its curve is measured (A3): a
	-- few of a lip's flat strips, so a curve of strips reads as the arc it makes, yet short enough to follow a curve
	-- from where it starts.
	curvatureWindow: number,
	pumpSlopeMultiplier: number,
	pumpFlatAccel: number,
	-- Within this slope of flat, pumping gives pumpFlatAccel.
	pumpFlatSlopeDeg: number,
	-- The Brake key's deceleration. The stick's part held back against the motion brakes as hard (the owner, #298,
	-- Q85: from the stride's top speed stopped in 0.37 s over 1.5 body lengths, then turned round).
	brakeDecel: number,
	tiptoeSpeed: number,
	-- A jump leaves the ground this fast: 48.99² / (2 × 130.8) = 9.2 studs up, 0.75 s in the air. √(2/3) of
	-- 60, so at two thirds of the gravity it rises as high as before and hangs longer, like RC's (the owner, #279).
	jumpImpulse: number,
	-- A jump, and an Air Pose, costs this share of the speed (the owner, #218: 10%, so jumping is no free move).
	jumpSpeedCost: number,
	-- The Air Pose (a press in the air, once until landing; it lasts while the key is held, #245) cancels any fall and
	-- adds this speed straight up: a hop of 34.29² / (2 × 130.8) = 4.5 studs, about half a jump's 9.2 (the owner,
	-- #218; √(2/3) of 42 since #279).
	-- After the hop the skater falls as anyone does: the pose adds no motion of its own (the owner, #278, Q76).
	airPoseImpulse: number,
	-- Touching down from the air on the belly (diving, or still posing) keeps this share of the speed, then the slide
	-- (the owner, #245: RC kept 59-73%, 65.5% on average: 133 -> 84, 139 -> 101, 104 -> 70, 97 -> 57 km/h).
	bellyLandingKeep: number,
	-- The ground's normal turning more than this between two rays is a corner: the speed into the new face is lost. A
	-- smaller turn is a curve: the skating follows it at once and keeps its speed through it, since the ground does no
	-- work (#255: smoothing the turn lagged the skating and added energy on curved walls; projecting the speed onto
	-- each strip lost ~12% of it per wall visit). The arena's smooth shape runs on in one direction where two of its
	-- strips meet turning less than this, so only a real corner turns sharper (#294).
	cornerDeg: number,
	-- The skater body's up eases toward the skating's at this rate (each step closes 1 − e^(−rate × dt) of the turn),
	-- so it turns smoothly where the skating turns at once: at a corner or a touchdown (#255, #294).
	bodyUpSmoothing: number,
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
	-- A knocked-down skater slides evenly to a stop in this many seconds from the slide's first step on the ground,
	-- whatever the speed, by the kind of knockdown (Attributes.Knockdown). The owner (#252, Q24), from RC's readout: a
	-- tackle 50 -> 0 km/h and posed falls 70 -> 0 and 57 -> 0 in 1.5 s each, dives 68 -> 0 in 0.7 s and 84 -> 10 in
	-- 0.8 s. Was one rate for all, 75 studs/s² on top of friction and drag.
	knockdownSlideSeconds: { Hit: number, Fall: number, Dive: number },
	-- A fall of `drop` studs or more (from the top of the last rise to where the skater comes to rest) onto ground
	-- flatter than wallAngle knocks them down for knockdownSeconds, sliding. The owner (#222): 40, above an uppercut's
	-- leap with an Air Pose at its top (~35); an Air Pose's hop starts a fall over.
	hardLanding: { drop: number, knockdownSeconds: number },
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
	cruiseSpeed = 46,
	softCap = 90,
	hardCap = 121,
	overSpeedBleed = 5,
	turnRateLow = 5.0,
	turnRateHigh = 2.0,
	turnRoundSeconds = 0.3,
	backwardsConeDeg = 30,
	airTurnRate = 1,
	airUprightRate = 6,
	fallLineDeg = 20,
	wallAngle = 30,
	wallGrip = 38,
	wallTurnRate = 1,
	climbSpeed = 40,
	climbAccel = 45,
	curvatureWindow = 10,
	pumpSlopeMultiplier = 1.6,
	pumpFlatAccel = 8,
	pumpFlatSlopeDeg = 3,
	brakeDecel = 120,
	tiptoeSpeed = 12,
	jumpImpulse = 48.99,
	jumpSpeedCost = 0.1,
	airPoseImpulse = 34.29,
	bellyLandingKeep = 0.65,
	cornerDeg = 30,
	bodyUpSmoothing = 30,
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
	knockdownSlideSeconds = { Hit = 1.5, Fall = 1.5, Dive = 0.8 },
	hardLanding = { drop = 40, knockdownSeconds = 1.5 },
	speedometerScale = 1.2,
}

local positive = Validate.number({ above = 0 })
local nonNegative = Validate.number({ min = 0 })
local angle = Validate.number({ above = 0, max = 180 })
-- Above zero, at most a quarter turn.
local quarterTurn = Validate.number({ above = 0, max = 90 })

local fields = Validate.record({
	colliderDiameter = Validate.number({ above = 0, max = PartSize.MAX }),
	hoverHeight = positive,
	hoverSpring = positive,
	groundProbeLength = positive,
	strideAccel = nonNegative,
	rollingFriction = nonNegative,
	airDrag = nonNegative,
	cruiseSpeed = positive,
	softCap = positive,
	hardCap = positive,
	overSpeedBleed = nonNegative,
	turnRateLow = nonNegative,
	turnRateHigh = nonNegative,
	turnRoundSeconds = positive,
	backwardsConeDeg = quarterTurn,
	airTurnRate = nonNegative,
	airUprightRate = positive,
	fallLineDeg = quarterTurn,
	-- A slope from flat short of upright: past it a surface's tilt tells nothing (the review, #303).
	wallAngle = Validate.number({ above = 0, below = 90 }),
	wallGrip = nonNegative,
	wallTurnRate = nonNegative,
	climbSpeed = positive,
	climbAccel = positive,
	curvatureWindow = positive,
	pumpSlopeMultiplier = Validate.number({ min = 1 }),
	pumpFlatAccel = nonNegative,
	pumpFlatSlopeDeg = Validate.number({ min = 0, below = 90 }),
	brakeDecel = positive,
	tiptoeSpeed = nonNegative,
	jumpImpulse = nonNegative,
	jumpSpeedCost = Validate.number({ min = 0, max = 1 }),
	airPoseImpulse = nonNegative,
	bellyLandingKeep = Validate.number({ above = 0, max = 1 }),
	cornerDeg = quarterTurn,
	bodyUpSmoothing = positive,
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
	knockdownSlideSeconds = Validate.record({ Hit = positive, Fall = positive, Dive = positive }),
	hardLanding = Validate.record({ drop = positive, knockdownSeconds = positive }),
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
		-- A climb is almost the flat's stride, "but almost not quite" (the owner, #299, Q82).
		message = "climbSpeed must stay below cruiseSpeed",
		holds = function(movement: MovementConfig): boolean
			return movement.climbSpeed < movement.cruiseSpeed
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
