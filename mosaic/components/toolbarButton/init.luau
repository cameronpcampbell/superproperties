--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Hydrate, Observer, Peek = Fusion.Hydrate, Fusion.Observer, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps = FusionUtils.CombineProps

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type ToolbarButtonProps = {
    Id: string,
    Tooltip: string,
    Text: string?,
    Icon: Fusion.UsedAs<string>?,
    Active: Fusion.UsedAs<boolean>?,
    Enabled: Fusion.UsedAs<boolean>?,
    ClickableWhenViewportHidden: Fusion.UsedAs<boolean>?,
    [Fusion.SpecialKey]: any
}

type Props = Typeforge.FlattenTable<ToolbarButtonProps & Fusion.PropertyTable>

type ToolbarButtonChild = {
    _MosaicToolbarButton: true,
    Mount: (PluginToolbar) -> PluginToolbarButton
}

return function(
    scope: Fusion.Scope,
    props: ToolbarButtonProps,
    ...: Fusion.PropertyTable
): ToolbarButtonChild
    local props = (CombineProps(props, ...) :: any) :: Props
    local props, id = TableExtract(props, "Id")
    local props, tooltip = TableExtract(props, "Tooltip")
    local props, text = TableExtract(props, "Text")
    local props, icon = TableExtract(props, "Icon", "")
    local props, active = TableExtract(props, "Active")
    local icon = icon :: Fusion.UsedAs<string>

    local toolbarButtonChild: ToolbarButtonChild = {
        _MosaicToolbarButton = true,
        Mount = function(toolbar: PluginToolbar): PluginToolbarButton
            local button = toolbar:CreateButton(
                id,
                tooltip,
                Peek<<string>>(icon),
                text or id
            )
            local hydratedButton = Hydrate(scope, button)(CombineProps({
                Icon = icon
            }, props))

            if active ~= nil then
                local active = active :: Fusion.UsedAs<boolean>

                Observer(scope, active):onBind(function()
                    button:SetActive(Peek<<boolean>>(active))
                end)
            end

            return hydratedButton :: PluginToolbarButton
        end
    }

    return toolbarButtonChild
end
