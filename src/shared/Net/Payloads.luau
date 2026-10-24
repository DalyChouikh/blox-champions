--!strict
-- The payloads the server sends to clients through Net/Remotes, typed once for the server that builds them and the
-- clients that read them.

local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local Types = require(script.Parent.Parent.Rules.Types)

-- MatchSnapshot: the server frame it was taken on (after that frame's events), the match, and the name of every player
-- in the server and of each who left during the match (the score tab still lists them).
export type MatchSnapshot = { frame: number, match: MatchEngine.Snapshot, names: { [Types.PlayerId]: string } }

-- RuleEvents: one server frame's rule events, in order, and that frame's number.
export type RuleEvents = { frame: number, events: { Types.Event } }

-- BallCarrier: who carries the ball; absent while it is loose.
export type BallCarrier = { carrier: Types.PlayerId? }

return table.freeze({})
