--!strict
-- Whether a seated player may switch to the other team now (spec §10.1; the owner, Q97, Q104, Q119, Q120, #310): the
-- mode offers it (Match.teamSwitching: normal games, never ranked), the other team has a free seat (Match.teamSize;
-- the teams may end up uneven, as nothing balances them), and the player isn't holding the ball. A ball they threw
-- doesn't hold a switch back, and there is no cooldown. The server judges a request by it (MatchService), and the HUD
-- greys its button by it (HudState.switchOffer).

local Config = require(script.Parent.Parent.Config)

local TeamSwitch = {}

-- `otherSeated`: the seats the other team's players hold.
function TeamSwitch.allowed(match: Config.MatchConfig, otherSeated: number, holdsBall: boolean): boolean
	return match.teamSwitching and otherSeated < match.teamSize and not holdsBall
end

return table.freeze(TeamSwitch)
