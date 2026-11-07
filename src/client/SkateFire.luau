--!strict
-- The skates' fire (#413, the owner's Q298): every skater with a team, the local one too, trails fire from both skates
-- in the team's colour whenever they move (skating, pumping, any motion), and none while still. Roblox's trails
-- lengthen with speed by themselves: each is UI.skateFire.lifetime of travel long. Each is a flat ribbon between two
-- attachments across the skate, just over its sole, drawn in the colour itself at UI.skateFire.brightness (look G, the
-- owner's Q331: light added onto our near-white floor turned it white), nearly solid for its first part and fading to
-- nothing at its tail, like Roller Champions' (Videos 35 and 36 in orange, Video 4's Blue skaters in cyan). Each client
-- draws its own, on the avatars' feet (SkaterRig.feet). Stepped before each frame is drawn (FrameController): a step
-- reads each player's team, character and speed, and writes a trail only when what it shows changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team

-- A skater's fire: the character and root it is on, its trails, their team, whether they show, and the step that last
-- saw its player.
type Fire = { character: Model, root: BasePart, trails: { Trail }, team: Team, shown: boolean, seen: number }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type SkateFire = {
	name: string,
	dependencies: { string },
	init: (self: SkateFire, deps: { [string]: any }) -> (),
	start: (self: SkateFire) -> (),
	step: (self: SkateFire, dt: number) -> (),
	_config: Config.GameConfig,
	_players: () -> { Player },
	_playerList: PlayerList.PlayerList?,
	-- How see-through every trail is along its length: one sequence, since a sequence never changes.
	_fade: NumberSequence,
	_fires: { [Player]: Fire },
	_stepId: number,
}

local function edge(foot: BasePart, name: string, across: number, lift: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = Vector3.new(across, -foot.Size.Y / 2 + lift, 0)
	attachment.Parent = foot
	return attachment
end

local function paint(fire: Fire, color: Color3)
	local sequence = ColorSequence.new(color)
	for _, trail in fire.trails do
		trail.Color = sequence
	end
end

-- The fire for `character`'s skates, or nil until its root and every foot its rig has are there.
local function build(self: SkateFire, character: Model, team: Team): Fire?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild(SkaterRig.root) :: BasePart?
	if humanoid == nil or root == nil then
		return nil
	end
	local names: { string } = if humanoid.RigType == Enum.HumanoidRigType.R6
		then SkaterRig.feet.R6
		else SkaterRig.feet.R15
	-- Checked first, so the frames spent waiting for an avatar's parts allocate nothing.
	for _, name in names do
		if character:FindFirstChild(name) == nil then
			return nil
		end
	end
	local settings = self._config.UI.skateFire
	local trails: { Trail } = {}
	for _, name in names do
		local foot = character:FindFirstChild(name) :: BasePart
		local trail = Instance.new("Trail")
		trail.Name = "SkateFire"
		-- Flat across the sole (FaceCamera stays off, its default), so it lies along the floor behind the skate. Drawn
		-- in its own colour and untouched by the scene's light: LightEmission and LightInfluence are 0 by default.
		trail.Attachment0 = edge(foot, "SkateFireLeft", -settings.width / 2, settings.lift)
		trail.Attachment1 = edge(foot, "SkateFireRight", settings.width / 2, settings.lift)
		trail.Lifetime = settings.lifetime
		trail.Brightness = settings.brightness
		trail.Transparency = self._fade
		trail.Enabled = false
		trail.Parent = foot
		table.insert(trails, trail)
	end
	local fire: Fire = { character = character, root = root, trails = trails, team = team, shown = false, seen = 0 }
	paint(fire, self._config.UI.teamColors[team])
	return fire
end

-- Takes `player`'s fire off their skates and forgets it.
local function drop(fires: { [Player]: Fire }, player: Player, fire: Fire)
	for _, trail in fire.trails do
		local left, right = trail.Attachment0 :: Attachment, trail.Attachment1 :: Attachment
		trail:Destroy()
		left:Destroy()
		right:Destroy()
	end
	fires[player] = nil
end

local SkateFire: SkateFire = {
	name = "SkateFire",
	dependencies = { "Config" },
	_config = nil :: any,
	_players = function(): { Player }
		return PlayerList.listOf(nil)
	end,
	_playerList = nil,
	_fade = NumberSequence.new(0),
	_fires = {},
	_stepId = 0,

	-- deps.Players replaces the game's players in tests.
	init = function(self: SkateFire, deps: { [string]: any })
		self._config = deps.Config
		local settings = self._config.UI.skateFire
		self._fade = NumberSequence.new({
			NumberSequenceKeypoint.new(0, settings.transparency),
			NumberSequenceKeypoint.new(settings.fade.from, settings.fade.transparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		self._players = deps.Players or function(): { Player }
			return PlayerList.listOf(self._playerList)
		end
		self._fires = {}
		self._stepId = 0
	end,

	start = function(self: SkateFire)
		self._playerList = PlayerList.new(Players)
	end,

	step = function(self: SkateFire, _dt: number)
		local stepId = self._stepId + 1
		self._stepId = stepId
		local fires = self._fires
		local minSpeed = self._config.UI.skateFire.minSpeed
		for _, player in self._players() do
			local team: Team? = player:GetAttribute(Attributes.Team) :: Team?
			local character = player.Character
			if team ~= nil and character ~= nil then
				local fire: Fire? = fires[player]
				if fire ~= nil and fire.character ~= character then
					drop(fires, player, fire)
					fire = nil
				end
				if fire == nil then
					fire = build(self, character, team)
					if fire ~= nil then
						fires[player] = fire
					end
				end
				if fire ~= nil then
					fire.seen = stepId
					if team ~= fire.team then
						fire.team = team
						paint(fire, self._config.UI.teamColors[team])
					end
					local shown = fire.root.AssemblyLinearVelocity.Magnitude >= minSpeed
					if shown ~= fire.shown then
						fire.shown = shown
						for _, trail in fire.trails do
							trail.Enabled = shown
						end
					end
				end
			end
		end
		-- A player who left, or who has no team or character now, takes their fire with them. Clearing a field while
		-- walking a table is allowed.
		for player, fire in fires do
			if fire.seen ~= stepId then
				drop(fires, player, fire)
			end
		end
	end,
}

return SkateFire
