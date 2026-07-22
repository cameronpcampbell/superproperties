--!strict

local Components = script.components
local CoreComponents = script.coreComponents

local Utils = script.utils
local ThemeUtils = require(Utils.themeUtils)

export type Theme = ThemeUtils.Theme

return {
    -- Plugin.
    Widget = require(Components.widget),
    Toolbar = require(Components.toolbar),
    ToolbarButton = require(Components.toolbarButton),

    -- Containers.
    Background = require(Components.background),
    Container = require(Components.container),

    -- Inputs.
    Input = require(Components.input),
    Select = require(Components.select),

    -- Buttons.
    Button = require(Components.button),
    IconButton = require(Components.iconButton),
    Checkbox = require(Components.checkbox),

    -- Map.
    Map = require(Components.map),
    VirtualMapScrollable = require(Components.virtualMapScrollable),

    -- Misc.
    Scrollable = require(Components.scrollable),
    SelectMenu = require(Components.selectMenu),
    Icon = require(Components.icon),
    Text = require(Components.text),

    -- Core components.
    PopoverFocus = require(CoreComponents.popoverFocus),

    -- Utils.
    GetTheme = ThemeUtils.GetThemeForScope,
    SetTheme = ThemeUtils.SetThemeForScope,
    DefaultThemeConfig = ThemeUtils.DefaultThemeConfig,
    CreateItemFilter = require(Utils.filterItems)
}
