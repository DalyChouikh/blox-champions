--!strict
-- The banner across the screen (spec §11.1): the kickoff's 5-4-3-2-1 inside a ring, GO <team> TEAM!, GOAL!, DENIED!,
-- the clock warnings, LAST CHANCE and OVERTIME, in the colour of the team it is about, or the HUD's text colour.
-- Hidden without a banner.
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
	local place, countdown = hud.layout.banner, hud.countdown
	local team: Team.Team? = if banner ~= nil then banner.team else nil
	local color = Style.teamColor(config, team)
	local counting = banner ~= nil and banner.kind == "Countdown"
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = place.position,
			Size = place.size,
			TextSize = if counting then countdown.textSize else hud.bannerSize,
			Text = if banner ~= nil then props.text:banner(banner) else "",
			TextColor3 = color,
			Visible = banner ~= nil,
		}),
		{
			Fit = Style.fit(config, props.area, place.size),
			-- The kickoff count's ring around its digit (the owner, Q108).
			Ring = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(countdown.ringSize, countdown.ringSize),
				BackgroundTransparency = 1,
				Visible = counting,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Stroke = React.createElement("UIStroke", { Color = color, Thickness = countdown.ringThickness }),
			}),
		}
	)
end

return Banner
