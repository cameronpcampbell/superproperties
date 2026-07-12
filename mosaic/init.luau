--!strict

local Components = script.components

local Utils = script.utils
local ThemeUtils = require(Utils.themeUtils)

export type Theme = ThemeUtils.Theme

return {
    Widget = require(Components.widget),
    Background = require(Components.background),
    Input = require(Components.input),
    Button = require(Components.button),
    IconButton = require(Components.iconButton),
    Icon = require(Components.icon),
    Text = require(Components.text),
    Map = require(Components.map),
    Scrollable = require(Components.scrollable),
    Checkbox = require(Components.checkbox),

    GetTheme = ThemeUtils.GetThemeForScope,
    SetTheme = ThemeUtils.SetThemeForScope
}
