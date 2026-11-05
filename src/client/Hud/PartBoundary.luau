--!strict
-- One HUD part behind an error boundary (#379, the owner's Q242). Without one, a part whose render throws takes React's
-- whole tree down: in session 78 one malformed lap event blanked the whole HUD until the next Play. Behind one, that
-- part alone shows nothing and the rest of the HUD goes on. The part then stays hidden, untried, for the rest of the
-- match, and is tried again when the next one starts (HudState.matchNumber), so one failure is reported at most once
-- a match, never every frame or every render. The report is a line naming the part, the error and where it was thrown
-- (React's own warning, which it gives for every error a boundary catches, has the error alone). The part's instances
-- take the boundary's key as their name, as they took the part's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type PartBoundaryProps = {
	-- The part, and its name in the report.
	name: string,
	part: React.ReactElement,
	-- The match the HUD shows (HudState.matchNumber): a new one tries a hidden part again.
	match: number,
	-- Where a failure is reported, one line each.
	report: (line: string) -> (),
}

type State = { failed: boolean, match: number }

local PartBoundary = React.Component:extend("PartBoundary")

-- The report's line: the part, the error's message and the first line of its stack, where it was thrown. React hands
-- a boundary a thrown string as an Error (message, stack, probed); anything else as thrown, reported as it reads.
local function line(name: string, problem: any): string
	local message, at = tostring(problem), "?"
	if typeof(problem) == "table" and problem.message ~= nil then
		message = tostring(problem.message)
		at = string.match(tostring(problem.stack), "^[^\n]*") :: string
	end
	return `[BloxChampions] Hud: {name} hidden until the next match: {message} ({at})`
end

function PartBoundary:init(props: PartBoundaryProps)
	self.state = { failed = false, match = props.match } :: State
end

function PartBoundary.getDerivedStateFromError(_problem: any): { failed: boolean }
	return { failed = true }
end

function PartBoundary.getDerivedStateFromProps(props: PartBoundaryProps, state: State): State?
	if props.match ~= state.match then
		return { failed = false, match = props.match }
	end
	return nil
end

function PartBoundary:componentDidCatch(problem: any)
	local props: PartBoundaryProps = self.props
	props.report(line(props.name, problem))
end

function PartBoundary:render(): React.ReactElement?
	local state: State = self.state
	if state.failed then
		return nil
	end
	local props: PartBoundaryProps = self.props
	return props.part
end

return PartBoundary
