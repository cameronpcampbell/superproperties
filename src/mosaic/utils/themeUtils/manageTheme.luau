--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Types = require(script.Parent.types)
local DefaultTheme = require(script.Parent.defaultTheme)

local Value = Fusion.Value

local ThemeForScopes: { [Fusion.Scope]: Fusion.Value<Types.Theme> } = {}

local function CreateThemeForScope(scope: Fusion.Scope, theme: Types.Theme)
    table.insert(scope, function()
        ThemeForScopes[scope] = nil
    end)

    local themeState = Value(scope, theme)
    ThemeForScopes[scope] = themeState

    return themeState
end

local function SetThemeForScope(scope: Fusion.Scope, theme: Types.Theme)
    if not ThemeForScopes[scope] then
        CreateThemeForScope(scope, theme)

    else
         ThemeForScopes[scope]:set(theme)
    end

end

local function GetThemeForScope(scope: Fusion.Scope): Fusion.UsedAs<Types.Theme>
    local themeState = ThemeForScopes[scope]

    if not themeState then
        themeState = CreateThemeForScope(scope, DefaultTheme)
    end

    return themeState
end

return {
    SetThemeForScope = SetThemeForScope,
    GetThemeForScope = GetThemeForScope
}
