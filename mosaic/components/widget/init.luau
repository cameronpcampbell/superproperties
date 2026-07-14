--!strict
--!nolint LocalShadow

local StarterGui = game:GetService("StarterGui")

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Hydrate, Children = Fusion.New, Fusion.Hydrate, Fusion.Children

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component = FusionUtils.Component

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Background = require(Components.background)

type WidgetProps = {
	Id: string,
    Title: Fusion.UsedAs<string>?,
	InitDockState: Enum.InitialDockState?,
	InitEnabled: boolean?,
	OverrideEnabledRestore: boolean?,
	FloatXSize: number?,
	FloatYSize: number?,
	MinWidth: number?,
	MinHeight: number?,
	Debug: boolean?,
	Enabled: Fusion.UsedAs<boolean>?
}

return Component<<WidgetProps>>(function(scope, props)
    local props, id = TableExtract(props, "Id")
    local props, title = TableExtract(props, "Title")
    local props, initDockState = TableExtract(props, "InitDockState")
    local props, initEnabled = TableExtract(props, "InitEnabled")
    local props, overrideEnabledRestore =
        TableExtract(props, "OverrideEnabledRestore")
    local props, floatXSize = TableExtract(props, "FloatXSize")
    local props, floatYSize = TableExtract(props, "FloatYSize")
    local props, minWidth = TableExtract(props, "MinWidth")
    local props, minHeight = TableExtract(props, "MinHeight")
    local props, debugMode = TableExtract(props, "Debug")
    local props, enabled = TableExtract(props, "Enabled")
    local props, children = TableExtract(props, Children)

    local widget = (script:FindFirstAncestorOfClass("Plugin") :: Plugin):CreateDockWidgetPluginGuiAsync(
        id,
        DockWidgetPluginGuiInfo.new(
            initDockState or Enum.InitialDockState.Float, initEnabled or true, overrideEnabledRestore or true,
            floatXSize or 0, floatYSize or 0,
            minWidth or floatXSize or 0, minHeight or floatYSize or 0
        )
    )
    widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local content = Background (scope, {
        [Children] = {
            children,
        }
    }, props :: { [any]: any })

    local debugGuiName = `CAMERONPCAMPBELL:MOSAIC_DEBUG[{id}]`
    local found = StarterGui:FindFirstChild(debugGuiName)
    if found then found:Destroy() end

    if debugMode then
        New(scope, "ScreenGui") {
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

            Parent = StarterGui,
            Name = debugGuiName,

            [Children] = (content :: Instance):Clone()
        }
    end

    return Hydrate(scope, widget) {
        Title = title or id,
        Enabled = enabled,

        [Children] = content,
    }
end)
