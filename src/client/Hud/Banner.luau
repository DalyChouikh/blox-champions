--!strict
-- The banner across the screen (spec §11.1): GO <team> TEAM!, GOAL!, DENIED!, the clock warnings, LAST CHANCE and
-- OVERTIME, in the colour of the team it is about, or the HUD's text colour. Hidden without a banner, and for the
-- kickoff's count, which Hud/Countdown draws a third of the way down (#353).
-- It centres in the HUD's stage (left of the touch buttons on touch) and shrinks to fit it. A plain function of its
-- props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

export type BannerProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	banner: HudState.Banner?,
	-- The HUD's stage, which the banner fits in.
	area: React.Binding<Vector2>,
}

local function Banner(props: BannerProps): React.ReactElement
	local config, banner = props.config, props.banner
	local hud = config.UI.hud
	local place = hud.layout.banner
	local team: Team.Team? = if banner ~= nil then banner.team else nil
	local shown = banner ~= nil and banner.kind ~= "Countdown"
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			AnchorPoint = Style.CENTRE,
			Position = place.position,
			Size = place.size,
			TextSize = hud.bannerSize,
			Text = if banner ~= nil and shown then props.text:banner(banner) else "",
			TextColor3 = Style.teamColor(config, team),
			Visible = shown,
		}),
		{ Fit = Style.fit(config, props.area, place.size) }
	)
end

return Banner
