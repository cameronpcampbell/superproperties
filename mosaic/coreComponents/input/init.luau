--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local New, Value, Computed, OnEvent =
    Fusion.New, Fusion.Value, Fusion.Computed, Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type InputProps = {
    TextTruncate: Fusion.UsedAs<Enum.TextTruncate>?,
    [any]: any
}

type FocusedCallback = () -> ()
type FocusLostCallback = (boolean, InputObject?) -> ()

local FocusedEvent = OnEvent "Focused"
local FocusLostEvent = OnEvent "FocusLost"

return Component<<InputProps>>(function(scope, props)
    local props, textTruncate =
        TableExtract(props, "TextTruncate", Enum.TextTruncate.AtEnd)
    local props, focusedCallback = TableExtract(props, FocusedEvent)
    local props, focusLostCallback = TableExtract(props, FocusLostEvent)

    local onFocused = focusedCallback :: FocusedCallback?
    local onFocusLost = focusLostCallback :: FocusLostCallback?
    local isFocusState = Value(scope, false)

    local computedTextTruncate = Computed(scope, function(use)
        return
            if use<<boolean>>(isFocusState) then
                Enum.TextTruncate.None
            else
                use<<Enum.TextTruncate>>(textTruncate)
    end)

    return New(scope, "TextBox")(CombineProps({
        TextTruncate = computedTextTruncate,

        [FocusedEvent] = function()
            isFocusState:set(true)
            if onFocused then onFocused() end
        end,

        [FocusLostEvent] = function(
            enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            isFocusState:set(false)
            if onFocusLost then
                onFocusLost(enterPressed, inputThatCausedFocusLoss)
            end
        end
    }, props))
end)
