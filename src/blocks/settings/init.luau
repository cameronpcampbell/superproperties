--!strict

local Packages = script.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local SettingKeys = {
    TintHeaders = "SuperProperties.TintHeaders",
    ShowNonScriptableProperties =
        "SuperProperties.ShowNonScriptableProperties"
}

export type State = {
    TintHeaders: Fusion.Value<boolean>,
    ShowNonScriptableProperties: Fusion.Value<boolean>
}

local function GetPlugin(): Plugin
    local plugin = script:FindFirstAncestorOfClass("Plugin")
    assert(plugin, "Settings must be created from inside a Plugin")
    return plugin
end

local function LoadBoolean(
    plugin: Plugin,
    key: string,
    defaultValue: boolean
): boolean
    local success, value = pcall(plugin.GetSetting, plugin, key)
    if success and type(value) == "boolean" then
        return value
    end

    return defaultValue
end

local function CreateState(scope: Fusion.Scope): State
    local plugin = GetPlugin()

    return {
        TintHeaders = Value(
            scope,
            LoadBoolean(plugin, SettingKeys.TintHeaders, false)
        ),
        ShowNonScriptableProperties = Value(
            scope,
            LoadBoolean(
                plugin,
                SettingKeys.ShowNonScriptableProperties,
                true
            )
        )
    }
end

local function CreateTrySetValue(
    plugin: Plugin,
    key: string,
    state: Fusion.Value<boolean>
): (any) -> (boolean, string?, any?)
    return function(value: any): (boolean, string?, any?)
        if type(value) ~= "boolean" then
            return false, "Setting values must be boolean."
        end

        local success, err = pcall(plugin.SetSetting, plugin, key, value)
        if not success then
            return false, tostring(err)
        end

        state:set(value)
        return true, nil, value
    end
end

local function CreateMap(
    scope: Fusion.Scope,
    state: State
): Fusion.Child
    local plugin = GetPlugin()
    local items: { Item } = {
        {
            Key = "Tint Headers",
            Value = state.TintHeaders,
            ValueType = "boolean",
            ValueWritable = true,
            TrySetValue = CreateTrySetValue(
                plugin,
                SettingKeys.TintHeaders,
                state.TintHeaders
            )
        },
        {
            Key = "Show Non Scriptable Properties",
            Value = state.ShowNonScriptableProperties,
            ValueType = "boolean",
            ValueWritable = true,
            TrySetValue = CreateTrySetValue(
                plugin,
                SettingKeys.ShowNonScriptableProperties,
                state.ShowNonScriptableProperties
            )
        }
    }

    return Map(scope, {
        Header = "Settings",
        HeaderColorTint = false,
        Collapsible = false,
        Items = items
    })
end

return {
    CreateState = CreateState,
    Map = CreateMap
}
