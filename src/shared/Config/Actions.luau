--!strict
-- The players' actions (spec §8.1–8.2): one entry per action, with its phases, cooldown, what it requires and what it
-- does. Adding an action is an entry here plus one effect function in ActionService. Times are in seconds, speeds in
-- studs/s and cones are half-angles in degrees, as Movement's are. The values the spec doesn't give (Dive's cooldown,
-- Dodge's and Uppercut's phases, the aim of each strike) are starting points for tuning, like the spec's own.

local Validate = require(script.Parent.Validate)

export type ActionName = "Tackle" | "Dive" | "Dodge" | "Uppercut" | "ChargeThrow" | "Pass" | "CallPass"
-- What the server does with an action: knock down who it reaches, make the player immune, throw, pass or call.
export type Effect = "Knockdown" | "Dodge" | "Throw" | "Pass" | "CallPass"
-- How a skater is posed while the action winds up and strikes.
export type PoseName = "Lunge" | "None"

export type Phases = { windup: number, active: number, recovery: number }
-- Whether an action needs the ball in hand, needs empty hands, or either.
export type BallRequirement = "with" | "without" | "any"
-- Whether an action starts only on the ground, only in the air, or either.
export type Grounded = "grounded" | "airborne" | "any"
export type Requires = {
	ball: BallRequirement,
	grounded: Grounded,
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
-- #240), replacing it if it still runs. An action named as a follow-up starts only that way.
export type FollowUp = { action: ActionName, from: number, to: number }
export type ThrowSettings = {
	-- Holding this long charges the throw fully.
	chargeMaxSeconds: number,
	minSpeed: number,
	maxSpeed: number,
	-- The share of the carrier's velocity the ball keeps.
	inheritCarrierVelocity: number,
}
export type PassSettings = {
	speed: number,
	homingAccel: number,
	-- Without a caller, a pass goes to the best teammate within coneDeg of the aim and maxRange, scored by
	-- angleWeight × (1 − angle / coneDeg) + distanceWeight × (1 − distance / maxRange).
	coneDeg: number,
	maxRange: number,
	angleWeight: number,
	distanceWeight: number,
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
	Pass: ActionConfig,
	CallPass: ActionConfig,
}

-- Every action, in a fixed order.
local names: { ActionName } = { "Tackle", "Dive", "Dodge", "Uppercut", "ChargeThrow", "Pass", "CallPass" }
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

-- On the ground or in the air alike, unless `grounded` says otherwise (a mode can too, through requires.grounded).
local function requires(ball: BallRequirement, grounded: Grounded?): Requires
	return { ball = ball, grounded = grounded or "any", notKnockedDown = true }
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
	-- Roller Champions' dive (the owner's Videos 5 and 6), only as the Tackle's follow-up: 72 km/h along the way, or a
	-- faster skater's own speed, and in the air down the fall line, speeding up (RC: 19 -> 65 km/h at the press, 133
	-- at the touchdown 1.1 s later). Its strike is a 0.3 s flight (the owner, #277 Q66: shorter, as RC's ~0.3 s), then
	-- on the belly until the slide is under 2 studs/s (2.4 km/h), 1.5 s at most (the owner, #242: RC's slid to 0-3 km/h
	-- in 0.7-0.8 s, and every action came back at the stop). It snaps to an opponent beside the diver, even a little
	-- behind (Q64: the owner's dives missed opponents 10-19 studs away, 62-96 deg off the facing).
	Dive = {
		phases = { windup = 0, active = 0.3, recovery = 0.9 },
		cooldown = 0.8,
		requires = requires("without"),
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
	-- Tackle-immune exactly while active.
	Dodge = {
		phases = { windup = 0, active = 0.3, recovery = 0.2 },
		cooldown = 1.5,
		requires = requires("with"),
		effect = "Dodge",
		pose = "None",
		motion = { sideSpeed = 45 },
	},
	-- Aimed up, so its cone covers "in front and above"; it leaps the skater up from any ground, 89.81² / (2 × 130.8) =
	-- 31 studs, 1.37 s in the air (the owner, #219: RC's uppercut launches on open floor; #279: √(2/3) of 110 at two
	-- thirds of the gravity, as high as before, hanging longer like RC's), or from a wall, but never in the air (the
	-- owner, #262: RC greys it there, Videos 10-11). No recovery: a Tackle may follow once its strike is over (the
	-- owner, #240: RC's air Tackle was ready 0.13-0.3 s after an Uppercut). It homes on an opponent above, up to its
	-- leap within 45 deg of straight up (the owner, #277: Q56, Q58), and hits a close skater anywhere in its front
	-- half, on the ground too (the owner's note; RC's Uppercuts at Video 24's 119.6 and 153.8 s).
	Uppercut = {
		phases = { windup = 0.05, active = 0.2, recovery = 0 },
		cooldown = 1.2,
		requires = requires("without", "grounded"),
		effect = "Knockdown",
		pose = "None",
		hit = { range = 6, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
		seek = {
			snap = { range = 12, coneDeg = 90, aimUpDeg = 0 },
			bend = { range = 31, coneDeg = 45, aimUpDeg = 90 },
			turnDegPerSecond = 360,
		},
		motion = { leapImpulse = 89.81 },
	},
	ChargeThrow = {
		phases = INSTANT,
		cooldown = 0,
		requires = requires("with"),
		effect = "Throw",
		pose = "None",
		throw = { chargeMaxSeconds = 1, minSpeed = 60, maxSpeed = 160, inheritCarrierVelocity = 0.5 },
	},
	Pass = {
		phases = INSTANT,
		cooldown = 0,
		requires = requires("with"),
		effect = "Pass",
		pose = "None",
		pass = { speed = 90, homingAccel = 60, coneDeg = 70, maxRange = 120, angleWeight = 0.6, distanceWeight = 0.4 },
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
	}),
	function(settings: ThrowSettings): boolean
		return settings.maxSpeed >= settings.minSpeed
	end,
	"maxSpeed must be at least minSpeed"
)
local pass = Validate.check(
	Validate.record({
		speed = positive,
		homingAccel = nonNegative,
		coneDeg = cone,
		maxRange = positive,
		angleWeight = nonNegative,
		distanceWeight = nonNegative,
	}),
	function(settings: PassSettings): boolean
		return settings.angleWeight + settings.distanceWeight > 0
	end,
	"angleWeight + distanceWeight must be above 0"
)

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
	Dodge = action(defaults.Dodge, { motion = Validate.record({ sideSpeed = positive }) }),
	Uppercut = action(defaults.Uppercut, {
		hit = hit,
		seek = seek,
		motion = Validate.record({ leapImpulse = positive }),
	}),
	ChargeThrow = action(defaults.ChargeThrow, { throw = throw }),
	Pass = action(defaults.Pass, { pass = pass }),
	CallPass = action(defaults.CallPass, {}),
})

return {
	defaults = defaults,
	schema = schema,
	names = names,
	nameOf = nameOf,
}
