--!strict
-- The control hints (spec §11.1), at the right of the screen: a row per control, in ControlLabels' order, showing its
-- key and what it does now. The key is the name the player's own keyboard gives it, or Roblox's glyph on a gamepad. A
-- row's label is a binding, so it follows the play each frame without a render, and the row hides while its control
-- would do nothing (an empty label). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ControlLabels = require(script.Parent.Parent.ControlLabels)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

-- One hint's key: its name, or its glyph.
export type KeyView = { text: string?, image: string? }
export type HintKeys = { [Config.TouchControl]: KeyView }
-- What each control does now; "" while it would do nothing.
export type HintLabels = { [Config.TouchControl]: React.Binding<string> }

export type ControlHintsProps = {
	config: Config.GameConfig,
	keys: HintKeys,
	labels: HintLabels,
}

local function shown(label: string): boolean
	return label ~= ""
end

-- A key: Roblox's glyph, or its name on a key cap, as tall as the row.
local function key(config: Config.GameConfig, view: KeyView, height: number): { [string]: React.Node }
	local size = UDim2.fromOffset(height, height)
	if view.image ~= nil then
		return {
			Glyph = React.createElement(
				"ImageLabel",
				Style.holder({ LayoutOrder = 1, Size = size, Image = view.image })
			),
		}
	end
	return {
		Key = React.createElement(
			"TextLabel",
			Style.text(
				config,
				Style.panel(config, {
					LayoutOrder = 1,
					Size = size,
					AutomaticSize = Enum.AutomaticSize.X,
					Text = view.text or "",
				})
			),
			{
				Corner = Style.corner(config),
				-- A long name ("Shift") widens its cap, keeping `spacing` at each side.
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, config.UI.hud.spacing),
					PaddingRight = UDim.new(0, config.UI.hud.spacing),
				}),
			}
		),
	}
end

local function ControlHints(props: ControlHintsProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.hints
	local height = place.rowHeight
	local rows: { [string]: React.Node } = {
		Layout = Style.list(
			config,
			Enum.FillDirection.Vertical,
			{ HorizontalAlignment = Enum.HorizontalAlignment.Right }
		),
	}
	for order, control: Config.TouchControl in ControlLabels.CONTROLS do
		local label = props.labels[control]
		local children = key(config, props.keys[control], height)
		children.Layout = Style.list(config, Enum.FillDirection.Horizontal, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		})
		children.Label = React.createElement(
			"TextLabel",
			Style.text(config, {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = label,
			})
		)
		rows[control] = React.createElement(
			"Frame",
			Style.holder({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), Visible = label:map(shown) }),
			children
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({ AnchorPoint = Vector2.new(1, 0.5), Position = place.position, Size = place.size }),
		rows
	)
end

return ControlHints
