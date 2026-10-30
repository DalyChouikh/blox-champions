--!strict
-- Types shared by the rules engine and everything that consumes its events (spec §4.7).

local Team = require(script.Parent.Team)

type Team = Team.Team

-- Players are plain ids so bots (M2) follow the same rules as Roblox players.
export type PlayerId = string

export type MatchState = "Waiting" | "Kickoff" | "Live" | "Celebration" | "Ended"

export type Period = "Regulation" | "LastChance" | "Overtime"

export type SaveKind = "Block" | "Steal"

export type PlayerStats = {
	player: PlayerId,
	team: Team,
	joinOrder: number,
	present: boolean,
	score: number,
	goals: number,
	assists: number,
	saves: number,
	steals: number,
}

export type MatchStats = {
	scores: { [Team]: number },
	players: { PlayerStats },
}

export type Event =
	{ name: "MatchStarted" }
	| { name: "KickoffStarted", countdownSeconds: number }
	| { name: "KickoffEnded" }
	| { name: "PossessionChanged", team: Team, player: PlayerId, previousTeam: Team? }
	| { name: "GateCrossed", team: Team, gateIndex: number, progress: number }
	| { name: "LapCompleted", team: Team, streak: number, holder: PlayerId }
	| { name: "GoalOpened", team: Team }
	| { name: "GoalClosed" }
	-- `points`: what the goal is worth to the team, by its streak's laps (GoalJudge.worth).
	| { name: "GoalScored", team: Team, scorer: PlayerId, assister: PlayerId?, points: number }
	| { name: "AssistAwarded", player: PlayerId }
	| { name: "SaveMade", player: PlayerId, kind: SaveKind }
	| { name: "Steal", player: PlayerId, fromTeam: Team }
	| { name: "TackleKnockdown", attacker: PlayerId, victim: PlayerId }
	| { name: "ClockWarning", secondsLeft: number }
	| { name: "LastChanceStarted", team: Team }
	| { name: "OvertimeStarted" }
	| { name: "MatchEnded", winner: Team, mvp: PlayerId?, stats: MatchStats }

return table.freeze({})
