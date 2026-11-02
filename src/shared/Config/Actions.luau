--!strict
-- The players' actions (spec §8.1–8.2): one entry per action, with its phases, cooldown, what it requires and what it
-- does. Adding an action is an entry here plus one effect function in ActionService. Times are in seconds, speeds in
-- studs/s and cones are half-angles in degrees, as Movement's are. The values the spec doesn't give (Dive's cooldown,
-- Dodge's and Uppercut's phases, the aim of each strike) are starting points for tuning, like the spec's own.

local Validate = require(script.Parent.Validate)

export type ActionName = "Tackle" | "Dive" | "Dodge" | "Uppercut" | "ChargeThrow" | "RollBall" | "Pass" | "CallPass"
-- What the server does with an action: knock down who it reaches, make the player immune, throw, roll the ball along
-- the floor, pass or call.
export type Effect = "Knockdown" | "Dodge" | "Throw" | "Roll" | "Pass" | "CallPass"
-- How a skater is posed while the action winds up and strikes.
export type PoseName = "Lunge" | "None"

export type Phases = { windup: number, active: number, recovery: number }
-- Whether an action needs the ball in hand, needs empty hands, or either.
export type BallRequirement = "with" | "without" | "any"
-- Whether an action starts only on the ground, only in the air, or either.
export type Grounded = "grounded" | "airborne" | "any"
-- Whether an action starts only while a throw charges (the throw key held with the ball, #312), only while none does,
-- or either.
export type ChargeRequirement = "charging" | "notCharging" | "any"
export type Requires = {
	ball: BallRequirement,
	grounded: Grounded,
	charge: ChargeRequirement,
	-- Only on their feet, out of any dive (every action but the throw, which a carrier's own dive allows: #314).
	notKnockedDown: boolean,
}
-- Who a strike reaches: within range, and within coneDeg of the facing pitched up by aimUpDeg.
export type Hit = { range: number, coneDeg: number, aimUpDeg: number, knockdownSeconds: number }
-- Where a strike looks for an opponent (#277): within range, and within coneDeg of the stick's way (else the
-- facing) pitched up by aimUpDeg.
export type Cone = { range: number, coneDeg: number, aimUpDeg: number }
-- How a strike homes (#277): the nearest opponent in `snap`, else in `bend`, is its target. At the press the skater
-- turns at once to face and move toward them (else the stick's way), and while they stay within `bend`'s cone the
-- motion turns toward them at most turnDegPerSecond until the strike ends.
export type Seek = { snap: Cone, bend: Cone, turnDegPerSecond: number }
-- The push an action gives its skater when it starts. The lunges' speeds are as the speedometer reads them: along the
-- surface on the ground, across the ground in the air (#233).
export type Motion = {
	-- More speed along the facing, never past lungeCap: a faster skater slows to it. From the strike's end the speed
	-- eases back to the speed before over the recovery, so a lunge never makes a skater faster (#241).
	lungeSpeed: number?,
	lungeCap: number?,
	sideSpeed: number?,
	-- Straight up: the Uppercut's leap (#219).
	leapImpulse: number?,
	-- The Dive's: this speed along the facing, or a faster skater's own, down the fall line in the air
	-- (Movement.fallLineDeg, #241).
	diveSpeed: number?,
}
-- How an action that ends on the skater's belly (the Dive, #221) ends: from its start they can do nothing until their
-- first touch of the ground after its active phase, which knocks them down until their slide is slower than stopSpeed
-- along the ground, or for knockdownSeconds at most; moving does not get them up sooner (#242).
export type Landing = { knockdownSeconds: number, stopSpeed: number }
-- Another action this one's key starts instead from `from` to `to` seconds after this one started (the Tackle's Dive,
-- #240, and the Dodge's, #314), replacing it if it still runs. An action named as a follow-up starts only that way.
export type FollowUp = { action: ActionName, from: number, to: number }
export type ThrowSettings = {
	-- Holding this long charges the throw fully.
	chargeMaxSeconds: number,
	minSpeed: number,
	maxSpeed: number,
	-- The share of the carrier's velocity the ball keeps.
	inheritCarrierVelocity: number,
	-- How far the crosshair's line runs from the camera looking for the spot a throw aims at (#313).
	aimReach: number,
	-- A throw comes down on its spot only if it gets there within this much of its flight; a farther one goes through
	-- the point of the crosshair's line it reaches by then and falls under the spot (#342).
	exactSeconds: number,
}
export type PassSettings = {
	speed: number,
	homingAccel: number,
	-- A pass goes only to a teammate within coneDeg of the aim and maxRange (PassTarget, #315).
	coneDeg: number,
	maxRange: number,
}
export type ActionConfig = {
	phases: Phases,
	-- From the action's start.
	cooldown: number,
	requires: Requires,
	effect: Effect,
	pose: PoseName,
	hit: Hit?,
	seek: Seek?,
	motion: Motion?,
	-- In the air its push is this much of its ground value instead of Actions.airMultiplier.
	airMultiplier: number?,
	landing: Landing?,
	followUp: FollowUp?,
	throw: ThrowSettings?,
	pass: PassSettings?,
}
export type ActionsConfig = {
	-- Pushes in the air are this much of their ground value (an air dodge, an uppercut in the air), unless the action
	-- sets its own (the Tackle). The Dive's speed is never scaled.
	airMultiplier: number,
	-- A call for a pass lasts this long.
	callPassWindow: number,
	-- A knocked-down skater who moves gets up this long after the knockdown, or at once if it is later; one who never
	-- moves gets up at the end of their hit's knockdownSeconds.
	getUpAfter: number,
	Tackle: ActionConfig,
	Dive: ActionConfig,
	Dodge: ActionConfig,
	Uppercut: ActionConfig,
	ChargeThrow: ActionConfig,
	RollBall: ActionConfig,
	Pass: ActionConfig,
	CallPass: ActionConfig,
}

-- Every action, in a fixed order.
local names: { ActionName } = { "Tackle", "Dive", "Dodge", "Uppercut", "ChargeThrow", "RollBall", "Pass", "CallPass" }
table.freeze(names)

-- The action called `name`, or nil: a name read back as a plain string (an attribute, a message) typed again.
local function nameOf(name: string?): ActionName?
	for _, action: ActionName in names do
		if action == name then
			return action
		end
	end
	return nil
end

-- Whether an action with this effect lets go of the ball: a throw, a roll or a pass leaves the hands, so the client
-- sends its aim and predicts the ball leaving.
local function releasesBall(effect: Effect): boolean
	return effect == "Throw" or effect == "Roll" or effect == "Pass"
end

-- Whether an action with this effect spends the charge: a throw and a roll go at its speed (#312), so the client sends
-- it.
local function spendsCharge(effect: Effect): boolean
	return effect == "Throw" or effect == "Roll"
end

-- Whether an action with this effect aims at the crosshair's spot: a throw does (#313, Q148), so the client sends
-- where the crosshair points; a roll keeps to the floor and a pass homes on its target.
local function aimsAtSpot(effect: Effect): boolean
	return effect == "Throw"
end

-- On the ground or in the air alike, charging or not, unless `grounded` or `charge` says otherwise (a mode can too,
-- through requires).
local function requires(ball: BallRequirement, grounded: Grounded?, charge: ChargeRequirement?): Requires
	return { ball = ball, grounded = grounded or "any", charge = charge or "any", notKnockedDown = true }
end

local INSTANT: Phases = { windup = 0, active = 0, recovery = 0 }

local defaults: ActionsConfig = {
	airMultiplier = 0.8,
	callPassWindow = 3,
	-- Any movement key asks to get a knocked-down skater up (#220), never before this: the owner (#287, Q62) keeps
	-- them down the whole 1.5 s slide, as RC's tackled skater slid 1.5 s and pushed off as it stopped (Video 4) and
	-- its posed falls the same (Video 7); was 0.5.
	getUpAfter = 1.5,
	-- On the ground and in the air. Roller Champions' tackle key (the owner, #240; Video 4): "Dive" replaces "Tackle"
	-- 0.1-0.2 s after the press for 0.7-0.8 s, and "Tackle" is back 0.9-1.0 s after it. Its lunge adds 48 km/h but
	-- never past 72 km/h, and eases back over the recovery (the owner, #241: RC's peaked at 65-75 km/h whatever the
	-- speed before, and fell back within ~0.3 s); in the air 0.4 as much, 19 km/h, under the same ceiling (RC: 27 -> 42
	-- km/h, 18 -> 37). It homes (the owner, #277: Q57-Q61; RC's hits in Video 24 landed 1-3 body lengths ahead, up to
	-- ~30 deg aside, 0.1-0.3 s after the press, and its lunge goes where the stick points, Video 26): anyone within
	-- 2 bodies in the front half, else 3 bodies within 45 deg, a quarter-turn over its strike; its hit counts the
	-- front half, so a skater beside is reached.
	Tackle = {
		phases = { windup = 0.05, active = 0.25, recovery = 0.35 },
		cooldown = 1,
		requires = requires("without"),
		effect = "Knockdown",
		pose = "Lunge",
		hit = { range = 7, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
		seek = {
			snap = { range = 12, coneDeg = 90, aimUpDeg = 0 },
			bend = { range = 18, coneDeg = 45, aimUpDeg = 0 },
			turnDegPerSecond = 300,
		},
		motion = { lungeSpeed = 40, lungeCap = 60 },
		airMultiplier = 0.4,
		followUp = { action = "Dive", from = 0.1, to = 1 },
	},
	-- Roller Champions' dive (the owner's Videos 5 and 6), only as a follow-up: the Tackle's with empty hands, or the
	-- Dodge's with the ball (#314), which the carrier keeps (Q102) and dives with as hard (Q152). 72 km/h along the
	-- way, or a faster skater's own speed, and in the air down the fall line, speeding up (RC: 19 -> 65 km/h at the
	-- press, 133 at the touchdown 1.1 s later). Its strike is a 0.3 s flight (the owner, #277 Q66: shorter, as RC's
	-- ~0.3 s), then on the belly until the slide is under 2 studs/s (2.4 km/h), 1.5 s at most (the owner, #242: RC's
	-- slid to 0-3 km/h in 0.7-0.8 s, and every action came back at the stop). It snaps to an opponent beside the diver,
	-- even a little behind (Q64: the owner's dives missed opponents 10-19 studs away, 62-96 deg off the facing).
	Dive = {
		phases = { windup = 0, active = 0.3, recovery = 0.9 },
		cooldown = 0.8,
		requires = requires("any"),
		effect = "Knockdown",
		pose = "Lunge",
		hit = { range = 11, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
		seek = {
			snap = { range = 18, coneDeg = 120, aimUpDeg = 0 },
			bend = { range = 18, coneDeg = 45, aimUpDeg = 0 },
			turnDegPerSecond = 300,
		},
		motion = { diveSpeed = 60 },
		landing = { knockdownSeconds = 1.5, stopSpeed = 2 },
	},
	-- Tackle-immune exactly while active. Its key then dives with the ball from 0.1 to 1.0 s after it, as the Tackle's
	-- does (#314, Q102): RC's Dodge row reads "Dive" for ~1 s after a dodge with the ball (Video 32 at 4.6-5.6 s; Video
	-- 33: the dodge at ~17.0 s, "Dive" from 17.2, pressed at 17.4).
	Dodge = {
		phases = { windup = 0, active = 0.3, recovery = 0.2 },
		cooldown = 1.5,
		requires = requires("with"),
		effect = "Dodge",
		pose = "None",
		motion = { sideSpeed = 45 },
		followUp = { action = "Dive", from = 0.1, to = 1 },
	},
	-- Aimed up, so its cone covers "in front and above"; it leaps the skater up from any ground, 89.81² / (2 × 130.8) =
	-- 31 studs, 1.37 s in the air (the owner, #219: RC's uppercut launches on open floor; #279: √(2/3) of 110 at two
	-- thirds of the gravity, as high as before, hanging longer like RC's), or from a wall, but never in the air (the
	-- owner, #262: RC greys it there, Videos 10-11). No recovery: a Tackle may follow once its strike is over (the
	-- owner, #240: RC's air Tackle was ready 0.13-0.3 s after an Uppercut). It homes on an opponent above within 45 deg
	-- of straight up (the owner, #277: Q56, Q58), only as far as its hit reaches by its strike's end (the owner, #303,
	-- Q89): the leap 18.4 up at 0.25 s, its 6-stud hit and the server's 3 make 27.4. It hits a close skater anywhere
	-- in its front half, on the ground too (the owner's note; RC's Uppercuts at Video 24's 119.6 and 153.8 s).
	Uppercut = {
		phases = { windup = 0.05, active = 0.2, recovery = 0 },
		cooldown = 1.2,
		requires = requires("without", "grounded"),
		effect = "Knockdown",
		pose = "None",
		hit = { range = 6, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
		seek = {
			snap = { range = 12, coneDeg = 90, aimUpDeg = 0 },
			bend = { range = 27, coneDeg = 45, aimUpDeg = 90 },
			turnDegPerSecond = 360,
		},
		motion = { leapImpulse = 89.81 },
	},
	-- Held with the ball to charge, let go to throw. A full charge in 0.5 s (the owner, Q99, kept in trial #311, Q133;
	-- was 1 s): RC's crosshair closes 0.4-0.6 s after the press (Video 4 at 6:05.9-6:06.4, Video 3 at 36:58, Video 32
	-- at 2.6-3.2 s). The throw comes down where the crosshair points (#313, Q148: RC's ball leaves the hand and flies
	-- into the crosshair, Video 31 at 39.0-39.3 s) under real gravity (Q150), flattened the realistic way, by speed
	-- (trial 150 kept, Q151; was 60-160): 90 studs/s at a tap to 240 at a full charge (15-41 body lengths a second). A
	-- spot 100 studs out then takes a 6 deg throw, one 177 out a 15 deg one rising 2.4 body heights in 0.76 s (RC's
	-- ball reaches the far end of Video 31's straight in about 1 s). The crosshair's line looks 1000 studs for the
	-- spot, past any arena's far side. But only so far, like RC's (Video 35: a goal ~0.85 s away went in dead centre,
	-- one far down a straight sank under the ring and missed): a throw is exact only if it gets to the spot within
	-- 0.8 s of flight (a full charge ~190 studs, 33 body lengths; a half ~100); farther, it goes through the point of
	-- the crosshair's line it reaches by then and falls on under the spot (3.85 body heights under one 260 out at a
	-- full charge), so a far target needs a higher aim (the owner, #342: Q166, Q169; trial 342 kept, Q170). Down too:
	-- through the carrier's own dive and belly slide (#314, Q154: RC's hints keep Charge Throw lit there, Video 33 at
	-- 17.6-19.0 s), the one knockdown that keeps the ball.
	ChargeThrow = {
		phases = INSTANT,
		cooldown = 0,
		requires = { ball = "with", grounded = "any", charge = "any", notKnockedDown = false },
		effect = "Throw",
		pose = "None",
		throw = {
			chargeMaxSeconds = 0.5,
			minSpeed = 90,
			maxSpeed = 240,
			inheritCarrierVelocity = 0.5,
			aimReach = 1000,
			exactSeconds = 0.8,
		},
	},
	-- RC's Roll Ball (the owner, Q100; Video 31 at 1:19.4: the ball drops to the floor beside the skater and rolls
	-- away ahead): the uppercut key while a throw charges puts the ball on the floor under the hand, rolling the
	-- aim's way across it at the charge's speed. It spends ChargeThrow's charge at ChargeThrow's speeds (one charge,
	-- one speed range), so it has no throw settings of its own. Only from a surface: in the air the uppercut key does
	-- nothing (#262, RC greys it there).
	RollBall = {
		phases = INSTANT,
		cooldown = 0,
		requires = requires("with", "grounded", "charging"),
		effect = "Roll",
		pose = "None",
	},
	-- Never while a throw charges (the owner, Q140: RC greys Magnetic Pass then, Video 32 at 2.6-3.2 s): letting go of
	-- the throw, Cancel & Dodge or Roll Ball are the ways out of a charge.
	Pass = {
		phases = INSTANT,
		cooldown = 0,
		requires = requires("with", nil, "notCharging"),
		effect = "Pass",
		pose = "None",
		pass = {
			-- The owner's trial on the smooth ball (Q139: #316's 2-player test, my bot passing to them 8 times) kept
			-- 100 (was 90); 150 felt instant and nobody could step into it (Q129), 90 with homing 150 too slow (Q131).
			speed = 100,
			-- The same trial: homing 150 (was 60), so a pass 40 studs out reaches a still teammate in 0.28 s at ~142.
			homingAccel = 150,
			-- Magnetic Pass (#315, Q105): a teammate within 70 deg of the aim and 120 studs (20 body lengths).
			coneDeg = 70,
			maxRange = 120,
		},
	},
	CallPass = {
		phases = INSTANT,
		cooldown = 1,
		requires = requires("without"),
		effect = "CallPass",
		pose = "None",
	},
}

local positive = Validate.number({ above = 0 })
local nonNegative = Validate.number({ min = 0 })
local fraction = Validate.number({ min = 0, max = 1 })
local cone = Validate.number({ above = 0, max = 180 })

local phases = Validate.record({ windup = nonNegative, active = nonNegative, recovery = nonNegative })
local requiresSchema = Validate.record({
	ball = Validate.string({ oneOf = { "with", "without", "any" } }),
	grounded = Validate.string({ oneOf = { "grounded", "airborne", "any" } }),
	charge = Validate.string({ oneOf = { "charging", "notCharging", "any" } }),
	notKnockedDown = Validate.boolean(),
})
local aimUp = Validate.number({ min = 0, max = 90 })
local hit = Validate.record({ range = positive, coneDeg = cone, aimUpDeg = aimUp, knockdownSeconds = positive })
local coneRecord = Validate.record({ range = positive, coneDeg = cone, aimUpDeg = aimUp })
local seek = Validate.record({ snap = coneRecord, bend = coneRecord, turnDegPerSecond = nonNegative })
local throw = Validate.check(
	Validate.record({
		chargeMaxSeconds = positive,
		minSpeed = positive,
		maxSpeed = positive,
		inheritCarrierVelocity = fraction,
		aimReach = positive,
		exactSeconds = positive,
	}),
	function(settings: ThrowSettings): boolean
		return settings.maxSpeed >= settings.minSpeed
	end,
	"maxSpeed must be at least minSpeed"
)
local pass = Validate.record({
	speed = positive,
	homingAccel = nonNegative,
	coneDeg = cone,
	maxRange = positive,
})

-- Every action's name as a plain string: Luau tables are invariant, so { ActionName } is not the { string } that
-- oneOf takes.
local nameStrings: { string } = {}
for _, name in names do
	table.insert(nameStrings, name)
end

-- Another action than `own`, in a window that ends after it starts.
local function followUp(own: ActionName): Validate.Validator
	return Validate.check(
		Validate.record({
			action = Validate.check(Validate.string({ oneOf = nameStrings }), function(action: string): boolean
				return action ~= own
			end, "must name another action"),
			from = nonNegative,
			to = positive,
		}),
		function(window: FollowUp): boolean
			return window.to > window.from
		end,
		"to must be after from"
	)
end

-- An action's record: the fields every action has, plus its own. Its effect is the default's and no other: modes
-- change an action's numbers, never what it does (Net/Schemas shapes each action's request by its effect).
local function action(default: ActionConfig, own: { [string]: Validate.Validator }): Validate.Validator
	-- A plain string: luau tables are invariant, so { Effect } is not the { string } oneOf takes.
	local effect: string = default.effect
	local fields: { [string]: Validate.Validator } = {
		phases = phases,
		cooldown = nonNegative,
		requires = requiresSchema,
		effect = Validate.string({ oneOf = { effect } }),
		pose = Validate.string({ oneOf = { "Lunge", "None" } }),
	}
	for name, validator in own do
		fields[name] = validator
	end
	return Validate.record(fields)
end

local schema = Validate.record({
	airMultiplier = fraction,
	callPassWindow = positive,
	getUpAfter = positive,
	Tackle = action(defaults.Tackle, {
		hit = hit,
		seek = seek,
		motion = Validate.record({ lungeSpeed = positive, lungeCap = positive }),
		airMultiplier = fraction,
		followUp = followUp("Tackle"),
	}),
	Dive = action(defaults.Dive, {
		hit = hit,
		seek = seek,
		motion = Validate.record({ diveSpeed = positive }),
		landing = Validate.record({ knockdownSeconds = positive, stopSpeed = positive }),
	}),
	Dodge = action(defaults.Dodge, {
		motion = Validate.record({ sideSpeed = positive }),
		followUp = followUp("Dodge"),
	}),
	Uppercut = action(defaults.Uppercut, {
		hit = hit,
		seek = seek,
		motion = Validate.record({ leapImpulse = positive }),
	}),
	ChargeThrow = action(defaults.ChargeThrow, { throw = throw }),
	RollBall = action(defaults.RollBall, {}),
	Pass = action(defaults.Pass, { pass = pass }),
	CallPass = action(defaults.CallPass, {}),
})

return {
	defaults = defaults,
	schema = schema,
	names = names,
	nameOf = nameOf,
	releasesBall = releasesBall,
	spendsCharge = spendsCharge,
	aimsAtSpot = aimsAtSpot,
}
