--!strict
-- Every remote the game uses (spec §10.2), named only here. The server creates them once; clients wait for them.
--   RuleEvents     server → clients  each frame's rule events, in order (one batch per frame that has any)
--   MatchSnapshot  server → clients  the match and its names, after each batch, on each seat change, and to a joiner
--   BallCarrier    server → clients  { carrier = PlayerId? } whenever the ball changes hands
--   SkateState     client → server   { pump, brake } whenever either changes (Net/Schemas checks it)
--   ActionRequest  client → server   { action, aim?, charge? } when a player starts an action (Net/Schemas)
--   ActionRejected server → client   { action } when the server refuses it, so the client cancels it

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Remotes = {}

Remotes.FOLDER = "Remotes"

-- Keyed by string so both `Remotes.names.RuleEvents` and a loop over every name type-check.
local names: { [string]: string } = {
	RuleEvents = "RuleEvents",
	MatchSnapshot = "MatchSnapshot",
	BallCarrier = "BallCarrier",
	SkateState = "SkateState",
	ActionRequest = "ActionRequest",
	ActionRejected = "ActionRejected",
}
Remotes.names = Freeze.deep(names)

local function isName(name: string): boolean
	for _, known in Remotes.names do
		if known == name then
			return true
		end
	end
	return false
end

function Remotes.create(parent: Instance): Folder
	if parent:FindFirstChild(Remotes.FOLDER) ~= nil then
		error(`Remotes: already created under {parent:GetFullName()}`, 0)
	end
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FOLDER
	for _, name in Remotes.names do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = parent
	return folder
end

-- Waits until the server has created the remote.
function Remotes.get(parent: Instance, name: string): RemoteEvent
	if not isName(name) then
		error(`Remotes: unknown remote "{name}"`, 0)
	end
	return parent:WaitForChild(Remotes.FOLDER):WaitForChild(name) :: RemoteEvent
end

return table.freeze(Remotes)
