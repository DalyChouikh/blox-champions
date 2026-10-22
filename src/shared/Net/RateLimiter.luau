--!strict
-- A token bucket per key (spec §13: remotes are rate-limited per player). Each key may send perSecond messages in a
-- burst, and gets them back at perSecond a second. Allocates only a key's first bucket.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, at: number }

type Fields = {
	_perSecond: number,
	_buckets: { [string]: Bucket },
}

export type RateLimiter = typeof(setmetatable({} :: Fields, RateLimiter))

function RateLimiter.new(perSecond: number): RateLimiter
	local self: Fields = { _perSecond = perSecond, _buckets = {} }
	return setmetatable(self, RateLimiter)
end

-- True, spending a token, when `key` may send a message at time `now` (seconds).
function RateLimiter.allow(self: RateLimiter, key: string, now: number): boolean
	local perSecond = self._perSecond
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = perSecond, at = now }
		self._buckets[key] = bucket
	end
	bucket.tokens = math.min(perSecond, bucket.tokens + (now - bucket.at) * perSecond)
	bucket.at = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: string)
	self._buckets[key] = nil
end

return RateLimiter
