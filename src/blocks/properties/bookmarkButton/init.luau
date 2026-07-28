--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, OnEvent, Peek =
    Fusion.Computed, Fusion.OnEvent, Fusion.peek

local Mosaic = require(Packages.mosaic)
local IconButton = Mosaic.IconButton

local FusionUtils = require(Packages.mosaic.utils.fusionUtils)
local Component, CoerceToValue, ComposeTransparency =
    FusionUtils.Component, FusionUtils.CoerceToValue,
    FusionUtils.ComposeTransparency

local TableUtils = require(Packages.mosaic.utils.tableUtils)
local TableExtract = TableUtils.Extract

local Assets = require(script.Parent.Parent.Parent.assets)

type BookmarkButtonProps = {
    Bookmarked: Fusion.UsedAs<boolean>?,
    Transparency: Fusion.UsedAs<number>?,
    Disabled: Fusion.UsedAs<boolean>?,
    OnChanged: ((bookmarked: boolean) -> ())?
}

local DisabledTransparency = 0.5

return Component<<BookmarkButtonProps>>(function(scope, props)
    local props, bookmarked =
        TableExtract(props, "Bookmarked", false)
    local props, transparency =
        TableExtract(props, "Transparency", 0)
    local props, disabled = TableExtract(props, "Disabled", false)
    local props, onChanged = TableExtract(props, "OnChanged")

    local bookmarkedState =
        CoerceToValue<<boolean>>(scope, bookmarked)
    local image = Computed(scope, function(use): string
        return
            if use<<boolean>>(bookmarkedState)
            then Assets.BookmarkFill
            else Assets.BookmarkOutlineThin
    end)
    local interactable = Computed(scope, function(use): boolean
        return not use<<boolean>>(disabled)
    end)
    local disabledTransparency = Computed(scope, function(use): number
        return
            if use<<boolean>>(disabled)
            then DisabledTransparency
            else 0
    end)
    local imageTransparency = ComposeTransparency(
        scope,
        transparency,
        disabledTransparency
    )

    return IconButton(scope, {
        Image = image,
        ImageTransparency = imageTransparency,
        Interactable = interactable,

        [OnEvent "MouseButton1Click"] = function()
            if Peek<<boolean>>(disabled) then return end

            local nextBookmarked =
                not Peek<<boolean>>(bookmarkedState)
            if onChanged then
                onChanged(nextBookmarked)
                return
            end

            bookmarkedState:set(nextBookmarked)
        end,

        Name = "BookmarkButton"
    }, props)
end)
