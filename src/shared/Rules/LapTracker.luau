--!strict
-- Lap progress of the possessing team's streak (spec §4.2). The first gate crossed after a reset starts the
-- sequence; after that only the next gate in track order counts, so backward or out-of-order crossings are
-- ignored. Crossing every gate in order is one lap.

local Crossing = require(script.Parent.Crossing)

local LapTracker = {}
LapTracker.__index = LapTracker

type Fields = {
	gateCount: number,
	streak: number,
	progress: number,
	_gates: { Crossing.Rectangle },
	_nextGate: number?,
	-- Reused by every call, so reporting and ordering crossings never allocates on a tick.
	_crossed: { number },
	_fractions: { [number]: number },
	_byFraction: (a: number, b: number) -> boolean,
}

export type LapTracker = typeof(setmetatable({} :: Fields, LapTracker))

function LapTracker.new(gates: { Crossing.Rectangle }): LapTracker
	if #gates == 0 then
		error("LapTracker: at least one gate is required", 0)
	end
	local fractions: { [number]: number } = {}
	return setmetatable(
		{
			gateCount = #gates,
			streak = 0,
			progress = 0,
			_gates = gates,
			_nextGate = nil,
			_crossed = {},
			_fractions = fractions,
			_byFraction = function(a: number, b: number): boolean
				return fractions[a] < fractions[b]
			end,
		} :: Fields,
		LapTracker
	)
end

-- Gates the segment crosses forward, in the order the segment meets them, or nil when none. The list is
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
-- streak grows by one and the next lap starts at 0), or nil when the crossing is out of order.
function LapTracker.accept(self: LapTracker, gateIndex: number): number?
	local nextGate = self._nextGate
	if nextGate ~= nil and gateIndex ~= nextGate then
		return nil
	end
	self._nextGate = gateIndex % self.gateCount + 1
	local progress = self.progress + 1
	if progress == self.gateCount then
		self.streak += 1
		self.progress = 0
	else
		self.progress = progress
	end
	return progress
end

function LapTracker.reset(self: LapTracker)
	self.streak = 0
	self.progress = 0
	self._nextGate = nil
end

return LapTracker
