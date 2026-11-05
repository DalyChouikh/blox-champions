--!strict
-- Lap progress of the possessing team's streak (spec §4.2). Every streak starts at the start gate (a match's is the
-- goal's), and only the next gate in track order counts, crossed either way (Crossing), so out-of-order crossings are
-- ignored. Crossing every gate in order is one lap. A streak counts laps up to its cap (the owner's Q255: once a goal
-- is worth its most, laps stop counting): the lap that reaches it counts as any other, then the lap stays full and no
-- gate counts until the streak ends (`reset`).

local Crossing = require(script.Parent.Crossing)

local LapTracker = {}
LapTracker.__index = LapTracker

type Fields = {
	gateCount: number,
	streak: number,
	-- Gates crossed this lap; the whole lap (gateCount) once the streak has reached its cap.
	progress: number,
	-- The gate that counts next: the start gate when a streak starts, none once it has reached its cap.
	nextGate: number?,
	_startGate: number,
	_cap: number,
	_gates: { Crossing.Rectangle },
	-- Reused by every call, so reporting and ordering crossings never allocates on a tick.
	_crossed: { number },
	_fractions: { [number]: number },
	_byFraction: (a: number, b: number) -> boolean,
}

export type LapTracker = typeof(setmetatable({} :: Fields, LapTracker))

-- `cap` is the most laps a streak counts.
function LapTracker.new(gates: { Crossing.Rectangle }, startGate: number, cap: number): LapTracker
	local gateCount = #gates
	if gateCount == 0 then
		error("LapTracker: at least one gate is required", 0)
	end
	-- A start gate that is not a gate would leave every crossing out of order: no lap would ever count.
	if startGate ~= math.floor(startGate) or startGate < 1 or startGate > gateCount then
		error(`LapTracker: the start gate must be one of the {gateCount} gates (got {startGate})`, 0)
	end
	-- The streak grows a whole lap at a time from 0, so a cap below 1 or between whole laps would never be reached.
	if cap ~= math.floor(cap) or cap < 1 then
		error(`LapTracker: the lap cap must be a whole number of laps, at least 1 (got {cap})`, 0)
	end
	local fractions: { [number]: number } = {}
	return setmetatable(
		{
			gateCount = gateCount,
			streak = 0,
			progress = 0,
			nextGate = startGate,
			_startGate = startGate,
			_cap = cap,
			_gates = gates,
			_crossed = {},
			_fractions = fractions,
			_byFraction = function(a: number, b: number): boolean
				return fractions[a] < fractions[b]
			end,
		} :: Fields,
		LapTracker
	)
end

-- Gates the segment crosses either way, in the order the segment meets them, or nil when none. The list is
-- reused by the next call, so read it before calling again.
function LapTracker.crossedGates(self: LapTracker, from: Vector3, to: Vector3): { number }?
	local crossed = self._crossed
	table.clear(crossed)
	for index, gate in self._gates do
		local fraction = Crossing.throughRectangle(gate, from, to)
		if fraction ~= nil then
			self._fractions[index] = fraction
			table.insert(crossed, index)
		end
	end
	if #crossed == 0 then
		return nil
	end
	if #crossed > 1 then
		table.sort(crossed, self._byFraction)
	end
	return crossed
end

-- Returns the progress after accepting the crossing (1..gateCount, where gateCount completes a lap: the
-- streak grows by one and the next lap starts at 0, or, at the cap, the lap stays full with no next gate), or nil
-- when the crossing is out of order or the streak has reached its cap (no gate is next).
function LapTracker.accept(self: LapTracker, gateIndex: number): number?
	if gateIndex ~= self.nextGate then
		return nil
	end
	local progress = self.progress + 1
	self.progress = progress
	self.nextGate = gateIndex % self.gateCount + 1
	if progress == self.gateCount then
		self.streak += 1
		if self.streak == self._cap then
			-- The streak's last lap stays full (Q268: every lap chip stays lit), and no gate counts until it ends.
			self.nextGate = nil
		else
			self.progress = 0
		end
	end
	return progress
end

function LapTracker.reset(self: LapTracker)
	self.streak = 0
	self.progress = 0
	self.nextGate = self._startGate
end

return LapTracker
