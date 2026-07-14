--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Children, Hydrate = Fusion.Children, Fusion.Hydrate

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps = FusionUtils.CombineProps

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type ToolbarProps = {
    Name: string,
    [Fusion.SpecialKey]: any
}

type Props = Typeforge.FlattenTable<ToolbarProps & Fusion.PropertyTable>

type ToolbarButtonChild = {
    _MosaicToolbarButton: true,
    Mount: (PluginToolbar) -> PluginToolbarButton
}

local function MountChildren(toolbar: PluginToolbar, children: any)
    if children == nil then return end

    if typeof(children) ~= "table" then
        error("Toolbar children must be ToolbarButton components", 3)
    end

    local toolbarButtonChild = children :: ToolbarButtonChild

    if toolbarButtonChild._MosaicToolbarButton then
        toolbarButtonChild.Mount(toolbar)
        return
    end

    for _, child in children do
        MountChildren(toolbar, child)
    end
end

return function(
    scope: Fusion.Scope,
    props: ToolbarProps,
    ...: Fusion.PropertyTable
): PluginToolbar
    local props = (CombineProps(props, ...) :: any) :: Props
    local props, name = TableExtract(props, "Name")
    local props, children = TableExtract(props, Children)

    local plugin = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
    assert(plugin, "Toolbar must be created from inside a Plugin")

    local toolbar = plugin:CreateToolbar(name)
    local hydratedToolbar = Hydrate(scope, toolbar)(props :: any) :: PluginToolbar

    MountChildren(hydratedToolbar, children)

    return hydratedToolbar
end
