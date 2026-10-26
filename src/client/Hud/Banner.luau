--!strict
-- The banner across the screen (spec §11.1): the kickoff's 3-2-1, GOAL!, STREAK POINT!, DENIED!, the clock warnings,
-- LAST CHANCE and OVERTIME, in the colour of the team it is about, or the HUD's text colour. Hidden without a banner.
-- It centres in the HUD's stage (left of the touch buttons on touch) and shrinks to fit it. A plain function of its
-- props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type BannerProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	banner: HudState.Banner?,
	-- The HUD's stage, which the banner fits in.
	area: React.Binding<Vector2>,
}

local function Banner(props: BannerProps): React.ReactElement
	local config, banner = props.config, props.banner
	local ui = config.UI
	local place = ui.hud.layout.banner
	local team = if banner ~= nil then banner.team else nil
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = place.position,
			Size = place.size,
			TextSize = ui.hud.bannerSize,
			Text = if banner ~= nil then props.text:banner(banner) else "",
			TextColor3 = if team ~= nil then ui.teamColors[team] else ui.hud.textColor,
			Visible = banner ~= nil,
		}),
		{ Fit = Style.fit(config, props.area, place.size) }
	)
end

return Banner
