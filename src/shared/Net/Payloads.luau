--!strict
-- The payloads the server sends to clients through Net/Remotes, typed once for the server that builds them and the
-- clients that read them.

local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local Types = require(script.Parent.Parent.Rules.Types)

-- MatchSnapshot: the match, and the name of every player who joined it, kept after they leave (the score tab still
-- lists them).
export type MatchSnapshot = { match: MatchEngine.Snapshot, names: { [Types.PlayerId]: string } }

-- BallCarrier: who carries the ball; absent while it is loose.
export type BallCarrier = { carrier: Types.PlayerId? }

return table.freeze({})
